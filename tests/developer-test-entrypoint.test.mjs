import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (relativePath) => fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
const exists = (relativePath) => fs.existsSync(path.join(repoRoot, relativePath));

assert.ok(exists("package.json"), "公开仓库应提供标准 package.json 测试入口");
assert.ok(exists("tests/run-all.mjs"), "公开仓库应提供聚合测试脚本");

const packageJson = JSON.parse(read("package.json"));
const runner = read("tests/run-all.mjs");
const readme = read("README.md");

assert.equal(packageJson.private, true, "本项目不是 npm 发布包，应标记 private");
assert.equal(packageJson.scripts.test, "node tests/run-all.mjs", "npm test 应运行本地聚合测试脚本");
assert.match(runner, /readdirSync/, "聚合测试脚本应自动发现 tests 目录里的测试");
assert.match(runner, /\.test\.mjs/, "聚合测试脚本应只运行 .test.mjs 文件");
assert.doesNotMatch(runner, /-Formal/, "npm test 入口不得触发正式采集");
assert.doesNotMatch(runner, /AMAP_API_KEY|FLYAI_API_KEY|BAIDU_MAP_AK/, "npm test 聚合脚本不得读取真实 Key");
assert.match(readme, /npm test/, "README 应说明标准本地测试入口");
