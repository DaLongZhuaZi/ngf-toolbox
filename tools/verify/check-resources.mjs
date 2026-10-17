/**
 * 资源引用与本地化一致性检查。
 *
 * ## 为什么需要这个脚本
 *
 * `$r('app.string.foo')` 这类资源引用**由 ets-loader 在构建期解析**：
 * 键不存在 → 构建失败。而本机没有 DevEco，构建走 CI，
 * 所以「手滑写错一个资源键」这件事在此之前只能靠 CI 发现——
 * 而 CI 是最后一道关，等它报错时改动已经攒了一批，定位成本很高。
 *
 * 尤其是做双语时，要一次性新增几十上百个字符串键并同时写进
 * `base/`、`zh_CN/`、`en_US/` 三份文件，漏一个、拼错一个几乎必然发生。
 *
 * 本脚本把这件事拉回本机可验证：
 *
 * 1. **代码 → 资源**：代码里 `$r('app.string.X')` / `$r('app.color.X')` 引用的键，
 *    必须在 `base/element/` 里存在（否则构建期失败）；
 * 2. **资源 → 代码**：定义了却没人用的键会被报为「疑似无用」，
 *    提醒清理（这类键留着会让后来人以为某处还在用）；
 * 3. **多语言对齐**：`base` 里有的键，`zh_CN` 与 `en_US` 必须都有，
 *    且**值不能与 base 完全相同**（完全相同通常意味着忘了翻译）。
 *
 * 用法：`node tools/verify/check-resources.mjs`
 */

import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..');
const MAIN = join(REPO_ROOT, 'entry', 'src', 'main');
const ETS = join(MAIN, 'ets');
const RES = join(MAIN, 'resources');

const problems = [];

const notes = [];

/** 递归收集某后缀的文件 */
function walk(dir, suffix, out = []) {
  if (!existsSync(dir)) {
    return out;
  }
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      // 跳过构建产物
      if (entry.name === 'build' || entry.name === 'node_modules' || entry.name === 'oh_modules') {
        continue;
      }
      walk(full, suffix, out);
      continue;
    }
    if (entry.name.endsWith(suffix)) {
      out.push(full);
    }
  }
  return out;
}

/** 读一份 element/*.json，返回 name -> value 映射 */
function readElementJson(filePath) {
  const map = new Map();
  if (!existsSync(filePath)) {
    return map;
  }
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(filePath, 'utf8'));
  } catch (error) {
    problems.push('资源文件不是合法 JSON：' + filePath + ' —— ' + error.message);
    return map;
  }
  // 结构形如 { "string": [ { name, value } ] } 或 { "color": [ { name, value } ] }
  const sections = Object.keys(parsed);
  for (const section of sections) {
    const list = parsed[section];
    if (!Array.isArray(list)) {
      continue;
    }
    for (const item of list) {
      if (item && typeof item.name === 'string') {
        // 重复键必须**在这里**发现：函数返回的是 Map，重复项在上面 map.set 时就
        // 已经被后写的覆盖掉了，出了这个函数再也看不见。
        //
        // 为什么值得单列一条：两份同名键的值一旦不同，先写的永远生效、后写的永远
        // 不显示——不报错、不崩溃、不失败，只有用户看到一句不属于这个工具的文案。
        // 实测踩过一次：jwt-decoder 与 json-toolkit 撞了 10 个 json_err_* 键。
        if (map.has(item.name)) {
          problems.push('资源文件出现重复键 ' + item.name + '（' + filePath
            + '）→ 两份定义会互相覆盖，先写的那份永远不显示；请改名或删掉一个');
        }
        map.set(item.name, item.value === undefined ? '' : item.value);
      }
    }
  }
  return map;
}

// ── 1. 收集代码里的资源引用 ──────────────────────────────────

/** key: 'app.string.foo' -> 引用它的文件集合 */
const referenced = new Map();
const addRef = (key, file) => {
  if (!referenced.has(key)) {
    referenced.set(key, new Set());
  }
  referenced.get(key).add(file);
};

const etsFiles = walk(ETS, '.ets');
// $r('...') 的实参必须是字面量（PR-013），所以这里能安全地用正则抓。
//
// 注意**不能**要求键后面紧跟右括号：带占位符参数时写的是
//   $r('app.string.err_x', args[0], args[1])
// 早先的正则只认无参形式，于是所有带参数的资源引用都被漏掉，
// 还会反过来把用到的键报成「已定义但未引用」（假问题）。
const resourcePattern = /\$r\(\s*'([^']+)'/g;

/**
 * 去掉块注释与行注释。
 *
 * **必须做**：文档注释里经常会举 `$r('app.string.xxx')` 这样的例子
 * （本仓的 ToolModel 就写了），如果直接在原文上扫，示例会被当成真实引用，
 * 于是报出一个「引用了不存在的资源键」的假问题——而假问题比没有问题更糟，
 * 它会让人开始怀疑这道门禁本身。
 *
 * 字符串内容**保留**：$r 的实参就在里面，剥掉字符串就什么也扫不到了。
 * 代价是注释标记出现在字符串里时可能误剥，但那种写法在本仓不存在
 * （并且 PR-014 已经禁止在注释里写星号加斜杠）。
 */
function stripComments(text) {
  let out = '';
  let i = 0;
  while (i < text.length) {
    const two = text.substr(i, 2);
    if (two === '/*') {
      const end = text.indexOf('*/', i + 2);
      i = end < 0 ? text.length : end + 2;
      out += ' ';
      continue;
    }
    if (two === '//') {
      const end = text.indexOf('\n', i);
      i = end < 0 ? text.length : end;
      continue;
    }
    out += text.charAt(i);
    i += 1;
  }
  return out;
}

for (const file of etsFiles) {
  const source = stripComments(readFileSync(file, 'utf8'));
  resourcePattern.lastIndex = 0;
  let match;
  while ((match = resourcePattern.exec(source)) !== null) {
    const full = match[1];
    // 只校验应用自己的资源；sys.* / ohos.* 是系统资源，不在本仓资源表里
    if (full.startsWith('app.')) {
      addRef(full, file.replace(REPO_ROOT + '\\', '').replace(REPO_ROOT + '/', ''));
    }
  }
}

// ── 2. 读三份资源表 ──────────────────────────────────────────

const baseStrings = readElementJson(join(RES, 'base', 'element', 'string.json'));
const baseColors = readElementJson(join(RES, 'base', 'element', 'color.json'));
const zhStrings = readElementJson(join(RES, 'zh_CN', 'element', 'string.json'));
const enStrings = readElementJson(join(RES, 'en_US', 'element', 'string.json'));
const darkColors = readElementJson(join(RES, 'dark', 'element', 'color.json'));


// ── 3. 代码引用的键必须存在 ──────────────────────────────────

const knownKeys = new Set();
baseStrings.forEach((_v, k) => knownKeys.add('app.string.' + k));
baseColors.forEach((_v, k) => knownKeys.add('app.color.' + k));
// 媒体资源（$r('app.media.x')）暂不校验：它们由文件名决定，且本仓只用启动图标
const resourcesWithFiles = new Set(['app.media']);

for (const [key, files] of referenced) {
  const isFileResource = key.startsWith('app.media.') || key.startsWith('app.float.')
    || key.startsWith('app.plural.');
  if (isFileResource) {
    continue;
  }
  if (!knownKeys.has(key)) {
    const where = Array.from(files).slice(0, 3).join('、');
    problems.push('代码引用了不存在的资源键 ' + key + '（在 ' + where
      + '）→ 构建期会失败');
  }
}

// ── 4. 多语言对齐 ────────────────────────────────────────────

/**
 * 允许「英文与 base 完全相同」的键。
 *
 * 这份白名单是刻意维护的：绝大多数键的英文必须与中文不同，
 * 所以只有当某个键**本来就该两种语言一样**时才登记进来。
 * 每加一条都要能说出理由，否则就说明翻译漏了。
 */
const SAME_IN_BOTH_LANGUAGES = new Set([
  // 版权行：人名与年份不翻译。
  // 键名带 app_ 前缀是刻意的：框架自己也有一份 about_copyright，
  // 同名会在打包时「先声明者胜出」静默覆盖（hvigor 只给一条 conflict 告警）。
  'about_app_copyright',
  // 「Base64」与「Hex」是技术专名，中文里也直接这么写。
  // 翻译它们反而会让用户认不出这是哪种编码——判断依据仍是那条：
  // **这个词在别的语言里会不会变**（对比 codec_mode_url「URL 整段」/ 'Full URL'，那个会变）。
  'codec_mode_base64',
  'codec_mode_hex',
  // 专有名词/技术缩写：两种语言写法相同。
  'sc_label_pwsh',
  'fb_class_nan',
  'sc_cat_git',
  'sc_label_bash',
  'cs_alg_adler32',
  'cs_alg_crc32',
  'cj_action_to_csv',
  'cj_action_to_json',
  // 位运算符名（AND/OR/XOR/NOT 是电路图标准写法）。
  'bo_op_and',
  'bo_op_not',
  'bo_op_or',
  'bo_op_xor',
  // SQL 注释前缀 '-- ' 是语法符号。
  'al_comment_sql',
  // cURL/HTTPie/URL 专有名词。
  'cb_label_curl',
  'cb_label_httpie',
  'cb_label_url',
]);

const sameAsBase = [];
for (const [name, value] of baseStrings) {
  if (!zhStrings.has(name)) {
    problems.push('zh_CN/element/string.json 缺少键：' + name);
  }
  if (!enStrings.has(name)) {
    problems.push('en_US/element/string.json 缺少键：' + name);
  } else {
    const enValue = enStrings.get(name);
    // 值完全一致通常意味着忘了翻译。但有些键**天生**两种语言相同
    // （产品名、包名、格式串），因此这里只报告、不判失败。
    if (String(enValue) === String(value) && !SAME_IN_BOTH_LANGUAGES.has(name)) {
      sameAsBase.push(name);
    }
  }
}
for (const name of zhStrings.keys()) {
  if (!baseStrings.has(name)) {
    problems.push('zh_CN 里有 base 中不存在的键：' + name + '（base 是回退源，缺了它非中文环境读不到）');
  }
}
for (const name of enStrings.keys()) {
  if (!baseStrings.has(name)) {
    problems.push('en_US 里有 base 中不存在的键：' + name);
  }
}

// ── 5. 暗色主题色对齐 ────────────────────────────────────────

for (const name of darkColors.keys()) {
  if (!baseColors.has(name)) {
    problems.push('dark/element/color.json 里有 base 中不存在的颜色键：' + name);
  }
}
for (const name of baseColors.keys()) {
  if (!darkColors.has(name)) {
    problems.push('dark/element/color.json 缺少颜色键：' + name + '（深色模式下会回退到浅色值）');
  }
}

// ── 6. 定义了但没人用的字符串键 ──────────────────────────────

const unused = [];
for (const name of baseStrings.keys()) {
  // module_desc / EntryAbility_* 由 module.json5 与 app.json5 引用，不在 .ets 里
  if (name === 'module_desc' || name.startsWith('EntryAbility_')) {
    continue;
  }
  if (!referenced.has('app.string.' + name)) {
    unused.push(name);
  }
}

// ── 7. 与框架副本的资源键冲突 ────────────────────────────────
//
// ## 为什么本地必须查这个
//
// 资源键在打包时是**跨模块合并**的：app（entry）与 HAR（ngf_framework）
// 定义了同名键会「先声明者胜出」——**静默覆盖**。
// hvigor 只在构建日志里留一行 conflict 告警，本机九道 Node 门禁完全看不见。
//
// 实测撞过一次：`about_copyright` 在 app 与框架里各有一份，
// 当时十道门禁全绿，只有真编译日志里有那行告警。
//
// ## 这条规则的误报率是零
//
// 重名就是重名，不存在「看起来像但其实没事」。唯一的例外是**有意覆盖**
// （想用 app 的值定制框架组件文案），那种情况登记到下面并写明理由。

/**
 * 允许与框架同名的键。
 *
 * 加之前先问一句：这个键是框架的 uiShell 组件在用的吗？
 * 是 → 覆盖它会让**框架组件的文案也跟着变**，确认这是想要的效果再登记。
 */
const ALLOWED_OVERRIDES = new Set([]);

const FRAMEWORK_RES = join(REPO_ROOT, 'ngf_framework', 'src', 'main', 'resources');
const frameworkStrings = readElementJson(join(FRAMEWORK_RES, 'base', 'element', 'string.json'));
const frameworkColors = readElementJson(join(FRAMEWORK_RES, 'base', 'element', 'color.json'));

const stringOverlaps = [];
for (const name of baseStrings.keys()) {
  if (frameworkStrings.has(name) && !ALLOWED_OVERRIDES.has(name)) {
    stringOverlaps.push(name);
  }
}
if (stringOverlaps.length > 0) {
  problems.push('以下字符串键与 ngf_framework 同名（' + stringOverlaps.length + ' 个）：'
    + stringOverlaps.slice(0, 10).join(', ')
    + (stringOverlaps.length > 10 ? ' 等' : '')
    + '。跨模块合并会「先声明者胜出」静默覆盖，建议给 app 侧加前缀改名；'
    + '若是有意覆盖框架文案，请登记进 ALLOWED_OVERRIDES 并写明理由。');
}

const colorOverlaps = [];
for (const name of baseColors.keys()) {
  if (frameworkColors.has(name)) {
    colorOverlaps.push(name);
  }
}
if (colorOverlaps.length > 0) {
  problems.push('以下颜色键与 ngf_framework 同名（' + colorOverlaps.length + ' 个）：'
    + colorOverlaps.join(', ') + '。同上，会发生静默覆盖。');
}

// ── 输出 ─────────────────────────────────────────────────────

console.log('检查 ' + etsFiles.length + ' 个 .ets，' + referenced.size + ' 处资源引用');
console.log('base 字符串键 ' + baseStrings.size + ' 个，颜色键 ' + baseColors.size + ' 个');

// 漏翻译**必须判失败**，不能只提示。
//
// 理由与工具元数据那边一样：英文字段缺失时系统会回退到 base（中文），
// 不报错、不崩溃、界面照常显示，只有英文用户会看到一段中文。
// 这种「安静的失败」如果不变成红灯，就等于没有检查。
for (const name of sameAsBase) {
  problems.push('字符串键 ' + name + ' 的 en_US 值与 base 完全相同，疑似漏翻译'
    + '（若确实两种语言一致，请把它加进 SAME_IN_BOTH_LANGUAGES 并写明理由）');
}

if (unused.length > 0) {
  notes.push('以下字符串键已定义但代码里没有引用（若确实未用，建议删掉以免误导）：');
  for (const name of unused.slice(0, 30)) {
    notes.push('  · ' + name);
  }
  if (unused.length > 30) {
    notes.push('  …… 另有 ' + (unused.length - 30) + ' 个');
  }
}

if (notes.length > 0) {
  console.log('');
  for (const line of notes) {
    console.log(line);
  }
}

console.log('');
// ── 硬编码色值白名单 ──
//
// 这次重构的全部意义就是「取色走 Token，不写死」。而写死一个 '#FF0000'
// 既不报错、也不失败——只是**那一处在深色主题下会瞎**，要等用户发现。
//
// 所以这里把「允许出现 hex 字面量」的文件列成白名单，其余一律判失败。
// 白名单里的三处都是**合法**用途：
//   · core/ToolboxPalette.ets        —— Token 的**值**就定义在这里，hex 本就该在这
//   · tools/color-convert/*          —— 颜色工具自己的预设色数据与默认输入值
//   · ui/ImmersiveChrome.ets         —— 传给 NGFImmersiveTopChromePresetFactory.build 的
//                                       渐变色参数（工厂只提供「传色」这一种入口，
//                                       没有「用默认值」的重载，所以必须显式传）
{
  const HEX_ALLOWED = new Set([
    'core/ToolboxPalette.ets',
    'tools/color-convert/ColorConvertPage.ets',
    'ui/ImmersiveChrome.ets',
    // 窗口系统栏的色值是**系统 API 的入参**（window.SystemBarProperties），
    // 不是页面取色：透明色没有对应的主题 Token，而图标色只有「浅/深」两种，
    // 由 applyWindowChrome(isDark) 在主题变化时重新应用——
    // 框架自己的 createDefaultStyleForMode 在这层同样是写死的。
    'ui/WindowChrome.ets',
    // pages/Index.ets 的浅色渐变底板数据（FULLSCREEN_CHROME 的色标数组）——
    // 是系统 API 的入参数据而非页面取色，与 ui/ImmersiveChrome.ets 同理。
    'pages/Index.ets',
  ]);
  const etsFiles = [];
  const walkEts = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walkEts(full);
      } else if (entry.name.endsWith('.ets')) {
        etsFiles.push(full);
      }
    }
  };
  walkEts(ETS);
  for (const file of etsFiles) {
    const rel = file.slice(ETS.length + 1).split('\\').join('/');
    if (HEX_ALLOWED.has(rel)) {
      continue;
    }
    const src = readFileSync(file, 'utf8').split(/\r?\n/);
    for (let i = 0; i < src.length; i++) {
      if (/['"]#[0-9A-Fa-f]{6,8}['"]/.test(src[i])) {
        problems.push(rel + ':' + (i + 1) + ' 出现硬编码色值 —— '
          + '取色必须走 colorOf(NGFColorToken.*)，否则深色/浅色主题切换时这一处不会跟着变。'
          + '确属合法用途（如工具自身的色值数据）时，把该文件加进本脚本的 HEX_ALLOWED 并写明理由。');
      }
    }
  }
}


// ── AppScope/resources 的三语对齐 ──
//
// ⚠️ 本脚本原先**只看 entry/src/main/resources**，完全不看 AppScope——
// 于是「应用名（桌面图标名 / app.json5 的 label）只有 base 中文」这件事
// 一直没被发现：英文设备上桌面图标是中文，而 ability 标签是英文，**两个名字互相矛盾**。
//
// AppScope 下的用户可见字符串只有 app_name 一个，但它恰恰是**用户最先看到的那个**。
{
  const scopeRes = join(REPO_ROOT, 'AppScope', 'resources');
  if (existsSync(scopeRes)) {
    const locales = ['base', 'zh_CN', 'en_US'];
    const tables = new Map();
    for (const loc of locales) {
      const file = join(scopeRes, loc, 'element', 'string.json');
      if (!existsSync(file)) {
        tables.set(loc, null);
        continue;
      }
      const parsed = JSON.parse(readFileSync(file, 'utf8'));
      const map = new Map();
      for (const item of parsed.string) {
        map.set(item.name, item.value);
      }
      tables.set(loc, map);
    }
    const baseTable = tables.get('base');
    if (baseTable === null) {
      problems.push('AppScope/resources/base/element/string.json 不存在 —— 应用名没有来源');
    } else {
      for (const loc of ['zh_CN', 'en_US']) {
        const table = tables.get(loc);
        if (table === null) {
          problems.push('AppScope/resources/' + loc + '/element/string.json 不存在 —— '
            + '应用名（app.json5 的 label）没有本地化，该语言下桌面图标会用 base 的取值。');
          continue;
        }
        for (const key of baseTable.keys()) {
          if (!table.has(key)) {
            problems.push('AppScope/resources/' + loc + ' 缺少键：' + key);
          } else if (table.get(key) === baseTable.get(key) && loc === 'en_US') {
            problems.push('AppScope/resources/en_US 的 ' + key + ' 与 base 完全相同 —— 漏翻译');
          }
        }
      }
    }
  }
}


if (problems.length === 0) {
  console.log('资源一致性检查：0 问题');

  process.exit(0);
}

console.log('资源一致性检查：' + problems.length + ' 个问题');
for (const problem of problems) {
  console.log('  [问题] ' + problem);
}
process.exit(1);
