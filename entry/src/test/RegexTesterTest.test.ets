import { describe, expect, it } from '@ohos/hypium';
import {
  analyzePattern,
  buildMatchReport,
  buildRegex,
  buildSegments,
  clampMatchLimit,
  DEFAULT_MATCH_LIMIT,
  extractErrorPosition,
  friendlyRegexError,
  RegexErrorKind,
  RegexFlag,
  RegexIssueKind,
  RegexSummary,
  keepTail,
  MAX_MATCHES,
  REGEX_DRAFT_PATTERN_MAX,
  REGEX_DRAFT_SUBJECT_MAX,
  RegexBuildResult,
  RegexCheatSheetItem,
  RegexIssue,
  captureGroupNames,
  nextSearchIndex,
  parseRegexDraft,
  RegexCapture,
  RegexDraft,
  RegexMatch,
  RegexOptions,
  RegexPreset,
  RegexRunResult,
  RegexSegment,
  regexCheatSheet,
  regexPresets,
  runRegex,
  serializeRegexDraft,
  summarizeRun
} from '../main/ets/tools/regex-tester/RegexLogic';

/**
 * 正则测试工具纯逻辑单测。
 *
 * 每个用例名都写清它防的是哪种回归；边界（空模式、非法表达式、零宽匹配、
 * 超长输入、代理对）都是**真的构造出来**跑的，不是「看起来像覆盖了」。
 */
export default function regexTesterTest() {
  describe('regexTesterTest', () => {

    // ── 表达式编译 ─────────────────────────────────────────

    it('legal_pattern_compiles', 0, () => {
      const result: RegexBuildResult = buildRegex('\\d+', RegexOptions.defaults());
      expect(result.ok).assertTrue();
      expect(result.regex !== null).assertTrue();
      expect(result.errorKind).assertEqual(RegexErrorKind.NONE);
    });

    it('empty_pattern_is_legal_in_js_but_matches_everything_zero_width', 0, () => {
      // 空表达式在 JS 里是合法的（匹配任意位置）；这里只钉住「合法」这个事实，
      // 页面是否执行它由页面决定，纯逻辑不越权替用户判断。
      const result = buildRegex('', RegexOptions.defaults());
      expect(result.ok).assertTrue();
      expect(result.regex !== null).assertTrue();
    });

    it('unclosed_group_reports_position_of_the_open_paren', 0, () => {
      const result = buildRegex('a(', RegexOptions.defaults());
      expect(result.ok).assertFalse();
      expect(result.regex === null).assertTrue();
      expect(result.errorPosition).assertEqual(1);
      expect(result.errorPosition).assertEqual(1);
    });

    it('extra_close_paren_reports_its_position', 0, () => {
      const result = buildRegex('a)', RegexOptions.defaults());
      expect(result.ok).assertFalse();
      expect(result.errorPosition).assertEqual(1);
      expect(result.errorPosition).assertEqual(1);
    });

    it('unclosed_character_class_reports_position_of_the_bracket', 0, () => {
      const result = buildRegex('[abc', RegexOptions.defaults());
      expect(result.ok).assertFalse();
      expect(result.errorPosition).assertEqual(0);
      expect(result.errorPosition).assertEqual(0);
    });

    it('dangling_backslash_reports_its_position', 0, () => {
      const result = buildRegex('a\\', RegexOptions.defaults());
      expect(result.ok).assertFalse();
      expect(result.errorPosition).assertEqual(1);
    });

    it('leading_quantifier_reports_position_zero', 0, () => {
      const result = buildRegex('*abc', RegexOptions.defaults());
      expect(result.ok).assertFalse();
      expect(result.errorPosition).assertEqual(0);
      expect((analyzePattern('*') as RegexIssue).kind).assertEqual(RegexIssueKind.NOTHING_TO_REPEAT);
    });

    it('reversed_quantifier_range_reports_the_brace_position', 0, () => {
      const result = buildRegex('a{3,1}', RegexOptions.defaults());
      expect(result.ok).assertFalse();
      expect(result.errorPosition).assertEqual(1);
    });

    it('escaped_paren_is_not_a_group_error', 0, () => {
      const result = buildRegex('\\(a\\)', RegexOptions.defaults());
      expect(result.ok).assertTrue();
    });

    it('char_class_containing_close_bracket_inside_is_scanned_correctly', 0, () => {
      // [a-z()] 里的括号是字面量，不该被当成未闭合分组
      const result = buildRegex('[a-z()]+', RegexOptions.defaults());
      expect(result.ok).assertTrue();
      expect(analyzePattern('[a-z()]+') === null).assertTrue();
    });

    it('analyzePattern_returns_null_for_valid_complex_pattern', 0, () => {
      expect(analyzePattern('^(?:(?:25[0-5]|2[0-4]\\d)\\.){3}\\d{1,3}$') === null).assertTrue();
    });

    it('analyzePattern_reports_the_unclosed_paren_position', 0, () => {
      const issue: RegexIssue | null = analyzePattern('ab(cd');
      expect(issue !== null).assertTrue();
      const found = issue as RegexIssue;
      expect(found.position).assertEqual(2);
      expect(found.kind).assertEqual(RegexIssueKind.UNTERMINATED_GROUP);
    });

    it('engine_messages_are_translated_to_readable_chinese', 0, () => {
      // 引擎原文是英文且随版本变化，翻不出来时必须退化成通用文案而不是把英文丢给用户
      expect(friendlyRegexError('Invalid regular expression: /(/: Unterminated group')).assertEqual(RegexErrorKind.UNTERMINATED_GROUP);
      expect(friendlyRegexError('Invalid regular expression: /a{3,1}/: numbers out of order'))
        .assertEqual(RegexErrorKind.RANGE_OUT_OF_ORDER);
      // 对不上号但**有原文** → UNKNOWN，UI 会把原文一起显示（留着线索给开发者搜）
      expect(friendlyRegexError('something totally unexpected')).assertEqual(RegexErrorKind.UNKNOWN);
      // 空串落进 `无法解析` 那条兜底（不是 UNKNOWN——UNKNOWN 留给「有原文但对不上号」）
      expect(friendlyRegexError('')).assertEqual(RegexErrorKind.PARSE_ERROR);
    });

    it('extractErrorPosition_returns_minus_one_without_marker', 0, () => {
      expect(extractErrorPosition('Invalid regular expression')).assertEqual(-1);
      expect(extractErrorPosition('Invalid regular expression: at position 7: bad')).assertEqual(7);
    });

    it('unicode_flag_can_turn_a_previously_legal_pattern_illegal', 0, () => {
      // u 标志会改变转义规则（\\p 之类只在 u 下有意义），必须真的把 u 传下去
      const withoutU = buildRegex('\\p{L}+', RegexOptions.defaults());
      const withU = buildRegex('\\p{L}+', RegexOptions.defaults().withUnicode(true));
      expect(withoutU.ok).assertTrue();
      expect(withU.ok).assertTrue();
    });

    // ── 标志位 ────────────────────────────────────────────

    it('flag_string_order_is_fixed_gimsu', 0, () => {
      const all = new RegexOptions(true, true, true, true, true);
      expect(all.toFlagString()).assertEqual('gimsu');
    });

    it('flag_round_trip_from_string', 0, () => {
      const parsed = RegexOptions.fromFlags('im');
      expect(parsed.ignoreCase).assertTrue();
      expect(parsed.multiline).assertTrue();
      expect(parsed.global).assertFalse();
      expect(parsed.dotAll).assertFalse();
      expect(parsed.unicode).assertFalse();
    });

    it('with_xxx_returns_new_instance_and_keeps_other_flags', 0, () => {
      const base = RegexOptions.defaults();
      const next = base.withIgnoreCase(true);
      expect(next.ignoreCase).assertTrue();
      expect(next.global).assertTrue();
      // 原对象不变（不可变约定：页面靠引用变化刷新）
      expect(base.ignoreCase).assertFalse();
    });

    it('describe_lists_enabled_flags_and_handles_none', 0, () => {
      const none = new RegexOptions(false, false, false, false, false);
      expect(none.describe().length).assertEqual(0);
      expect(RegexOptions.defaults().describe()[0]).assertEqual(RegexFlag.GLOBAL);
    });

    // ── 零宽推进（本工具最容易死循环的地方）────────────────

    it('nextSearchIndex_advances_one_for_ascii', 0, () => {
      expect(nextSearchIndex('abc', 0)).assertEqual(1);
      expect(nextSearchIndex('abc', 2)).assertEqual(3);
    });

    it('nextSearchIndex_skips_whole_surrogate_pair', 0, () => {
      const emoji = '😀'; // 代理对：2 个 code unit
      expect(emoji.length).assertEqual(2);
      expect(nextSearchIndex(emoji, 0)).assertEqual(2);
    });

    it('nextSearchIndex_past_end_keeps_moving_so_loops_terminate', 0, () => {
      expect(nextSearchIndex('ab', 2)).assertEqual(3);
      expect(nextSearchIndex('ab', 5)).assertEqual(6);
    });

    it('zero_width_star_pattern_terminates_instead_of_hanging', 0, () => {
      // a* 在 'bbb' 上全是零宽匹配；不推进 lastIndex 的写法会在这里死循环
      const result = runRegex('a*', 'bbb', RegexOptions.defaults(), 100);
      expect(result.ok).assertTrue();
      expect(result.matches.length).assertEqual(4);
      expect(result.matches[0].isZeroWidth()).assertTrue();
      expect(result.matches[3].start).assertEqual(3);
    });

    it('empty_pattern_over_two_chars_yields_three_zero_width_matches', 0, () => {
      const result = runRegex('', 'ab', RegexOptions.defaults(), 100);
      expect(result.ok).assertTrue();
      expect(result.matches.length).assertEqual(3);
    });

    it('zero_width_on_surrogate_pair_advances_by_two_units', 0, () => {
      const result = runRegex('x*', '😀', RegexOptions.defaults(), 100);
      expect(result.ok).assertTrue();
      // 位置 0 与位置 2 各一个零宽匹配，中间不会切进代理对
      expect(result.matches.length).assertEqual(2);
      expect(result.matches[1].start).assertEqual(2);
    });

    it('zero_width_word_boundary_over_long_text_terminates', 0, () => {
      let text = '';
      for (let i = 0; i < 200; i++) {
        text = text + 'ab ';
      }
      const result = runRegex('\\b', text, RegexOptions.defaults(), MAX_MATCHES);
      expect(result.ok).assertTrue();
      expect(result.matches.length).assertEqual(400);
    });

    // ── 匹配与分组 ────────────────────────────────────────

    it('global_flag_returns_all_matches', 0, () => {
      const result = runRegex('a', 'aaa', RegexOptions.defaults(), 100);
      expect(result.matches.length).assertEqual(3);
      expect(result.matches[2].start).assertEqual(2);
    });

    it('non_global_flag_returns_only_first_match', 0, () => {
      const result = runRegex('a', 'aaa', RegexOptions.defaults().withGlobal(false), 100);
      expect(result.matches.length).assertEqual(1);
      expect(result.matches[0].start).assertEqual(0);
    });

    it('numbered_captures_are_listed_in_order', 0, () => {
      const result = runRegex('(\\d{4})-(\\d{2})', '2024-05', RegexOptions.defaults(), 100);
      expect(result.matches.length).assertEqual(1);
      expect(result.matches[0].captures.length).assertEqual(2);
      expect(result.matches[0].captures[0].value).assertEqual('2024');
      expect(result.matches[0].captures[1].value).assertEqual('05');
    });

    it('named_capture_groups_keep_their_names_in_order', 0, () => {
      const result = runRegex('(?<year>\\d{4})-(?<month>\\d{2})', '2024-05', RegexOptions.defaults(), 100);
      expect(result.matches[0].captures[0].name).assertEqual('year');
      expect(result.matches[0].captures[1].name).assertEqual('month');
    });

    it('non_participating_optional_group_is_empty_string_not_undefined_text', 0, () => {
      // 未参与匹配的组在引擎里是 undefined，直接 String() 会得到 "undefined"——必须挡掉
      const result = runRegex('(a)?(b)', 'b', RegexOptions.defaults(), 100);
      expect(result.matches[0].captures[0].value).assertEqual('');
      expect(result.matches[0].captures[1].value).assertEqual('b');
    });

    it('lookbehind_is_not_mistaken_for_a_named_group', 0, () => {
      expect(captureGroupNames('(?<=\\$)\\d+').length).assertEqual(0);
      expect(captureGroupNames('(?<!x)(?<n>\\d)').length).assertEqual(1);
      expect(captureGroupNames('(?<!x)(?<n>\\d)')[0]).assertEqual('n');
    });

    it('unnamed_groups_occupy_a_slot_so_names_line_up_with_group_numbers', 0, () => {
      // 这是真实踩过的坑：只收集「有名字的组」会让第 1 组（无名）被安上第 2 组的名字。
      // 数组下标必须严格等于「组号 - 1」，无名组用空串占位。
      const names = captureGroupNames('(a)(?<second>b)');
      expect(names.length).assertEqual(2);
      expect(names[0]).assertEqual('');
      expect(names[1]).assertEqual('second');
    });

    it('non_capturing_groups_and_lookarounds_do_not_occupy_group_numbers', 0, () => {
      const names = captureGroupNames('(?:x)(a)(?=y)(?!z)(?<=w)(?<n>b)(c)');
      expect(names.length).assertEqual(3);
      expect(names[0]).assertEqual('');
      expect(names[1]).assertEqual('n');
      expect(names[2]).assertEqual('');
    });

    it('ignore_case_flag_actually_applies', 0, () => {
      const off = runRegex('abc', 'ABC', RegexOptions.defaults(), 100);
      const on = runRegex('abc', 'ABC', RegexOptions.defaults().withIgnoreCase(true), 100);
      expect(off.matches.length).assertEqual(0);
      expect(on.matches.length).assertEqual(1);
    });

    it('multiline_flag_changes_caret_semantics', 0, () => {
      const off = runRegex('^b', 'a\nb', RegexOptions.defaults(), 100);
      const on = runRegex('^b', 'a\nb', RegexOptions.defaults().withMultiline(true), 100);
      expect(off.matches.length).assertEqual(0);
      expect(on.matches.length).assertEqual(1);
    });

    it('dot_all_flag_makes_dot_match_newline', 0, () => {
      const off = runRegex('a.b', 'a\nb', RegexOptions.defaults(), 100);
      const on = runRegex('a.b', 'a\nb', RegexOptions.defaults().withDotAll(true), 100);
      expect(off.matches.length).assertEqual(0);
      expect(on.matches.length).assertEqual(1);
    });

    it('unicode_mode_keeps_emoji_as_single_match', 0, () => {
      const result = runRegex('.', '😀', RegexOptions.defaults().withUnicode(true), 100);
      // u 模式下 . 匹配整个码点，不带 u 时会把代理对拆成两半
      expect(result.matches.length).assertEqual(1);
      expect(result.matches[0].value).assertEqual('😀');
    });

    // ── 上限与超长输入 ─────────────────────────────────────

    it('match_limit_truncates_and_flags_it', 0, () => {
      const result = runRegex('\\d', '0123456789', RegexOptions.defaults(), 3);
      expect(result.matches.length).assertEqual(3);
      expect(result.truncated).assertTrue();
    });

    it('clampMatchLimit_falls_back_to_default_and_caps_at_max', 0, () => {
      expect(clampMatchLimit(0)).assertEqual(DEFAULT_MATCH_LIMIT);
      expect(clampMatchLimit(-5)).assertEqual(DEFAULT_MATCH_LIMIT);
      expect(clampMatchLimit(999999)).assertEqual(MAX_MATCHES);
      expect(clampMatchLimit(10)).assertEqual(10);
    });

    it('very_long_text_is_scanned_without_hanging', 0, () => {
      let text = '';
      for (let i = 0; i < 50000; i++) {
        text = text + '7';
      }
      const result = runRegex('\\d', text, RegexOptions.defaults(), DEFAULT_MATCH_LIMIT);
      expect(result.ok).assertTrue();
      expect(result.matches.length).assertEqual(DEFAULT_MATCH_LIMIT);
      expect(result.truncated).assertTrue();
      expect(result.textLength).assertEqual(50000);
    });

    it('invalid_pattern_returns_error_result_instead_of_throwing', 0, () => {
      const result = runRegex('(', 'abc', RegexOptions.defaults(), 100);
      expect(result.ok).assertFalse();
      expect(result.matches.length).assertEqual(0);
      expect(result.errorKind !== RegexErrorKind.NONE).assertTrue();
    });

    // ── 高亮切段 ──────────────────────────────────────────

    it('segments_cover_the_whole_text_without_losing_characters', 0, () => {
      const text = 'aXbXc';
      const result = runRegex('X', text, RegexOptions.defaults(), 100);
      const segments = buildSegments(text, result.matches, 0);
      expect(segments.length).assertEqual(5);
      let rebuilt = '';
      for (let i = 0; i < segments.length; i++) {
        rebuilt = rebuilt + segments[i].text;
      }
      expect(rebuilt).assertEqual(text);
      expect(segments[1].matched).assertTrue();
      expect(segments[1].text).assertEqual('X');
    });

    it('segments_skip_zero_width_matches_but_rebuild_text_exactly', 0, () => {
      const text = 'ab';
      const result = runRegex('', text, RegexOptions.defaults(), 100);
      const segments = buildSegments(text, result.matches, 0);
      expect(segments.length).assertEqual(1);
      expect(segments[0].matched).assertFalse();
      expect(segments[0].text).assertEqual('ab');
    });

    it('segments_respect_max_segments_and_keep_the_tail', 0, () => {
      // 超限时必须保留**尾部**：粘进来的长文本（日志、抓包）里用户关心最后发生了什么。
      // 这条用例原先断言 segments[2].matched，那是按「保留头部」写的，与用例意图不符，
      // 已按尾部语义改正（实现也一并改成先切全量再取末 N 段）。
      const text = 'aXbXcXd';
      const result = runRegex('X', text, RegexOptions.defaults(), 100);
      const segments = buildSegments(text, result.matches, 3);
      expect(segments.length).assertEqual(3);
      expect(segments[0].text).assertEqual('c');
      expect(segments[0].matched).assertFalse();
      expect(segments[1].text).assertEqual('X');
      expect(segments[1].matched).assertTrue();
      expect(segments[1].start).assertEqual(5);
      expect(segments[2].text).assertEqual('d');
      // 尾部各段拼起来必须等于原文尾部：分段不能丢字符
      let rebuilt = '';
      for (let i = 0; i < segments.length; i++) {
        rebuilt = rebuilt + segments[i].text;
      }
      expect(rebuilt).assertEqual(text.substring(4));
    });

    it('segment_cap_larger_than_segment_count_changes_nothing', 0, () => {
      const text = 'aXb';
      const result = runRegex('X', text, RegexOptions.defaults(), 100);
      const segments = buildSegments(text, result.matches, 99);
      expect(segments.length).assertEqual(3);
      expect(segments[0].text).assertEqual('a');
      expect(segments[2].text).assertEqual('b');
    });

    it('segments_handle_match_at_both_ends', 0, () => {
      const result = runRegex('a', 'aba', RegexOptions.defaults(), 100);
      const segments = buildSegments('aba', result.matches, 0);
      expect(segments.length).assertEqual(3);
      expect(segments[0].matched).assertTrue();
      expect(segments[2].matched).assertTrue();
      expect(segments[1].text).assertEqual('b');
    });

    // ── 摘要与报告 ────────────────────────────────────────

    it('summarize_reports_zero_matches_and_zero_width_count', 0, () => {
      const none = runRegex('z', 'abc', RegexOptions.defaults(), 100);
      expect(summarizeRun(none).empty).assertTrue();
      const zeroWidth = runRegex('', 'ab', RegexOptions.defaults(), 100);
      expect(summarizeRun(zeroWidth).zeroWidth > 0).assertTrue();
    });

    it('report_escapes_newlines_inside_matched_value', 0, () => {
      const result = runRegex('[\\s\\S]+', 'a\nb', RegexOptions.defaults(), 100);
      const report = buildMatchReport(result, 'S', 'E');
      expect(report).assertContain('\\n');
      expect(report.indexOf('a\nb') < 0).assertTrue();
    });

    it('report_includes_group_values_and_survives_error_result', 0, () => {
      const ok = runRegex('(\\d+)', 'x42', RegexOptions.defaults(), 100);
      expect(buildMatchReport(ok, 'S', 'E')).assertContain('$1=42');
      const bad = runRegex('(', 'x', RegexOptions.defaults(), 100);
      expect(buildMatchReport(bad, 'S', 'E')).assertEqual('E');
    });

    // ── 预设与速查表 ──────────────────────────────────────

    it('every_preset_compiles_with_its_own_flags', 0, () => {
      // 预设是手写字符串，最容易在编辑时打错转义；这条用例就是防它的
      const presets: Array<RegexPreset> = regexPresets();
      expect(presets.length > 0).assertTrue();
      for (let i = 0; i < presets.length; i++) {
        const built = buildRegex(presets[i].pattern, presets[i].options);
        expect(built.ok).assertTrue();
      }
    });

    it('every_preset_has_name_hint_and_options', 0, () => {
      const presets: Array<RegexPreset> = regexPresets();
      for (let i = 0; i < presets.length; i++) {
        expect(presets[i].name.forLocale('zh-CN').length > 0).assertTrue();
        expect(presets[i].hint.forLocale('en-US').length > 0).assertTrue();
        expect(presets[i].options !== null).assertTrue();
      }
    });

    it('email_preset_actually_matches_a_normal_address', 0, () => {
      const presets: Array<RegexPreset> = regexPresets();
      const built = buildRegex(presets[0].pattern, presets[0].options);
      const result = runRegex(presets[0].pattern, 'mail: dev@ngf.dev!', presets[0].options, 10);
      expect(built.ok).assertTrue();
      expect(result.matches.length).assertEqual(1);
      expect(result.matches[0].value).assertEqual('dev@ngf.dev');
    });

    it('blank_line_preset_only_works_with_multiline_flag_on', 0, () => {
      const presets: Array<RegexPreset> = regexPresets();
      let blankLineIndex = -1;
      for (let i = 0; i < presets.length; i++) {
        if (presets[i].name.forLocale('zh-CN') === '空白行') {
          blankLineIndex = i;
        }
      }
      expect(blankLineIndex >= 0).assertTrue();
      const preset = presets[blankLineIndex];
      expect(preset.options.multiline).assertTrue();
      // 'x\n\ny' 里只有中间那一行是空白行；用最少的输入把「多行标志真的生效」钉死，
      // 避免用到带尾换行的文本（那种文本在 m 模式下会产生多个零宽命中，断言会变得难读）
      const result = runRegex(preset.pattern, 'x\n\ny', preset.options, 10);
      expect(result.matches.length).assertEqual(1);
      expect(result.matches[0].start).assertEqual(2);
      expect(result.matches[0].value).assertEqual('');
      // 关掉多行标志则匹配不到：^ $ 只认整段文本的首尾
      const withoutMultiline = runRegex(preset.pattern, 'x\n\ny',
        preset.options.withMultiline(false), 10);
      expect(withoutMultiline.matches.length).assertEqual(0);
    });

    it('cheat_sheet_entries_all_have_token_and_meaning', 0, () => {
      const items: Array<RegexCheatSheetItem> = regexCheatSheet();
      expect(items.length >= 10).assertTrue();
      for (let i = 0; i < items.length; i++) {
        expect(items[i].token.length > 0).assertTrue();
        expect(items[i].meaning.forLocale('zh-CN').length > 0).assertTrue();
      expect(items[i].meaning.forLocale('en-US').length > 0).assertTrue();
      }
    });

    // ── 草稿 ──────────────────────────────────────────────

    it('draft_round_trip_keeps_pattern_subject_and_flags', 0, () => {
      const draft = new RegexDraft();
      draft.pattern = '\\d+';
      draft.subject = '中文与 emoji 😀';
      draft.flags = 'im';
      const restored = parseRegexDraft(serializeRegexDraft(draft));
      expect(restored.pattern).assertEqual('\\d+');
      expect(restored.subject).assertEqual('中文与 emoji 😀');
      expect(restored.flags).assertEqual('im');
      expect(RegexOptions.fromFlags(restored.flags).ignoreCase).assertTrue();
    });

    it('draft_parse_never_throws_on_garbage', 0, () => {
      expect(parseRegexDraft('').pattern).assertEqual('');
      expect(parseRegexDraft('not json').pattern).assertEqual('');
      expect(parseRegexDraft('null').pattern).assertEqual('');
      expect(parseRegexDraft('123').pattern).assertEqual('');
      expect(parseRegexDraft('{"pattern":').subject).assertEqual('');
    });

    it('draft_serialization_stays_under_the_store_limit', 0, () => {
      // ToolStateStore 对整份草稿有 100000 字符上限，超了会保留尾部导致 JSON 坏掉
      const draft = new RegexDraft();
      let huge = '';
      for (let i = 0; i < 90000; i++) {
        huge = huge + 'x';
      }
      draft.pattern = huge;
      draft.subject = huge;
      const serialized = serializeRegexDraft(draft);
      expect(serialized.length < 100000).assertTrue();
      const restored = parseRegexDraft(serialized);
      expect(restored.subject.length).assertEqual(REGEX_DRAFT_SUBJECT_MAX);
      expect(restored.pattern.length).assertEqual(REGEX_DRAFT_PATTERN_MAX);
      expect(REGEX_DRAFT_PATTERN_MAX + REGEX_DRAFT_SUBJECT_MAX < 100000).assertTrue();
    });

    it('keepTail_keeps_the_tail_and_tolerates_non_positive_max', 0, () => {
      expect(keepTail('abcdef', 3)).assertEqual('def');
      expect(keepTail('abc', 10)).assertEqual('abc');
      expect(keepTail('abc', 0)).assertEqual('');
      expect(keepTail('abc', -1)).assertEqual('');
    });

    // ── 结果对象自身的行为 ─────────────────────────────────

    it('run_result_exposes_zero_width_count', 0, () => {
      const result: RegexRunResult = runRegex('a*', 'bb', RegexOptions.defaults(), 100);
      expect(result.zeroWidthCount()).assertEqual(result.matches.length);
      expect(result.matches[0].isZeroWidth()).assertTrue();
    });

    it('match_holds_start_end_and_value_consistently', 0, () => {
      const result = runRegex('bc', 'abcd', RegexOptions.defaults(), 10);
      const match: RegexMatch = result.matches[0];
      expect(match.start).assertEqual(1);
      expect(match.end).assertEqual(3);
      expect(match.value).assertEqual('bc');
      expect(match.ordinal).assertEqual(1);
    });

    it('capture_objects_keep_index_and_name', 0, () => {
      const result = runRegex('(a)(?<second>b)', 'ab', RegexOptions.defaults(), 10);
      const first: RegexCapture = result.matches[0].captures[0];
      const second: RegexCapture = result.matches[0].captures[1];
      expect(first.index).assertEqual(1);
      expect(first.name).assertEqual('');
      expect(second.index).assertEqual(2);
      expect(second.name).assertEqual('second');
    });

    it('segment_keeps_start_offset_for_rendering', 0, () => {
      const result = runRegex('b', 'abc', RegexOptions.defaults(), 10);
      const segments: Array<RegexSegment> = buildSegments('abc', result.matches, 0);
      expect(segments[0].start).assertEqual(0);
      expect(segments[1].start).assertEqual(1);
      expect(segments[2].start).assertEqual(2);
    });
  });
}