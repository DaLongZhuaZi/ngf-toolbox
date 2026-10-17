import { describe, expect, it } from '@ohos/hypium';
import {
  addDaysToDate,
  addMonthsToDate,
  addYearsToDate,
  DateDiffField,
  DateDiffResult,
  DateParseFailure,
  DateParseResult,
  DateShiftFailure,
  DateShiftResult,
  daysInMonth,
  diffDates,
  formatDate,
  formatDateWithWeekday,
  fromDayNumber,
  isLeapYear,
  isWorkday,
  isValidYear,
  NGFDate,
  parseDateText,
  toDayNumber,
  weekdayLabel,
  weekdayOf
} from '../main/ets/tools/date-calc/DateCalc';

/**
 * 日期计算的纯逻辑单测。
 *
 * 期望值来自独立参考实现的换算（Node 的 UTC 日序数），并且刻意覆盖三个"看起来对"的错答案：
 * 1. 1900 年不是闰年（100 年不闰）、2000 年是（400 年再闰）；
 * 2. 1/31 加一个月应当是 2 月最后一天，而不是 3 月 2/3 日；
 * 3. 2/29 加一年应当是 2/28，而加四年应当还是 2/29。
 */
/**
 * 取结果里的日期文本（'YYYY-MM-DD'）；失败时空串。
 *
 * 原先断言的是 \`result.text\`——那个字段存的是拼好的「YYYY-MM-DD 周X」，
 * 其中的「周X」是文案，已下移到 UI 层，所以纯逻辑侧只留日期本身。
 */
function dateTextOf(result: DateShiftResult): string {
  return result.date === null ? '' : formatDate(result.date);
}

export default function dateCalcTest() {
  describe('dateCalcTest', () => {
    it('闰年规则必须同时满足 4/100/400 三条(防只写 year%4)', 0, () => {
      expect(isLeapYear(2024)).assertTrue();
      expect(isLeapYear(2023)).assertFalse();
      expect(isLeapYear(1900)).assertFalse();
      expect(isLeapYear(2000)).assertTrue();
      expect(isLeapYear(2100)).assertFalse();
      expect(isLeapYear(2400)).assertTrue();
    });

    it('每月天数：2 月随闰年变化，小月固定 30 天', 0, () => {
      expect(daysInMonth(2024, 2)).assertEqual(29);
      expect(daysInMonth(2023, 2)).assertEqual(28);
      expect(daysInMonth(1900, 2)).assertEqual(28);
      expect(daysInMonth(2000, 2)).assertEqual(29);
      expect(daysInMonth(2024, 4)).assertEqual(30);
      expect(daysInMonth(2024, 12)).assertEqual(31);
      expect(daysInMonth(2024, 1)).assertEqual(31);
    });

    it('日期解析接受多种常见写法', 0, () => {
      const dashed: DateParseResult = parseDateText('2024-02-29');
      expect(dashed.ok).assertTrue();
      const slash: DateParseResult = parseDateText('2024/2/9');
      expect(slash.ok).assertTrue();
      const dotted: DateParseResult = parseDateText('2024.2.9');
      expect(dotted.ok).assertTrue();
      const compact: DateParseResult = parseDateText('20240229');
      expect(compact.ok).assertTrue();
      const chinese: DateParseResult = parseDateText('2024年2月29日');
      expect(chinese.ok).assertTrue();
      const date = chinese.date as NGFDate;
      expect(date.year).assertEqual(2024);
      expect(date.month).assertEqual(2);
      expect(date.day).assertEqual(29);
    });

    it('不存在的日期必须报错并说明该月天数(防静默滚到下个月)', 0, () => {
      const result: DateParseResult = parseDateText('2023-02-29');
      expect(result.ok).assertFalse();
      // 文案已下移到 UI 层；纯逻辑只给码与参数。
      // 断言参数而不是文案：文案改措辞不该让测试变红。
      expect(result.failure).assertEqual(DateParseFailure.DAY_RANGE);
      expect(result.args[2]).assertEqual('28');
      expect(parseDateText('2023-04-31').failure).assertEqual(DateParseFailure.DAY_RANGE);
      expect(parseDateText('2023-04-31').args[2]).assertEqual('30');
      expect(parseDateText('2023-01-32').args[2]).assertEqual('31');
      expect(parseDateText('2023-13-01').failure).assertEqual(DateParseFailure.MONTH_RANGE);
      expect(parseDateText('2023-00-10').failure).assertEqual(DateParseFailure.MONTH_RANGE);
      expect(parseDateText('10000-01-01').failure).assertEqual(DateParseFailure.YEAR_RANGE);
      // 年份上下限要跟着参数走，常量改了文案才不会过期
      expect(parseDateText('10000-01-01').args.length).assertEqual(2);
      expect(parseDateText('').failure).assertEqual(DateParseFailure.EMPTY);
      expect(parseDateText('昨天').failure).assertEqual(DateParseFailure.UNRECOGNIZED);
      expect(parseDateText('2024-1a-01').failure).assertEqual(DateParseFailure.NON_DIGIT);
    });

    it('日序数换算与参考实现一致(1-01-01 是 -719162)', 0, () => {
      expect(toDayNumber(new NGFDate(1970, 1, 1))).assertEqual(0);
      expect(toDayNumber(new NGFDate(1, 1, 1))).assertEqual(-719162);
      const roundTrip: NGFDate = fromDayNumber(toDayNumber(new NGFDate(2024, 2, 29)));
      expect(roundTrip.year).assertEqual(2024);
      expect(roundTrip.month).assertEqual(2);
      expect(roundTrip.day).assertEqual(29);
      const ancient: NGFDate = fromDayNumber(-719162);
      expect(ancient.year).assertEqual(1);
      expect(ancient.month).assertEqual(1);
      expect(ancient.day).assertEqual(1);
    });

    it('星期换算正确(1-01-01 是周一，2024-02-29 是周四)', 0, () => {
      expect(weekdayOf(new NGFDate(1, 1, 1))).assertEqual(1);
      expect(weekdayOf(new NGFDate(2024, 2, 29))).assertEqual(4);
      expect(weekdayOf(new NGFDate(2024, 1, 8))).assertEqual(1);
      // 星期名是双语数据：两侧都要写得出来，且越界返回空串而不是 undefined
      expect(weekdayLabel(0, 'zh-CN')).assertEqual('周日');
      expect(weekdayLabel(4, 'zh-CN')).assertEqual('周四');
      expect(weekdayLabel(0, 'en-US')).assertEqual('Sun');
      expect(weekdayLabel(4, 'en-US')).assertEqual('Thu');
      expect(weekdayLabel(9, 'zh-CN')).assertEqual('');
      expect(weekdayLabel(-1, 'zh-CN')).assertEqual('');
    });

    it('工作日判定只认周一到周五(不含节假日)', 0, () => {
      expect(isWorkday(new NGFDate(2024, 1, 5))).assertTrue();
      expect(isWorkday(new NGFDate(2024, 1, 6))).assertFalse();
      expect(isWorkday(new NGFDate(2024, 1, 7))).assertFalse();
      expect(isWorkday(new NGFDate(2024, 1, 8))).assertTrue();
    });

    it('间隔天数与工作日数（全年口径要能对上参考值）', 0, () => {
      const full: DateDiffResult = diffDates('2024-01-01', '2024-12-31', true);
      expect(full.ok).assertTrue();
      expect(full.days).assertEqual(365);
      expect(full.workdays).assertEqual(261);
      expect(full.reversed).assertFalse();
      expect(full.sameDay).assertFalse();
    });

    it('同一天间隔必须为 0，且 sameDay 为真(防把起算日算进去)', 0, () => {
      const same: DateDiffResult = diffDates('2024-05-20', '2024-05-20', true);
      expect(same.days).assertEqual(0);
      expect(same.workdays).assertEqual(0);
      expect(same.sameDay).assertTrue();
    });

    it('起止倒置时天数是负数（工作日同号），并给出 reversed 标记', 0, () => {
      const reversed: DateDiffResult = diffDates('2024-12-31', '2024-01-01', true);
      expect(reversed.ok).assertTrue();
      expect(reversed.days).assertEqual(-365);
      expect(reversed.workdays).assertEqual(-261);
      expect(reversed.reversed).assertTrue();
    });

    it('跨周末的工作日只算工作日(周五到周一 = 1 个工作日)', 0, () => {
      const weekend: DateDiffResult = diffDates('2024-01-05', '2024-01-08', true);
      expect(weekend.days).assertEqual(3);
      expect(weekend.workdays).assertEqual(1);
      const noFilter: DateDiffResult = diffDates('2024-01-05', '2024-01-08', false);
      expect(noFilter.workdays).assertEqual(3);
    });

    it('超长跨度不能算溢出(公元 1 年 → 9999 年)', 0, () => {
      const long: DateDiffResult = diffDates('0001-01-01', '9999-12-31', false);
      expect(long.ok).assertTrue();
      expect(long.days).assertEqual(3652058);
      expect(long.workdays).assertEqual(3652058);
    });

    it('加减天数：跨月、跨年与负向都要对', 0, () => {
      expect(dateTextOf(addDaysToDate('2024-02-28', 1))).assertEqual('2024-02-29');
      expect(dateTextOf(addDaysToDate('2023-02-28', 1))).assertEqual('2023-03-01');
      expect(dateTextOf(addDaysToDate('2024-12-31', 1))).assertEqual('2025-01-01');
      expect(dateTextOf(addDaysToDate('2024-01-01', -1))).assertEqual('2023-12-31');
      expect(dateTextOf(addDaysToDate('2024-03-01', -1))).assertEqual('2024-02-29');
      const nonInteger: DateShiftResult = addDaysToDate('2024-01-01', 1.5);
      expect(nonInteger.ok).assertFalse();
      expect(nonInteger.failure).assertEqual(DateShiftFailure.DAYS_NOT_INTEGER);
    });

    it('加月数时目标月没有 31 日必须夹到月末并标记(经典坑)', 0, () => {
      const january: DateShiftResult = addMonthsToDate('2024-01-31', 1);
      expect(january.ok).assertTrue();
      expect(dateTextOf(january)).assertEqual('2024-02-29');
      expect(january.clamped).assertTrue();
      const february: DateShiftResult = addMonthsToDate('2023-01-31', 1);
      expect(dateTextOf(february)).assertEqual('2023-02-28');
      expect(february.clamped).assertTrue();
      const noClamp: DateShiftResult = addMonthsToDate('2024-01-15', 1);
      expect(dateTextOf(noClamp)).assertEqual('2024-02-15');
      expect(noClamp.clamped).assertFalse();
    });

    it('加月数：跨年、减月、加 12 个月', 0, () => {
      expect(dateTextOf(addMonthsToDate('2024-11-15', 2))).assertEqual('2025-01-15');
      expect(dateTextOf(addMonthsToDate('2024-03-31', -1))).assertEqual('2024-02-29');
      expect(dateTextOf(addMonthsToDate('2024-02-29', 12))).assertEqual('2025-02-28');
      expect(dateTextOf(addMonthsToDate('2024-05-31', -3))).assertEqual('2024-02-29');
    });

    it('加年数：2/29 加 1 年变 2/28，加 4 年仍是 2/29', 0, () => {
      const oneYear: DateShiftResult = addYearsToDate('2024-02-29', 1);
      expect(dateTextOf(oneYear)).assertEqual('2025-02-28');
      expect(oneYear.clamped).assertTrue();
      const fourYears: DateShiftResult = addYearsToDate('2024-02-29', 4);
      expect(dateTextOf(fourYears)).assertEqual('2028-02-29');
      expect(fourYears.clamped).assertFalse();
      const minus: DateShiftResult = addYearsToDate('2024-02-29', -1);
      expect(dateTextOf(minus)).assertEqual('2023-02-28');
    });

    it('结果超出可表示年份范围时要报错而不是给出错日期', 0, () => {
      expect(addYearsToDate('9999-12-31', 1).ok).assertFalse();
      expect(addYearsToDate('9999-12-31', 1).failure).assertEqual(DateShiftFailure.OUT_OF_RANGE);
      expect(addDaysToDate('0001-01-01', -1).ok).assertFalse();
      expect(addMonthsToDate('9999-12-01', 1).ok).assertFalse();
      expect(isValidYear(0)).assertFalse();
      expect(isValidYear(10000)).assertFalse();
      expect(isValidYear(2024)).assertTrue();
    });

    it('格式化输出固定口径(补零 + 星期)', 0, () => {
      expect(formatDate(new NGFDate(2024, 1, 8))).assertEqual('2024-01-08');
      expect(formatDateWithWeekday(new NGFDate(2024, 1, 8), 'zh-CN')).assertEqual('2024-01-08 周一');
      expect(formatDateWithWeekday(new NGFDate(2024, 1, 8), 'en-US')).assertEqual('2024-01-08 Mon');
      expect(formatDate(new NGFDate(1, 1, 1))).assertEqual('0001-01-01');
    });

    it('非法日期参与运算时返回错误而不是默认值', 0, () => {
      expect(diffDates('2023-02-29', '2024-01-01', true).ok).assertFalse();
      // 间隔失败要能说清是**哪一侧**日期有问题
      expect(diffDates('2023-02-29', '2024-01-01', true).failure.field)
        .assertEqual(DateDiffField.START);
      expect(diffDates('2024-01-01', 'bad', true).failure.field)
        .assertEqual(DateDiffField.END);
      // 并且内层原因也要带过来，页面才能拼出「结束日期：无法识别的日期格式」
      expect(diffDates('2024-01-01', 'bad', true).failure.innerFailure)
        .assertEqual(DateParseFailure.UNRECOGNIZED);
      expect(addDaysToDate('bad', 1).ok).assertFalse();
      expect(addMonthsToDate('bad', 1).ok).assertFalse();
      expect(addYearsToDate('bad', 1).ok).assertFalse();
    });
  });
}