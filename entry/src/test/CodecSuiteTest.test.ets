import { describe, expect, it } from '@ohos/hypium';
import {
  base64DecodeBytes,
  base64EncodeBytes,
  ByteResult,
  byteToHex,
  CodecDirection,
  CodecFailureCode,
  CodecMode,
  CodecResult,
  codecModes,
  decodeBase64,
  decodeHex,
  decodeUrlComponent,
  encodeBase64,
  encodeHex,
  encodeUrl,
  encodeUrlComponent,
  escapeUnicode,
  hexValue,
  runCodec,
  unescapeUnicode,
  utf8BytesOf,
  utf8TextOf
} from '../main/ets/tools/codec-suite/CodecLogic';

/** 反斜杠：转义相关的断言里到处要用，抽成常量比一层层数转义可靠得多 */
const BS: string = '\\';
const EMOJI: string = '😀';
const HARD_TEXT: string = '中文 ' + EMOJI + ' a"b' + BS + 'c\n\t 空格';

export default function codecSuiteTest() {
  describe('codecSuiteTest', () => {

    // ── UTF-8 字节层 ──────────────────────────────────────

    it('utf8_encodes_ascii_bmp_and_astral_in_one_pass', 0, () => {
      expect(utf8BytesOf('A').length).assertEqual(1);
      expect(utf8BytesOf('A')[0]).assertEqual(65);
      const chinese = utf8BytesOf('中');
      expect(chinese.length).assertEqual(3);
      expect(chinese[0]).assertEqual(0xE4);
      expect(chinese[1]).assertEqual(0xB8);
      expect(chinese[2]).assertEqual(0xAD);
    });

    it('utf8_encodes_emoji_as_one_four_byte_sequence', 0, () => {
      // 代理对必须合成一个码点再编码：写成两段三字节就会解出两个问号
      const bytes = utf8BytesOf(EMOJI);
      expect(bytes.length).assertEqual(4);
      expect(bytes[0]).assertEqual(0xF0);
      expect(bytes[1]).assertEqual(0x9F);
      expect(bytes[2]).assertEqual(0x98);
      expect(bytes[3]).assertEqual(0x80);
    });

    it('utf8_replaces_lone_surrogates_instead_of_crashing', 0, () => {
      // 粘漏一半的 emoji 很常见，不能因此报错，更不能编出非法字节
      const lone = utf8BytesOf(String.fromCharCode(0xD83D));
      expect(lone.length).assertEqual(3);
      expect(lone[0]).assertEqual(0xEF);
      expect(lone[1]).assertEqual(0xBF);
      expect(lone[2]).assertEqual(0xBD);
    });

    it('utf8_round_trips_hard_text', 0, () => {
      const restored: CodecResult = utf8TextOf(utf8BytesOf(HARD_TEXT));
      expect(restored.ok).assertTrue();
      expect(restored.text).assertEqual(HARD_TEXT);
    });

    it('utf8_decoding_empty_bytes_gives_empty_text', 0, () => {
      expect(utf8BytesOf('').length).assertEqual(0);
      expect(utf8TextOf([]).ok).assertTrue();
      expect(utf8TextOf([]).text).assertEqual('');
    });

    it('utf8_rejects_every_class_of_invalid_sequence', 0, () => {
      expect(utf8TextOf([0xFF]).ok).assertFalse();
      expect(utf8TextOf([0xE4, 0xB8]).ok).assertFalse();
      // 断言原因码而不是文案（文案已下移到 UI 层）
      expect(utf8TextOf([0xE4, 0xB8]).failure.code)
        .assertEqual(CodecFailureCode.UTF8_TRUNCATED);
      // 0xC0 是过长编码的首字节，必须拒绝
      expect(utf8TextOf([0xC0, 0x80]).ok).assertFalse();
      // 续字节格式不对
      expect(utf8TextOf([0xE4, 0x41, 0x41]).ok).assertFalse();
      // 代理区码点（U+D800）不能用三字节形式出现
      expect(utf8TextOf([0xED, 0xA0, 0x80]).ok).assertFalse();
      // 超出 U+10FFFF
      expect(utf8TextOf([0xF5, 0x80, 0x80, 0x80]).ok).assertFalse();
    });

    it('hex_helpers_agree_on_digits', 0, () => {
      expect(hexValue('0')).assertEqual(0);
      expect(hexValue('a')).assertEqual(10);
      expect(hexValue('F')).assertEqual(15);
      expect(hexValue('g')).assertEqual(-1);
      expect(byteToHex(0x0F, false)).assertEqual('0f');
      expect(byteToHex(0x0F, true)).assertEqual('0F');
      expect(byteToHex(0xB8, false)).assertEqual('b8');
    });

    // ── Base64 ────────────────────────────────────────────

    it('base64_matches_known_vectors_including_chinese', 0, () => {
      expect(encodeBase64('中文').text).assertEqual('5Lit5paH');
      expect(decodeBase64('5Lit5paH').text).assertEqual('中文');
      expect(encodeBase64('a').text).assertEqual('YQ==');
      expect(encodeBase64('ab').text).assertEqual('YWI=');
      expect(encodeBase64('abc').text).assertEqual('YWJj');
      expect(encodeBase64('').text).assertEqual('');
    });

    it('base64_handles_emoji_through_utf8_bytes', 0, () => {
      expect(encodeBase64(EMOJI).text).assertEqual('8J+YgA==');
      expect(decodeBase64('8J+YgA==').text).assertEqual(EMOJI);
    });

    it('base64_round_trips_hard_text', 0, () => {
      const restored: CodecResult = decodeBase64(encodeBase64(HARD_TEXT).text);
      expect(restored.ok).assertTrue();
      expect(restored.text).assertEqual(HARD_TEXT);
    });

    it('base64_accepts_missing_padding_and_wrapped_lines', 0, () => {
      // 不带 = 的串与折行的串都很常见，拒绝它们只会让用户以为工具坏了
      expect(decodeBase64('YQ').text).assertEqual('a');
      expect(decodeBase64('YWI').text).assertEqual('ab');
      expect(decodeBase64('5Lit\n5paH').text).assertEqual('中文');
      expect(decodeBase64(' 5Lit 5paH ').text).assertEqual('中文');
    });

    it('base64_rejects_malformed_input_with_reasons', 0, () => {
      expect(decodeBase64('!!!!').ok).assertFalse();
      expect(decodeBase64('!!!!').failure.code).assertEqual(CodecFailureCode.B64_BAD_CHAR);
      // 长度模 4 余 1：无论怎么补都凑不出一个字节
      expect(decodeBase64('a').ok).assertFalse();
      expect(decodeBase64('YWJj=').failure.code).assertEqual(CodecFailureCode.B64_PAD_MISMATCH);
      expect(decodeBase64('YQ=a').failure.code).assertEqual(CodecFailureCode.B64_PAD_NOT_AT_END);
      expect(decodeBase64('YQ===').failure.code).assertEqual(CodecFailureCode.B64_TOO_MANY_PAD);
    });

    it('base64_decode_reports_non_utf8_payload_instead_of_returning_garbage', 0, () => {
      // /w== 是字节 0xFF：Base64 本身合法，但它不是任何 UTF-8 文本
      const result: CodecResult = decodeBase64('/w==');
      expect(result.ok).assertFalse();
      expect(result.text).assertEqual('');
      expect(result.failure.code === CodecFailureCode.NONE).assertFalse();
    });

    it('byte_level_base64_api_still_exposes_raw_bytes', 0, () => {
      // 文本层拒绝非 UTF-8，字节层必须仍能拿到原始字节（换工具或自己排查时要看）
      const decoded: ByteResult = base64DecodeBytes('/w==');
      expect(decoded.ok).assertTrue();
      expect(decoded.bytes.length).assertEqual(1);
      expect(decoded.bytes[0]).assertEqual(255);
      expect(base64EncodeBytes([255])).assertEqual('/w==');
      expect(base64DecodeBytes('').ok).assertTrue();
      expect(base64DecodeBytes('').bytes.length).assertEqual(0);
    });

    it('base64_round_trips_every_byte_length_modulo_three', 0, () => {
      // 长度 1/2/3 分别对应 2/3/0 个补齐字符，最容易写错的就是这三条分支
      expect(encodeBase64('x').text).assertEqual('eA==');
      expect(encodeBase64('xy').text).assertEqual('eHk=');
      expect(encodeBase64('xyz').text).assertEqual('eHl6');
      expect(decodeBase64('eA==').text).assertEqual('x');
      expect(decodeBase64('eHk=').text).assertEqual('xy');
      expect(decodeBase64('eHl6').text).assertEqual('xyz');
    });

    // ── URL 百分号编码 ────────────────────────────────────

    it('url_component_escapes_reserved_characters', 0, () => {
      expect(encodeUrlComponent('中文 abc&x=1')).assertEqual('%E4%B8%AD%E6%96%87%20abc%26x%3D1');
      expect(encodeUrlComponent('a/b?c=d&e')).assertEqual('a%2Fb%3Fc%3Dd%26e');
      expect(encodeUrlComponent(EMOJI)).assertEqual('%F0%9F%98%80');
    });

    it('url_component_leaves_exactly_the_unreserved_set_alone', 0, () => {
      // ECMAScript 规定不转义的只有 A-Za-z0-9 - _ . ! ~ * ' ( )
      expect(encodeUrlComponent("AZaz09-_.!~*'()")).assertEqual("AZaz09-_.!~*'()");
      expect(encodeUrlComponent(' ')).assertEqual('%20');
      // 空格编成 %20 而不是 +：+ 是表单编码的口径，混用会让后端解出错的值
      expect(encodeUrlComponent('a+b')).assertEqual('a%2Bb');
    });

    it('url_mode_keeps_characters_that_have_syntax_meaning', 0, () => {
      expect(encodeUrl('http://a.com/p?x=1&y=中')).assertEqual('http://a.com/p?x=1&y=%E4%B8%AD');
      expect(encodeUrl('https://a.com/a b')).assertEqual('https://a.com/a%20b');
      // 两个模式在 & 与 = 上必须给出不同结果，否则「整段 / 参数值」就是白分的
      expect(encodeUrl('a=1&b=2')).assertEqual('a=1&b=2');
      expect(encodeUrlComponent('a=1&b=2')).assertEqual('a%3D1%26b%3D2');
    });

    it('url_decode_handles_escaped_unescaped_and_mixed_input', 0, () => {
      expect(decodeUrlComponent('%E4%B8%AD').text).assertEqual('中');
      expect(decodeUrlComponent('%F0%9F%98%80').text).assertEqual(EMOJI);
      expect(decodeUrlComponent('a%20b').text).assertEqual('a b');
      // 一半转义一半没转义：未转义部分也要按 UTF-8 参与解码
      expect(decodeUrlComponent('中%20a').text).assertEqual('中 a');
      // + 保持为 +（不是表单编码口径）
      expect(decodeUrlComponent('a+b').text).assertEqual('a+b');
    });

    it('url_decode_rejects_broken_escapes', 0, () => {
      expect(decodeUrlComponent('%ZZ').ok).assertFalse();
      expect(decodeUrlComponent('%ZZ').failure.code).assertEqual(CodecFailureCode.PERCENT_BAD);
      expect(decodeUrlComponent('%E4').ok).assertFalse();
      expect(decodeUrlComponent('%E4').failure.code).assertEqual(CodecFailureCode.UTF8_TRUNCATED);
      expect(decodeUrlComponent('abc%').ok).assertFalse();
      expect(decodeUrlComponent('a%2').ok).assertFalse();
    });

    it('url_round_trips_hard_text', 0, () => {
      const encoded: string = encodeUrlComponent(HARD_TEXT);
      const restored: CodecResult = decodeUrlComponent(encoded);
      expect(restored.ok).assertTrue();
      expect(restored.text).assertEqual(HARD_TEXT);
    });

    // ── Unicode 转义 ──────────────────────────────────────

    it('unicode_escape_writes_non_ascii_as_four_hex_digits', 0, () => {
      expect(escapeUnicode('中')).assertEqual(BS + 'u4E2D');
      expect(escapeUnicode('abc')).assertEqual('abc');
      expect(escapeUnicode(EMOJI)).assertEqual(BS + 'uD83D' + BS + 'uDE00');
      expect(escapeUnicode('\n')).assertEqual(BS + 'u000A');
      // 反斜杠本身要转义，否则还原时无法区分「真转义」与「原文里的反斜杠」
      expect(escapeUnicode('a' + BS + 'b')).assertEqual('a' + BS + BS + 'b');
    });

    it('unicode_unescape_restores_every_supported_form', 0, () => {
      expect(unescapeUnicode(BS + 'u4E2D').text).assertEqual('中');
      expect(unescapeUnicode(BS + 'uD83D' + BS + 'uDE00').text).assertEqual(EMOJI);
      expect(unescapeUnicode(BS + 'n').text.charCodeAt(0)).assertEqual(10);
      expect(unescapeUnicode(BS + 't').text.charCodeAt(0)).assertEqual(9);
      expect(unescapeUnicode(BS + BS).text).assertEqual(BS);
      expect(unescapeUnicode(BS + '"').text).assertEqual('"');
    });

    it('unicode_escape_round_trips_hard_text', 0, () => {
      const escaped: string = escapeUnicode(HARD_TEXT);
      const restored: CodecResult = unescapeUnicode(escaped);
      expect(restored.ok).assertTrue();
      expect(restored.text).assertEqual(HARD_TEXT);
    });

    it('unicode_unescape_rejects_broken_escapes', 0, () => {
      expect(unescapeUnicode(BS + 'u12').ok).assertFalse();
      expect(unescapeUnicode(BS + 'uZZZZ').ok).assertFalse();
      expect(unescapeUnicode(BS + 'uZZZZ').failure.code).assertEqual(CodecFailureCode.UNICODE_BAD_HEX);
      expect(unescapeUnicode(BS + 'x').ok).assertFalse();
      expect(unescapeUnicode('abc' + BS).ok).assertFalse();
    });

    // ── Hex ───────────────────────────────────────────────

    it('hex_encodes_utf8_bytes_with_optional_grouping', 0, () => {
      expect(encodeHex('中', false, '')).assertEqual('e4b8ad');
      expect(encodeHex('中', true, '')).assertEqual('E4B8AD');
      expect(encodeHex('AB', true, ' ')).assertEqual('41 42');
      expect(encodeHex('', false, ' ')).assertEqual('');
    });

    it('hex_accepts_the_grouping_people_actually_paste', 0, () => {
      expect(decodeHex('e4b8ad').text).assertEqual('中');
      expect(decodeHex('E4:B8:AD').text).assertEqual('中');
      expect(decodeHex('0xE4 0xB8 0xAD').text).assertEqual('中');
      expect(decodeHex('e4-b8-ad').text).assertEqual('中');
      expect(decodeHex('').text).assertEqual('');
    });

    it('hex_rejects_odd_length_and_non_hex_characters', 0, () => {
      expect(decodeHex('abc').ok).assertFalse();
      expect(decodeHex('abc').failure.code).assertEqual(CodecFailureCode.HEX_ODD_LENGTH);
      expect(decodeHex('abc').failure.args[0]).assertEqual('3');
      expect(decodeHex('zz').ok).assertFalse();
      expect(decodeHex('zz').failure.code).assertEqual(CodecFailureCode.HEX_BAD_CHAR);
    });

    it('hex_decode_reports_non_utf8_payload', 0, () => {
      const result: CodecResult = decodeHex('ff');
      expect(result.ok).assertFalse();
      expect(result.failure.code === CodecFailureCode.NONE).assertFalse();
    });

    it('hex_round_trips_hard_text', 0, () => {
      const restored: CodecResult = decodeHex(encodeHex(HARD_TEXT, false, ''));
      expect(restored.ok).assertTrue();
      expect(restored.text).assertEqual(HARD_TEXT);
    });

    // ── 统一入口 ──────────────────────────────────────────

    it('run_codec_dispatches_every_mode_and_direction', 0, () => {
      expect(runCodec(CodecMode.BASE64, CodecDirection.ENCODE, 'abc').text).assertEqual('YWJj');
      expect(runCodec(CodecMode.BASE64, CodecDirection.DECODE, '5Lit5paH').text).assertEqual('中文');
      expect(runCodec(CodecMode.URL, CodecDirection.ENCODE, 'a=1&b=2').text).assertEqual('a=1&b=2');
      expect(runCodec(CodecMode.URL, CodecDirection.DECODE, '%E4%B8%AD').text).assertEqual('中');
      expect(runCodec(CodecMode.URL_COMPONENT, CodecDirection.ENCODE, 'a=1&b=2').text).assertEqual('a%3D1%26b%3D2');
      expect(runCodec(CodecMode.UNICODE, CodecDirection.ENCODE, '中').text).assertEqual(BS + 'u4E2D');
      expect(runCodec(CodecMode.UNICODE, CodecDirection.DECODE, BS + 'u4E2D').text).assertEqual('中');
      expect(runCodec(CodecMode.HEX, CodecDirection.ENCODE, '中').text).assertEqual('e4 b8 ad');
      expect(runCodec(CodecMode.HEX, CodecDirection.DECODE, 'e4b8ad').text).assertEqual('中');
    });

    it('run_codec_refuses_empty_input_with_a_hint', 0, () => {
      const result: CodecResult = runCodec(CodecMode.BASE64, CodecDirection.ENCODE, '');
      expect(result.ok).assertFalse();
      expect(result.failure.code).assertEqual(CodecFailureCode.EMPTY);
    });

    it('run_codec_propagates_decode_errors', 0, () => {
      const result: CodecResult = runCodec(CodecMode.BASE64, CodecDirection.DECODE, '!!!!');
      expect(result.ok).assertFalse();
      expect(result.text).assertEqual('');
      expect(result.failure.code === CodecFailureCode.NONE).assertFalse();
    });

    it('mode_metadata_is_complete_for_the_picker', 0, () => {
      const modes: Array<CodecMode> = codecModes();
      expect(modes.length).assertEqual(5);
      // 模式名与说明已下移到 UI 层（它们返回的是**文案**，纯逻辑不能 import $r）。
      // 这里钉住的是枚举本身：非空、唯一、且包含全部五种。
      const seen: Array<string> = [];
      for (let i: number = 0; i < modes.length; i++) {
        expect(modes[i].length > 0).assertTrue();
        expect(seen.indexOf(modes[i]) < 0).assertTrue();
        seen.push(modes[i]);
      }
      expect(seen.indexOf(CodecMode.BASE64) >= 0).assertTrue();
      expect(seen.indexOf(CodecMode.URL) >= 0).assertTrue();
      expect(seen.indexOf(CodecMode.URL_COMPONENT) >= 0).assertTrue();
      expect(seen.indexOf(CodecMode.UNICODE) >= 0).assertTrue();
      expect(seen.indexOf(CodecMode.HEX) >= 0).assertTrue();
    });
  });
}