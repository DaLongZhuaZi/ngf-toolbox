/**
 * 主题对比度门禁。
 *
 * ## 为什么它必须存在
 *
 * 主题颜色是**最容易被随手改坏**的东西：改一个十六进制值不会让任何测试失败，
 * 也不会让构建失败，只会让某些文字在某种底色上变得难读——
 * 而这种问题只有真实用户在特定光线下的手机屏上才会察觉。
 *
 * ## 它审计的是哪份数据（第 4 轮改过，别改回去）
 *
 * 审计对象是 **\`core/ToolboxPalette.ets\`**——也就是 \`ui/ThemeSource.ets\`
 * 启动时注册进框架 Token 体系的那**同一份**色值。
 *
 * 首版审计的是自建的两份 \`resources/<语言>/element/color.json\`；迁移到 uiTheme 的
 * 运行时 Token 之后，那两份文件已删除。**如果这里不同步改，门禁会去读一份
 * 不存在的色表**——要么直接报错，要么（更糟）静默变成假绿：
 * 它审的是一份早已不用的数据，而界面用的是另一份。
 *
 * ## 为什么调 App 自己的颜色实现
 *
 * 用 \`tools/color-convert/ColorConvert.ets\`（35 个单测、含 WCAG 相对亮度与反 gamma）
 * 而不是在脚本里另写一份公式：两份公式迟早漂移，漂移之后门禁会开始骗人。
 *
 * ## 阈值怎么定
 *
 * 按 WCAG 2.1 AA：正文（含 12~14px 的提示文字）需 4.5:1。
 * 对所有文本色一律要求 4.5，**不留「次要文字可以低一点」的口子**——
 * 次要文字恰恰是提示与帮助文案，读不清后果更严重。
 *
 * 用法：\`node --import ./tools/verify/register.mjs tools/verify/check-theme-contrast.mjs\`
 */

import { contrastRatio, parseColor } from '../../entry/src/main/ets/tools/color-convert/ColorConvert';
import { toolboxPalette } from '../../entry/src/main/ets/core/ToolboxPalette';

/** WCAG AA 对正文的最低要求 */
const MIN_RATIO = 4.5;

/** 框架 Token 的总数（UITheme 的 NGFColorToken）。调色板必须一个不缺。 */
const EXPECTED_TOKEN_COUNT = 25;

/**
 * 需要审计的「前景 / 背景」组合。
 *
 * 这份清单要与**代码里真实的用法**对应：每一条都是某个 \`fontColor(...)\` 落在
 * 某个 \`backgroundColor(...)\` 上的实际搭配。新增配色用法时这里要同步加一条，
 * 否则门禁会漏掉它（这也是它唯一的局限：它只能验证被列出的组合）。
 *
 * 键名是 Token 的**字符串值**（\`NGFColorToken\` 的取值），不是枚举名——
 * 这样脚本不必依赖枚举，拼错会被下面的「未注册 Token」检查抓出来。
 */
const PAIRS = [
  ['on_surface', 'background', '主文本 / 页面底'],
  ['on_surface', 'surface', '主文本 / 卡片'],
  ['on_surface', 'surface_variant', '主文本 / 输出区'],
  ['on_surface_variant', 'background', '次文本 / 页面底'],
  ['on_surface_variant', 'surface', '次文本 / 卡片'],
  ['on_surface_variant', 'surface_variant', '次文本 / 输出区'],
  ['primary', 'background', '强调色 / 页面底'],
  ['primary', 'surface', '强调色 / 卡片'],
  ['primary', 'primary_container', '强调色 / 强调底'],
  ['error', 'error_container', '错误色 / 错误底'],
  ['error', 'surface', '错误色 / 卡片'],
  ['warning', 'warning_container', '警告色 / 警告底'],
  ['warning', 'surface', '警告色 / 卡片'],
  ['success', 'surface_variant', '成功色 / 输出区'],
  ['success', 'surface', '成功色 / 卡片'],
];

const problems = [];
let checked = 0;

const palette = toolboxPalette();

// ── 1. 调色板本身的完整性 ────────────────────────────────────
if (palette.length !== EXPECTED_TOKEN_COUNT) {
  problems.push('调色板有 ' + palette.length + ' 个 Token，框架枚举是 '
    + EXPECTED_TOKEN_COUNT + ' 个——新增 Token 时要同步补色值，'
    + '否则该 Token 未注册，resolveColor() 会返回 #000000');
}

const light = new Map();
const dark = new Map();
for (const entry of palette) {
  if (light.has(entry.token)) {
    problems.push('调色板里 Token 重复：' + entry.token);
  }
  light.set(entry.token, entry.light);
  dark.set(entry.token, entry.dark);
  // 明暗两套色若有任何一个相同，多半是漏填了一列
  if (entry.light === entry.dark) {
    problems.push('Token ' + entry.token + ' 的明暗两色相同（' + entry.light
      + '）——深色主题下会与浅色一模一样，多半是漏填了一列');
  }
}

const themes = [
  ['浅色主题', light],
  ['深色主题', dark],
];

for (const [themeName, table] of themes) {
  console.log('=== ' + themeName + ' ===');
  for (const [fgToken, bgToken, label] of PAIRS) {
    const fg = table.get(fgToken);
    const bg = table.get(bgToken);
    if (fg === undefined) {
      problems.push(themeName + ' 未注册 Token ' + fgToken + '（无法审计「' + label + '」）');
      continue;
    }
    if (bg === undefined) {
      problems.push(themeName + ' 未注册 Token ' + bgToken + '（无法审计「' + label + '」）');
      continue;
    }
    const fgParsed = parseColor(fg);
    const bgParsed = parseColor(bg);
    if (!fgParsed.ok || !bgParsed.ok) {
      problems.push(themeName + ' 的颜色值无法解析：' + fgToken + '=' + fg + ' 或 '
        + bgToken + '=' + bg);
      continue;
    }
    const ratio = contrastRatio(fgParsed.color, bgParsed.color);
    checked += 1;
    const pass = ratio >= MIN_RATIO;
    console.log('  ' + (pass ? 'AA  ' : 'FAIL') + ' ' + ratio.toFixed(2).padStart(6)
      + '  ' + label + '   (' + fg + ' / ' + bg + ')');
    if (!pass) {
      problems.push(themeName + '「' + label + '」对比度 ' + ratio.toFixed(2)
        + ' 低于 AA 门槛 ' + MIN_RATIO + '（' + fg + ' 配 ' + bg + '）');
    }
  }
  console.log('');
}

console.log('共审计 ' + checked + ' 组配色（源自 core/ToolboxPalette.ets），门槛 ' + MIN_RATIO + ':1');
if (problems.length === 0) {
  console.log('主题对比度检查：0 问题');
  process.exit(0);
}
console.log('主题对比度检查：' + problems.length + ' 个问题');
for (const problem of problems) {
  console.log('  [问题] ' + problem);
}
process.exit(1);
