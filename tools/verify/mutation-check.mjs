/**
 * 门禁变异验证（mutation check）。
 *
 * ## 它解决什么问题
 *
 * 门禁的「0 问题」有两种含义：**「检查通过」**和**「检查没跑」**。
 * 实测挖出过两处从未执行过的检查（`check-wiring` §5.5 的两个子检查），
 * 它们一直显示「0 问题」——因为正则早已匹配不上任何一行 / 条件永远为假。
 *
 * 靠人肉一次性验证不可靠：门禁改了没人重验，假绿就会重新长出来。
 * 本脚本把那些变异**固化下来**，可随时重跑。
 *
 * ## 它怎么工作
 *
 * 对每一条变异：备份文件 → 注入变异 → 跑对应门禁 → 断言【退出码非零】
 * 且输出里出现【预期的诊断片段】→ 还原文件。全部条目跑完再核对一遍文件已还原。
 *
 * ## ⚠️ 它会修改工作区文件
 *
 * 因此：
 * - **不放进十道门禁**，只在需要时手动跑（`node tools/verify/mutation-check.mjs`）；
 * - 所有触及的文件先备份到 `.mutation-backup/`，且**每条变异结束就还原**；
 * - 进程被强杀时，下次跑 `--restore` 可从备份还原；
 * - 跑完会校验「文件内容与开始时逐字节一致」，不一致就报失败。
 *
 * ## 加新变异
 *
 * 在 MUTATIONS 里加一条。`gate` 必须是**能在 1–2 秒内跑完**的命令——
 * 真编译（build.ps1）要几分钟，有意排除在外，那条手动跑。
 */

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..');
const BACKUP_DIR = join(REPO_ROOT, '.mutation-backup');

const MUTATIONS = [
  {
    name: 'check-resources：删掉 AppScope 的英文本地化',
    file: 'AppScope/resources/en_US/element/string.json',
    deleteFile: true,
    gate: 'node tools/verify/check-resources.mjs',
    expect: '应用名',
  },
  {
    name: 'check-resources：工具页里写死一个色值',
    file: 'entry/src/main/ets/tools/timestamp/TimestampPage.ets',
    find: '.fontColor(colorOf(NGFColorToken.ON_SURFACE))',
    replace: ".fontColor('#FF0000')",
    gate: 'node tools/verify/check-resources.mjs',
    expect: '出现硬编码色值',
  },
  {
    name: 'check-pages：不存在的组件名',
    file: 'entry/src/main/ets/ui/ToolScaffold.ets',
    find: 'NGFImmersiveTopChromeUnderlay(',
    replace: 'NGFGhostWidget(',
    gate: 'node tools/verify/check-pages.mjs',
    expect: '未登记的组件名',
  },
  {
    name: 'check-pages：$r() 入参写成拼接',
    file: 'entry/src/main/ets/ui/ToolScaffold.ets',
    find: "$r('sys.symbol.checkmark_square')",
    replace: "$r('sys.symbol.' + 'checkmark_square')",
    gate: 'node tools/verify/check-pages.mjs',
    expect: '不是字符串字面量',
  },
  {
    name: 'check-pages：build() 顶层写 return',
    file: 'entry/src/main/ets/ui/ToolScaffold.ets',
    find: '  build() {\n',
    replace: '  build() {\n    if (this.isDark) { return; }\n',
    gate: 'node tools/verify/check-pages.mjs',
    expect: '提前返回',
  },
  {
    name: 'check-pages：调用本文件不存在的方法',
    file: 'entry/src/main/ets/ui/ToolScaffold.ets',
    find: 'this.buildHeader()',
    replace: 'this.buildHeaderXyz()',
    gate: 'node tools/verify/check-pages.mjs',
    expect: '未声明的方法',
  },
  {
    name: 'check-resources：从 zh_CN 表删一个键',
    file: 'entry/src/main/resources/zh_CN/element/string.json',
    find: '"shell_back"',
    replace: '"shell_back_renamed"',
    gate: 'node tools/verify/check-resources.mjs',
    expect: '缺少键',
  },
  {
    name: 'check-theme-contrast：某 Token 明暗同色',
    file: 'entry/src/main/ets/core/ToolboxPalette.ets',
    find: "NGFColorToken.PRIMARY, '#0962F2', '#5B9CFF'",
    replace: "NGFColorToken.PRIMARY, '#0962F2', '#0962F2'",
    gate: 'node --import ./tools/verify/register.mjs tools/verify/check-theme-contrast.mjs',
    expect: '明暗两色相同',
  },
  {
    name: 'check-theme-contrast：次文本调亮到不达标',
    file: 'entry/src/main/ets/core/ToolboxPalette.ets',
    find: "NGFColorToken.ON_SURFACE_VARIANT, '#636E7E', '#9AA4B2'",
    replace: "NGFColorToken.ON_SURFACE_VARIANT, '#AAB2BC', '#9AA4B2'",
    gate: 'node --import ./tools/verify/register.mjs tools/verify/check-theme-contrast.mjs',
    expect: '低于 AA 门槛',
  },
  {
    // ⚠️ 这条必须**删掉文件**，不能只改内容——检查判的是「文件在不在」。
    // 用改内容的方式写会永远「通过」，变成一条假装覆盖了实际没覆盖的变异。
    name: 'check-wiring §5.10：删掉某工具模块的 README',
    file: 'entry/src/main/ets/tools/digest/README.md',
    deleteFile: true,
    gate: 'node --import ./tools/verify/register.mjs tools/verify/check-wiring.mjs',
    expect: '没有 README.md',
  },
  {
    name: 'check-wiring §5.11：类型与值写进同一条 import（PR-010）',
    file: 'entry/src/main/ets/tools/timestamp/TimestampLogic.ets',
    find: "import { NGFLocalizedText } from '../../core/ToolModel';",
    replace: "import { NGFLocalizedText, NGFToolId } from '../../core/ToolModel';",
    gate: 'node --import ./tools/verify/register.mjs tools/verify/check-wiring.mjs',
    expect: '违反 PR-010',
  },
  {
    name: 'check-wiring：引用不存在的页面构建器',
    file: 'entry/src/main/ets/ui/ToolPageRegistry.ets',
    find: 'wrapBuilder(buildRegexTesterPage)',
    replace: 'wrapBuilder(buildGhostPage)',
    gate: 'node --import ./tools/verify/register.mjs tools/verify/check-wiring.mjs',
    expect: '没有 import 它',
  },
  {
    name: 'scan-comments：注释里写「星号 + 斜杠」',
    file: 'tools/verify/check-theme-contrast.mjs',
    find: ' * 主题颜色是**最容易被随手改坏**的东西',
    replace: ' * 例如 resources/*/element 这种写法',
    gate: 'node tools/verify/scan-comments.mjs',
    expect: '问题',
    expectFile: 'check-theme-contrast',
  },
  {
    name: 'run.mjs --logic：纯逻辑里塞 $r()',
    file: 'entry/src/main/ets/core/ToolRoutes.ets',
    find: 'export function encodeToolRouteParam(toolId: string): string {',
    replace: "export function encodeToolRouteParam(toolId: string): string {\n  const leak: string = $r('app.string.shell_back') as string;\n  if (leak.length < 0) { return ''; }",
    gate: 'node --import ./tools/verify/register.mjs tools/verify/run.mjs --logic',
    expect: '$r()',
  },
  {
    name: 'cross-verify-hash：改一个 SHA-256 轮常量',
    file: 'entry/src/main/ets/tools/digest/HashCore.ets',
    find: '0x6a09e667',
    replace: '0x6a09e660',
    gate: 'node --import ./tools/verify/register.mjs tools/verify/cross-verify-hash.mjs',
    expect: '不一致',
  },
  {
    name: 'check-pages：去掉 Toggle 的可访问名称',
    file: 'entry/src/main/ets/tools/uuid-password/UuidPasswordPage.ets',
    find: "          .accessibilityText(ToolUiKit.text($r('app.string.uuidpwd_uuid_uppercase')))\n",
    replace: '',
    gate: 'node tools/verify/check-pages.mjs',
    expect: '没有 .accessibilityText',
  },
  {
    name: '单测：真的清空某工具的英文名',
    file: 'entry/src/main/ets/tools/ToolsCatalog.ets',
    find: "l10n('正则测试', 'Regex Tester'),",
    replace: "l10n('正则测试', ''),",
    gate: 'node --import ./tools/verify/register.mjs tools/verify/run.mjs',
    expect: '失败',
  },
];

function run(cmd) {
  const r = spawnSync(cmd, { cwd: REPO_ROOT, shell: true, encoding: 'utf8' });
  return { code: r.status === null ? -1 : r.status, out: (r.stdout || '') + (r.stderr || '') };
}

function backup(rel) {
  const src = join(REPO_ROOT, rel);
  const dst = join(BACKUP_DIR, rel);
  mkdirSync(dirname(dst), { recursive: true });
  writeFileSync(dst, readFileSync(src));
}

function restore(rel) {
  const src = join(REPO_ROOT, rel);
  const dst = join(BACKUP_DIR, rel);
  if (existsSync(dst)) {
    writeFileSync(src, readFileSync(dst));
  }
}

// `--restore`：从备份还原全部触及文件（进程曾被强杀时用）
if (process.argv.includes('--restore')) {
  let n = 0;
  for (const m of MUTATIONS) {
    if (existsSync(join(BACKUP_DIR, m.file))) { restore(m.file); n += 1; }
  }
  console.log('已从 ' + BACKUP_DIR + ' 还原 ' + n + ' 个文件');
  process.exit(0);
}

console.log('门禁变异验证：' + MUTATIONS.length + ' 条');
console.log('（本脚本会临时修改工作区文件，每条跑完立即还原）');
console.log('');

// 预检：先备份所有会触及的文件，并记下原始内容用于最终比对
const originals = new Map();
for (const m of MUTATIONS) {
  const abs = join(REPO_ROOT, m.file);
  if (!existsSync(abs)) {
    console.log('[跳过] 文件不存在：' + m.file);
    continue;
  }
  if (!originals.has(m.file)) {
    originals.set(m.file, readFileSync(abs, 'utf8'));
    backup(m.file);
  }
}

const failures = [];
let passed = 0;
let skipped = 0;

for (const m of MUTATIONS) {
  const abs = join(REPO_ROOT, m.file);
  const before = originals.get(m.file);
  if (before === undefined) { skipped += 1; continue; }

  if (m.deleteFile !== true && before.indexOf(m.find) < 0) {
    console.log('[跳过] 锚点已不存在：' + m.name);
    console.log('        ' + m.file + ' 里找不到 ' + JSON.stringify(m.find.slice(0, 60)));
    skipped += 1;
    continue;
  }

  try {
    if (m.deleteFile === true) {
      rmSync(abs);
    } else {
      writeFileSync(abs, before.replace(m.find, m.replace));
    }
    const r = run(m.gate);
    const ok = r.code !== 0 && r.out.indexOf(m.expect) >= 0;
    if (ok) {
      passed += 1;
      console.log('[通过] ' + m.name);
    } else {
      failures.push(m.name);
      console.log('[失败] ' + m.name);
      console.log('        期望：退出码非零 且 输出含 ' + JSON.stringify(m.expect));
      console.log('        实际：退出码 ' + r.code + (r.out.indexOf(m.expect) >= 0 ? '（含预期片段）' : '（不含预期片段）'));
    }
  } finally {
    restore(m.file);
  }
}

// 最终核对：所有文件逐字节还原
const dirty = [];
for (const [rel, text] of originals) {
  if (readFileSync(join(REPO_ROOT, rel), 'utf8') !== text) { dirty.push(rel); }
}

console.log('');
if (dirty.length > 0) {
  console.log('⚠️ 以下文件未能还原，请手动检查（备份在 ' + BACKUP_DIR + '）：');
  for (const d of dirty) { console.log('  · ' + d); }
  process.exit(1);
}
console.log('工作区已逐字节还原（' + originals.size + ' 个文件）');

if (failures.length === 0) {
  console.log('变异验证：' + passed + ' 通过，0 失败' + (skipped > 0 ? '，' + skipped + ' 跳过' : ''));
  process.exit(0);
}
console.log('变异验证：' + passed + ' 通过，' + failures.length + ' 失败');
for (const f of failures) { console.log('  [失败] ' + f); }
process.exit(1);
