/**
 * 生成 entry/src/test/List.test.ets —— hypium 的测试总入口。
 *
 * ## 为什么要脚本生成而不是手写
 *
 * hypium 的入口必须**显式 import 并调用**每一个测试套件（它没有自动发现机制）。
 * 手写的结果是：新增一个 *.test.ets 后忘了登记 —— 文件在仓库里、
 * 单测看着「写了」，但真机上根本不会跑。这种「假覆盖」比没有测试更危险。
 *
 * 本脚本扫描目录生成入口，导入与调用一一对应。
 * 新增测试文件后执行：
 *   node tools/verify/gen-test-entry.mjs
 *
 * 注意：生成出来的文件是**要提交**的（CI/真机构建都依赖它），
 * 这个脚本只是保证它与目录一致。
 */

import { readdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..');
const TEST_DIR = join(REPO_ROOT, 'entry', 'src', 'test');
const ENTRY_FILE = join(TEST_DIR, 'List.test.ets');

/**
 * 把文件名转成 hypium 约定的导出函数名。
 *
 * 约定：`<Name>.test.ets` 导出 `<camelName>Test`（与文件同名，首字母小写）。
 * 这个约定让「文件名 → 函数名」可推导，避免两边写歪。
 */
function exportNameOf(fileName) {
  const base = fileName.replace(/\.test\.ets$/, '');
  // 去掉尾部的 "Test" 再补一次，避免出现 RegexTesterTestTest 这种名字。
  // 约定：<Name>.test.ets 导出 <camelName>Test（例如 RegexTesterTest.test.ets
  // 导出 regexTesterTest），这样「文件名 → 函数名」可推导且不重复。
  const stem = base.endsWith('Test') ? base.slice(0, base.length - 'Test'.length) : base;
  return stem.charAt(0).toLowerCase() + stem.slice(1) + 'Test';
}

function main() {
  const files = readdirSync(TEST_DIR)
    .filter((name) => name.endsWith('.test.ets') && name !== 'List.test.ets')
    .sort();

  const lines = [];
  lines.push('/**');
  lines.push(' * hypium 本地单测总入口。');
  lines.push(' *');
  lines.push(' * ⚠️ 本文件由 tools/verify/gen-test-entry.mjs 生成，请勿手工编辑。');
  lines.push(' * 新增/删除测试文件后执行： node tools/verify/gen-test-entry.mjs');
  lines.push(' *');
  lines.push(' * 为什么要有这个入口：hypium 没有测试自动发现机制，必须显式 import 并调用');
  lines.push(' * 每个套件。手工维护的后果是「文件在仓库里但真机上从不执行」——');
  lines.push(' * 那种假覆盖比没有测试更危险。');
  lines.push(' */');
  lines.push('');

  for (const file of files) {
    const moduleName = file.replace(/\.test\.ets$/, '.test');
    lines.push("import " + exportNameOf(file) + " from './" + moduleName + "';");
  }

  lines.push('');
  lines.push('export default function testsuite() {');
  for (const file of files) {
    lines.push('  ' + exportNameOf(file) + '();');
  }
  lines.push('}');
  lines.push('');

  writeFileSync(ENTRY_FILE, lines.join('\n'), 'utf8');
  console.log('已生成 ' + ENTRY_FILE + '，包含 ' + files.length + ' 个测试套件：');
  for (const file of files) {
    console.log('  - ' + file + '  ->  ' + exportNameOf(file) + '()');
  }
}

main();
