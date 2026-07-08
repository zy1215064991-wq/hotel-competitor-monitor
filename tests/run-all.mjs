import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const testsDir = path.dirname(fileURLToPath(import.meta.url));
const currentFile = path.basename(fileURLToPath(import.meta.url));
const testFiles = fs
  .readdirSync(testsDir)
  .filter((name) => name.endsWith(".test.mjs"))
  .sort();

for (const testFile of testFiles) {
  if (testFile === currentFile) continue;
  console.log(`TEST ${testFile}`);
  const result = spawnSync(process.execPath, [path.join(testsDir, testFile)], {
    cwd: path.resolve(testsDir, ".."),
    stdio: "inherit"
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}
