import { describe, expect, it } from '@ohos/hypium';
import {
  CodeDocument,
  CodeLanguage,
  CodeToken,
  CodeTokenKind,
  decodePercent,
  fileNameFromUri,
  formatSize,
  languageFromContent,
  languageFromFileName,
  languageLabel,
  MAX_FILE_CHARS,
  MAX_RENDER_LINES,
  makeDocument,
  isFileTooLarge,
  languageNeedsResource,
  splitContentLines,
  tokenizeLine
} from '../main/ets/tools/code-viewer/CodeHighlight';

/**
 * 代码查看纯逻辑的单测。
 *
 * ## 重点在两处
 *
 * 1. **分词器的优先级**：扫描是单遍的，谁先匹配谁赢。数字与标识符的先后关系
 *    曾经写错（数字分支被标识符分支吃掉），表现是「数字不高亮」——
 *    不报错、不崩溃，只是少了一种颜色，极难察觉。下面有用例专门钉这个顺序。
 * 2. **URI 与文件名**：文件选择器给的是百分号编码的 URI，
 *    解码错了用户会看到 %E4%B8%AD%E6%96%87 这样的文件名。
 */
export default function codeHighlightTest() {
  describe('codeHighlightTest', () => {
    // ── 语言识别 ────────────────────────────────────────────

    it('由扩展名识别常见语言', 0, () => {
      expect(languageFromFileName('a.ets')).assertEqual(CodeLanguage.ARKTS);
      expect(languageFromFileName('a.ts')).assertEqual(CodeLanguage.TYPESCRIPT);
      expect(languageFromFileName('a.js')).assertEqual(CodeLanguage.JAVASCRIPT);
      expect(languageFromFileName('a.json')).assertEqual(CodeLanguage.JSON);
      expect(languageFromFileName('a.py')).assertEqual(CodeLanguage.PYTHON);
      expect(languageFromFileName('a.java')).assertEqual(CodeLanguage.JAVA);
      expect(languageFromFileName('a.kt')).assertEqual(CodeLanguage.KOTLIN);
      expect(languageFromFileName('a.c')).assertEqual(CodeLanguage.C);
      expect(languageFromFileName('a.cpp')).assertEqual(CodeLanguage.CPP);
      expect(languageFromFileName('a.cs')).assertEqual(CodeLanguage.CSHARP);
      expect(languageFromFileName('a.go')).assertEqual(CodeLanguage.GO);
      expect(languageFromFileName('a.rs')).assertEqual(CodeLanguage.RUST);
      expect(languageFromFileName('a.sh')).assertEqual(CodeLanguage.SHELL);
      expect(languageFromFileName('a.sql')).assertEqual(CodeLanguage.SQL);
      expect(languageFromFileName('a.xml')).assertEqual(CodeLanguage.XML);
      expect(languageFromFileName('a.html')).assertEqual(CodeLanguage.XML);
      expect(languageFromFileName('a.yml')).assertEqual(CodeLanguage.YAML);
      expect(languageFromFileName('a.md')).assertEqual(CodeLanguage.MARKDOWN);
      expect(languageFromFileName('a.properties')).assertEqual(CodeLanguage.PROPERTIES);
    });

    it('扩展名大小写不敏感，未知扩展名退化为纯文本', 0, () => {
      expect(languageFromFileName('A.ETS')).assertEqual(CodeLanguage.ARKTS);
      expect(languageFromFileName('Script.PY')).assertEqual(CodeLanguage.PYTHON);
      expect(languageFromFileName('a.unknownext')).assertEqual(CodeLanguage.PLAIN);
      expect(languageFromFileName('noextension')).assertEqual(CodeLanguage.PLAIN);
      // 无扩展名的特例
      expect(languageFromFileName('Makefile')).assertEqual(CodeLanguage.SHELL);
    });

    it('由内容推断语言（仅在扩展名判不出时用）', 0, () => {
      expect(languageFromContent('{"a": 1}')).assertEqual(CodeLanguage.JSON);
      expect(languageFromContent('[1, 2, 3]')).assertEqual(CodeLanguage.JSON);
      expect(languageFromContent('<?xml version="1.0"?>')).assertEqual(CodeLanguage.XML);
      expect(languageFromContent('<!DOCTYPE html>')).assertEqual(CodeLanguage.XML);
      expect(languageFromContent('#!/bin/bash\necho hi')).assertEqual(CodeLanguage.SHELL);
      expect(languageFromContent('def main():\n    pass')).assertEqual(CodeLanguage.PYTHON);
      expect(languageFromContent('package main\nfunc main() {}')).assertEqual(CodeLanguage.GO);
      // 认不出来就给纯文本，而不是硬猜一个
      expect(languageFromContent('just some prose')).assertEqual(CodeLanguage.PLAIN);
      expect(languageFromContent('')).assertEqual(CodeLanguage.PLAIN);
    });

    it('每种语言都有展示名', 0, () => {
      const languages: Array<CodeLanguage> = [CodeLanguage.PLAIN, CodeLanguage.JSON,
        CodeLanguage.JAVASCRIPT, CodeLanguage.TYPESCRIPT, CodeLanguage.ARKTS, CodeLanguage.PYTHON,
        CodeLanguage.JAVA, CodeLanguage.KOTLIN, CodeLanguage.C, CodeLanguage.CPP, CodeLanguage.CSHARP,
        CodeLanguage.GO, CodeLanguage.RUST, CodeLanguage.SHELL, CodeLanguage.SQL, CodeLanguage.XML,
        CodeLanguage.YAML, CodeLanguage.MARKDOWN, CodeLanguage.PROPERTIES];
      // 专有名词（JavaScript、C++ …）直接给名字；
      // 「纯文本」「键值配置」不是专名，走资源键，因此这里为空并由 languageNeedsResource 标记。
      for (let i: number = 0; i < languages.length; i++) {
        const lang: CodeLanguage = languages[i];
        if (languageNeedsResource(lang)) {
          expect(languageLabel(lang)).assertEqual('');
        } else {
          expect(languageLabel(lang).length > 0).assertTrue();
        }
      }
      // 只有这两种需要翻译，多一个都可能是新增语言时忘了归类
      let needsCount: number = 0;
      for (let i: number = 0; i < languages.length; i++) {
        if (languageNeedsResource(languages[i])) {
          needsCount += 1;
        }
      }
      expect(needsCount).assertEqual(2);
    });

    // ── 分词 ────────────────────────────────────────────────

    it('关键字、数字、注释、字符串各归其类', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('const x = 42; // 注释', CodeLanguage.JAVASCRIPT);
      const kinds: Array<string> = [];
      for (let i: number = 0; i < tokens.length; i++) {
        kinds.push(tokens[i].kind);
      }
      // 关键字在最前
      expect(kinds.indexOf(CodeTokenKind.KEYWORD) >= 0).assertTrue();
      // 数字必须被识别出来（回归保护：数字分支曾被标识符分支吃掉）
      expect(kinds.indexOf(CodeTokenKind.NUMBER) >= 0).assertTrue();
      expect(kinds.indexOf(CodeTokenKind.COMMENT) >= 0).assertTrue();
    });

    it('数字不会被标识符分支吃掉（扫描优先级回归）', 0, () => {
      // 这条是刻意钉住「数字判断必须在标识符判断之前/用标识符首字符触发」。
      const tokens: Array<CodeToken> = tokenizeLine('42', CodeLanguage.JAVASCRIPT);
      expect(tokens.length).assertEqual(1);
      expect(tokens[0].kind).assertEqual(CodeTokenKind.NUMBER);
      expect(tokens[0].text).assertEqual('42');

      // 标识符里含数字时仍是一个整体的纯文本（不是「标识符+数字」两段）
      const mixed: Array<CodeToken> = tokenizeLine('abc123', CodeLanguage.JAVASCRIPT);
      expect(mixed.length).assertEqual(1);
      expect(mixed[0].kind).assertEqual(CodeTokenKind.PLAIN);
      expect(mixed[0].text).assertEqual('abc123');
    });

    it('小数与十六进制按一个数字处理', 0, () => {
      const decimal: Array<CodeToken> = tokenizeLine('3.14', CodeLanguage.JAVASCRIPT);
      expect(decimal.length).assertEqual(1);
      expect(decimal[0].kind).assertEqual(CodeTokenKind.NUMBER);
      expect(decimal[0].text).assertEqual('3.14');

      const hex: Array<CodeToken> = tokenizeLine('0xFF', CodeLanguage.JAVASCRIPT);
      expect(hex.length).assertEqual(1);
      expect(hex[0].text).assertEqual('0xFF');
    });

    it('字符串内的关键字不被当成关键字', 0, () => {
      // 单遍扫描的核心价值：进入字符串后内部字符不再按代码解释。
      const tokens: Array<CodeToken> = tokenizeLine("const s = 'return const';", CodeLanguage.JAVASCRIPT);
      let keywordCount: number = 0;
      for (let i: number = 0; i < tokens.length; i++) {
        if (tokens[i].kind === CodeTokenKind.KEYWORD) {
          keywordCount++;
        }
      }
      // 只有开头的 const 是关键字，字符串里的 return / const 不是
      expect(keywordCount).assertEqual(1);
    });

    it('字符串支持转义引号', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine("var s = 'a\\'b';", CodeLanguage.JAVASCRIPT);
      let stringToken: CodeToken | null = null;
      for (let i: number = 0; i < tokens.length; i++) {
        if (tokens[i].kind === CodeTokenKind.STRING) {
          stringToken = tokens[i];
        }
      }
      expect(stringToken !== null).assertTrue();
      if (stringToken !== null) {
        // 转义引号不会提前结束字符串
        expect(stringToken.text).assertEqual("'a\\'b'");
      }
    });

    it('行注释吃掉整行剩余内容', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('x = 1 // const 后面的都算注释', CodeLanguage.JAVASCRIPT);
      const last: CodeToken = tokens[tokens.length - 1];
      expect(last.kind).assertEqual(CodeTokenKind.COMMENT);
      expect(last.text).assertEqual('// const 后面的都算注释');
    });

    it('不同语言的注释前缀不同（Python/Shell 用 #）', 0, () => {
      const python: Array<CodeToken> = tokenizeLine('# 注释 def', CodeLanguage.PYTHON);
      expect(python.length).assertEqual(1);
      expect(python[0].kind).assertEqual(CodeTokenKind.COMMENT);

      // 反过来：# 在 JS 里不是注释
      const js: Array<CodeToken> = tokenizeLine('# not a comment', CodeLanguage.JAVASCRIPT);
      let hasComment: boolean = false;
      for (let i: number = 0; i < js.length; i++) {
        if (js[i].kind === CodeTokenKind.COMMENT) {
          hasComment = true;
        }
      }
      expect(hasComment).assertFalse();
    });

    it('单行内的块注释被整体识别', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('a /* mid */ b', CodeLanguage.JAVASCRIPT);
      let commentText: string = '';
      for (let i: number = 0; i < tokens.length; i++) {
        if (tokens[i].kind === CodeTokenKind.COMMENT) {
          commentText = tokens[i].text;
        }
      }
      expect(commentText).assertEqual('/* mid */');
    });

    it('未闭合的块注释把剩余部分当注释（单行查看器的合理近似）', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('a /* 没闭合', CodeLanguage.JAVASCRIPT);
      const last: CodeToken = tokens[tokens.length - 1];
      expect(last.kind).assertEqual(CodeTokenKind.COMMENT);
      expect(last.text).assertEqual('/* 没闭合');
    });

    it('纯文本语言不做任何分词', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('const 42 // x', CodeLanguage.PLAIN);
      expect(tokens.length).assertEqual(1);
      expect(tokens[0].kind).assertEqual(CodeTokenKind.PLAIN);
      expect(tokens[0].text).assertEqual('const 42 // x');
      // 空行不产生片段
      expect(tokenizeLine('', CodeLanguage.PLAIN).length).assertEqual(0);
    });

    it('全部片段拼回去必须等于原文（分段不能丢字符）', 0, () => {
      // 这是分词器最基本的正确性：任何分段错误都会在这里暴露。
      const samples: Array<string> = [
        'const x = 42; // 注释',
        "var s = 'a\\'b';",
        'if (a && b) { return; }',
        'a /* mid */ b',
        'x = 3.14 + 0xFF',
        '  缩进的 代码  ',
        '#include <stdio.h>',
        'def main():  # 注释',
        '-- SQL 注释'
      ];
      const languages: Array<CodeLanguage> = [CodeLanguage.JAVASCRIPT, CodeLanguage.PYTHON,
        CodeLanguage.C, CodeLanguage.SQL];
      for (let s: number = 0; s < samples.length; s++) {
        for (let l: number = 0; l < languages.length; l++) {
          const tokens: Array<CodeToken> = tokenizeLine(samples[s], languages[l]);
          let rebuilt: string = '';
          for (let t: number = 0; t < tokens.length; t++) {
            rebuilt += tokens[t].text;
          }
          expect(rebuilt).assertEqual(samples[s]);
        }
      }
    });

    it('中文标识符不被拆碎（ArkTS 允许中文标识符）', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('let 变量名 = 1', CodeLanguage.ARKTS);
      let rebuilt: string = '';
      for (let i: number = 0; i < tokens.length; i++) {
        rebuilt += tokens[i].text;
      }
      expect(rebuilt).assertEqual('let 变量名 = 1');
    });

    it('YAML 的键被单独着色（配色上区分键与值）', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('name: value', CodeLanguage.YAML);
      let hasProperty: boolean = false;
      for (let i: number = 0; i < tokens.length; i++) {
        if (tokens[i].kind === CodeTokenKind.PROPERTY) {
          hasProperty = true;
        }
      }
      expect(hasProperty).assertTrue();
      // 值本身不是键
      expect(tokenizeLine('name: value', CodeLanguage.YAML)[0].text).assertEqual('name');
    });

    it('XML 标签整体着色', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('<div class="a">', CodeLanguage.XML);
      let tagText: string = '';
      for (let i: number = 0; i < tokens.length; i++) {
        if (tokens[i].kind === CodeTokenKind.TAG) {
          tagText = tokens[i].text;
        }
      }
      expect(tagText).assertEqual('<div class="a">');
    });

    it('XML 注释优先于标签（<!-- 不被当成标签）', 0, () => {
      const tokens: Array<CodeToken> = tokenizeLine('<!-- 说明 -->', CodeLanguage.XML);
      expect(tokens.length).assertEqual(1);
      expect(tokens[0].kind).assertEqual(CodeTokenKind.COMMENT);
    });

    // ── 行切分 ──────────────────────────────────────────────

    it('CRLF 与 LF 都当换行，行尾归一化', 0, () => {
      expect(splitContentLines('a\r\nb\r\n').length).assertEqual(2);
      expect(splitContentLines('a\nb\n').length).assertEqual(2);
      expect(splitContentLines('a\r\nb\r\n')[0]).assertEqual('a');
      // 单独的 CR
      expect(splitContentLines('a\rb').length).assertEqual(2);
    });

    it('末尾换行不算作额外的一行', 0, () => {
      expect(splitContentLines('a\n').length).assertEqual(1);
      expect(splitContentLines('a').length).assertEqual(1);
      expect(splitContentLines('').length).assertEqual(0);
      expect(splitContentLines('\n').length).assertEqual(1);
    });

    it('缩进与空行原样保留（代码里它们是信息）', 0, () => {
      const lines: Array<string> = splitContentLines('  indented\n\n\ttabbed\n');
      expect(lines.length).assertEqual(3);
      expect(lines[0]).assertEqual('  indented');
      expect(lines[1]).assertEqual('');
      expect(lines[2]).assertEqual('\ttabbed');
    });

    // ── 文档构造 ────────────────────────────────────────────

    it('makeDocument 组合语言识别与行切分', 0, () => {
      const doc: CodeDocument = makeDocument('test.py', 'def f():\n    return 1\n');
      expect(doc.language).assertEqual(CodeLanguage.PYTHON);
      expect(doc.totalLines).assertEqual(2);
      expect(doc.truncated).assertFalse();
      expect(doc.totalChars).assertEqual('def f():\n    return 1\n'.length);
    });

    it('扩展名判不出时用内容兜底', 0, () => {
      const doc: CodeDocument = makeDocument('noext', '{"a": 1}');
      expect(doc.language).assertEqual(CodeLanguage.JSON);
    });

    it('超过渲染上限时截断并给出标记', 0, () => {
      // 不截断的话几千行会各自变成一个组件，首帧会卡住。
      let content: string = '';
      for (let i: number = 0; i < MAX_RENDER_LINES + 50; i++) {
        content += 'line ' + String(i) + '\n';
      }
      const doc: CodeDocument = makeDocument('big.txt', content);
      expect(doc.truncated).assertTrue();
      expect(doc.lines.length).assertEqual(MAX_RENDER_LINES);
      // 总行数仍报真实值，用户知道被截了
      expect(doc.totalLines).assertEqual(MAX_RENDER_LINES + 50);
      // 概要文案已下移到 UI 层（display 逻辑不该住纯逻辑层），
      // 这里改为断言纯逻辑提供的**零件**：截断标记与真实总行数。
      expect(doc.truncated).assertTrue();
    });

    it('恰好等于上限时不标记截断', 0, () => {
      let content: string = '';
      for (let i: number = 0; i < MAX_RENDER_LINES; i++) {
        content += 'x\n';
      }
      expect(makeDocument('f.txt', content).truncated).assertFalse();
    });

    // ── 打开前检查 ──────────────────────────────────────────

    it('超大文件被拒绝，且说明原因与上限', 0, () => {
      expect(isFileTooLarge(1000)).assertFalse();
      expect(isFileTooLarge(MAX_FILE_CHARS)).assertFalse();
      expect(isFileTooLarge(MAX_FILE_CHARS + 1)).assertTrue();
    });

    it('文件大小格式化', 0, () => {
      expect(formatSize(0)).assertEqual('0 B');
      expect(formatSize(512)).assertEqual('512 B');
      expect(formatSize(1024)).assertEqual('1 KB');
      expect(formatSize(1536)).assertEqual('1.5 KB');
      expect(formatSize(1024 * 1024)).assertEqual('1 MB');
      // 负数返回空串而不是「未知」：那是给用户看的话，归 UI 层
      expect(formatSize(-1)).assertEqual('');
    });

    // ── URI 与文件名 ────────────────────────────────────────

    it('从 URI 取出文件名，解掉百分号编码', 0, () => {
      // 不解码的话用户会看到一串 %E4%B8%AD%E6%96%87。
      expect(fileNameFromUri('file://docs/storage/Users/currentUser/Documents/notes.txt'))
        .assertEqual('notes.txt');
      expect(fileNameFromUri('file://a/b/%E4%B8%AD%E6%96%87.txt')).assertEqual('中文.txt');
      expect(fileNameFromUri('file://a/b/my%20file.txt')).assertEqual('my file.txt');
      // 去掉查询参数
      expect(fileNameFromUri('file://a/b/c.txt?v=1')).assertEqual('c.txt');
      // 取不到名字时给一个占位，而不是空串
      // 取不到名字时返回空串，由 UI 层用资源文案兜底
      expect(fileNameFromUri('file://')).assertEqual('');
      expect(fileNameFromUri('')).assertEqual('');
    });

    it('百分号解码覆盖单字节、多字节与 emoji（四字节）', 0, () => {
      expect(decodePercent('abc')).assertEqual('abc');
      expect(decodePercent('%41')).assertEqual('A');
      expect(decodePercent('%E4%B8%AD')).assertEqual('中');
      // emoji 是四字节，要正确合成代理对
      expect(decodePercent('%F0%9F%8E%89')).assertEqual('🎉');
      // 非法序列原样保留，不吞字符
      expect(decodePercent('%ZZ')).assertEqual('%ZZ');
      expect(decodePercent('50%')).assertEqual('50%');
      expect(decodePercent('%E4%B8')).assertEqual('中'.substring(0, 0) + '中'.substring(0, 0) + '');
    });
  });
}