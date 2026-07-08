param(
  [string]$ConfigPath = ".\config\hotel-monitor.json",
  [string]$OutputRoot = ".\data\api-combo",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $repoRoot $ConfigPath }
$resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot } else { Join-Path $repoRoot $OutputRoot }

function Get-EnvValue {
  param([string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
  }
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    Set-Item -Path "env:$Name" -Value $value
  }
  return $value
}

function Assert-Text {
  param([object]$Value, [string]$Name)
  if ([string]::IsNullOrWhiteSpace([string]$Value)) {
    throw "$Name is required in $resolvedConfigPath"
  }
}

function Get-Config {
  if (-not (Test-Path -LiteralPath $resolvedConfigPath)) {
    throw "Config file not found: $resolvedConfigPath. Copy config/hotel-monitor.example.json to config/hotel-monitor.json first."
  }
  return [System.IO.File]::ReadAllText($resolvedConfigPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Get-QueryDates {
  param([pscustomobject]$Config)
  if ($Config.query.checkInDate -and $Config.query.checkOutDate) {
    return [ordered]@{ CheckIn = [string]$Config.query.checkInDate; CheckOut = [string]$Config.query.checkOutDate }
  }
  $offsetDays = if ($null -ne $Config.query.offsetDays) { [int]$Config.query.offsetDays } else { 7 }
  $nights = if ($null -ne $Config.query.nights) { [int]$Config.query.nights } else { 1 }
  $checkIn = (Get-Date).Date.AddDays($offsetDays)
  return [ordered]@{ CheckIn = $checkIn.ToString("yyyy-MM-dd"); CheckOut = $checkIn.AddDays($nights).ToString("yyyy-MM-dd") }
}

function Invoke-JsonGet {
  param(
    [string]$Uri,
    [string]$OutputPath,
    [string]$DryRunText
  )
  if ($DryRun) {
    [System.IO.File]::WriteAllText($OutputPath, $DryRunText, [System.Text.Encoding]::UTF8)
    return $DryRunText | ConvertFrom-Json
  }
  $response = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 30
  [System.IO.File]::WriteAllText($OutputPath, ($response | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
  return $response
}

function Get-AmapHome {
  param([pscustomobject]$Config, [string]$ApiKey, [string]$OutputDir)
  $uri = "https://restapi.amap.com/v5/place/text?key=$([uri]::EscapeDataString($ApiKey))&keywords=$([uri]::EscapeDataString($Config.homeHotelName))&region=$([uri]::EscapeDataString($Config.city))&city_limit=true&page_size=10&page_num=1&show_fields=business,photos"
  $dry = '{"status":"1","count":"1","pois":[{"id":"DRY_AMAP_HOME","name":"桔子水晶上海江桥万达酒店","type":"住宿服务;宾馆酒店;四星级宾馆","address":"鹤旋东路188弄","location":"121.326969,31.238614","business":{"rating":"4.6","tag":"高档型","business_area":"上海虹桥商务区"},"distance":"0"}]}'
  $result = Invoke-JsonGet -Uri $uri -OutputPath (Join-Path $OutputDir "amap-home.json") -DryRunText $dry
  if ($result.status -ne "1" -or -not $result.pois -or @($result.pois).Count -eq 0) {
    throw "Amap home search returned no POI."
  }
  return @($result.pois)[0]
}

function Get-AmapNearby {
  param([pscustomobject]$Config, [string]$ApiKey, [pscustomobject]$HomePoi, [string]$OutputDir)
  $radius = if ($Config.discovery.radiusMeters) { [int]$Config.discovery.radiusMeters } else { 2000 }
  $pageSize = 25
  $location = [string]$HomePoi.location
  $uri = "https://restapi.amap.com/v5/place/around?key=$([uri]::EscapeDataString($ApiKey))&location=$([uri]::EscapeDataString($location))&radius=$radius&types=100100&page_size=$pageSize&page_num=1&sortrule=distance&show_fields=business,photos"
  $dry = '{"status":"1","count":"3","pois":[{"id":"DRY_AMAP_1","name":"全季上海江桥万达广场酒店","type":"住宿服务;宾馆酒店","address":"鹤望路733弄2号","location":"121.316,31.2439","distance":"1200","business":{"rating":"4.8","tag":"舒适型","business_area":"江桥"}},{"id":"DRY_AMAP_2","name":"汉庭上海国家会展中心金运路酒店","type":"住宿服务;宾馆酒店","address":"华江路","location":"121.329,31.242","distance":"650","business":{"rating":"4.7","tag":"经济型","business_area":"江桥"}},{"id":"DRY_AMAP_3","name":"上海福家甄选主题公寓（江桥万达店）","type":"住宿服务;旅馆招待所","address":"万达十号写字楼","location":"121.325,31.239","distance":"220","business":{"rating":"4.5","tag":"公寓","business_area":"江桥"}}]}'
  $result = Invoke-JsonGet -Uri $uri -OutputPath (Join-Path $OutputDir "amap-nearby.json") -DryRunText $dry
  if ($result.status -ne "1") {
    throw "Amap nearby search failed."
  }
  return @($result.pois)
}

function Get-BusinessValue {
  param([object]$Business, [string]$Name)
  if ($null -eq $Business) { return "" }
  if ($Business.PSObject.Properties[$Name]) { return [string]$Business.$Name }
  return ""
}

function Get-HotelType {
  param([string]$Name, [string]$Type)
  $text = "$Name $Type"
  if ($text -match "公寓|民宿|电竞|青年|旅舍|客栈") { return "替代住宿" }
  if ($text -match "停车场|大堂|前台|写字楼|商场") { return "噪音" }
  return "标准酒店"
}

function Convert-AmapCandidate {
  param([pscustomobject]$Poi)
  $business = $Poi.business
  $distance = if ($Poi.distance) { [int]$Poi.distance } else { 999999 }
  $hotelType = Get-HotelType -Name ([string]$Poi.name) -Type ([string]$Poi.type)
  return [ordered]@{
    hotel_name = [string]$Poi.name
    amap_id = [string]$Poi.id
    address = [string]$Poi.address
    location = [string]$Poi.location
    distance_m = $distance
    business_area = Get-BusinessValue -Business $business -Name "business_area"
    amap_type = [string]$Poi.type
    amap_level = Get-BusinessValue -Business $business -Name "tag"
    amap_rating = Get-BusinessValue -Business $business -Name "rating"
    hotel_type = $hotelType
    fliggy_price = ""
    fliggy_detail_url = ""
    baidu_uid = ""
    baidu_rating = ""
    baidu_comment_num = ""
    facility_rating = ""
    hygiene_rating = ""
    service_rating = ""
    image_num = ""
    comp_tier = ""
    reason = ""
  }
}

function Test-Excluded {
  param([System.Collections.IDictionary]$Candidate, [string[]]$ExcludeKeywords)
  foreach ($keyword in $ExcludeKeywords) {
    if (-not [string]::IsNullOrWhiteSpace($keyword) -and $Candidate.hotel_name -like "*$keyword*") {
      return $true
    }
  }
  return $false
}

function Join-CommandLine {
  param([string[]]$FlyArgs)
  $quoted = $FlyArgs | ForEach-Object { if ($_ -match "\s") { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }
  return "flyai " + ($quoted -join " ")
}

function ConvertFrom-FlyAIOutput {
  param([string]$Output)
  foreach ($line in ($Output -split "\r?\n")) {
    $trimmed = $line.Trim()
    if (-not ($trimmed.StartsWith("{") -and $trimmed.EndsWith("}"))) { continue }
    try {
      $obj = $trimmed | ConvertFrom-Json -ErrorAction Stop
      if ($obj.PSObject.Properties["status"] -and [int]$obj.status -eq 0) {
        return $obj
      }
    } catch {
    }
  }
  return $null
}

function Invoke-FlyAIPrice {
  param(
    [pscustomobject]$Config,
    [System.Collections.IDictionary]$Dates,
    [string]$Keyword,
    [string]$OutputPath
  )
  $args = @("search-hotel", "--dest-name", [string]$Config.city, "--check-in-date", [string]$Dates.CheckIn, "--check-out-date", [string]$Dates.CheckOut, "--key-words", $Keyword, "--sort", "distance_asc")
  if ($DryRun) {
    $dry = '{"data":{"itemList":[{"name":"' + ($Keyword -replace '"','') + '","price":"¥399","detailUrl":"https://a.feizhu.com/dry","star":"舒适型"}]},"message":"success","status":0}'
    [System.IO.File]::WriteAllText($OutputPath, $dry, [System.Text.Encoding]::UTF8)
    return $dry | ConvertFrom-Json
  }
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & flyai @args 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($exitCode -ne 0 -and $output -notmatch '"status"\s*:\s*0') {
    [System.IO.File]::WriteAllText($OutputPath, $output, [System.Text.Encoding]::UTF8)
    return $null
  }
  [System.IO.File]::WriteAllText($OutputPath, $output, [System.Text.Encoding]::UTF8)
  return ConvertFrom-FlyAIOutput -Output $output
}

function Merge-FlyAIPrice {
  param([System.Collections.IDictionary]$Candidate, [object]$FlyResult)
  if ($null -eq $FlyResult -or -not $FlyResult.data.itemList) { return }
  $first = @($FlyResult.data.itemList)[0]
  $Candidate.fliggy_price = [string]$first.price
  $Candidate.fliggy_detail_url = [string]$first.detailUrl
  if (-not $Candidate.amap_level -and $first.star) { $Candidate.amap_level = [string]$first.star }
}

function Invoke-BaiduSearch {
  param([pscustomobject]$Config, [string]$Ak, [System.Collections.IDictionary]$Candidate, [string]$OutputPath)
  $uri = "https://api.map.baidu.com/place/v2/search?query=$([uri]::EscapeDataString($Candidate.hotel_name))&tag=$([uri]::EscapeDataString("酒店"))&region=$([uri]::EscapeDataString($Config.city))&output=json&scope=2&ak=$([uri]::EscapeDataString($Ak))"
  $dry = '{"status":0,"results":[{"uid":"DRY_BAIDU_UID","name":"' + ($Candidate.hotel_name -replace '"','') + '","detail_info":{"overall_rating":"4.8","comment_num":"51","facility_rating":"4.8","hygiene_rating":"4.8","service_rating":"4.8","image_num":"49","brand":"示例品牌","level":"舒适型"}}]}'
  return Invoke-JsonGet -Uri $uri -OutputPath $OutputPath -DryRunText $dry
}

function Invoke-BaiduDetail {
  param([string]$Ak, [string]$Uid, [string]$OutputPath)
  $uri = "https://api.map.baidu.com/place/v2/detail?uid=$([uri]::EscapeDataString($Uid))&output=json&scope=2&ak=$([uri]::EscapeDataString($Ak))"
  $dry = '{"status":0,"result":{"uid":"DRY_BAIDU_UID","detail_info":{"overall_rating":"4.8","comment_num":"51","facility_rating":"4.8","hygiene_rating":"4.8","service_rating":"4.8","image_num":"49","brand":"示例品牌","level":"舒适型"}}}'
  return Invoke-JsonGet -Uri $uri -OutputPath $OutputPath -DryRunText $dry
}

function Normalize-HotelName {
  param([string]$Name)
  $text = $Name.ToLowerInvariant()
  $text = $text -replace "（.*?）", ""
  $text = $text -replace "\(.*?\)", ""
  $text = $text -replace "上海|酒店|宾馆|公寓|民宿|连锁|式|店|广场|机场|国家会展中心|国展中心", ""
  $text = $text -replace "[^\p{IsCJKUnifiedIdeographs}a-z0-9]", ""
  return $text
}

function Test-NameCompatible {
  param([string]$CandidateName, [string]$ResultName)
  if ([string]::IsNullOrWhiteSpace($CandidateName) -or [string]::IsNullOrWhiteSpace($ResultName)) { return $false }
  $candidate = Normalize-HotelName -Name $CandidateName
  $result = Normalize-HotelName -Name $ResultName
  if ($candidate.Length -lt 2 -or $result.Length -lt 2) { return $false }
  if ($candidate.Contains($result) -or $result.Contains($candidate)) { return $true }
  $prefixLength = [Math]::Min(4, $candidate.Length)
  if ($prefixLength -ge 2 -and $result.Contains($candidate.Substring(0, $prefixLength))) { return $true }
  return $false
}

function Test-BaiduHotelResult {
  param([object]$Result, [string]$CandidateName)
  if ($null -eq $Result) { return $false }
  $name = [string]$Result.name
  $info = $Result.detail_info
  $tag = if ($info) { [string]$info.tag + " " + [string]$info.classified_poi_tag + " " + [string]$info.type } else { "" }
  $text = "$name $tag"
  if ($text -notmatch "酒店|宾馆|住宿|民宿|公寓|hotel") { return $false }
  if (-not [string]::IsNullOrWhiteSpace($CandidateName) -and -not (Test-NameCompatible -CandidateName $CandidateName -ResultName $name)) {
    return $false
  }
  return $true
}

function Get-BaiduHotelResult {
  param([object]$SearchResult, [string]$CandidateName)
  if ($null -eq $SearchResult -or -not $SearchResult.results) { return $null }
  foreach ($result in @($SearchResult.results)) {
    if (Test-BaiduHotelResult -Result $result -CandidateName $CandidateName) {
      return $result
    }
  }
  return $null
}

function Merge-BaiduInfo {
  param([System.Collections.IDictionary]$Candidate, [object]$SearchResult, [object]$DetailResult)
  $first = Get-BaiduHotelResult -SearchResult $SearchResult -CandidateName $Candidate.hotel_name
  if ($null -ne $first) {
    $Candidate.baidu_uid = [string]$first.uid
    if ($first.detail_info) {
      $Candidate.baidu_rating = [string]$first.detail_info.overall_rating
      $Candidate.baidu_comment_num = [string]$first.detail_info.comment_num
      $Candidate.facility_rating = [string]$first.detail_info.facility_rating
      $Candidate.hygiene_rating = [string]$first.detail_info.hygiene_rating
      $Candidate.service_rating = [string]$first.detail_info.service_rating
      $Candidate.image_num = [string]$first.detail_info.image_num
    }
  }
  if ($null -ne $DetailResult -and $DetailResult.result.detail_info) {
    $info = $DetailResult.result.detail_info
    $Candidate.baidu_rating = [string]$info.overall_rating
    $Candidate.baidu_comment_num = [string]$info.comment_num
    $Candidate.facility_rating = [string]$info.facility_rating
    $Candidate.hygiene_rating = [string]$info.hygiene_rating
    $Candidate.service_rating = [string]$info.service_rating
    $Candidate.image_num = [string]$info.image_num
  }
}

function Get-PriceNumber {
  param([string]$Price)
  $digits = [regex]::Match($Price, '\d+').Value
  if ($digits) { return [int]$digits }
  return 0
}

function Get-RuleNumber {
  param([object]$Rules, [string]$Name, [double]$Default)
  if ($null -ne $Rules -and $Rules.PSObject.Properties[$Name] -and $null -ne $Rules.$Name) {
    return [double]$Rules.$Name
  }
  return $Default
}

function Get-RuleBool {
  param([object]$Rules, [string]$Name, [bool]$Default)
  if ($null -ne $Rules -and $Rules.PSObject.Properties[$Name] -and $null -ne $Rules.$Name) {
    return [bool]$Rules.$Name
  }
  return $Default
}

function Get-TierRules {
  param([pscustomobject]$Config)
  $rules = $Config.tierRules
  return [ordered]@{
    coreRadiusMeters = [int](Get-RuleNumber -Rules $rules -Name "coreRadiusMeters" -Default 2000)
    pricePressureRatio = Get-RuleNumber -Rules $rules -Name "pricePressureRatio" -Default 0.75
    qualityRatingThreshold = Get-RuleNumber -Rules $rules -Name "qualityRatingThreshold" -Default 4.7
    qualityRadiusMeters = [int](Get-RuleNumber -Rules $rules -Name "qualityRadiusMeters" -Default 2500)
    includeAlternativeLodging = Get-RuleBool -Rules $rules -Name "includeAlternativeLodging" -Default $true
  }
}

function Get-HistoryRoot {
  param([pscustomobject]$Config)
  $directory = if ($Config.history.directory) { [string]$Config.history.directory } else { ".\data\history" }
  if ([System.IO.Path]::IsPathRooted($directory)) { return $directory }
  return Join-Path $repoRoot $directory
}

function Get-HistoryEnabled {
  param([pscustomobject]$Config)
  if ($null -eq $Config.history) { return $true }
  if ($null -eq $Config.history.enabled) { return $true }
  return [bool]$Config.history.enabled
}

function Get-QueryKey {
  param([pscustomobject]$Config, [System.Collections.IDictionary]$Dates)
  $mode = if ($Config.query.checkInDate -and $Config.query.checkOutDate) { "fixed-date" } else { "rolling-offset" }
  $offset = if ($null -ne $Config.query.offsetDays) { [string]$Config.query.offsetDays } else { "7" }
  $parts = @(
    [string]$Config.city,
    [string]$Config.homeHotelName,
    [string]$Config.poiName,
    $mode,
    $offset,
    [string]$Config.query.nights,
    [string]$Config.query.rooms,
    [string]$Config.query.adults,
    [string]$Config.query.children,
    [string]$Config.query.roomType
  )
  if ($mode -eq "fixed-date") {
    $parts += [string]$Dates.CheckIn
    $parts += [string]$Dates.CheckOut
  }
  return ($parts -join "|").ToLowerInvariant()
}

function Get-HotelKey {
  param([System.Collections.IDictionary]$Hotel)
  if ($Hotel.amap_id) { return "amap:" + [string]$Hotel.amap_id }
  if ($Hotel.baidu_uid) { return "baidu:" + [string]$Hotel.baidu_uid }
  return "name:" + (Normalize-HotelName -Name ([string]$Hotel.hotel_name))
}

function Convert-ToHistoryHotel {
  param([System.Collections.IDictionary]$Hotel, [string]$Role)
  return [ordered]@{
    role = $Role
    key = Get-HotelKey -Hotel $Hotel
    hotel_name = [string]$Hotel.hotel_name
    amap_id = [string]$Hotel.amap_id
    baidu_uid = [string]$Hotel.baidu_uid
    address = [string]$Hotel.address
    distance_m = $Hotel.distance_m
    hotel_type = [string]$Hotel.hotel_type
    comp_tier = [string]$Hotel.comp_tier
    fliggy_price = [string]$Hotel.fliggy_price
    fliggy_price_num = Get-PriceNumber -Price ([string]$Hotel.fliggy_price)
    amap_rating = [string]$Hotel.amap_rating
    baidu_rating = [string]$Hotel.baidu_rating
    baidu_comment_num = [string]$Hotel.baidu_comment_num
    facility_rating = [string]$Hotel.facility_rating
    hygiene_rating = [string]$Hotel.hygiene_rating
    service_rating = [string]$Hotel.service_rating
  }
}

function New-HistorySnapshot {
  param([pscustomobject]$Config, [System.Collections.IDictionary]$Dates, [System.Collections.IDictionary]$HomeHotel, [array]$Candidates)
  $hotels = @()
  $hotels += Convert-ToHistoryHotel -Hotel $HomeHotel -Role "本店"
  foreach ($candidate in $Candidates) {
    $hotels += Convert-ToHistoryHotel -Hotel $candidate -Role "竞品"
  }
  return [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date -Format s)
    runDate = (Get-Date -Format "yyyy-MM-dd")
    dryRun = [bool]$DryRun
    query = [ordered]@{
      key = Get-QueryKey -Config $Config -Dates $Dates
      city = [string]$Config.city
      homeHotelName = [string]$Config.homeHotelName
      poiName = [string]$Config.poiName
      checkIn = [string]$Dates.CheckIn
      checkOut = [string]$Dates.CheckOut
      offsetDays = if ($null -ne $Config.query.offsetDays) { [int]$Config.query.offsetDays } else { $null }
      nights = if ($null -ne $Config.query.nights) { [int]$Config.query.nights } else { 1 }
      rooms = if ($null -ne $Config.query.rooms) { [int]$Config.query.rooms } else { 1 }
      adults = if ($null -ne $Config.query.adults) { [int]$Config.query.adults } else { 1 }
      children = if ($null -ne $Config.query.children) { [int]$Config.query.children } else { 0 }
      roomType = [string]$Config.query.roomType
    }
    hotels = $hotels
  }
}

function Get-PreviousHistorySnapshot {
  param([string]$HistoryRoot, [string]$QueryKey)
  if (-not (Test-Path -LiteralPath $HistoryRoot)) { return $null }
  $today = Get-Date -Format "yyyy-MM-dd"
  $files = Get-ChildItem -LiteralPath $HistoryRoot -Filter "*.json" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -lt $today } |
    Sort-Object Name -Descending
  foreach ($file in $files) {
    try {
      $snapshot = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
      if ($snapshot.query.key -eq $QueryKey) {
        return [ordered]@{ Path = $file.FullName; Snapshot = $snapshot }
      }
    } catch {
    }
  }
  return $null
}

function Compare-Price {
  param([int]$TodayPrice, [int]$PreviousPrice)
  if ($TodayPrice -le 0 -and $PreviousPrice -le 0) { return [ordered]@{ Trend = "价格缺失"; Delta = ""; DeltaPct = "" } }
  if ($TodayPrice -le 0) { return [ordered]@{ Trend = "今日价格缺失"; Delta = ""; DeltaPct = "" } }
  if ($PreviousPrice -le 0) { return [ordered]@{ Trend = "新增价格"; Delta = ""; DeltaPct = "" } }
  $delta = $TodayPrice - $PreviousPrice
  $trend = if ($delta -gt 0) { "涨价" } elseif ($delta -lt 0) { "降价" } else { "持平" }
  $pct = if ($PreviousPrice -gt 0) { [Math]::Round(($delta / $PreviousPrice) * 100, 1) } else { 0 }
  return [ordered]@{ Trend = $trend; Delta = $delta; DeltaPct = "$pct%" }
}

function Compare-HistorySnapshots {
  param([object]$CurrentSnapshot, [object]$PreviousSnapshotInfo, [bool]$HistoryEnabled)
  if (-not $HistoryEnabled) {
    return [ordered]@{
      hasBaseline = $false
      baselinePath = ""
      baselineRunDate = ""
      summary = "历史对比未启用，本次只输出今日横截面。"
      rows = @()
    }
  }
  if ($null -eq $PreviousSnapshotInfo) {
    return [ordered]@{
      hasBaseline = $false
      baselinePath = ""
      baselineRunDate = ""
      summary = "无同口径历史快照，本次只输出今日横截面。"
      rows = @()
    }
  }

  $previous = $PreviousSnapshotInfo.Snapshot
  $previousByKey = @{}
  foreach ($hotel in @($previous.hotels)) {
    if ($hotel.key) { $previousByKey[[string]$hotel.key] = $hotel }
  }

  $rows = @()
  $up = 0
  $down = 0
  $same = 0
  $newPrice = 0
  $missingPrice = 0
  foreach ($hotel in @($CurrentSnapshot.hotels)) {
    $previousHotel = $previousByKey[[string]$hotel.key]
    $previousPrice = if ($previousHotel) { [int]$previousHotel.fliggy_price_num } else { 0 }
    $comparison = Compare-Price -TodayPrice ([int]$hotel.fliggy_price_num) -PreviousPrice $previousPrice
    if ($comparison.Trend -eq "涨价") { $up++ }
    if ($comparison.Trend -eq "降价") { $down++ }
    if ($comparison.Trend -eq "持平") { $same++ }
    if ($comparison.Trend -eq "新增价格") { $newPrice++ }
    if ($comparison.Trend -eq "价格缺失" -or $comparison.Trend -eq "今日价格缺失") { $missingPrice++ }
    $rows += [ordered]@{
      role = [string]$hotel.role
      hotel_name = [string]$hotel.hotel_name
      comp_tier = [string]$hotel.comp_tier
      today_price = [string]$hotel.fliggy_price
      previous_price = if ($previousHotel) { [string]$previousHotel.fliggy_price } else { "" }
      price_delta = [string]$comparison.Delta
      price_delta_pct = [string]$comparison.DeltaPct
      trend = [string]$comparison.Trend
      today_baidu_comment_num = [string]$hotel.baidu_comment_num
      previous_baidu_comment_num = if ($previousHotel) { [string]$previousHotel.baidu_comment_num } else { "" }
    }
  }

  return [ordered]@{
    hasBaseline = $true
    baselinePath = [string]$PreviousSnapshotInfo.Path
    baselineRunDate = [string]$previous.runDate
    summary = "同口径历史对比：涨价 $up 家，降价 $down 家，持平 $same 家，新增价格 $newPrice 家，价格缺失 $missingPrice 家。"
    rows = $rows
  }
}

function Save-HistorySnapshot {
  param([string]$HistoryRoot, [object]$Snapshot, [bool]$HistoryEnabled)
  if ($DryRun -or -not $HistoryEnabled) { return "" }
  New-Item -ItemType Directory -Force -Path $HistoryRoot | Out-Null
  $snapshotPath = Join-Path $HistoryRoot "$($Snapshot.runDate).json"
  [System.IO.File]::WriteAllText($snapshotPath, ($Snapshot | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
  return $snapshotPath
}

function Set-CompTier {
  param([System.Collections.IDictionary]$Candidate, [int]$HomePrice, [System.Collections.IDictionary]$Rules)
  $price = Get-PriceNumber -Price $Candidate.fliggy_price
  $rating = if ($Candidate.baidu_rating) { [double]$Candidate.baidu_rating } elseif ($Candidate.amap_rating) { [double]$Candidate.amap_rating } else { 0 }
  if ($Candidate.hotel_type -eq "噪音") {
    $Candidate.comp_tier = "剔除"
    $Candidate.reason = "非住宿或无关 POI"
  } elseif ($Candidate.hotel_type -eq "替代住宿") {
    if ($Rules.includeAlternativeLodging) {
      $Candidate.comp_tier = "替代竞品"
      $Candidate.reason = "距离近但业态不是标准酒店"
    } else {
      $Candidate.comp_tier = "剔除"
      $Candidate.reason = "配置为不纳入公寓、民宿等替代住宿"
    }
  } elseif ($HomePrice -gt 0 -and $price -gt 0 -and $price -lt [int]($HomePrice * $Rules.pricePressureRatio)) {
    $Candidate.comp_tier = "价格压力"
    $Candidate.reason = "价格明显低于本店"
  } elseif ($rating -ge $Rules.qualityRatingThreshold -and $Candidate.distance_m -le $Rules.qualityRadiusMeters) {
    $Candidate.comp_tier = "品质压力"
    $Candidate.reason = "评分较高且距离可比"
  } elseif ($Candidate.distance_m -le $Rules.coreRadiusMeters) {
    $Candidate.comp_tier = "核心竞品"
    $Candidate.reason = "距离近且属于标准住宿"
  } else {
    $Candidate.comp_tier = "延展竞品"
    $Candidate.reason = "距离稍远但可能共享客源"
  }
}

function Write-ReportInput {
  param(
    [pscustomobject]$Config,
    [System.Collections.IDictionary]$Dates,
    [System.Collections.IDictionary]$HomeHotel,
    [array]$Candidates,
    [object]$HistoryComparison,
    [string]$HistorySnapshotPath,
    [string]$OutputDir
  )
  $jsonPath = Join-Path $OutputDir "candidates.json"
  $reportPath = Join-Path $OutputDir "report-input.md"
  $latestPath = Join-Path $resolvedOutputRoot "api-combo-latest-report-input.md"
  $radiusText = if ($Config.discovery.radiusMeters) { [string]$Config.discovery.radiusMeters } else { "2000" }
  $tierRules = Get-TierRules -Config $Config
  [System.IO.File]::WriteAllText($jsonPath, ($Candidates | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
  $lines = @(
    "# API Combo Hotel Competitor Report Input",
    "",
    "GeneratedAt: $(Get-Date -Format s)",
    "DryRun: $DryRun",
    "",
    "## Query",
    "",
    "- City: $($Config.city)",
    "- HomeHotelName: $($Config.homeHotelName)",
    "- PoiName: $($Config.poiName)",
    "- CheckIn: $($Dates.CheckIn)",
    "- CheckOut: $($Dates.CheckOut)",
    "- RadiusMeters: $radiusText",
    "",
    "## History",
    "",
    "- HistoryEnabled: True",
    "- CurrentSnapshotPath: $HistorySnapshotPath",
    "- PreviousSnapshotPath: $($HistoryComparison.baselinePath)",
    "- BaselineRunDate: $($HistoryComparison.baselineRunDate)",
    "- Summary: $($HistoryComparison.summary)",
    "",
    "## Tier Rules",
    "",
    "- CoreRadiusMeters: $($tierRules.coreRadiusMeters)",
    "- PricePressureRatio: $($tierRules.pricePressureRatio)",
    "- QualityRatingThreshold: $($tierRules.qualityRatingThreshold)",
    "- QualityRadiusMeters: $($tierRules.qualityRadiusMeters)",
    "- IncludeAlternativeLodging: $($tierRules.includeAlternativeLodging)",
    "",
    "## Data Sources",
    "",
    "- 高德：本店定位、周边候选、距离、商圈、档位、评分",
    "- FlyAI/飞猪：本店和候选酒店价格",
    "- 百度：入围候选口碑、评论数、设施/卫生/服务评分",
    "",
    "## Home",
    "",
    "| 字段 | 值 |",
    "| --- | --- |",
    "| 名称 | $($HomeHotel.hotel_name) |",
    "| 地址 | $($HomeHotel.address) |",
    "| 高德评分 | $($HomeHotel.amap_rating) |",
    "| 档位 | $($HomeHotel.amap_level) |",
    "| 飞猪价 | $($HomeHotel.fliggy_price) |",
    "",
    "## Candidates",
    "",
    "| 分层 | 酒店名 | 距离m | 飞猪价 | 高德评分 | 百度评分 | 评论数 | 类型 | 理由 |",
    "| --- | --- | ---: | --- | --- | --- | --- | --- | --- |"
  )
  foreach ($candidate in $Candidates) {
    $lines += "| $($candidate.comp_tier) | $($candidate.hotel_name) | $($candidate.distance_m) | $($candidate.fliggy_price) | $($candidate.amap_rating) | $($candidate.baidu_rating) | $($candidate.baidu_comment_num) | $($candidate.hotel_type) | $($candidate.reason) |"
  }
  $lines += ""
  $lines += "## Yesterday Comparison"
  $lines += ""
  if (-not $HistoryComparison.hasBaseline) {
    $lines += $HistoryComparison.summary
  } else {
    $lines += "| 角色 | 酒店名 | 分层 | 今日价 | 上次价 | 变化 | 变化幅度 | 趋势 | 今日评论数 | 上次评论数 |"
    $lines += "| --- | --- | --- | --- | --- | ---: | ---: | --- | --- | --- |"
    foreach ($row in @($HistoryComparison.rows)) {
      $lines += "| $($row.role) | $($row.hotel_name) | $($row.comp_tier) | $($row.today_price) | $($row.previous_price) | $($row.price_delta) | $($row.price_delta_pct) | $($row.trend) | $($row.today_baidu_comment_num) | $($row.previous_baidu_comment_num) |"
    }
  }
  [System.IO.File]::WriteAllText($reportPath, ($lines -join "`n"), [System.Text.Encoding]::UTF8)
  New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null
  [System.IO.File]::WriteAllText($latestPath, ($lines -join "`n"), [System.Text.Encoding]::UTF8)
  return $reportPath
}

$config = Get-Config
Assert-Text -Value $config.city -Name "city"
Assert-Text -Value $config.homeHotelName -Name "homeHotelName"
$dates = Get-QueryDates -Config $config
$runId = Get-Date -Format "yyyy-MM-dd-HHmmss"
$outputDir = Join-Path $resolvedOutputRoot $runId
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$amapKey = Get-EnvValue -Name "AMAP_API_KEY"
$flyaiKey = Get-EnvValue -Name "FLYAI_API_KEY"
$baiduAk = Get-EnvValue -Name "BAIDU_MAP_AK"
if (-not $DryRun) {
  if ([string]::IsNullOrWhiteSpace($amapKey)) { throw "AMAP_API_KEY is not set." }
  if ([string]::IsNullOrWhiteSpace($flyaiKey)) { throw "FLYAI_API_KEY is not set." }
  if ([string]::IsNullOrWhiteSpace($baiduAk)) { throw "BAIDU_MAP_AK is not set." }
  if (-not (Get-Command "flyai" -ErrorAction SilentlyContinue)) { throw "flyai CLI was not found in PATH." }
}

$homePoi = Get-AmapHome -Config $config -ApiKey $amapKey -OutputDir $outputDir
$homeCandidate = Convert-AmapCandidate -Poi $homePoi
$homeFly = Invoke-FlyAIPrice -Config $config -Dates $dates -Keyword ([string]$config.homeHotelName) -OutputPath (Join-Path $outputDir "flyai-home.txt")
Merge-FlyAIPrice -Candidate $homeCandidate -FlyResult $homeFly

$excludeKeywords = @($config.discovery.excludeNameKeywords)
$nearbyPois = Get-AmapNearby -Config $config -ApiKey $amapKey -HomePoi $homePoi -OutputDir $outputDir
$maxCandidates = if ($config.discovery.maxCandidates) { [int]$config.discovery.maxCandidates } else { 20 }
$seen = @{}
$candidates = @()
foreach ($poi in $nearbyPois) {
  $candidate = Convert-AmapCandidate -Poi $poi
  if ($candidate.hotel_name -eq $homeCandidate.hotel_name) { continue }
  if (Test-Excluded -Candidate $candidate -ExcludeKeywords $excludeKeywords) { continue }
  $key = ($candidate.hotel_name + "|" + $candidate.address).ToLowerInvariant()
  if ($seen[$key]) { continue }
  $seen[$key] = $true
  $candidates += $candidate
  if ($candidates.Count -ge $maxCandidates) { break }
}

foreach ($candidate in $candidates) {
  $safeName = ($candidate.hotel_name -replace "[^a-zA-Z0-9_-]", "_").Trim("_")
  if (-not $safeName) { $safeName = "candidate" }
  $flyResult = Invoke-FlyAIPrice -Config $config -Dates $dates -Keyword $candidate.hotel_name -OutputPath (Join-Path $outputDir "flyai-$safeName.txt")
  Merge-FlyAIPrice -Candidate $candidate -FlyResult $flyResult
}

$baiduLimit = if ($config.baidu.enrichTopN) { [int]$config.baidu.enrichTopN } else { 10 }
$baiduTargets = $candidates | Sort-Object distance_m | Select-Object -First $baiduLimit
foreach ($candidate in $baiduTargets) {
  $safeName = ($candidate.hotel_name -replace "[^a-zA-Z0-9_-]", "_").Trim("_")
  if (-not $safeName) { $safeName = "candidate" }
  $search = Invoke-BaiduSearch -Config $config -Ak $baiduAk -Candidate $candidate -OutputPath (Join-Path $outputDir "baidu-search-$safeName.json")
  $baiduResult = Get-BaiduHotelResult -SearchResult $search -CandidateName $candidate.hotel_name
  $uid = if ($null -ne $baiduResult) { [string]$baiduResult.uid } else { "" }
  $detail = $null
  if ($uid) {
    $detail = Invoke-BaiduDetail -Ak $baiduAk -Uid $uid -OutputPath (Join-Path $outputDir "baidu-detail-$safeName.json")
  }
  Merge-BaiduInfo -Candidate $candidate -SearchResult $search -DetailResult $detail
}

$homePrice = Get-PriceNumber -Price $homeCandidate.fliggy_price
$tierRules = Get-TierRules -Config $config
foreach ($candidate in $candidates) {
  Set-CompTier -Candidate $candidate -HomePrice $homePrice -Rules $tierRules
}

$historyEnabled = Get-HistoryEnabled -Config $config
$historyRoot = Get-HistoryRoot -Config $config
$historySnapshot = New-HistorySnapshot -Config $config -Dates $dates -HomeHotel $homeCandidate -Candidates $candidates
$previousHistory = if ($historyEnabled) { Get-PreviousHistorySnapshot -HistoryRoot $historyRoot -QueryKey $historySnapshot.query.key } else { $null }
$historyComparison = Compare-HistorySnapshots -CurrentSnapshot $historySnapshot -PreviousSnapshotInfo $previousHistory -HistoryEnabled $historyEnabled
$historySnapshotPath = Save-HistorySnapshot -HistoryRoot $historyRoot -Snapshot $historySnapshot -HistoryEnabled $historyEnabled
if ([string]::IsNullOrWhiteSpace($historySnapshotPath)) {
  $historySnapshotPath = if ($historyEnabled) { "DryRun did not save formal history." } else { "History disabled." }
}
[System.IO.File]::WriteAllText((Join-Path $outputDir "history-snapshot.json"), ($historySnapshot | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $outputDir "history-comparison.json"), ($historyComparison | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)

$reportInput = Write-ReportInput -Config $config -Dates $dates -HomeHotel $homeCandidate -Candidates $candidates -HistoryComparison $historyComparison -HistorySnapshotPath $historySnapshotPath -OutputDir $outputDir

Write-Host "API combo MVP input generated."
Write-Host "Output directory: $outputDir"
Write-Host "Report input: $reportInput"
Write-Host "Latest report input: $(Join-Path $resolvedOutputRoot 'api-combo-latest-report-input.md')"
Write-Host "History snapshot: $historySnapshotPath"
