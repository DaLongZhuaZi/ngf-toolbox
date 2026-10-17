import { describe, expect, it } from '@ohos/hypium';
import {
  DateParseResult,
  DateParts,
  daysInMonth,
  formatParts,
  formatWithOffset,
  InterpretKind,
  interpretInput,
  isLeapYear,
  isValidTimestamp,
  localOffsetMinutes,
  millisToSeconds,
  nowMilliseconds,
  offsetOf,
  offsetText,
  padNumber,
  parseDateString,
  parseTimestamp,
  partsOf,
  RelativeTime,
  relativeTime,
  TIMESTAMP_MAX_DIGITS,
  TimestampDateFailure,
  TimestampFailure,
  secondsToMillis,
  TIMESTAMP_MAX_MS,
  TimestampInterpretation,
  TimestampParseResult,
  TimestampUnit,
  TimeZoneOption,
  timeZoneOptions,
  weekdayLabel,
  ZoneRow,
  zoneRows
} from '../main/ets/tools/timestamp/TimestampLogic';
import { NGFLocalizedText } from '../main/ets/core/ToolModel';

const MINUTE: number = 60000;
const HOUR: number = 3600000;
const DAY: number = 86400000;

/** 从时区对照表里按名字片段取一行，避免依赖行的顺序 */
function rowLabeled(rows: Array<ZoneRow>, fragment: string): ZoneRow {
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].label.forLocale('zh-CN').indexOf(fragment) >= 0) {
      return rows[i];
    }
  }
  return new ZoneRow(new NGFLocalizedText('', ''), '', '', 0, false);
}

/**
 * 把相对时间压成一行便于断言。
 *
 * 之所以不直接断言「3 分钟前」：那已经是**文案**，已下移到 UI 层。
 * 纯逻辑给的是结构（量级 / 数量 / 方向），这才是它该负责、也值得钉住的部分。
 */
function relSpec(time: RelativeTime): string {
  return time.unit + '|' + time.value + '|' + (time.past ? 'past' : 'future');
}

export default function timestampTest() {
  describe('timestampTest', () => {

    // ── 闰年与月天数 ───────────────────────────────────────

    it('leap_year_rules_follow_gregorian_calendar', 0, () => {
      expect(isLeapYear(2024)).assertTrue();
      expect(isLeapYear(2023)).assertFalse();
      expect(isLeapYear(2000)).assertTrue();
      // 1900 与 2100 不是闰年：能被 100 整除但不能被 400 整除
      expect(isLeapYear(1900)).assertFalse();
      expect(isLeapYear(2100)).assertFalse();
    });

    it('days_in_month_knows_february', 0, () => {
      expect(daysInMonth(2024, 2)).assertEqual(29);
      expect(daysInMonth(2023, 2)).assertEqual(28);
      expect(daysInMonth(2000, 2)).assertEqual(29);
      expect(daysInMonth(1900, 2)).assertEqual(28);
      expect(daysInMonth(2024, 1)).assertEqual(31);
      expect(daysInMonth(2024, 4)).assertEqual(30);
      expect(daysInMonth(2024, 12)).assertEqual(31);
      // 越界月份返回 0，而不是抛异常或编一个 31 出来
      expect(daysInMonth(2024, 0)).assertEqual(0);
      expect(daysInMonth(2024, 13)).assertEqual(0);
    });

    // ── 时间戳解析 ────────────────────────────────────────

    it('ten_digits_are_read_as_seconds', 0, () => {
      const result: TimestampParseResult = parseTimestamp('1700000000');
      expect(result.ok).assertTrue();
      expect(result.unit).assertEqual(TimestampUnit.SECONDS);
      expect(result.milliseconds).assertEqual(1700000000000);
      expect(result.digitCount).assertEqual(10);
    });

    it('thirteen_digits_are_read_as_milliseconds', 0, () => {
      const result: TimestampParseResult = parseTimestamp('1700000000000');
      expect(result.ok).assertTrue();
      expect(result.unit).assertEqual(TimestampUnit.MILLISECONDS);
      expect(result.milliseconds).assertEqual(1700000000000);
    });

    it('eleven_and_twelve_digits_are_read_as_milliseconds', 0, () => {
      // 11 位当秒解释会得到公元 5138 年，那不是任何人的意图
      expect(parseTimestamp('10000000000').unit).assertEqual(TimestampUnit.MILLISECONDS);
      expect(parseTimestamp('10000000000').milliseconds).assertEqual(10000000000);
      expect(parseTimestamp('100000000000').unit).assertEqual(TimestampUnit.MILLISECONDS);
    });

    it('single_digit_and_zero_are_seconds', 0, () => {
      expect(parseTimestamp('0').milliseconds).assertEqual(0);
      expect(parseTimestamp('0').unit).assertEqual(TimestampUnit.SECONDS);
      expect(parseTimestamp('5').milliseconds).assertEqual(5000);
    });

    it('negative_timestamps_reach_before_1970', 0, () => {
      const result: TimestampParseResult = parseTimestamp('-86400');
      expect(result.ok).assertTrue();
      expect(result.milliseconds).assertEqual(-86400000);
      expect(formatWithOffset(result.milliseconds, 0, 'YYYY-MM-DD HH:mm:ss')).assertEqual('1969-12-31 00:00:00');
    });

    it('plus_sign_and_surrounding_spaces_are_tolerated', 0, () => {
      expect(parseTimestamp('  +1700000000  ').milliseconds).assertEqual(1700000000000);
      expect(parseTimestamp('1700000000 ').ok).assertTrue();
    });

    it('rejects_empty_and_non_numeric_input', 0, () => {
      expect(parseTimestamp('').ok).assertFalse();
      expect(parseTimestamp('   ').ok).assertFalse();
      expect(parseTimestamp('abc').ok).assertFalse();
      expect(parseTimestamp('1700.5').ok).assertFalse();
      expect(parseTimestamp('1e9').ok).assertFalse();
      expect(parseTimestamp('abc').failure).assertEqual(TimestampFailure.NOT_DIGITS);
    });

    it('rejects_too_many_digits', 0, () => {
      const result = parseTimestamp('12345678901234567');
      expect(result.ok).assertFalse();
      // 这里是 TimestampParseResult（一层失败），不是 InterpretFailure（两层）
      expect(result.failure).assertEqual(TimestampFailure.TOO_MANY_DIGITS);
      // 上限要跟着参数走，常量改了文案才不会过期
      expect(result.args[0]).assertEqual(String(TIMESTAMP_MAX_DIGITS));
    });

    it('accepts_the_exact_maximum_and_rejects_beyond_it', 0, () => {
      const atMax = parseTimestamp(String(TIMESTAMP_MAX_MS));
      expect(atMax.ok).assertTrue();
      expect(atMax.milliseconds).assertEqual(TIMESTAMP_MAX_MS);
      const overMax = parseTimestamp('8640000000000001');
      expect(overMax.ok).assertFalse();
      expect(overMax.failure).assertEqual(TimestampFailure.OUT_OF_RANGE);
    });

    it('isValidTimestamp_guards_nan_and_infinity_too', 0, () => {
      expect(isValidTimestamp(0)).assertTrue();
      expect(isValidTimestamp(-TIMESTAMP_MAX_MS)).assertTrue();
      expect(isValidTimestamp(TIMESTAMP_MAX_MS + 1)).assertFalse();
      expect(isValidTimestamp(Number.NaN)).assertFalse();
      expect(isValidTimestamp(Number.POSITIVE_INFINITY)).assertFalse();
    });

    // ── 单位与补零 ────────────────────────────────────────

    it('unit_conversion_round_trips_for_positive_values', 0, () => {
      expect(secondsToMillis(1700000000)).assertEqual(1700000000000);
      expect(millisToSeconds(1700000000000)).assertEqual(1700000000);
      expect(millisToSeconds(0)).assertEqual(0);
    });

    it('millis_to_seconds_floors_negative_values', 0, () => {
      // -1ms 是 1969-12-31T23:59:59.999，它的秒级时间戳应该是 -1 而不是 0
      expect(millisToSeconds(-1)).assertEqual(-1);
      expect(millisToSeconds(1999)).assertEqual(1);
    });

    it('padNumber_pads_and_keeps_the_sign', 0, () => {
      expect(padNumber(5, 2)).assertEqual('05');
      expect(padNumber(123, 2)).assertEqual('123');
      expect(padNumber(0, 4)).assertEqual('0000');
      expect(padNumber(-5, 2)).assertEqual('-05');
    });

    // ── 时区换算 ──────────────────────────────────────────

    it('epoch_is_1970_01_01_thursday_in_utc', 0, () => {
      const parts: DateParts = partsOf(0, 0);
      expect(parts.year).assertEqual(1970);
      expect(parts.month).assertEqual(1);
      expect(parts.day).assertEqual(1);
      expect(parts.hour).assertEqual(0);
      expect(parts.weekday).assertEqual(4);
      expect(weekdayLabel(parts.weekday, 'zh-CN')).assertEqual('周四');
    });

    it('positive_and_negative_offsets_shift_the_wall_clock', 0, () => {
      expect(formatWithOffset(0, 480, 'YYYY-MM-DD HH:mm:ss')).assertEqual('1970-01-01 08:00:00');
      expect(formatWithOffset(0, -300, 'YYYY-MM-DD HH:mm:ss')).assertEqual('1969-12-31 19:00:00');
      expect(partsOf(0, -300).weekday).assertEqual(3);
    });

    it('half_hour_and_quarter_hour_offsets_are_exact', 0, () => {
      // 印度 +5:30、尼泊尔 +5:45：只按整小时算的实现会在这里露馅
      expect(formatWithOffset(0, 330, 'HH:mm')).assertEqual('05:30');
      expect(formatWithOffset(0, 345, 'HH:mm')).assertEqual('05:45');
      expect(offsetText(330)).assertEqual('UTC+05:30');
      expect(offsetText(345)).assertEqual('UTC+05:45');
    });

    it('offset_text_always_shows_sign_and_minutes', 0, () => {
      expect(offsetText(480)).assertEqual('UTC+08:00');
      expect(offsetText(0)).assertEqual('UTC+00:00');
      expect(offsetText(-300)).assertEqual('UTC-05:00');
      // 东八区以外还要覆盖「非整数小时」与「负偏移带半小时」的组合
      expect(offsetText(-210)).assertEqual('UTC-03:30');
    });

    it('patterns_render_all_supported_tokens', 0, () => {
      const parts = partsOf(1715000000123, 0);
      expect(formatParts(parts, 'YYYY/MM/DD HH:mm:ss.SSS')).assertEqual(
        formatParts(parts, 'YYYY') + '/'
        + padNumber(parts.month, 2) + '/' + padNumber(parts.day, 2) + ' '
        + padNumber(parts.hour, 2) + ':' + padNumber(parts.minute, 2) + ':'
        + padNumber(parts.second, 2) + '.' + padNumber(parts.millisecond, 3));
      expect(formatParts(parts, 'YYYY')).assertEqual('2024');
      expect(formatParts(parts, 'SSS')).assertEqual(padNumber(parts.millisecond, 3));
    });

    it('weekday_label_is_empty_for_out_of_range_values', 0, () => {
      expect(weekdayLabel(0, 'zh-CN')).assertEqual('周日');
      expect(weekdayLabel(6, 'zh-CN')).assertEqual('周六');
      expect(weekdayLabel(-1, 'zh-CN')).assertEqual('');
      expect(weekdayLabel(7, 'zh-CN')).assertEqual('');
    });

    it('local_offset_is_a_whole_number_of_minutes_in_range', 0, () => {
      const offset: number = localOffsetMinutes(1700000000000);
      expect(Number.isInteger(offset)).assertTrue();
      expect(offset >= -720).assertTrue();
      expect(offset <= 840).assertTrue();
    });

    it('local_offset_formatting_matches_the_system_clock', 0, () => {
      // 与系统自己的本地时间读数对齐：验证「偏移 + getUTC*」这套算法没有读写反
      const ms: number = 1715000000000;
      const expected = String(new Date(ms).getHours()) + ':'
        + padNumber(new Date(ms).getMinutes(), 2) + ':'
        + padNumber(new Date(ms).getSeconds(), 2);
      const actual = formatWithOffset(ms, localOffsetMinutes(ms), 'HH:mm:ss');
      expect(actual.indexOf(':') > 0).assertTrue();
      expect(formatWithOffset(ms, localOffsetMinutes(ms), 'HH')).assertEqual(String(new Date(ms).getHours()));
      expect(padNumber(new Date(ms).getMinutes(), 2)).assertEqual(
        formatWithOffset(ms, localOffsetMinutes(ms), 'mm'));
      expect(expected.length > 0).assertTrue();
      expect(actual.length).assertEqual(8);
    });

    it('time_zone_table_has_one_local_row_and_expected_zones', 0, () => {
      const options: Array<TimeZoneOption> = timeZoneOptions();
      let localCount = 0;
      for (let i = 0; i < options.length; i++) {
        if (options[i].isLocal) {
          localCount++;
        }
      }
      expect(localCount).assertEqual(1);
      expect(options.length >= 10).assertTrue();
    });

    it('offsetOf_resolves_fixed_and_local_zones', 0, () => {
      const options: Array<TimeZoneOption> = timeZoneOptions();
      const beijing: TimeZoneOption = options[2];
      // 固定时区直接给出偏移；本地时区必须走系统当前偏移（会随夏令时变化）
      expect(offsetOf(beijing, 0)).assertEqual(480);
      for (let i = 0; i < options.length; i++) {
        if (options[i].isLocal) {
          expect(offsetOf(options[i], 1700000000000)).assertEqual(localOffsetMinutes(1700000000000));
        }
      }
      expect(beijing.isLocal).assertFalse();
    });

    it('zone_rows_show_each_zone_at_the_same_instant', 0, () => {
      const rows = zoneRows(0);
      const beijing = rowLabeled(rows, '北京');
      expect(beijing.dateTimeText).assertEqual('1970-01-01 08:00:00');
      expect(beijing.offsetText).assertEqual('UTC+08:00');
      // 星期几现在是索引（措辞在 UI 层）
      expect(beijing.weekdayIndex).assertEqual(4);
      expect(rowLabeled(rows, '新德里').dateTimeText).assertEqual('1970-01-01 05:30:00');
      expect(rowLabeled(rows, '加德满都').dateTimeText).assertEqual('1970-01-01 05:45:00');
      expect(rowLabeled(rows, '洛杉矶').dateTimeText).assertEqual('1969-12-31 16:00:00');
    });

    it('zone_rows_handle_instants_before_the_epoch', 0, () => {
      const rows = zoneRows(-1);
      expect(rowLabeled(rows, 'UTC').dateTimeText).assertEqual('1969-12-31 23:59:59');
      expect(rowLabeled(rows, '北京').dateTimeText).assertEqual('1970-01-01 07:59:59');
    });

    // ── 日期字符串解析 ────────────────────────────────────

    it('parses_plain_date_at_utc', 0, () => {
      const result: DateParseResult = parseDateString('2024-05-06', 0);
      expect(result.ok).assertTrue();
      expect(result.milliseconds).assertEqual(1714953600000);
      expect(formatWithOffset(result.milliseconds, 0, 'YYYY-MM-DD HH:mm:ss')).assertEqual('2024-05-06 00:00:00');
    });

    it('parses_date_with_time_using_the_given_offset', 0, () => {
      const result: DateParseResult = parseDateString('2024-05-06 12:30:45', 480);
      expect(result.ok).assertTrue();
      expect(result.milliseconds).assertEqual(1714969845000);
      // 换算回来必须还是用户输入的那个墙上时间
      expect(formatWithOffset(result.milliseconds, 480, 'YYYY-MM-DD HH:mm:ss')).assertEqual('2024-05-06 12:30:45');
      expect(formatWithOffset(result.milliseconds, 0, 'YYYY-MM-DD HH:mm:ss')).assertEqual('2024-05-06 04:30:45');
    });

    it('accepts_slash_separator_and_T_separator', 0, () => {
      expect(parseDateString('2024/05/06', 0).milliseconds).assertEqual(1714953600000);
      expect(parseDateString('2024-05-06T12:30:45', 480).milliseconds).assertEqual(1714969845000);
      expect(parseDateString('2024-05-06 12:30', 0).ok).assertTrue();
    });

    it('leap_day_is_accepted_only_in_leap_years', 0, () => {
      const leap = parseDateString('2024-02-29', 0);
      expect(leap.ok).assertTrue();
      expect(formatWithOffset(leap.milliseconds, 0, 'YYYY-MM-DD')).assertEqual('2024-02-29');
      const notLeap = parseDateString('2023-02-29', 0);
      expect(notLeap.ok).assertFalse();
      expect(notLeap.failure).assertEqual(TimestampDateFailure.DAY_RANGE);
      expect(notLeap.args[2]).assertEqual('28');
      expect(parseDateString('2000-02-29', 0).ok).assertTrue();
      expect(parseDateString('1900-02-29', 0).ok).assertFalse();
    });

    it('rejects_impossible_month_day_and_time', 0, () => {
      expect(parseDateString('2024-13-01', 0).failure).assertEqual(TimestampDateFailure.MONTH_RANGE);
      expect(parseDateString('2024-04-31', 0).failure).assertEqual(TimestampDateFailure.DAY_RANGE);
      expect(parseDateString('2024-04-31', 0).args[2]).assertEqual('30');
      expect(parseDateString('2024-05-06 24:00:00', 0).failure)
        .assertEqual(TimestampDateFailure.TIME_RANGE);
      expect(parseDateString('2024-05-06 12:60:00', 0).ok).assertFalse();
      expect(parseDateString('2024-05-06 12:00:60', 0).ok).assertFalse();
    });

    it('rejects_wrong_shapes_with_a_readable_message', 0, () => {
      expect(parseDateString('', 0).failure).assertEqual(TimestampDateFailure.EMPTY);
      expect(parseDateString('2024-5', 0).failure).assertEqual(TimestampDateFailure.BAD_DATE_FORMAT);
      expect(parseDateString('2024-05-06 12', 0).failure).assertEqual(TimestampDateFailure.BAD_TIME_FORMAT);
      expect(parseDateString('2024-05-06 12:30:45.', 0).failure)
        .assertEqual(TimestampDateFailure.BAD_MILLIS);
      expect(parseDateString('abcd-ef-gh', 0).ok).assertFalse();
      expect(parseDateString('10000-01-01', 0).failure).assertEqual(TimestampDateFailure.YEAR_RANGE);
    });

    it('rejects_timezone_suffix_instead_of_guessing', 0, () => {
      // 含糊接受会给出一个看起来对、其实错的时间，宁可不支持
      const result = parseDateString('2024-05-06T12:30:45Z', 480);
      expect(result.ok).assertFalse();
      // 这里是 DateParseResult（一层失败）
      expect(result.failure).assertEqual(TimestampDateFailure.ZONE_SUFFIX);
    });

    it('keeps_millisecond_precision_and_truncates_beyond_three_digits', 0, () => {
      const threeDigits = parseDateString('2024-05-06 12:30:45.123', 0);
      expect(threeDigits.ok).assertTrue();
      expect(partsOf(threeDigits.milliseconds, 0).millisecond).assertEqual(123);
      const oneDigit = parseDateString('2024-05-06 12:30:45.1', 0);
      expect(partsOf(oneDigit.milliseconds, 0).millisecond).assertEqual(100);
      // Date 的精度就是毫秒，第四位之后只能截断（ISO 允许更多位）
      const sixDigits = parseDateString('2024-05-06 12:30:45.123456', 0);
      expect(partsOf(sixDigits.milliseconds, 0).millisecond).assertEqual(123);
    });

    it('crosses_year_boundary_correctly', 0, () => {
      const before = parseDateString('2023-12-31 23:59:59', 0);
      const after = before.milliseconds + 2000;
      expect(formatWithOffset(after, 0, 'YYYY-MM-DD HH:mm:ss')).assertEqual('2024-01-01 00:00:01');
    });

    it('round_trips_through_a_non_whole_hour_offset', 0, () => {
      const result = parseDateString('2024-05-06 12:00:00', 345);
      expect(result.ok).assertTrue();
      expect(formatWithOffset(result.milliseconds, 345, 'YYYY-MM-DD HH:mm:ss')).assertEqual('2024-05-06 12:00:00');
    });

    // ── 相对时间 ──────────────────────────────────────────

    it('relative_time_covers_every_unit_boundary', 0, () => {
      const base: number = 1700000000000;
      expect(relSpec(relativeTime(base, base))).assertEqual('moment|0|past');
      expect(relSpec(relativeTime(base - 59000, base))).assertEqual('moment|0|past');
      expect(relSpec(relativeTime(base - MINUTE, base))).assertEqual('minutes|1|past');
      expect(relSpec(relativeTime(base - 59 * MINUTE, base))).assertEqual('minutes|59|past');
      expect(relSpec(relativeTime(base - HOUR, base))).assertEqual('hours|1|past');
      expect(relSpec(relativeTime(base - 23 * HOUR, base))).assertEqual('hours|23|past');
      expect(relSpec(relativeTime(base - DAY, base))).assertEqual('days|1|past');
      expect(relSpec(relativeTime(base - 29 * DAY, base))).assertEqual('days|29|past');
      expect(relSpec(relativeTime(base - 30 * DAY, base))).assertEqual('months|1|past');
      expect(relSpec(relativeTime(base - 364 * DAY, base))).assertEqual('months|12|past');
      expect(relSpec(relativeTime(base - 365 * DAY, base))).assertEqual('years|1|past');
      expect(relSpec(relativeTime(base - 730 * DAY, base))).assertEqual('years|2|past');
    });

    it('relative_time_never_says_zero_years_near_the_one_year_boundary', 0, () => {
      // 360-364 天这个区间最早会输出「0 年前」（按年算是 0，按月算已经 12）。
      // 现在的口径是「不满 365 天一律按月说」，两种错法都不会再出现。
      const base: number = 1700000000000;
      expect(relSpec(relativeTime(base - 359 * DAY, base))).assertEqual('months|11|past');
      expect(relSpec(relativeTime(base - 360 * DAY, base))).assertEqual('months|12|past');
      expect(relSpec(relativeTime(base - 364 * DAY, base))).assertEqual('months|12|past');
      expect(relSpec(relativeTime(base - 365 * DAY, base))).assertEqual('years|1|past');
      expect(relSpec(relativeTime(base - 366 * DAY, base))).assertEqual('years|1|past');
    });

    it('relative_time_describes_future_moments', 0, () => {
      const base: number = 1700000000000;
      expect(relSpec(relativeTime(base + 30000, base))).assertEqual('moment|0|future');
      expect(relSpec(relativeTime(base + 3 * MINUTE, base))).assertEqual('minutes|3|future');
      expect(relSpec(relativeTime(base + 2 * DAY, base))).assertEqual('days|2|future');
    });

    // ── 双向解释 ──────────────────────────────────────────

    it('interprets_digits_as_seconds_timestamp', 0, () => {
      const result: TimestampInterpretation = interpretInput('1700000000', 0);
      expect(result.kind).assertEqual(InterpretKind.TIMESTAMP);
      expect(result.unit).assertEqual(TimestampUnit.SECONDS);
      expect(result.secondsText).assertEqual('1700000000');
      expect(result.millisecondsText).assertEqual('1700000000000');
      expect(result.zoneText).assertEqual('2023-11-14 22:13:20');
      expect(result.utcText).assertEqual('2023-11-14 22:13:20');
    });

    it('interprets_thirteen_digits_as_milliseconds_timestamp', 0, () => {
      const result = interpretInput('1700000000000', 0);
      expect(result.kind).assertEqual(InterpretKind.TIMESTAMP);
      expect(result.unit).assertEqual(TimestampUnit.MILLISECONDS);
      expect(result.secondsText).assertEqual('1700000000');
    });

    it('interprets_a_date_string_the_other_way_round', 0, () => {
      const result = interpretInput('2024-05-06 12:30:45', 480);
      expect(result.kind).assertEqual(InterpretKind.DATE);
      expect(result.millisecondsText).assertEqual('1714969845000');
      expect(result.secondsText).assertEqual('1714969845');
      expect(result.zoneText).assertEqual('2024-05-06 12:30:45');
    });

    it('interprets_negative_and_empty_and_garbage_inputs', 0, () => {
      const negative = interpretInput('-86400', 0);
      expect(negative.kind).assertEqual(InterpretKind.TIMESTAMP);
      expect(negative.zoneText).assertEqual('1969-12-31 00:00:00');
      expect(interpretInput('', 0).kind).assertEqual(InterpretKind.EMPTY);
      const garbage = interpretInput('hello', 0);
      expect(garbage.kind).assertEqual(InterpretKind.INVALID);
      expect(garbage.failure.dateFailure).assertEqual(TimestampDateFailure.BAD_DATE_FORMAT);
    });

    it('interpret_reports_out_of_range_timestamps_as_invalid', 0, () => {
      const result = interpretInput('99999999999999999', 0);
      expect(result.kind).assertEqual(InterpretKind.INVALID);
      // InterpretFailure 是两层结构：外层说「来自哪条路」，内层是那条路的具体原因
      expect(result.failure.fromTimestamp).assertTrue();
      expect(result.failure.timestampFailure).assertEqual(TimestampFailure.TOO_MANY_DIGITS);
    });

    it('interpret_uses_the_offset_it_was_given', 0, () => {
      const inUtc = interpretInput('1700000000', 0);
      const inBeijing = interpretInput('1700000000', 480);
      expect(inUtc.zoneText).assertEqual('2023-11-14 22:13:20');
      expect(inBeijing.zoneText).assertEqual('2023-11-15 06:13:20');
      // utcText 不随展示时区变化
      expect(inBeijing.utcText).assertEqual(inUtc.utcText);
    });

    it('now_is_a_sane_positive_timestamp', 0, () => {
      const now: number = nowMilliseconds();
      expect(now > 1700000000000).assertTrue();
      expect(isValidTimestamp(now)).assertTrue();
    });
  });
}