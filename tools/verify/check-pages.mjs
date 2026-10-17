/**
 * ArkUI 页面文件的**结构化检查**（在 CI 之外提前抓错）。
 *
 * ## 为什么需要它
 *
 * `tools/verify/run.mjs` 只跑纯逻辑，因为 Node 无法执行 ArkTS 的装饰器与
 * 「组件调用 + 尾随块」语法（`Column() { ... }`）。于是 `*Page.ets` 的正确性
 * 一直要等到 CI 或真机才能验证——而这是整个工程里**反馈最慢**的一环。
 *
 * 本脚本补上中间那一层：不做类型检查、不执行，只做**结构性**核对。
 * 它能抓到的正是页面文件最常见的翻车方式：
 *
 * 1. 组件名拼错（`Textinput` / `SymnbolGlyph`）——运行时才会白屏；
 * 2. 忘了给 ``@Builder`` 方法加括号调用（`this.buildXxx` 少写 `()`）；
 * 3. 括号/大括号不配对（复制粘贴时最常发生）；
 * 4. `build()` 里出现 `return`（ArkTS 明确禁止，且报错信息很难懂）；
 * 5. 调用了本文件里并不存在的方法（改名后漏改调用点）。
 *
 * 这些都是**静态可判定**的，不需要编译器。把它跑在提交之前，
 * 可以把「推一次 CI 等几分钟」压缩成「一秒」。
 *
 * ## 边界（诚实说明）
 *
 * - 它**不能**替代编译：类型错误、属性类型不匹配、装饰器约束都查不出来。
 * - 组件清单是**人工维护**的常用集，不是 SDK 全量。报「未知组件」时要先看
 *   是不是清单里缺了，而不是直接改代码。
 *
 * 用法：node tools/verify/check-pages.mjs
 */

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..');
const ETS_ROOT = join(REPO_ROOT, 'entry', 'src', 'main', 'ets');

/**
 * 常用 ArkUI 内置组件。
 *
 * 人工维护的常用集（见文件头「边界」）。新增页面用到新组件时把它加进来，
 * 这样下一个人写错名字时能被这里挡住。
 */
const BUILTIN_COMPONENTS = new Set([
  // 布局
  'Column', 'Row', 'Flex', 'Stack', 'RelativeContainer', 'Grid', 'GridItem', 'GridRow', 'GridCol',
  'List', 'ListItem', 'ListItemGroup', 'Scroll', 'Swiper', 'Tabs', 'TabContent', 'WaterFlow',
  'FlowItem', 'SideBarContainer', 'Refresh', 'Scrollable', 'Counter', 'Navigator', 'Navigation',
  'NavDestination', 'NavRouter', 'Stepper', 'StepperItem', 'Blank', 'Divider', 'Panel', 'FolderStack',
  'EffectComponent', 'Select', 'Search',
  // 基础
  'Text', 'Span', 'Image', 'ImageSpan', 'SymbolSpan', 'SymbolGlyph', 'TextInput', 'TextArea',
  'Button', 'Toggle', 'Checkbox', 'CheckboxGroup', 'Radio', 'Rating', 'Slider', 'Progress',
  'LoadingProgress', 'QRCode', 'Marquee', 'Datapanel', 'DataPanel', 'Gauge', 'Badge', 'Rect',
  'Circle', 'Ellipse', 'Line', 'Polyline', 'Polygon', 'Path', 'Shape', 'Canvas', 'Web', 'Video',
  'XComponent', 'RichText', 'RichEditor', 'PatternLock', 'Menu', 'MenuItem', 'MenuItemGroup',
  'AlphabetIndexer', 'Indexer', 'SegmentButton', 'Chip', 'TextPicker', 'TimePicker', 'DatePicker',
  // 弹层与容器
  'Dialog', 'AlertDialog', 'ActionSheet', 'CustomDialog', 'BindSheet', 'BindContentCover',
  'Sheet', 'Popup', 'Toast', 'Progress',
  // 内置迭代/条件语法（不是组件声明，但同样以 大写名( 出现）
  'ForEach', 'LazyForEach', 'Repeat', 'If', 'Content',
]);

/**
 * 结构性检查。返回问题列表（空数组表示通过）。
 */
function checkFile(filePath, projectComponents) {
  const source = readFileSync(filePath, 'utf8');
  const problems = [];
  const relativePath = relative(REPO_ROOT, filePath);

  // ── 1. 括号 / 大括号配对（忽略字符串与注释里的括号） ──
  const stripped = stripStringsAndComments(source);
  const balance = checkBalance(stripped);
  if (balance !== '') {
    problems.push(balance);
  }

  // ── 2. 用到的组件名是否在白名单内 ──
  const declaredTypes = collectDeclaredTypes(stripped);
  // 用**原始源码**（而非去字符串后的版本）解析 import：
  // 去字符串会把多行 import 之间的换行折叠掉，导致跨行 import 解析失败
  // （现象是 ToolScaffold 这类明明已导入的名字被误报成未知组件）。
  const importedNames = collectImportedNames(source);
  const typeAnnotationNames = collectTypeAnnotationNames(stripped);
  for (const name of collectComponentNames(stripped, declaredTypes, importedNames, typeAnnotationNames)) {
    if (!BUILTIN_COMPONENTS.has(name) && !projectComponents.has(name)) {
      problems.push('用到未登记的组件名「' + name + '」：若不是 SDK 组件，检查是否拼错；'
        + '若是本项目自己的组件，把它加进 BUILTIN_COMPONENTS（见文件头「边界」）');
    }
  }

  // ── 3. @Builder 方法调用是否带括号 ──
  const builderNames = collectBuilderMethodNames(source);
  for (const name of builderNames) {
    // 形如 this.name 后面既不是 ( 也不是标识符字符 —— 就是漏了 ()
    const pattern = new RegExp('this\\.' + name + '(?![\\w(])', 'g');
    let hit = pattern.exec(stripped);
    let offending = false;
    while (hit !== null) {
      // 例外：`@BuilderParam content: () => void = this.defaultContent;`
      //
      // 这一行的不带括号引用是**正确的**：它是在把一个 builder 当默认值赋给
      // @BuilderParam，不是要在字段位置渲染 UI。写成 this.defaultContent() 反而错。
      // 只豁免带 @BuilderParam 的那一行，别处漏括号照旧要报。
      const lineStart = stripped.lastIndexOf('\n', hit.index) + 1;
      const lineEnd = stripped.indexOf('\n', hit.index);
      const line = stripped.substring(lineStart, lineEnd < 0 ? stripped.length : lineEnd);
      // 例外一：\`@BuilderParam content: () => void = this.defaultContent;\`
      // 这一行的不带括号引用是**正确的**（把 builder 当默认值赋给 @BuilderParam）。
      if (line.includes('@BuilderParam')) {
        hit = pattern.exec(stripped);
        continue;
      }
      // 例外二：把 builder **作为属性值传出去**，形如
      //   \`NGFHdsImmersiveTabs({ contentBuilder: this.buildTabContent })\`
      // 这是 ArkUI 给 @BuilderParam 赋值的标准写法，同样不该带括号。
      // 判据是标识符**前面紧邻** \`名字:\`，而不是「这一行里出现过冒号」——
      // 后者会把普通语句里的漏括号一起放过。
      // 通用判据：\`this.X\` 不带括号出现在**值的位置**就是合法的——
      // ArkUI 有至少三种「把 builder 当值传」的写法：
      //   1. \`@BuilderParam content: () => void = this.defaultContent;\`   （默认值）
      //   2. \`NGFHdsImmersiveTabs({ contentBuilder: this.buildTabContent })\` （组件属性）
      //   3. \`Navigation(...).navDestination(this.destBuilder)\`           （方法实参）
      // 逐个枚举形态会漏（这三种是先后踩出来的），所以改判「前面是不是 = : ( ,」。
      // 只有**语句位置**的裸 \`this.X\` 才是漏括号。
      const beforeName = stripped.substring(Math.max(0, hit.index - 40), hit.index);
      if (/[=:(,]\s*$/.test(beforeName)) {
        hit = pattern.exec(stripped);
        continue;
      }
      offending = true;
      break;
      hit = pattern.exec(stripped);
    }
    if (offending) {
      problems.push('@Builder 方法 this.' + name + ' 被引用时没有调用（应写成 this.'
        + name + '()）');
    }
  }

  // ── 4. build() 里出现 return ──
  // 只看 build() **顶层**的 return：嵌在回调（.onClick(() => { ... })）里的 return
  // 是合法的普通 JavaScript，第一版没区分嵌套深度，把首页 onAreaChange 回调里的
  // return 误报成了「build() 提前返回」。
  const topLevelReturn = findTopLevelReturn(stripped);
  if (topLevelReturn) {
    problems.push('build() 顶层出现 return —— ArkTS 不允许在 build() 中提前返回，'
      + '请改用 if/else 分支');
  }

  // ── 4.5 $r() 的入参必须是字符串字面量 ──
  // ArkUI 的 $r('...') 由 ets-loader 在**构建期**按字面量静态改写成资源 ID。
  // 写成拼接（$r('sys.symbol.' + name)）时构建期看不到字面量，改写不成立——
  // 这类错误不会被纯逻辑单测或结构检查抓到，只在编译/真机上表现为「图标不显示」。
  // 它真实发生过一次（首页工具卡片图标），因此固化成检查项。
  const dynamicResource = /\$r\(\s*[^)]*\+/.exec(stripped);
  if (dynamicResource !== null) {
    problems.push('$r() 的入参不是字符串字面量（出现了拼接）：$r() 由构建期静态改写，'
      + '拼接表达式无效。请改成字面量表（参考 ui/ToolSymbols.ets）');
  }

  // ── 5. 调用了本文件不存在的 this.xxx() 方法 ──
  const declared = collectDeclaredMembers(stripped);
  const called = collectThisCalls(stripped);
  for (const call of called) {
    if (!declared.has(call)) {
      // 只报「看起来像本项目方法」的调用：以 build / on / apply / resolve 等开头的
      if (/^(build|on|apply|resolve|collect|compute|format|parse|render|measure|load|open|handle)/.test(call)) {
        problems.push('调用了本文件未声明的方法 this.' + call + '()');
      }
    }
  }

  // ── 6. 开关类控件必须有可访问名称 ──
  //
  // 为什么单独为它立一条：Button 的标签写在构造参数里、TextInput/TextArea 有
  // placeholder，屏幕阅读器都能读到；而 **Toggle 是一个裸开关，自身没有任何文本**，
  // 旁边那行 Text 标签**不会**自动关联到它。实测全仓 5 个 Toggle 全无标注，
  // 读屏只会念「开关」，用户不知道这个开关控制什么。
  //
  // 这是本仓零误报的无障碍规则：Toggle 不存在「自带文本」的情形。
  //
  // ⚠️ 块范围必须**按缩进**界定，不能用「往后 N 行」或「遇到 } 为止」。
  // 实测踩过：写成「最多往后 20 行」时，第 171 行那个 Toggle 的块会一直延到第 190 行，
  // **把下一个 Toggle 的 .accessibilityText 也吞进来** —— 两个开关相邻是常态，
  // 于是前一个没标注也查不出来（假阴性）。现在的规则是：
  // 只吃「空行」或「缩进比 Toggle 更深的行」，遇到缩进不超过它的非空行就停。
  {
    const src = source.split(/\r?\n/);
    const indentOf = (s) => s.length - s.trimStart().length;
    for (let i = 0; i < src.length; i++) {
      const m = src[i].match(/^(\s*)(Toggle|Checkbox|Radio)\s*\(/);
      if (m === null) {
        continue;
      }
      const baseIndent = m[1].length;
      let end = i;
      for (let j = i + 1; j < src.length; j++) {
        const line = src[j];
        if (line.trim() === '') {
          end = j;
          continue;
        }
        if (indentOf(line) <= baseIndent) {
          break;
        }
        end = j;
      }
      const block = src.slice(i, end + 1).join('\n');
      if (block.indexOf('.accessibilityText(') < 0) {
        problems.push('第 ' + (i + 1) + ' 行的 ' + m[2] + ' 没有 .accessibilityText —— '
          + '它是裸开关，自身没有文本，读屏只会念「开关」。'
          + '把旁边那行标签挂上去：.accessibilityText(ToolUiKit.text($r(\'app.string.xxx\')))；'
          + '**不能直接传 $r()** —— 它返回 Resource，而该 API 要 string，'
          + 'ArkTS 会报 No overload matches this call（九道 Node 门禁查不出类型，只有真编译会报）。'
          + '若在共享 @Builder 里，用它的 label 参数：ToolUiKit.text(label)。');
      }
    }
  }
  return problems;
}

/** 去掉字符串字面量与注释，避免括号统计被它们干扰 */
function stripStringsAndComments(source) {
  let out = '';
  let index = 0;
  const length = source.length;
  while (index < length) {
    const ch = source.charAt(index);
    const next = source.charAt(index + 1);
    if (ch === '/' && next === '/') {
      while (index < length && source.charAt(index) !== '\n') {
        index += 1;
      }
      continue;
    }
    if (ch === '/' && next === '*') {
      index += 2;
      while (index < length && !(source.charAt(index) === '*' && source.charAt(index + 1) === '/')) {
        index += 1;
      }
      index += 2;
      continue;
    }
    if (ch === "'" || ch === '"' || ch === '`') {
      const quote = ch;
      index += 1;
      while (index < length) {
        const c = source.charAt(index);
        if (c === '\\') {
          index += 2;
          continue;
        }
        if (c === quote) {
          index += 1;
          break;
        }
        index += 1;
      }
      out += '""';
      continue;
    }
    out += ch;
    index += 1;
  }
  return out;
}

/** 括号配对检查 */
function checkBalance(stripped) {
  const stack = [];
  const closing = { ')': '(', ']': '[', '}': '{' };
  for (let i = 0; i < stripped.length; i += 1) {
    const ch = stripped.charAt(i);
    if (ch === '(' || ch === '[' || ch === '{') {
      stack.push(ch);
    } else if (ch === ')' || ch === ']' || ch === '}') {
      if (stack.length === 0) {
        return '括号不配对：多了一个 ' + ch;
      }
      const open = stack.pop();
      if (open !== closing[ch]) {
        return '括号不配对：' + open + ' 与 ' + ch + ' 交叉';
      }
    }
  }
  if (stack.length !== 0) {
    return '括号不配对：还有 ' + stack.length + ' 个未闭合（最后一个是 ' + stack[stack.length - 1] + '）';
  }
  return '';
}

/**
 * 收集**疑似 ArkUI 组件调用**的首字母大写标识符。
 *
 * ## 为什么要做这么多排除（这是本检查器最容易误报的地方）
 *
 * 裸的「大写标识符紧跟 (」会命中大量**不是组件**的东西，实测第一版误报 100+ 条：
 * - 类/接口的构造调用：\`new NGFToolMeta(...)\`、\`new ToolRegistry()\`；
 * - 类声明与继承：\`class Foo {\`、\`extends Bar\`、\`implements IBaz\`；
 * - 全局内建类型：\`String(x)\`、\`Number(y)\`、\`Date()\`、\`Uint8Array(n)\`；
 * - 本项目自己的组件（ToolScaffold / ToolCard…）——它们**是**合法组件，
 *   只是不在 SDK 白名单里。
 *
 * 检查器的价值在于「低误报」，否则没人会看它的输出。因此这里逐个排除上述四类，
 * 只留下「真的像是写错了的 SDK 组件名」。
 */
function collectComponentNames(stripped, declaredTypes, importedNames, typeAnnotationNames) {
  const names = new Set();
  const pattern = /(?:^|[^\w.$])([A-Z][A-Za-z0-9]*)\s*\(/g;
  let match;
  while ((match = pattern.exec(stripped)) !== null) {
    const name = match[1];
    // 取「标识符本身」的下标，而不是 match.index。
    //
    // 正则以 (?:^|[^\w.$]) 开头，所以 match.index 落在标识符**前面那个字符**上（通常是空格）。
    // 早先直接用它截 16 个字符当 before，等于把那个空格排除在窗口之外，
    // 于是 /\b(new|…)\s+$/ 永远匹配不到——「排除 new 构造调用」那条分支其实是**死代码**，
    // 任何 new Foo( 只要 Foo 不在导入/声明表里就会被误报成未登记组件。
    const nameIndex = match.index + match[0].indexOf(name);
    // 排除**装饰器**位置：`@StorageProp(KEY)` 长得跟组件调用一模一样，
    // 但它不是组件。按 `@` 判断而不是逐个列装饰器名——
    // 后者每加一个装饰器就得回来补一次（`@StorageProp` 就这么被误报过 20 处）。
    if (stripped.charAt(nameIndex - 1) === '@') {
      continue;
    }
    const before = stripped.substring(Math.max(0, nameIndex - 16), nameIndex);
    // 排除构造调用与声明位置：new X( / extends X( / implements X( / class X(
    // （\`new X(...)\` 是普通对象构造，不是 ArkUI 组件调用）
    if (/\b(new|extends|implements|class|interface|enum|type|return)\s+$/.test(before)) {
      continue;
    }
    // 排除类型标注位置（\`: RegexRunResult\`）
    if (typeAnnotationNames.has(name)) {
      continue;
    }
    // 排除本文件自己声明的类/接口/枚举/struct
    if (declaredTypes.has(name)) {
      continue;
    }
    // 排除从别处 import 进来的符号（组件、类型、常量都算——它们是**已知存在**的名字，
    // 拼错的话 import 本身就会失败，不需要这里再报一次）
    if (importedNames.has(name)) {
      continue;
    }
    // 排除全局内建
    if (GLOBAL_BUILTINS.has(name)) {
      continue;
    }
    names.add(name);
  }
  return names;
}

/** 全局内建类型/常量：它们带括号调用但不是 ArkUI 组件 */
const GLOBAL_BUILTINS = new Set([
  'String', 'Number', 'Boolean', 'Object', 'Array', 'Date', 'Math', 'JSON', 'RegExp',
  'Error', 'Map', 'Set', 'Promise', 'Symbol', 'BigInt', 'Function',
  'Uint8Array', 'Int8Array', 'Uint16Array', 'Int16Array', 'Uint32Array', 'Int32Array',
  'Float32Array', 'Float64Array', 'ArrayBuffer', 'DataView', 'Buffer', 'NaN', 'Infinity'
]);

/**
 * 收集 import 进来的**全部符号名**（含 default 与命名导入）。
 *
 * 为什么需要：\`ToolScaffold\`、\`ToolContext\`、\`ForEach\` 这些名字以
 * 「大写名(」的形式出现在页面里，但它们**不是** SDH 组件名，而是本工程自己的符号。
 * 不排除它们会产生大量误报（实测第一版 107 条里绝大多数都是这一类）。
 * 这些名字在别处已经定义过，拼错的话 import 语句本身就会报错，
 * 本检查器不必重复承担那个职责。
 */
function collectImportedNames(stripped) {
  const names = new Set();
  // 先把换行压成空格：本项目里带花括号的 import 常常跨多行
  // （例如 RegexTesterPage 的 import { buildMatchReport, ... } from './RegexLogic' 有 20 行），
  // 不压缩的话正则匹配不到，于是 ToolScaffold 这类**已导入**的名字会被误报成未知组件。
  const flat = stripped.replace(/[\r\n]+/g, ' ');
  const pattern = /import\s+([^;]+?)\s+from\s+['"][^'"]+['"]/g;
  let match;
  // 注意必须对 `flat` 执行，不能对 `stripped`——
  // 这里曾经写成 stripped（压行白算了），导致**跨行 import 一律解析不到**，
  // 于是已导入的名字（NGFLocalizedText、ToolScaffold 这类）被误报成「未登记的组件名」。
  // 单行 import 恰好能匹配，所以这个错误很长时间没有被发现。
  while ((match = pattern.exec(flat)) !== null) {
    const clause = match[1].trim();
    // default 导入：import Foo from '...'
    const defaultMatch = clause.match(/^([A-Za-z_$][\w$]*)$/);
    if (defaultMatch) {
      names.add(defaultMatch[1]);
      continue;
    }
    // 带花括号的命名导入
    const braceStart = clause.indexOf('{');
    if (braceStart >= 0) {
      const head = clause.substring(0, braceStart).trim().replace(/,$/, '').trim();
      if (head.length > 0 && head.indexOf('*') < 0) {
        names.add(head);
      }
      const braceEnd = clause.lastIndexOf('}');
      const inner = clause.substring(braceStart + 1, braceEnd < 0 ? clause.length : braceEnd);
      for (const part of inner.split(',')) {
        const cleaned = part.trim().replace(/^type\s+/, '');
        if (cleaned.length === 0) {
          continue;
        }
        // import { A as B } -> 以 B 为准（本地名字）
        const asMatch = cleaned.match(/\bas\s+([A-Za-z_$][\w$]*)$/);
        names.add(asMatch ? asMatch[1] : cleaned);
      }
    }
  }
  return names;
}

/**
 * 收集本文件自己声明的类型名（class / interface / enum / struct）。
 *
 * 这些名字会在文件里以「导出类名(」之外的形式出现（例如 \`new Foo()\`、
 * 类型标注 \`Foo | null\`），一并排除以免误报成组件。
 */
/**
 * 收集「以**类型标注**身份出现」的 PascalCase 名字。
 *
 * 形如 `@State private run: RegexRunResult`、`const draft: RegexDraft`。
 * 这些名字出现在 `: Name` 的位置上，是**类型**而不是组件调用；
 * 不排除会把「定义在别处的类型」误报成未知组件。
 */
function collectTypeAnnotationNames(stripped) {
  const names = new Set();
  const pattern = /:\s*([A-Z][A-Za-z0-9]*)\s*(?:=|;|,|\)|\||\[)/g;
  let match;
  while ((match = pattern.exec(stripped)) !== null) {
    names.add(match[1]);
  }
  return names;
}

function collectDeclaredTypes(stripped) {
  const names = new Set();
  const pattern = /\b(?:class|interface|enum|struct|type)\s+([A-Z][A-Za-z0-9]*)/g;
  let match;
  while ((match = pattern.exec(stripped)) !== null) {
    names.add(match[1]);
  }
  return names;
}

/** 收集形如 `private buildXxx(...)` 且带 @Builder 的方法名 */
function collectBuilderMethodNames(source) {
  const names = [];
  const lines = source.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    if (lines[i].indexOf('@Builder') >= 0) {
      // @Builder 后紧跟方法声明（可能隔空行）
      for (let j = i + 1; j < Math.min(i + 4, lines.length); j += 1) {
        const match = lines[j].match(/^\s*(?:private\s+|public\s+)?([a-zA-Z_][\w]*)\s*\(/);
        if (match) {
          names.push(match[1]);
          break;
        }
      }
    }
  }
  return names;
}

/** 取 build() 方法体（用括号配对定位） */
function extractBuildBody(stripped) {
  const match = stripped.match(/\bbuild\s*\(\s*\)\s*\{/);
  if (!match) {
    return null;
  }
  const start = match.index + match[0].length;
  let depth = 1;
  let index = start;
  while (index < stripped.length && depth > 0) {
    const ch = stripped.charAt(index);
    if (ch === '{') {
      depth += 1;
    } else if (ch === '}') {
      depth -= 1;
    }
    index += 1;
  }
  return stripped.substring(start, index - 1);
}

/**
 * 判断 build() 的**顶层**（括号深度 0）是否存在 return 语句。
 *
 * 深度 > 0 的 return 属于回调/箭头函数，是合法的，不能报。
 */
/**
 * 判断 build() 里是否存在**非法的提前返回**。
 *
 * ## 什么算非法
 *
 * ArkTS 明确禁止在 `build()` 中提前返回。但判断「是不是提前返回」不能只看
 * 括号深度——下面这种**最常见的**写法，return 在 `if` 花括号里，深度并不为 0：
 *
 * ```
 * build() {
 *   if (loading) { return }   // ← 非法，且深度是 1
 * }
 * ```
 *
 * ## 什么合法
 *
 * 嵌在**回调**里的 return 是合法 JavaScript，不能报：
 *
 * ```
 * .onClick(() => { if (x) { return } })   // ← 合法
 * ```
 *
 * ## 判据
 *
 * 靠「花括号是不是**箭头函数体**」来区分：箭头函数体前面一定有 `=>`。
 * 于是维护两个计数——总花括号深度、以及箭头函数体深度——
 * 只有「箭头深度为 0」时出现的 return 才算非法。
 * 这个区分是必须的：本仓首页的 onAreaChange 回调里就有合法 return，
 * 早期版本把那条误报成了「build() 提前返回」。
 */
function findTopLevelReturn(stripped) {
  const body = extractBuildBody(stripped);
  if (body === null) {
    return false;
  }
  let braceDepth = 0;
  let arrowDepth = 0;
  for (let i = 0; i < body.length; i += 1) {
    const ch = body.charAt(i);
    if (ch === '{') {
      // 判断这个 { 是否是箭头函数体：往前跳过空白看是不是 '>'
      let back = i - 1;
      while (back >= 0 && /\s/.test(body.charAt(back))) {
        back -= 1;
      }
      if (back >= 0 && body.charAt(back) === '>') {
        arrowDepth += 1;
      }
      braceDepth += 1;
      continue;
    }
    if (ch === '}') {
      braceDepth -= 1;
      if (arrowDepth > braceDepth) {
        arrowDepth = braceDepth;
      }
      continue;
    }
    if (ch === 'r' && arrowDepth === 0 && /^return\b/.test(body.substring(i))) {
      return true;
    }
  }
  return false;
}

/** 收集本文件声明的方法与属性名（粗糙但够用） */
function collectDeclaredMembers(stripped) {
  const declared = new Set();
  const methodPattern = /(?:private\s+|public\s+|protected\s+|static\s+|readonly\s+)*([a-zA-Z_][\w]*)\s*\([^)]*\)\s*[:{]/g;
  let match;
  while ((match = methodPattern.exec(stripped)) !== null) {
    declared.add(match[1]);
  }
  const fieldPattern = /(?:private\s+|public\s+|protected\s+|static\s+|readonly\s+|@State\s+|@Prop\s+|@Link\s+)*([a-zA-Z_][\w]*)\s*[:=]/g;
  while ((match = fieldPattern.exec(stripped)) !== null) {
    declared.add(match[1]);
  }
  return declared;
}

/** 收集 this.xxx( 形式的调用 */
function collectThisCalls(stripped) {
  const calls = new Set();
  const pattern = /this\.([a-zA-Z_][\w]*)\s*\(/g;
  let match;
  while ((match = pattern.exec(stripped)) !== null) {
    calls.add(match[1]);
  }
  return calls;
}

/** 递归收集 .ets 文件 */
function collectEtsFiles(dir) {
  const result = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      result.push(...collectEtsFiles(full));
    } else if (entry.endsWith('.ets')) {
      result.push(full);
    }
  }
  return result;
}

/**
 * 收集**本工程自己声明的全部组件**（\`@Component struct X\`）。
 *
 * ## 为什么不用人工白名单
 *
 * 第一版把「本项目组件」也放进 \`BUILTIN_COMPONENTS\` 手工维护，结果每加一件工具
 * 都要记得回来补一行——漏补就误报，误报多了这个检查就没人看了。
 * 改成扫描全工程自动收集之后，新增组件零维护成本，检查器也保持「低误报」。
 */
function collectProjectComponents(allFiles) {
  const names = new Set();
  const pattern = /@(?:Component|ComponentV2|Reusable|Entry)\s*(?:\n\s*)*struct\s+([A-Za-z_$][\w$]*)/g;
  for (const file of allFiles) {
    const source = readFileSync(file, 'utf8');
    let match;
    while ((match = pattern.exec(source)) !== null) {
      names.add(match[1]);
    }
  }
  return names;
}

const files = collectEtsFiles(ETS_ROOT).sort();
const PROJECT_COMPONENTS = collectProjectComponents(files);
let problemCount = 0;
let checkedCount = 0;

for (const file of files) {
  const problems = checkFile(file, PROJECT_COMPONENTS);
  checkedCount += 1;
  if (problems.length > 0) {
    problemCount += problems.length;
    console.log('[问题] ' + relative(REPO_ROOT, file));
    for (const problem of problems) {
      console.log('   - ' + problem);
    }
  }
}

console.log('');
console.log('检查 ' + checkedCount + ' 个 .ets 文件，发现 ' + problemCount + ' 个结构性问题');
process.exitCode = problemCount === 0 ? 0 : 1;
