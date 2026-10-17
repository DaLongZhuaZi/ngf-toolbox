/**
 * 代码查看的纯逻辑：语言识别、逐行分词、显示分页（零 import，可直接单测）。
 *
 * ## 为什么语法高亮要自己写
 *
 * 鸿蒙没有内置的代码高亮组件，而引入第三方高亮库会同时带来两个问题：
 * 一是依赖体积，二是**不可测**——高亮结果对不对，只有盯着屏幕才知道。
 *
 * 这里做的是一份**确定性的逐行分词器**：给定语言与一行源码，产出一串带类型的片段。
 * 它不做真正的语法分析（不解析 AST、不区分声明与调用），但完全够用——
 * 用户看代码时要的是「关键字/字符串/注释一眼可辨」，
 * 而不是把编辑器级别的语义分析搬进一个只读查看器。
 *
 * 确定性带来一个实际好处：**每个用例的期望值都是可推导的**，
 * 因此高亮规则可以被单测逐条钉住，而不是靠肉眼比对。
 *
 * ## 明确不做的事
 *
 * - 不做跨行状态（例如 JS 模板字符串、C 的块注释跨行）：只看单行，
 *   因此块注释的中间行会被当成普通代码。这是**有意的取舍**——
 *   跨行状态会让「滚到第 5000 行」变成必须从头解析，代价远高于收益。
 * - 不做折叠、不做跳转、不做编辑（工具边界里已写明）。
 *
 * @module tools/code-viewer/CodeHighlight
 */

/** 语言标识 */
export enum CodeLanguage {
  PLAIN = 'plain',
  JSON = 'json',
  JAVASCRIPT = 'javascript',
  TYPESCRIPT = 'typescript',
  ARKTS = 'arkts',
  PYTHON = 'python',
  JAVA = 'java',
  KOTLIN = 'kotlin',
  C = 'c',
  CPP = 'cpp',
  CSHARP = 'csharp',
  GO = 'go',
  RUST = 'rust',
  SHELL = 'shell',
  SQL = 'sql',
  XML = 'xml',
  YAML = 'yaml',
  MARKDOWN = 'markdown',
  PROPERTIES = 'properties'
}

/** 片段类型 */
export enum CodeTokenKind {
  PLAIN = 'plain',
  KEYWORD = 'keyword',
  STRING = 'string',
  COMMENT = 'comment',
  NUMBER = 'number',
  PUNCTUATION = 'punctuation',
  TAG = 'tag',
  ATTRIBUTE = 'attribute',
  PROPERTY = 'property'
}

/** 一个高亮片段 */
export class CodeToken {
  readonly text: string;
  readonly kind: CodeTokenKind;

  constructor(text: string, kind: CodeTokenKind) {
    this.text = text;
    this.kind = kind;
  }
}

/** 一种语言的词法规则 */
class LanguageRule {
  readonly language: CodeLanguage;
  readonly label: string;
  readonly keywords: Array<string>;
  /** 行注释前缀，按长度从长到短排列（\`//\` 必须在 \`/\` 之前匹配） */
  readonly lineComment: string;
  /** 块注释起止；空串表示该语言没有块注释 */
  readonly blockStart: string;
  readonly blockEnd: string;
  readonly stringQuotes: string;
  /** 是否有反引号模板字符串（当作字符串处理，单行内） */
  readonly hasTemplateString: boolean;

  constructor(
    language: CodeLanguage,
    label: string,
    keywords: Array<string>,
    lineComment: string,
    blockStart: string,
    blockEnd: string,
    stringQuotes: string,
    hasTemplateString: boolean
  ) {
    this.language = language;
    this.label = label;
    this.keywords = keywords;
    this.lineComment = lineComment;
    this.blockStart = blockStart;
    this.blockEnd = blockEnd;
    this.stringQuotes = stringQuotes;
    this.hasTemplateString = hasTemplateString;
  }
}

/** 语言配置表（首次使用时构建，之后复用） */
const RULES: Map<CodeLanguage, LanguageRule> = buildRules();
const KEYWORD_SETS: Map<CodeLanguage, Set<string>> = buildKeywordSets();

function buildKeywordSets(): Map<CodeLanguage, Set<string>> {
  const map: Map<CodeLanguage, Set<string>> = new Map<CodeLanguage, Set<string>>();
  RULES.forEach((rule: LanguageRule): void => {
    const set: Set<string> = new Set<string>();
    for (let i: number = 0; i < rule.keywords.length; i++) {
      set.add(rule.keywords[i]);
    }
    map.set(rule.language, set);
  });
  return map;
}

function buildRules(): Map<CodeLanguage, LanguageRule> {
  const map: Map<CodeLanguage, LanguageRule> = new Map<CodeLanguage, LanguageRule>();

  const jsLike: Array<string> = ['const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while',
    'do', 'switch', 'case', 'break', 'continue', 'new', 'class', 'extends', 'super', 'this', 'try',
    'catch', 'finally', 'throw', 'typeof', 'instanceof', 'in', 'of', 'delete', 'void', 'yield',
    'async', 'await', 'import', 'export', 'default', 'from', 'as', 'static', 'get', 'set',
    'true', 'false', 'null', 'undefined', 'NaN', 'Infinity'];

  const tsLike: Array<string> = jsLike.concat(['interface', 'type', 'enum', 'namespace', 'declare',
    'implements', 'public', 'private', 'protected', 'readonly', 'abstract', 'any', 'string',
    'number', 'boolean', 'never', 'unknown', 'keyof', 'infer']);

  // 需要按语言翻译的展示名留空，由 UI 层的 codeLanguageLabel 补上资源文案；
  // 其余是专有名词（JavaScript、C++ 等），两种语言下都保持原样。
  map.set(CodeLanguage.PLAIN, new LanguageRule(CodeLanguage.PLAIN, '',
    [], '', '', '', '', false));
  map.set(CodeLanguage.JSON, new LanguageRule(CodeLanguage.JSON, 'JSON',
    ['true', 'false', 'null'], '', '', '', '"', false));
  map.set(CodeLanguage.JAVASCRIPT, new LanguageRule(CodeLanguage.JAVASCRIPT, 'JavaScript',
    jsLike, '//', '/*', '*/', '\'"', true));
  map.set(CodeLanguage.TYPESCRIPT, new LanguageRule(CodeLanguage.TYPESCRIPT, 'TypeScript',
    tsLike, '//', '/*', '*/', '\'"', true));
  map.set(CodeLanguage.ARKTS, new LanguageRule(CodeLanguage.ARKTS, 'ArkTS',
    tsLike.concat(['struct', 'build', 'State', 'Prop', 'Link', 'Component', 'Entry']),
    '//', '/*', '*/', '\'"', true));
  map.set(CodeLanguage.PYTHON, new LanguageRule(CodeLanguage.PYTHON, 'Python',
    ['def', 'class', 'return', 'if', 'elif', 'else', 'for', 'while', 'break', 'continue', 'import',
      'from', 'as', 'try', 'except', 'finally', 'raise', 'with', 'lambda', 'yield', 'global',
      'nonlocal', 'assert', 'del', 'pass', 'in', 'is', 'not', 'and', 'or', 'None', 'True', 'False',
      'async', 'await', 'self'],
    '#', '', '', '\'"', false));
  map.set(CodeLanguage.JAVA, new LanguageRule(CodeLanguage.JAVA, 'Java',
    ['public', 'private', 'protected', 'class', 'interface', 'enum', 'extends', 'implements',
      'static', 'final', 'void', 'int', 'long', 'double', 'float', 'boolean', 'char', 'byte',
      'short', 'String', 'new', 'return', 'if', 'else', 'for', 'while', 'do', 'switch', 'case',
      'break', 'continue', 'try', 'catch', 'finally', 'throw', 'throws', 'this', 'super',
      'import', 'package', 'abstract', 'synchronized', 'true', 'false', 'null'],
    '//', '/*', '*/', '\'"', false));
  map.set(CodeLanguage.KOTLIN, new LanguageRule(CodeLanguage.KOTLIN, 'Kotlin',
    ['fun', 'val', 'var', 'class', 'object', 'interface', 'data', 'sealed', 'when', 'if', 'else',
      'for', 'while', 'do', 'return', 'break', 'continue', 'try', 'catch', 'finally', 'throw',
      'import', 'package', 'private', 'public', 'protected', 'internal', 'override', 'open',
      'abstract', 'companion', 'suspend', 'true', 'false', 'null', 'this', 'super'],
    '//', '/*', '*/', '\'"', false));
  map.set(CodeLanguage.C, new LanguageRule(CodeLanguage.C, 'C',
    ['int', 'long', 'short', 'char', 'float', 'double', 'void', 'struct', 'union', 'enum',
      'typedef', 'static', 'extern', 'const', 'volatile', 'unsigned', 'signed', 'if', 'else',
      'for', 'while', 'do', 'switch', 'case', 'break', 'continue', 'return', 'goto', 'sizeof',
      'include', 'define', 'ifdef', 'ifndef', 'endif'],
    '//', '/*', '*/', '"', false));
  map.set(CodeLanguage.CPP, new LanguageRule(CodeLanguage.CPP, 'C++',
    ['int', 'long', 'short', 'char', 'float', 'double', 'void', 'bool', 'struct', 'class', 'union',
      'enum', 'typedef', 'namespace', 'using', 'template', 'typename', 'static', 'extern', 'const',
      'constexpr', 'volatile', 'unsigned', 'signed', 'public', 'private', 'protected', 'virtual',
      'override', 'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'break', 'continue',
      'return', 'new', 'delete', 'try', 'catch', 'throw', 'true', 'false', 'nullptr', 'auto'],
    '//', '/*', '*/', '\'"', false));
  map.set(CodeLanguage.CSHARP, new LanguageRule(CodeLanguage.CSHARP, 'C#',
    ['public', 'private', 'protected', 'internal', 'class', 'interface', 'struct', 'enum',
      'namespace', 'using', 'static', 'readonly', 'const', 'void', 'int', 'long', 'double',
      'float', 'bool', 'string', 'var', 'new', 'return', 'if', 'else', 'for', 'foreach', 'while',
      'do', 'switch', 'case', 'break', 'continue', 'try', 'catch', 'finally', 'throw', 'this',
      'base', 'async', 'await', 'true', 'false', 'null'],
    '//', '/*', '*/', '\'"', false));
  map.set(CodeLanguage.GO, new LanguageRule(CodeLanguage.GO, 'Go',
    ['package', 'import', 'func', 'var', 'const', 'type', 'struct', 'interface', 'map', 'chan',
      'go', 'defer', 'return', 'if', 'else', 'for', 'range', 'switch', 'case', 'break', 'continue',
      'select', 'default', 'fallthrough', 'goto', 'nil', 'true', 'false', 'int', 'int64', 'string',
      'bool', 'byte', 'error', 'make', 'new', 'append', 'len', 'cap'],
    '//', '/*', '*/', '\'"', true));
  map.set(CodeLanguage.RUST, new LanguageRule(CodeLanguage.RUST, 'Rust',
    ['fn', 'let', 'mut', 'const', 'static', 'struct', 'enum', 'trait', 'impl', 'pub', 'use', 'mod',
      'crate', 'self', 'super', 'match', 'if', 'else', 'for', 'while', 'loop', 'break', 'continue',
      'return', 'move', 'ref', 'as', 'where', 'unsafe', 'async', 'await', 'dyn', 'true', 'false',
      'Some', 'None', 'Ok', 'Err'],
    '//', '/*', '*/', '"', false));
  map.set(CodeLanguage.SHELL, new LanguageRule(CodeLanguage.SHELL, 'Shell',
    ['if', 'then', 'else', 'elif', 'fi', 'for', 'in', 'do', 'done', 'while', 'case', 'esac',
      'function', 'return', 'exit', 'export', 'local', 'readonly', 'echo', 'cd', 'set', 'unset',
      'source', 'alias', 'sudo', 'true', 'false'],
    '#', '', '', '\'"', false));
  map.set(CodeLanguage.SQL, new LanguageRule(CodeLanguage.SQL, 'SQL',
    ['select', 'from', 'where', 'insert', 'into', 'values', 'update', 'set', 'delete', 'create',
      'table', 'index', 'view', 'drop', 'alter', 'add', 'column', 'primary', 'key', 'foreign',
      'references', 'join', 'inner', 'left', 'right', 'outer', 'on', 'group', 'by', 'order',
      'having', 'limit', 'offset', 'distinct', 'as', 'and', 'or', 'not', 'null', 'is', 'in',
      'between', 'like', 'union', 'all', 'count', 'sum', 'avg', 'min', 'max',
      'SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE', 'CREATE',
      'TABLE', 'INDEX', 'DROP', 'ALTER', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'ON', 'GROUP', 'BY',
      'ORDER', 'HAVING', 'LIMIT', 'DISTINCT', 'AS', 'AND', 'OR', 'NOT', 'NULL', 'IS', 'IN',
      'BETWEEN', 'LIKE', 'UNION', 'ALL', 'COUNT', 'SUM', 'AVG', 'MIN', 'MAX'],
    '--', '/*', '*/', '\'', false));
  map.set(CodeLanguage.XML, new LanguageRule(CodeLanguage.XML, 'XML / HTML',
    [], '', '<!--', '-->', '\'"', false));
  map.set(CodeLanguage.YAML, new LanguageRule(CodeLanguage.YAML, 'YAML',
    ['true', 'false', 'null', 'yes', 'no', 'on', 'off'], '#', '', '', '\'"', false));
  map.set(CodeLanguage.MARKDOWN, new LanguageRule(CodeLanguage.MARKDOWN, 'Markdown',
    [], '', '<!--', '-->', '\'"', false));
  map.set(CodeLanguage.PROPERTIES, new LanguageRule(CodeLanguage.PROPERTIES, '',
    [], '#', '', '', '\'"', false));
  return map;
}

/** 取语言配置；未知语言退化为纯文本 */
export function ruleOf(language: CodeLanguage): LanguageRule {
  const rule: LanguageRule | undefined = RULES.get(language);
  if (rule === undefined) {
    return new LanguageRule(CodeLanguage.PLAIN, '', [], '', '', '', '', false);
  }
  return rule;
}

/**
 * 语言的**专有名词**展示名（JavaScript、C++、YAML…）。
 *
 * 对「纯文本」与「键值配置」这两种**需要按语言翻译**的名字返回空串——
 * 它们不是专有名词，中英文写法不同。调用方应改用 UI 层的 \`codeLanguageLabel\`，
 * 它会先用 {@link languageNeedsResource} 判断，再补上资源文案。
 */
export function languageLabel(language: CodeLanguage): string {
  return ruleOf(language).label;
}

/**
 * 该语言的展示名是否需要走资源键（即不是专有名词）。
 *
 * 只有两种：纯文本、键值配置。判断依据是「这个词是不是某个技术的专名」——
 * JavaScript 在任何语言里都叫 JavaScript，而「纯文本」不是。
 */
export function languageNeedsResource(language: CodeLanguage): boolean {
  return language === CodeLanguage.PLAIN || language === CodeLanguage.PROPERTIES;
}

// ── 语言识别 ─────────────────────────────────────────────────

/** 由文件名推断语言 */
export function languageFromFileName(fileName: string): CodeLanguage {
  const lower: string = fileName.trim().toLowerCase();
  const dot: number = lower.lastIndexOf('.');
  if (dot < 0) {
    // 没有扩展名时按常见的无扩展名文件判断
    if (lower === 'makefile' || lower === 'dockerfile') {
      return CodeLanguage.SHELL;
    }
    return CodeLanguage.PLAIN;
  }
  const ext: string = lower.substring(dot + 1);

  if (ext === 'json') {
    return CodeLanguage.JSON;
  }
  if (ext === 'ets') {
    return CodeLanguage.ARKTS;
  }
  if (ext === 'ts' || ext === 'mts' || ext === 'cts') {
    return CodeLanguage.TYPESCRIPT;
  }
  if (ext === 'js' || ext === 'mjs' || ext === 'cjs' || ext === 'jsx') {
    return CodeLanguage.JAVASCRIPT;
  }
  if (ext === 'tsx') {
    return CodeLanguage.TYPESCRIPT;
  }
  if (ext === 'py' || ext === 'pyw') {
    return CodeLanguage.PYTHON;
  }
  if (ext === 'java') {
    return CodeLanguage.JAVA;
  }
  if (ext === 'kt' || ext === 'kts') {
    return CodeLanguage.KOTLIN;
  }
  if (ext === 'c' || ext === 'h') {
    return CodeLanguage.C;
  }
  if (ext === 'cpp' || ext === 'cc' || ext === 'cxx' || ext === 'hpp' || ext === 'hxx') {
    return CodeLanguage.CPP;
  }
  if (ext === 'cs') {
    return CodeLanguage.CSHARP;
  }
  if (ext === 'go') {
    return CodeLanguage.GO;
  }
  if (ext === 'rs') {
    return CodeLanguage.RUST;
  }
  if (ext === 'sh' || ext === 'bash' || ext === 'zsh' || ext === 'fish') {
    return CodeLanguage.SHELL;
  }
  if (ext === 'sql') {
    return CodeLanguage.SQL;
  }
  if (ext === 'xml' || ext === 'html' || ext === 'htm' || ext === 'svg') {
    return CodeLanguage.XML;
  }
  if (ext === 'yaml' || ext === 'yml') {
    return CodeLanguage.YAML;
  }
  if (ext === 'md' || ext === 'markdown') {
    return CodeLanguage.MARKDOWN;
  }
  if (ext === 'properties' || ext === 'ini' || ext === 'conf' || ext === 'cfg' || ext === 'env') {
    return CodeLanguage.PROPERTIES;
  }
  return CodeLanguage.PLAIN;
}

/** 由文件内容推断语言（仅在扩展名无法判断时用） */
export function languageFromContent(content: string): CodeLanguage {
  const head: string = content.length > 2000 ? content.substring(0, 2000) : content;
  const trimmed: string = head.trim();
  if (trimmed.length === 0) {
    return CodeLanguage.PLAIN;
  }
  // JSON：以 { 或 [ 开头且能被 JSON.parse 解析
  if (trimmed.charAt(0) === '{' || trimmed.charAt(0) === '[') {
    return CodeLanguage.JSON;
  }
  if (trimmed.indexOf('<?xml') === 0 || trimmed.indexOf('<!DOCTYPE') === 0 || trimmed.indexOf('<html') === 0) {
    return CodeLanguage.XML;
  }
  if (trimmed.indexOf('#!/bin/') === 0 || trimmed.indexOf('#!') === 0) {
    return CodeLanguage.SHELL;
  }
  // Python：def/import 开头，且没有分号结尾的 JS 特征
  if (trimmed.indexOf('def ') === 0 || trimmed.indexOf('import ') === 0 || trimmed.indexOf('from ') === 0) {
    if (trimmed.indexOf(';') < 0) {
      return CodeLanguage.PYTHON;
    }
  }
  // Go
  if (trimmed.indexOf('package ') === 0 && trimmed.indexOf('func ') > 0) {
    return CodeLanguage.GO;
  }
  return CodeLanguage.PLAIN;
}

// ── 分词 ─────────────────────────────────────────────────────

/**
 * 判断字符是否可以作为**标识符的首字符**。
 *
 * 刻意**不含数字**：数字由 {@link isDigit} 单独处理，
 * 否则扫描到 \`42\` 时会先被标识符分支吃掉（因为它把 \`4\` 当标识符字符），
 * 数字高亮就永远不会触发——这个坑实际踩过一次。
 */
function isIdentifierStart(ch: string): boolean {
  const code: number = ch.charCodeAt(0);
  if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122) || ch === '_' || ch === '$') {
    return true;
  }
  // 中文等非 ASCII 也可以作标识符（ArkTS 允许）
  return code > 127;
}

/** 判断字符是否为标识符的后续字符（含数字） */
function isIdentifierChar(ch: string): boolean {
  return isIdentifierStart(ch) || isDigit(ch);
}

/** 判断字符是否为数字字符 */
function isDigit(ch: string): boolean {
  const code: number = ch.charCodeAt(0);
  return code >= 48 && code <= 57;
}

/**
 * 把一行源码切成带类型的片段。
 *
 * 实现是**单遍扫描**：从左到右判断当前位置属于哪种结构，匹配上就整段取出、
 * 跳到其末尾。这样天然避免了「在字符串里又去匹配关键字」这类错误——
 * 一旦进入字符串，内部的字符不会再被当成代码看。
 */
export function tokenizeLine(line: string, language: CodeLanguage): Array<CodeToken> {
  const rule: LanguageRule = ruleOf(language);
  if (rule.language === CodeLanguage.PLAIN) {
    return line.length === 0 ? [] : [new CodeToken(line, CodeTokenKind.PLAIN)];
  }
  const keywords: Set<string> | undefined = KEYWORD_SETS.get(rule.language);
  const tokens: Array<CodeToken> = [];
  let plain: string = '';

  const flushPlain = (): void => {
    if (plain.length > 0) {
      tokens.push(new CodeToken(plain, CodeTokenKind.PLAIN));
      plain = '';
    }
  };

  let i: number = 0;
  while (i < line.length) {
    // 行注释
    if (rule.lineComment.length > 0 && line.substring(i, i + rule.lineComment.length) === rule.lineComment) {
      flushPlain();
      tokens.push(new CodeToken(line.substring(i), CodeTokenKind.COMMENT));
      return tokens;
    }
    // 块注释（单行内闭合）
    if (rule.blockStart.length > 0 && line.substring(i, i + rule.blockStart.length) === rule.blockStart) {
      const endAt: number = line.indexOf(rule.blockEnd, i + rule.blockStart.length);
      if (endAt >= 0) {
        flushPlain();
        tokens.push(new CodeToken(line.substring(i, endAt + rule.blockEnd.length), CodeTokenKind.COMMENT));
        i = endAt + rule.blockEnd.length;
        continue;
      }
      // 没有闭合：把其余部分当注释（这是单行查看器的合理近似）
      flushPlain();
      tokens.push(new CodeToken(line.substring(i), CodeTokenKind.COMMENT));
      return tokens;
    }
    // XML 标签
    if (rule.language === CodeLanguage.XML && line.charAt(i) === '<') {
      const closeAt: number = line.indexOf('>', i);
      if (closeAt >= 0) {
        flushPlain();
        const tagText: string = line.substring(i, closeAt + 1);
        tokens.push(new CodeToken(tagText, CodeTokenKind.TAG));
        i = closeAt + 1;
        continue;
      }
    }

    const ch: string = line.charAt(i);

    // 字符串
    if (rule.stringQuotes.indexOf(ch) >= 0) {
      flushPlain();
      const start: number = i;
      i++;
      while (i < line.length) {
        const current: string = line.charAt(i);
        if (current === '\\') {
          i += 2;
          continue;
        }
        if (current === ch) {
          i++;
          break;
        }
        i++;
      }
      const text: string = line.substring(start, i > line.length ? line.length : i);
      tokens.push(new CodeToken(text, CodeTokenKind.STRING));
      continue;
    }
    // 模板字符串（单行内）
    if (rule.hasTemplateString && ch === '\u0060') {
      flushPlain();
      const start: number = i;
      i++;
      while (i < line.length) {
        const current: string = line.charAt(i);
        if (current === '\\') {
          i += 2;
          continue;
        }
        if (current === '\u0060') {
          i++;
          break;
        }
        i++;
      }
      const text: string = line.substring(start, i > line.length ? line.length : i);
      tokens.push(new CodeToken(text, CodeTokenKind.STRING));
      continue;
    }

    // 标识符 / 关键字（触发条件是「标识符首字符」，不是「标识符字符」——
    // 后者会把数字也吃进来，见 isIdentifierStart 的说明）
    if (isIdentifierStart(ch)) {
      const start: number = i;
      while (i < line.length && isIdentifierChar(line.charAt(i))) {
        i++;
      }
      const word: string = line.substring(start, i);
      // 只有整个词**就是**关键字时才高亮：`iffy` 里的 `if` 不是关键字。
      // 这里靠「一次扫完整个连续标识符」天然保证，无需再做额外边界判断。
      const isKeyword: boolean = keywords !== undefined && keywords.has(word);
      // 紧跟冒号的标识符在 YAML/键值配置里是「键」，配色上区分开更易读
      const isProperty: boolean = (rule.language === CodeLanguage.YAML
        || rule.language === CodeLanguage.PROPERTIES)
        && i < line.length && (line.charAt(i) === ':' || line.charAt(i) === '=');
      if (isKeyword) {
        flushPlain();
        tokens.push(new CodeToken(word, CodeTokenKind.KEYWORD));
      } else if (isProperty) {
        flushPlain();
        tokens.push(new CodeToken(word, CodeTokenKind.PROPERTY));
      } else {
        plain += word;
      }
      continue;
    }

    // 数字
    if (isDigit(ch)) {
      flushPlain();
      const start: number = i;
      while (i < line.length) {
        const current: string = line.charAt(i);
        if (isDigit(current) || current === '.' || current === 'x' || current === 'X'
          || (current >= 'a' && current <= 'f') || (current >= 'A' && current <= 'F')) {
          i++;
          continue;
        }
        break;
      }
      tokens.push(new CodeToken(line.substring(start, i), CodeTokenKind.NUMBER));
      continue;
    }

    // 其余按纯文本累积（标点不做特殊着色：代码里的括号引号太多，
    // 全都着色反而让高亮失去信息量）
    plain += ch;
    i++;
  }

  flushPlain();
  return tokens;
}

// ── 显示分页 ─────────────────────────────────────────────────

/**
 * 单次最多渲染的行数。
 *
 * 为什么要限：ArkUI 里每一行都是一个组件，几千行会把首帧拖到几秒。
 * 限制之后是「先看前 N 行」而不是「卡住不动」，用户至少能看到内容并决定下一步。
 */
export const MAX_RENDER_LINES: number = 3000;

/** 打开文档的结果 */
export class CodeDocument {
  readonly fileName: string;
  readonly language: CodeLanguage;
  readonly lines: Array<string>;
  /** 文件的完整行数（可能大于 lines.length） */
  readonly totalLines: number;
  /** 是否因为渲染上限而截断 */
  readonly truncated: boolean;
  /** 原始字符数 */
  readonly totalChars: number;

  constructor(
    fileName: string,
    language: CodeLanguage,
    lines: Array<string>,
    totalLines: number,
    truncated: boolean,
    totalChars: number
  ) {
    this.fileName = fileName;
    this.language = language;
    this.lines = lines;
    this.totalLines = totalLines;
    this.truncated = truncated;
    this.totalChars = totalChars;
  }
}

/**
 * 按行切分内容。
 *
 * 与文本 Diff 的行切分口径一致：CRLF 与 LF 都当换行，行尾归一化，
 * 不把末尾换行算作额外一行。刻意**不 trim**：代码的缩进是信息。
 */
export function splitContentLines(content: string): Array<string> {
  if (content.length === 0) {
    return [];
  }
  const lines: Array<string> = [];
  let current: string = '';
  for (let i: number = 0; i < content.length; i++) {
    const ch: string = content.charAt(i);
    if (ch === '\r') {
      const next: string = i + 1 < content.length ? content.charAt(i + 1) : '';
      if (next === '\n') {
        i++;
      }
      lines.push(current);
      current = '';
      continue;
    }
    if (ch === '\n') {
      lines.push(current);
      current = '';
      continue;
    }
    current += ch;
  }
  if (current.length > 0 || content.charAt(content.length - 1) !== '\n') {
    lines.push(current);
  }
  return lines;
}

/** 构造可查看的文档（含语言识别与渲染截断） */
export function makeDocument(fileName: string, content: string): CodeDocument {
  const allLines: Array<string> = splitContentLines(content);
  let language: CodeLanguage = languageFromFileName(fileName);
  if (language === CodeLanguage.PLAIN) {
    // 扩展名判断不出来时再看内容
    const byContent: CodeLanguage = languageFromContent(content);
    if (byContent !== CodeLanguage.PLAIN) {
      language = byContent;
    }
  }
  const truncated: boolean = allLines.length > MAX_RENDER_LINES;
  const visible: Array<string> = truncated ? allLines.slice(0, MAX_RENDER_LINES) : allLines;
  return new CodeDocument(fileName, language, visible, allLines.length, truncated, content.length);
}

/**
 * 从 URI 里取出文件名。
 *
 * 文件选择器给的是 URI（形如 file://docs/storage/.../notes.txt），
 * 直接显示整条 URI 在手机上会被截断，用户看不到自己选的是什么文件。
 */
export function fileNameFromUri(uri: string): string {
  const cleaned: string = uri.split('?')[0];
  const slash: number = cleaned.lastIndexOf('/');
  const name: string = slash >= 0 ? cleaned.substring(slash + 1) : cleaned;
  // 取不到名字时返回空串，由 UI 层决定显示什么（"未命名文件" 这句话也要能跟随系统语言）
  if (name.length === 0) {
    return '';
  }
  return decodePercent(name);
}

/** 解码 URI 里的百分号编码（文件名里的空格、中文会被编码） */
export function decodePercent(text: string): string {
  let result: string = '';
  let i: number = 0;
  while (i < text.length) {
    const ch: string = text.charAt(i);
    if (ch === '%' && i + 2 < text.length) {
      const high: number = hexValue(text.charAt(i + 1));
      const low: number = hexValue(text.charAt(i + 2));
      if (high >= 0 && low >= 0) {
        const byte: number = high * 16 + low;
        // 单字节直接还原；多字节 UTF-8 需要把连续字节一起解码
        if (byte < 0x80) {
          result += String.fromCharCode(byte);
          i += 3;
          continue;
        }
        const decoded: PercentDecode = decodeUtf8At(text, i);
        if (decoded.consumed > 0) {
          result += decoded.text;
          i += decoded.consumed;
          continue;
        }
      }
    }
    result += ch;
    i++;
  }
  return result;
}

/** 多字节解码结果 */
class PercentDecode {
  readonly text: string;
  readonly consumed: number;

  constructor(text: string, consumed: number) {
    this.text = text;
    this.consumed = consumed;
  }
}

/** 从 %XX 序列解出一个 UTF-8 字符（可能占多个 %XX） */
function decodeUtf8At(text: string, start: number): PercentDecode {
  const bytes: Array<number> = [];
  let i: number = start;
  while (i + 2 < text.length + 1 && text.charAt(i) === '%') {
    const high: number = hexValue(text.charAt(i + 1));
    const low: number = hexValue(text.charAt(i + 2));
    if (high < 0 || low < 0) {
      break;
    }
    bytes.push(high * 16 + low);
    i += 3;
    // 一个 UTF-8 字符最多 4 字节
    if (bytes.length >= 4) {
      break;
    }
    // 后续字节必须以 10 开头，否则说明这个字符到此为止
    if (bytes.length === 1) {
      const lead: number = bytes[0];
      let expected: number = 1;
      if (lead >= 0xF0) {
        expected = 4;
      } else if (lead >= 0xE0) {
        expected = 3;
      } else if (lead >= 0xC0) {
        expected = 2;
      }
      // 继续读到够 expected 个字节
      while (bytes.length < expected && i + 2 < text.length + 1 && text.charAt(i) === '%') {
        const h2: number = hexValue(text.charAt(i + 1));
        const l2: number = hexValue(text.charAt(i + 2));
        if (h2 < 0 || l2 < 0) {
          break;
        }
        bytes.push(h2 * 16 + l2);
        i += 3;
      }
      break;
    }
  }
  if (bytes.length === 0) {
    return new PercentDecode('', 0);
  }
  return new PercentDecode(utf8Decode(bytes), i - start);
}

/** 单字符十六进制值；非法返回 -1 */
function hexValue(ch: string): number {
  const code: number = ch.charCodeAt(0);
  if (code >= 48 && code <= 57) {
    return code - 48;
  }
  if (code >= 65 && code <= 70) {
    return code - 55;
  }
  if (code >= 97 && code <= 102) {
    return code - 87;
  }
  return -1;
}

/** UTF-8 字节序列 → 字符串 */
function utf8Decode(bytes: Array<number>): string {
  let result: string = '';
  let i: number = 0;
  while (i < bytes.length) {
    const b0: number = bytes[i];
    if (b0 < 0x80) {
      result += String.fromCharCode(b0);
      i++;
      continue;
    }
    if (b0 >= 0xC0 && b0 < 0xE0 && i + 1 < bytes.length) {
      const code: number = ((b0 & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
      result += String.fromCharCode(code);
      i += 2;
      continue;
    }
    if (b0 >= 0xE0 && b0 < 0xF0 && i + 2 < bytes.length) {
      const code: number = ((b0 & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F);
      result += String.fromCharCode(code);
      i += 3;
      continue;
    }
    if (b0 >= 0xF0 && i + 3 < bytes.length) {
      // 四字节码点要转成代理对
      const codePoint: number = ((b0 & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12)
        | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
      const adjusted: number = codePoint - 0x10000;
      result += String.fromCharCode(0xD800 + (adjusted >> 10));
      result += String.fromCharCode(0xDC00 + (adjusted & 0x3FF));
      i += 4;
      continue;
    }
    // 非法字节：原样跳过，不要让整段解码失败
    i++;
  }
  return result;
}

/**
 * 文件大小的可读写法。
 *
 * 负数返回空串（而不是「未知」）：那句话是给用户看的，纯逻辑层不该产出它。
 * 单位（B/KB/MB）是国际通用的，不需要翻译。
 */
export function formatSize(bytes: number): string {
  if (bytes < 0) {
    return '';
  }
  if (bytes < 1024) {
    return String(bytes) + ' B';
  }
  if (bytes < 1024 * 1024) {
    return String(Math.round(bytes / 1024 * 10) / 10) + ' KB';
  }
  return String(Math.round(bytes / (1024 * 1024) * 10) / 10) + ' MB';
}

/** 文件太大时拒绝打开的门槛（字符数）。超过它读取与渲染都会明显卡顿。 */
export const MAX_FILE_CHARS: number = 2000000;

/**
 * 打开前的检查：文件是否大到不该打开。
 *
 * 这里**只回答是或否**，不再返回一句中文。原因是那句话里嵌了语言相关的东西
 * （数字单位、「行」这个量词、以及整句语序），纯逻辑层没有能力按语言重组它。
 * 文案由 UI 层的 fileTooLargeText 用资源键生成。
 *
 * 顺带说明为什么原先放在这里不合适：describeDocument / rejectReason 都是**显示**函数，
 * 却住在纯逻辑层——那正是这一轮要修的分层错误（显示逻辑归 UI）。
 */
export function isFileTooLarge(charCount: number): boolean {
  return charCount > MAX_FILE_CHARS;
}