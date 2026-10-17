/**
 * 双语覆盖面门禁。
 *
 * ## 它解决什么问题
 *
 * 「把 16 件工具的内部文案做完双语」是一件跨多轮的长活。没有度量的话：
 * - 不知道还剩多少，每轮都要重新数；
 * - 已经做完的工具**可能悄悄回退**（新加一句中文提示、改一处忘了走资源键），
 *   而现有八道门禁一道都看不出来——漏翻译是「安静的失败」。
 *
 * 本脚本把两者都变成可核对的输出：
 * 1. 打出每件工具**用户可见中文串**的剩余数量（进度表）；
 * 2. 对登记在 {@link COMPLETED_TOOLS} 里的工具，残留即判失败（防回退）。
 *
 * ## 什么算「用户可见中文串」
 *
 * 判据是「含中文字符的字符串字面量」，并**排除**：
 * - 注释（`//` 与块注释）——那里写中文是给读代码的人看的；
 * - `logger.*` 调用里的参数——那是开发日志，不是用户界面文案。
 *
 * 剩下的一律计入。这个口径偏保守（可能数进少量并非直接显示给用户的串），
 * 但**宁可高估**：漏数会让进度看起来比实际好，那是更糟的错误。
 *
 * 用法：`node tools/verify/check-i18n.mjs`
 */

import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..');
const TOOLS_DIR = join(REPO_ROOT, 'entry', 'src', 'main', 'ets', 'tools');

/**
 * 已**完整**做完双语的工具。
 *
 * 判定标准（两条都要满足）：
 * 1. 纯逻辑不再产出面向用户的句子——失败改走错误码，文案在 `*Messages.ets` 里映射；
 * 2. 页面文案全部走资源键，且三份 `string.json` 都有对应条目。
 *
 * 加进来的那一刻起，本脚本会挡住它的回退。**加之前请确认真的清干净了**，
 * 否则这道门禁第一天就在骗人。
 */
const COMPLETED_TOOLS = new Set([
  'radix-convert',
  'digest',
  'code-viewer',
  'text-diff',
  'subnet-calc',
  'color-convert',
  'date-calc',
  'uuid-password',
  'timestamp',
  'qrcode',
  'codec-suite',
  'jwt-decoder',
  'cron-parser',
  'json-toolkit',
  'port-tester',
  'regex-tester'
]);

/** 从源码里剥掉注释（字符串保留：要数的就是字符串里的中文） */
function stripComments(text) {
  let out = '';
  let i = 0;
  while (i < text.length) {
    const two = text.substr(i, 2);
    if (two === '/*') {
      const end = text.indexOf('*/', i + 2);
      const stop = end < 0 ? text.length : end + 2;
      // 用等量的换行补回块注释占掉的行，这样**行号在剥离前后一致**。
      // 行号一致是「按行豁免」能成立的前提：豁免标记写在注释里，
      // 剥离后注释没了，只能靠行号回头去原文里核对。
      for (let k = i; k < stop; k++) {
        if (text.charAt(k) === '\n') {
          out += '\n';
        }
      }
      out += ' ';
      i = stop;
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

/** 去掉单引号字符串里的转义，避免 \\' 破坏配对 */
function normalize(text) {
  return text.replace(/\\'/g, '');
}

/** 文本里是否有中文字符 */
function hasChinese(text) {
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if ((code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3000 && code <= 0x303F)
      || (code >= 0xFF00 && code <= 0xFFEF) || (code >= 0x3400 && code <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}

/**
 * 数一个文件里用户可见的中文串。
 *
 * @returns 命中的代码片段（便于人工核对是哪几句）
 */
/**
 * 收集「双语成对」字面量的位置，这些**不算未翻译**。
 *
 * 判据必须精确，不能靠「这行看起来像有英文」这类猜测——放宽门禁等于关掉门禁。
 * 这里只认两种**结构上可证明成对**的写法：
 *   l10n('中文', 'English')
 *   new NGFLocalizedText('中文', 'English')
 * 即「中文串后面紧跟一个非空、不含中文的串」，那是有译文的确证。
 *
 * 之所以需要它：纯数据层（`NGFLocalizedText`）把两种语言写在同一个字面量对里，
 * 与「页面里硬编码一句中文」在字符层面长得一样，但性质完全不同。
 * 早先没区分时误报过 subnet-calc 的 8 处保留网段名。
 */
/**
 * 解析器把「别人写给我们看」的输入语法写在字面量里（例如 date-calc 接受
 * "2024年2月29日"，源码里就有 '年' / '月' / '日'）。这类字面量不是产给用户的文案，
 * 翻译它没有意义，所以允许在同一行用本标记豁免。
 *
 * 要求写在同一行 + 最后把全部豁免点打印出来，是为了让豁免**可审计**：
 * 一个不说话的口子迟早会变成掩盖真实残留的工具。
 */
/**
 * 豁免标记表。**每种豁免都必须写明理由**，而且跑完会把全部豁免点打印出来。
 *
 * 为什么不做成一个通用忽略标记：不同的忽略理由对应不同的风险。
 * 分成几组之后，复核的人一眼能看出「这个项目到底放宽了几类判断、各几处」。
 */
const EXEMPTION_MARKERS = [
  {
    // 解析器的**输入语法**：别人写给我们看的（例如 date-calc 接受 "2024年2月29日"）
    pattern: /\/\/\s*i18n-parser-literal\b/,
    label: '解析器输入语法',
    hits: []
  },
  {
    // **开发者可见**的契约错误：带堆栈抛到开发期，正常构建下用户永远看不到
    pattern: /\/\/\s*i18n-dev-error\b/,
    label: '开发者可见的契约错误',
    hits: []
  },
  {
    // 生成器的语料数据：用户主动选择该语言时才输出（如 lorem-ipsum 的中文假词表）。
    // 翻译它反而破坏功能——这个词表本来就是中文语料。
    pattern: /\/\/\s*i18n-corpus-data\b/,
    label: '生成器语料数据',
    hits: []
  }
];

/** 命中豁免标记的行 → 它属于哪一类豁免（没命中返回 null） */
function exemptionOfLine(line) {
  for (let i = 0; i < EXEMPTION_MARKERS.length; i++) {
    if (EXEMPTION_MARKERS[i].pattern.test(line)) {
      return EXEMPTION_MARKERS[i];
    }
  }
  return null;
}

/** 收集到的豁免点（跑完会打印，便于复核） */
const parserLiterals = [];

function findPairedLiterals(source) {
  const ranges = [];
  const pairPattern = /(?:l10n|new\s+NGFLocalizedText)\s*\(\s*'([^'\n]*)'\s*,\s*'([^'\n]*)'\s*\)/g;
  let pair = pairPattern.exec(source);
  while (pair !== null) {
    const zh = pair[1];
    const en = pair[2];
    // 只有「中文 + 非空且无中文的译文」才算成对
    if (hasChinese(zh) && en.trim().length > 0 && !hasChinese(en)) {
      const zhStart = pair.index + pair[0].indexOf("'" + zh + "'");
      ranges.push([zhStart, zhStart + zh.length + 2]);
    }
    pair = pairPattern.exec(source);
  }
  return ranges;
}

/** 位置是否落在某个「已成对」区间内 */
function insidePaired(index, ranges) {
  for (let i = 0; i < ranges.length; i++) {
    if (index >= ranges[i][0] && index < ranges[i][1]) {
      return true;
    }
  }
  return false;
}

function findUserFacingChinese(filePath) {
  const raw = readFileSync(filePath, 'utf8');
  const rawLines = raw.split('\n');
  // 先记下哪些行带豁免标记（注释剥离后就看不到标记本身了，只能靠行号回头核对）
  const exemptLines = new Map();
  for (let i = 0; i < rawLines.length; i++) {
    const group = exemptionOfLine(rawLines[i]);
    if (group !== null) {
      exemptLines.set(i, group);
    }
  }
  const stripped = normalize(stripComments(raw));
  const paired = findPairedLiterals(stripped);
  const hits = [];
  const pattern = /'([^'\n]*)'/g;
  let match;
  while ((match = pattern.exec(stripped)) !== null) {
    const literal = match[1];
    if (!hasChinese(literal)) {
      continue;
    }
    if (insidePaired(match.index, paired)) {
      continue;
    }
    // 排除 logger 调用的参数：那是开发日志，不是界面文案。
    //
    // 判据按**行**而不是按「往前数 N 个字符」：早先用的是
    // /logger\.(\w+)\([^)]*$/ 这种回溯式判断，只要参数里出现**嵌套括号**
    // （例如 String(doc.totalLines)）就匹配不上，于是日志文案被算成用户可见文案。
    // 实测被这条误报拦下来过一次（code-viewer 的 ' 行'）。
    const lineStart = stripped.lastIndexOf('\n', match.index) + 1;
    const before = stripped.substring(lineStart, match.index);
    if (/\blogger\.(info|warn|error|debug|fatal|lifecycle|startup|stateChange)\s*\(/.test(before)) {
      continue;
    }
    // 解析器的输入语法（不是产出给用户看的文案）。
    //
    // 例：date-calc 接受 "2024年2月29日" 这种输入，于是源码里有 '年' / '月' / '日'
    // 三个字面量。它们是**别人写给我们看的**，不是我们写给用户看的，翻译它们没有意义。
    //
    // 用显式标记而不是自动猜：标记写在**同一行**，且脚本最后会打印全部豁免点，
    // 这样「豁免」始终可审计，不会变成静默的口子。
    const lineIndex = stripped.substring(0, match.index).split('\n').length - 1;
    const exemptGroup = exemptLines.get(lineIndex);
    if (exemptGroup !== undefined) {
      exemptGroup.hits.push(filePath + ':' + (lineIndex + 1) + '  ' + rawLines[lineIndex].trim());
      continue;
    }
    hits.push(literal);
  }
  return hits;
}

if (!existsSync(TOOLS_DIR)) {
  console.log('找不到工具目录：' + TOOLS_DIR);
  process.exit(2);
}

const toolIds = readdirSync(TOOLS_DIR, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();

const rows = [];
const problems = [];

for (const toolId of toolIds) {
  const dir = join(TOOLS_DIR, toolId);
  let total = 0;
  const sample = [];
  const walk = (current) => {
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const full = join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.name.endsWith('.ets')) {
        continue;
      }
      const hits = findUserFacingChinese(full);
      total += hits.length;
      if (sample.length < 2 && hits.length > 0) {
        sample.push(hits[0]);
      }
    }
  };
  walk(dir);

  rows.push({ toolId, total, sample });
  if (COMPLETED_TOOLS.has(toolId) && total > 0) {
    problems.push('工具 ' + toolId + ' 已登记为「双语完成」，但仍残留 ' + total
      + ' 处用户可见中文串（例如「' + sample.join('」「') + '」）→ 已回退，请补齐或从 COMPLETED_TOOLS 移除');
  }
}

const done = rows.filter((row) => row.total === 0).length;
console.log('工具双语进度：' + done + '/' + rows.length + ' 件无残留用户可见中文串');
console.log('');
for (const row of rows) {
  const mark = row.total === 0 ? 'OK  ' : '    ';
  const note = row.total === 0 ? '' : String(row.total).padStart(4) + ' 处'
    + (row.sample.length > 0 ? '   如「' + row.sample.join('」「') + '」' : '');
  console.log('  ' + mark + ' ' + row.toolId.padEnd(16) + note);
}

const remaining = rows.reduce((sum, row) => sum + row.total, 0);
console.log('');
console.log('合计剩余：' + remaining + ' 处');

if (problems.length === 0) {
  console.log('双语覆盖检查：0 问题');

  for (let g = 0; g < EXEMPTION_MARKERS.length; g++) {
    const group = EXEMPTION_MARKERS[g];
    if (group.hits.length === 0) {
      continue;
    }
    // 全部打印：豁免必须可审计，不能是静默的口子
    console.log('以下 ' + group.hits.length + ' 处按「' + group.label + '」豁免（请复核）：');
    for (let i = 0; i < group.hits.length; i++) {
      console.log('  · ' + group.hits[i]);
    }
  }
  // ── 交接文档的口径核对 ────────────────────────────────────
  //
  // 实测踩过：`docs/开发交接.md` 里**相邻两行**同时写着
  // 「第 3 步（未做）」与「第 3 步（进行中）」，而这道门禁报的是 16/16、剩余 0。
  // 文档与门禁各说各话，接手的人只会信文档。
  //
  // 这条检查很窄，但**零误报**：只有在门禁判「全部完成」时才要求文档改口。
  const handoffPath = join(REPO_ROOT, 'docs', '开发交接.md');
  if (existsSync(handoffPath)) {
    const handoff = readFileSync(handoffPath, 'utf8');
    const stale = ['第 3 步（未做）', '第 3 步（进行中）'].filter((s) => handoff.indexOf(s) >= 0);
    if (stale.length > 0) {
      console.log('双语覆盖检查：1 个问题');
      console.log('  [问题] 门禁判定全部 ' + COMPLETED_TOOLS.size + ' 件工具已完成（剩余 0 处），'
        + '但 docs/开发交接.md 里仍写着「' + stale.join('」「') + '」→ 文档与门禁口径不一致，'
        + '接手的人会信文档。请把那一段改成以门禁输出为准。');
      process.exit(1);
    }
  }
  process.exit(0);
}
console.log('双语覆盖检查：' + problems.length + ' 个问题');
for (const problem of problems) {
  console.log('  [问题] ' + problem);
}
process.exit(1);