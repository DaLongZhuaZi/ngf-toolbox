import { describe, expect, it } from '@ohos/hypium';
import {
  clampIndent,
  describeJsonRoot,
  JsonErrorCode,
  uniqueDuplicateKeys,
  escapeJsonString,
  formatJson,
  JSON_DEFAULT_INDENT,
  JSON_MAX_DEPTH,
  JSON_MAX_INDENT,
  JSON_MIN_INDENT,
  JsonError,
  JsonFormatResult,
  JsonMember,
  JsonNode,
  JsonNodeKind,
  JsonParseResult,
  JsonStringResult,
  minifyJson,
  parseJson,
  unescapeJsonString
} from '../main/ets/tools/json-toolkit/JsonLogic';

/** 反斜杠：测试里到处要用，抽成一个常量比反复数转义层级可靠 */
const BACKSLASH: string = '\\';
/** 用 N 个 '[' 拼出深层嵌套，用于验证层级上限不会把调用栈打爆 */
function nestedArray(depth: number): string {
  let head: string = '';
  let tail: string = '';
  for (let i = 0; i < depth; i++) {
    head = head + '[';
    tail = tail + ']';
  }
  return head + '1' + tail;
}

/**
 * 解析失败的**码**；成功时返回 NONE。
 *
 * 原先断言的是 errorText() 的中文子串——那是文案，已下移到 UI 层。
 * 断言码之后，文案改措辞不会让测试变红，而「这段 JSON 错在哪」被钉住了。
 */
function errCode(text: string): JsonErrorCode {
  const parsed: JsonParseResult = parseJson(text);
  return parsed.error === null ? JsonErrorCode.NONE : parsed.error.code;
}

export default function jsonToolkitTest() {
  describe('jsonToolkitTest', () => {

    // ── 解析正常路径 ───────────────────────────────────────

    it('parses_object_and_keeps_member_order', 0, () => {
      const result = parseJson('{"b":1,"a":2}');
      expect(result.ok).assertTrue();
      const root = result.root as JsonNode;
      expect(root.kind).assertEqual(JsonNodeKind.OBJECT);
      expect(root.members.length).assertEqual(2);
      // 顺序必须保持原样：工具是给人读的，重排键会让用户怀疑数据被改了
      const first: JsonMember = root.members[0];
      expect(first.key).assertEqual('b');
      expect(first.keyRaw).assertEqual('"b"');
      expect(first.value.raw).assertEqual('1');
      expect(root.members[1].key).assertEqual('a');
    });

    it('handles_all_top_level_kinds', 0, () => {
      expect((parseJson('[1,2,3]').root as JsonNode).kind).assertEqual(JsonNodeKind.ARRAY);
      expect((parseJson('"hi"').root as JsonNode).kind).assertEqual(JsonNodeKind.STRING);
      expect((parseJson('42').root as JsonNode).kind).assertEqual(JsonNodeKind.NUMBER);
      expect((parseJson('true').root as JsonNode).kind).assertEqual(JsonNodeKind.BOOLEAN);
      expect((parseJson('null').root as JsonNode).kind).assertEqual(JsonNodeKind.NULL);
    });

    it('accepts_bom_prefixed_text_from_windows_editors', 0, () => {
      const text = String.fromCharCode(0xFEFF) + '{"a":1}';
      const result = parseJson(text);
      expect(result.ok).assertTrue();
      expect((result.root as JsonNode).members.length).assertEqual(1);
    });

    it('rejects_empty_and_whitespace_only_input', 0, () => {
      expect(parseJson('').ok).assertFalse();
      expect(parseJson('   \n  ').ok).assertFalse();
      expect(errCode('')).assertEqual(JsonErrorCode.EMPTY);
    });

    // ── 大数字不丢精度（本工具的立身之本）──────────────────

    it('keeps_big_integer_literal_exactly_as_written', 0, () => {
      // 这条是防「用 JSON.parse 再 stringify」这种实现：那样 12345678901234567890
      // 会变成 12345678901234567000，用户的数据被悄悄改了
      const text = '{"id":12345678901234567890}';
      const formatted = formatJson(text, 2);
      expect(formatted.ok).assertTrue();
      expect(formatted.text).assertContain('12345678901234567890');
      expect(formatted.text.indexOf('12345678901234567000') < 0).assertTrue();
    });

    it('keeps_number_literals_that_js_would_not_survive', 0, () => {
      expect(formatJson('{"a":1e400}', 0).text).assertContain('1e400');
      expect(formatJson('{"a":-0}', 0).text).assertContain('-0');
      expect(formatJson('{"a":1.500}', 0).text).assertContain('1.500');
      expect(formatJson('{"a":1E+2}', 0).text).assertContain('1E+2');
    });

    it('rejects_malformed_numbers_instead_of_guessing', 0, () => {
      expect(parseJson('01').ok).assertFalse();
      expect(parseJson('1.').ok).assertFalse();
      expect(parseJson('1e').ok).assertFalse();
      expect(parseJson('-').ok).assertFalse();
      expect(parseJson('.5').ok).assertFalse();
      expect(errCode('01')).assertEqual(JsonErrorCode.NUMBER_LEADING_ZERO);
    });

    // ── 格式化 / 压缩 ──────────────────────────────────────

    it('formats_with_two_space_indent', 0, () => {
      const result = formatJson('{"a":1}', 2);
      expect(result.ok).assertTrue();
      expect(result.text).assertEqual('{\n  "a": 1\n}');
    });

    it('formats_nested_object_and_array', 0, () => {
      const result = formatJson('{"a":[1,2]}', 2);
      expect(result.text).assertEqual('{\n  "a": [\n    1,\n    2\n  ]\n}');
    });

    it('indent_zero_still_breaks_lines_but_adds_no_spaces', 0, () => {
      const result = formatJson('{"a":{"b":1}}', 0);
      expect(result.text).assertEqual('{\n"a": {\n"b": 1\n}\n}');
    });

    it('clamps_indent_to_supported_range', 0, () => {
      expect(clampIndent(-3)).assertEqual(JSON_MIN_INDENT);
      expect(clampIndent(99)).assertEqual(JSON_MAX_INDENT);
      expect(clampIndent(JSON_DEFAULT_INDENT)).assertEqual(2);
      // 越界值会被夹住而不是报错：用户要的是结果，不是一句「缩进太大」
      expect(formatJson('{"a":1}', 99).text).assertContain('        "a"');
    });

    it('keeps_empty_object_and_array_on_one_line', 0, () => {
      expect(formatJson('{}', 2).text).assertEqual('{}');
      expect(formatJson('{"a":{},"b":[]}', 2).text).assertEqual('{\n  "a": {},\n  "b": []\n}');
    });

    it('minify_removes_every_non_essential_space', 0, () => {
      const result = minifyJson('{\n  "a": [1, 2],\n  "b": "x y"\n}');
      expect(result.ok).assertTrue();
      expect(result.text).assertEqual('{"a":[1,2],"b":"x y"}');
      // 字符串里的空格不能被删掉，否则数据就坏了
      expect(result.text).assertContain('x y');
    });

    it('format_and_minify_are_idempotent', 0, () => {
      const once = minifyJson('{"a": [1, {"b": 2}]}').text;
      const twice = minifyJson(once).text;
      expect(twice).assertEqual(once);
      const pretty = formatJson(once, 2).text;
      expect(formatJson(pretty, 2).text).assertEqual(pretty);
    });

    it('format_failure_reports_error_and_empty_text', 0, () => {
      const result: JsonFormatResult = formatJson('{"a":}', 2);
      expect(result.ok).assertFalse();
      expect(result.text).assertEqual('');
      expect(result.error !== null).assertTrue();
      expect(result.error === null).assertFalse();
    });

    it('duplicate_keys_are_reported_but_kept_in_output', 0, () => {
      const result: JsonParseResult = parseJson('{"a":1,"a":2}');
      expect(result.ok).assertTrue();
      expect(result.duplicateKeys.length).assertEqual(1);
      expect(result.duplicateKeys[0]).assertEqual('a');
      expect(uniqueDuplicateKeys(result.duplicateKeys).length > 0).assertTrue();
      // 结构必须原样保留：不替用户决定该丢哪一个
      expect(formatJson('{"a":1,"a":2}', 0).text).assertContain('"a": 1');
      expect(formatJson('{"a":1,"a":2}', 0).text).assertContain('"a": 2');
      expect(uniqueDuplicateKeys([]).length).assertEqual(0);
    });

    // ── 错误定位 ──────────────────────────────────────────

    it('locates_trailing_comma_position', 0, () => {
      const result = parseJson('{"a":1,}');
      expect(result.ok).assertFalse();
      const error = result.error as JsonError;
      expect(error.line).assertEqual(1);
      expect(error.column).assertEqual(8);
      expect(error.position).assertEqual(7);
      expect(error.code).assertEqual(JsonErrorCode.OBJECT_TRAILING_COMMA);
    });

    it('locates_error_on_the_correct_line_and_column', 0, () => {
      // '{\n"a":1,\n}' 里出问题的是第 3 行第 1 列的 '}'（尾随逗号）；
      // 换行会把列号重置为 1，所以是第 1 列而不是第 2 列
      const result = parseJson('{\n"a":1,\n}');
      const error = result.error as JsonError;
      expect(error.line).assertEqual(3);
      expect(error.column).assertEqual(1);
      // 位置不再拼进文案；直接断言 line / column（UI 层负责组织语言）
      expect(result.error === null).assertFalse();
      expect((result.error as JsonError).line).assertEqual(3);
      expect((result.error as JsonError).column).assertEqual(1);
    });

    it('locates_missing_comma_between_members', 0, () => {
      // 第 3 行是 '  "b": 2'，第二个键的左引号在它的第 3 列
      const result = parseJson('{\n  "a": 1\n  "b": 2\n}');
      const error = result.error as JsonError;
      expect(error.line).assertEqual(3);
      expect(error.column).assertEqual(3);
      expect(error.code).assertEqual(JsonErrorCode.OBJECT_MISSING_COMMA);
    });

    it('rejects_single_quoted_strings', 0, () => {
      const result = parseJson("{'a':1}");
      expect(result.ok).assertFalse();
      // 对象里用单引号当**键**，走的是「键必须用双引号」那条码
      expect((result.error as JsonError).code).assertEqual(JsonErrorCode.OBJECT_KEY_SINGLE_QUOTE);
      expect(parseJson('["x"]').ok).assertTrue();
      // 数组里用单引号当**值**，走的是「字符串必须用双引号」那条
      expect(parseJson("['x']").ok).assertFalse();
      expect(errCode("['x']")).assertEqual(JsonErrorCode.SINGLE_QUOTE_STRING);
    });

    it('rejects_unquoted_keys_and_missing_colon', 0, () => {
      expect(errCode('{a:1}')).assertEqual(JsonErrorCode.OBJECT_KEY_NOT_STRING);
      expect(errCode('{"a" 1}')).assertEqual(JsonErrorCode.OBJECT_COLON);
    });

    it('rejects_comments_which_are_not_part_of_json', 0, () => {
      expect(errCode('// note\n{"a":1}')).assertEqual(JsonErrorCode.COMMENT);
      expect(parseJson('{"a":1} /* tail */').ok).assertFalse();
      expect(parseJson('{"a":1} // tail').ok).assertFalse();
    });

    it('rejects_unterminated_string_and_control_chars', 0, () => {
      expect(errCode('{"a":"x}')).assertEqual(JsonErrorCode.STRING_UNTERMINATED);
      const withNewline = '{"a":"x' + String.fromCharCode(10) + 'y"}';
      expect(errCode(withNewline)).assertEqual(JsonErrorCode.STRING_CONTROL_CHAR);
      expect(parseJson('{"a":"x' + BACKSLASH).ok).assertFalse();
    });

    it('rejects_trailing_content_after_the_value', 0, () => {
      const result = parseJson('{"a":1} {"b":2}');
      expect(result.ok).assertFalse();
      expect((result.error as JsonError).code).assertEqual(JsonErrorCode.TRAILING);
      expect((result.error as JsonError).position).assertEqual(8);
    });

    it('rejects_unclosed_object_and_array', 0, () => {
      expect(errCode('{"a":1')).assertEqual(JsonErrorCode.OBJECT_UNCLOSED);
      expect(errCode('[1,2')).assertEqual(JsonErrorCode.ARRAY_UNCLOSED);
      expect(errCode('[1,2,]')).assertEqual(JsonErrorCode.ARRAY_TRAILING_COMMA);
    });

    it('rejects_unknown_literals', 0, () => {
      expect(parseJson('NaN').ok).assertFalse();
      expect(parseJson('Infinity').ok).assertFalse();
      expect(parseJson('undefined').ok).assertFalse();
      expect(parseJson('tru').ok).assertFalse();
    });

    // ── 深层嵌套（防调用栈崩溃）────────────────────────────

    it('accepts_nesting_at_the_limit_and_rejects_beyond_it', 0, () => {
      const atLimit = parseJson(nestedArray(JSON_MAX_DEPTH));
      expect(atLimit.ok).assertTrue();
      const overLimit = parseJson(nestedArray(JSON_MAX_DEPTH + 1));
      expect(overLimit.ok).assertFalse();
      expect((overLimit.error as JsonError).code).assertEqual(JsonErrorCode.TOO_DEEP);
    });

    it('absurdly_deep_input_fails_fast_without_crashing', 0, () => {
      // 5000 层：必须在 129 层就停下并报错，而不是一直递归到栈溢出
      // （栈溢出是捕获不到的崩溃，不是一条红字错误）
      const result = parseJson(nestedArray(5000));
      expect(result.ok).assertFalse();
      expect((result.error as JsonError).code).assertEqual(JsonErrorCode.TOO_DEEP);
    });

    // ── 转义 / 反转义 ─────────────────────────────────────

    it('escape_only_touches_what_json_requires', 0, () => {
      expect(escapeJsonString('中文😀')).assertEqual('中文😀');
      expect(escapeJsonString('a"b')).assertEqual('a' + BACKSLASH + '"b');
      expect(escapeJsonString('a' + BACKSLASH + 'b')).assertEqual('a' + BACKSLASH + BACKSLASH + 'b');
      expect(escapeJsonString('a\nb')).assertEqual('a' + BACKSLASH + 'nb');
    });

    it('escape_turns_control_chars_into_unicode_escapes', 0, () => {
      expect(escapeJsonString(String.fromCharCode(1))).assertEqual(BACKSLASH + 'u0001');
      expect(escapeJsonString(String.fromCharCode(0x1F))).assertEqual(BACKSLASH + 'u001F');
    });

    it('unescape_restores_every_supported_escape', 0, () => {
      expect(unescapeJsonString(BACKSLASH + 'u4E2D').text).assertEqual('中');
      expect(unescapeJsonString(BACKSLASH + 'n').text.charCodeAt(0)).assertEqual(10);
      expect(unescapeJsonString(BACKSLASH + 't').text.charCodeAt(0)).assertEqual(9);
      expect(unescapeJsonString(BACKSLASH + '"').text).assertEqual('"');
      expect(unescapeJsonString(BACKSLASH + '/').text).assertEqual('/');
      expect(unescapeJsonString(BACKSLASH + BACKSLASH).text).assertEqual(BACKSLASH);
    });

    it('escape_and_unescape_round_trip_on_hard_text', 0, () => {
      const hard = '中文😀"quote"' + BACKSLASH + '\n\t 空 格';
      const escaped = escapeJsonString(hard);
      const restored: JsonStringResult = unescapeJsonString(escaped);
      expect(restored.ok).assertTrue();
      expect(restored.text).assertEqual(hard);
    });

    it('unescape_rejects_broken_escapes_instead_of_silently_passing_them_through', 0, () => {
      expect(unescapeJsonString(BACKSLASH + 'u12').ok).assertFalse();
      expect(unescapeJsonString(BACKSLASH + 'uZZZZ').ok).assertFalse();
      expect(unescapeJsonString(BACKSLASH + 'x').ok).assertFalse();
      expect(unescapeJsonString('abc' + BACKSLASH).ok).assertFalse();
      expect(unescapeJsonString(BACKSLASH + 'x').failure).assertEqual(JsonErrorCode.ESCAPE_UNSUPPORTED);
    });

    it('escaped_keys_are_decoded_but_written_back_verbatim', 0, () => {
      // 键的原文必须原样写回：把 \u4e2d 改写成「中」虽然等价，但用户会以为工具改了数据
      const rawKey = '"' + BACKSLASH + 'u4e2d"';
      const result = parseJson('{' + rawKey + ':1}');
      expect(result.ok).assertTrue();
      expect((result.root as JsonNode).members[0].key).assertEqual('中');
      expect(formatJson('{' + rawKey + ':1}', 0).text).assertContain(rawKey);
    });

    it('string_values_are_written_back_verbatim_too', 0, () => {
      const text = '{"p":"a' + BACKSLASH + 'nb"}';
      const formatted = formatJson(text, 0).text;
      expect(formatted).assertContain('a' + BACKSLASH + 'nb');
      // 不能被还原成真实换行后按换行重新缩进
      expect(formatted.indexOf('a\nb') < 0).assertTrue();
    });

    // ── 描述与摘要 ────────────────────────────────────────

    it('describes_each_root_kind_for_the_header_line', 0, () => {
      // 概要改成结构后，断言种类与数量而不是中文措辞
      expect(describeJsonRoot(parseJson('{"a":1,"b":2}').root).count).assertEqual(2);
      expect(describeJsonRoot(parseJson('{"a":1,"b":2}').root).kind).assertEqual(JsonNodeKind.OBJECT);
      expect(describeJsonRoot(parseJson('[1,2,3]').root).count).assertEqual(3);
      expect(describeJsonRoot(parseJson('[1,2,3]').root).kind).assertEqual(JsonNodeKind.ARRAY);
      expect(describeJsonRoot(parseJson('"abc"').root).count).assertEqual(3);
      expect(describeJsonRoot(parseJson('42').root).raw).assertEqual('42');
      expect(describeJsonRoot(parseJson('true').root).raw).assertEqual('true');
      expect(describeJsonRoot(parseJson('null').root).kind).assertEqual(JsonNodeKind.NULL);
      expect(describeJsonRoot(null).empty).assertTrue();
    });

    it('error_text_is_empty_when_parse_succeeded', 0, () => {
      const ok: JsonParseResult = parseJson('{"a":1}');
      expect(ok.error === null).assertTrue();
      expect(ok.error === null).assertTrue();
      expect(ok.duplicateKeys.length).assertEqual(0);
    });

    it('parse_error_keeps_root_null_so_callers_cannot_read_half_a_tree', 0, () => {
      const failed = parseJson('{"a":1,');
      expect(failed.ok).assertFalse();
      expect(failed.root === null).assertTrue();
    });

    it('handles_large_input_without_losing_structure', 0, () => {
      // 2000 个成员的数组：保证大输入下不会截断、不会漏项
      let text = '[';
      for (let i = 0; i < 2000; i++) {
        if (i > 0) {
          text = text + ',';
        }
        text = text + String(i);
      }
      text = text + ']';
      const result = parseJson(text);
      expect(result.ok).assertTrue();
      expect((result.root as JsonNode).items.length).assertEqual(2000);
      const minified = minifyJson(text);
      expect(minified.ok).assertTrue();
      expect(minified.text).assertEqual(text);
    });
  });
}