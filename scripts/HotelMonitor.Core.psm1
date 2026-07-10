function Normalize-HotelMonitorName {
  param([string]$Name)

  if ([string]::IsNullOrWhiteSpace($Name)) { return "" }
  $text = $Name.ToLowerInvariant()
  $text = $text -replace '\uFF08.*?\uFF09', ''
  $text = $text -replace '\(.*?\)', ''
  $genericWords = '\u4E0A\u6D77|\u9152\u5E97\u5F0F|\u9152\u5E97|\u5BBE\u9986|\u516C\u5BD3|\u6C11\u5BBF|\u8FDE\u9501|\u5E97|\u5E7F\u573A|\u673A\u573A|\u56FD\u5BB6\u4F1A\u5C55\u4E2D\u5FC3|\u56FD\u5C55\u4E2D\u5FC3'
  $text = $text -replace $genericWords, ''
  $text = $text -replace '[^\u4e00-\u9fffa-z0-9]', ''
  return $text
}

function Test-HotelMonitorNameCompatible {
  param(
    [string]$ExpectedName,
    [string]$ActualName
  )

  $expected = Normalize-HotelMonitorName -Name $ExpectedName
  $actual = Normalize-HotelMonitorName -Name $ActualName
  if ($expected.Length -lt 2 -or $actual.Length -lt 2) { return $false }
  if ($expected -eq $actual) { return $true }
  return ($expected.Contains($actual) -or $actual.Contains($expected))
}

function Get-HotelMonitorBedType {
  param([string]$RoomType)

  if ([string]::IsNullOrWhiteSpace($RoomType)) { return "" }
  if ($RoomType -match '\u53CC\u5E8A|\u4E24\u5F20\u5E8A|twin') { return "twin" }
  if ($RoomType -match '\u5927\u5E8A|\u7279\u5927\u5E8A|\u53CC\u4EBA\u5E8A|king') { return "king" }
  return ""
}

function Test-HotelMonitorMaskedPrice {
  param([string]$Price)
  return (-not [string]::IsNullOrWhiteSpace($Price) -and $Price -match "[xX]")
}

function Get-HotelMonitorPriceNumber {
  param([string]$Price)

  if (Test-HotelMonitorMaskedPrice -Price $Price) { return 0 }
  $digits = [regex]::Match([string]$Price, '\d[\d,]*').Value -replace ",", ""
  if ($digits) { return [int]$digits }
  return 0
}

function ConvertFrom-HotelMonitorCodePoints {
  param([int[]]$CodePoints)
  return -join @($CodePoints | ForEach-Object { [char]$_ })
}

function Compare-HotelMonitorPrice {
  param(
    [string]$TodayPrice,
    [string]$TodayQuality,
    [string]$PreviousPrice,
    [string]$PreviousQuality
  )

  $maskedTrend = ConvertFrom-HotelMonitorCodePoints -CodePoints @(0x4EF7, 0x683C, 0x5E26, 0x4E0D, 0x53EF, 0x7CBE, 0x786E, 0x6BD4, 0x8F83)
  if ($TodayQuality -eq 'masked' -or $PreviousQuality -eq 'masked' -or
      (Test-HotelMonitorMaskedPrice -Price $TodayPrice) -or
      (Test-HotelMonitorMaskedPrice -Price $PreviousPrice)) {
    return [ordered]@{ Trend = $maskedTrend; Delta = ""; DeltaPct = "" }
  }

  $todayNumber = Get-HotelMonitorPriceNumber -Price $TodayPrice
  $previousNumber = Get-HotelMonitorPriceNumber -Price $PreviousPrice
  if ($todayNumber -le 0 -and $previousNumber -le 0) {
    $trend = ConvertFrom-HotelMonitorCodePoints -CodePoints @(0x4EF7, 0x683C, 0x7F3A, 0x5931)
    return [ordered]@{ Trend = $trend; Delta = ""; DeltaPct = "" }
  }
  if ($todayNumber -le 0) {
    $trend = ConvertFrom-HotelMonitorCodePoints -CodePoints @(0x4ECA, 0x65E5, 0x4EF7, 0x683C, 0x7F3A, 0x5931)
    return [ordered]@{ Trend = $trend; Delta = ""; DeltaPct = "" }
  }
  if ($previousNumber -le 0) {
    $trend = ConvertFrom-HotelMonitorCodePoints -CodePoints @(0x65B0, 0x589E, 0x4EF7, 0x683C)
    return [ordered]@{ Trend = $trend; Delta = ""; DeltaPct = "" }
  }

  $delta = $todayNumber - $previousNumber
  if ($delta -gt 0) {
    $trend = ConvertFrom-HotelMonitorCodePoints -CodePoints @(0x6DA8, 0x4EF7)
  } elseif ($delta -lt 0) {
    $trend = ConvertFrom-HotelMonitorCodePoints -CodePoints @(0x964D, 0x4EF7)
  } else {
    $trend = ConvertFrom-HotelMonitorCodePoints -CodePoints @(0x6301, 0x5E73)
  }
  $pct = [Math]::Round(($delta / $previousNumber) * 100, 1)
  return [ordered]@{ Trend = $trend; Delta = $delta; DeltaPct = "$pct%" }
}

function Select-HotelMonitorFlyAIItem {
  param(
    [object]$Result,
    [string]$ExpectedName
  )

  if ($null -eq $Result -or $null -eq $Result.data -or -not $Result.data.itemList) { return $null }
  $items = @($Result.data.itemList)
  $normalizedExpected = Normalize-HotelMonitorName -Name $ExpectedName

  foreach ($item in $items) {
    if ((Normalize-HotelMonitorName -Name ([string]$item.name)) -eq $normalizedExpected) {
      return $item
    }
  }
  foreach ($item in $items) {
    if (Test-HotelMonitorNameCompatible -ExpectedName $ExpectedName -ActualName ([string]$item.name)) {
      return $item
    }
  }
  return $null
}

Export-ModuleMember -Function @(
  "Normalize-HotelMonitorName",
  "Test-HotelMonitorNameCompatible",
  "Get-HotelMonitorBedType",
  "Test-HotelMonitorMaskedPrice",
  "Get-HotelMonitorPriceNumber",
  "Compare-HotelMonitorPrice",
  "Select-HotelMonitorFlyAIItem"
)
