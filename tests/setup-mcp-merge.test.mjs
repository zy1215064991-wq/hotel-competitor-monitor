import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-mcp-"));
const existingConfig = {
  mcpServers: {
    "existing-tool": {
      type: "stdio",
      command: "existing.exe",
      args: ["--keep"]
    }
  },
  permissions: {
    allow: ["mcp__existing-tool"]
  },
  customSetting: {
    keep: true
  }
};

for (const name of [".mcp.json", "mcp.json"]) {
  fs.writeFileSync(path.join(tempDir, name), JSON.stringify(existingConfig, null, 2), "utf8");
}

try {
  execFileSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "scripts", "setup-workbuddy-mcp.ps1"),
      "-ConfigDir",
      tempDir,
      "-Browser",
      "chrome"
    ],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8" }
  );

  for (const name of [".mcp.json", "mcp.json"]) {
    const filePath = path.join(tempDir, name);
    const bytes = fs.readFileSync(filePath);
    assert.notDeepEqual([...bytes.slice(0, 3)], [0xef, 0xbb, 0xbf], `${name} 不应该带 UTF-8 BOM`);

    const config = JSON.parse(bytes.toString("utf8"));
    assert.ok(config.mcpServers["existing-tool"], `${name} 应该保留已有 MCP server`);
    assert.ok(config.mcpServers["playwright-browser"], `${name} 应该新增 playwright-browser`);
    assert.equal(config.customSetting.keep, true, `${name} 应该保留未知顶层配置`);
    assert.ok(config.permissions.allow.includes("mcp__existing-tool"), `${name} 应该保留已有 allow 权限`);
    assert.ok(config.permissions.allow.includes("mcp__playwright-browser"), `${name} 应该新增 playwright-browser 权限`);
  }
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
