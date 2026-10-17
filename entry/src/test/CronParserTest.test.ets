import { describe, expect, it } from '@ohos/hypium';
import {
  CRON_MAX_RUNS,
  CronDescription,
  CronTimeBasis,
  CronField,
  CronFieldError,
  CronFieldKey,
  cronDayMatches,
  CronNextRunsResult,
  CronParseFailureCode,
  CronParseResult,
  formatCronRun,
  nextCronRuns,
  parseCronExpression
} from '../main/ets/tools/cron-parser/CronParser';

/**
 * cron 解析的纯逻辑单测。
 *
 * 时间断言一律用「本地时间字段」比较（getFullYear/getHours...），绝不用固定时间戳的字面量：
 * 前者在任何时区都成立，后者会在 CI（UTC）与开发机（UTC+8）之间随机红。
 */
export default function cronParserTest() {
  describe('cronParserTest', () => {
    it('*/5 展开为 0..55 每 5 分钟，且保留 isWildcard 与 step', 0, () => {
      const parsed: CronParseResult = parseCronExpression('*/5 * * * *');
      expect(parsed.ok).assertTrue();
      const minutes = parsed.minutes as CronField;
      expect(minutes.values.length).assertEqual(12);
      expect(minutes.values[0]).assertEqual(0);
      expect(minutes.values[11]).assertEqual(55);
      expect(minutes.step).assertEqual(5);
      expect(minutes.isWildcard).assertTrue();
    });

    it('区间 1-5 与列表 1,3,5 都要展开正确', 0, () => {
      const range = parseCronExpression('1-5 * * * *');
      expect(range.ok).assertTrue();
      const rangeMinutes = range.minutes as CronField;
      expect(rangeMinutes.values.length).assertEqual(5);
      expect(rangeMinutes.isWildcard).assertFalse();
      const list = parseCronExpression('1,3,5 * * * *');
      const listMinutes = list.minutes as CronField;
      expect(listMinutes.values.length).assertEqual(3);
      expect(listMinutes.values[2]).assertEqual(5);
    });

    it('英文月份与星期缩写(含区间)必须能解析', 0, () => {
      const parsed: CronParseResult = parseCronExpression('0 9 * JAN,MAR MON-FRI');
      expect(parsed.ok).assertTrue();
      const months = parsed.months as CronField;
      expect(months.values[0]).assertEqual(1);
      expect(months.values[1]).assertEqual(3);
      const weekdays = parsed.daysOfWeek as CronField;
      expect(weekdays.values.length).assertEqual(5);
      expect(weekdays.values[0]).assertEqual(1);
      expect(weekdays.values[4]).assertEqual(5);
    });

    it('星期 7 与 0 都表示周日，且不会重复成两个值', 0, () => {
      const seven = parseCronExpression('0 0 * * 7');
      const sevenField = seven.daysOfWeek as CronField;
      expect(sevenField.values.length).assertEqual(1);
      expect(sevenField.values[0]).assertEqual(0);
      const mixed = parseCronExpression('0 0 * * 0,7');
      const mixedField = mixed.daysOfWeek as CronField;
      expect(mixedField.values.length).assertEqual(1);
    });

    it('段数不是 5 时必须报错，并区分 6 段与 @ 别名', 0, () => {
      const four = parseCronExpression('* * * *');
      expect(four.ok).assertFalse();
      expect(four.failure.codes[0]).assertEqual(CronParseFailureCode.WRONG_SEGMENT_COUNT);
      expect(four.failure.args[0]).assertEqual('4');
      const six = parseCronExpression('0 0 12 * * ?');
      expect(six.ok).assertFalse();
      expect(six.failure.codes.indexOf(CronParseFailureCode.SIX_SEGMENTS) >= 0).assertTrue();
      const alias = parseCronExpression('@daily');
      expect(alias.ok).assertFalse();
      expect(alias.failure.codes.indexOf(CronParseFailureCode.ALIAS) >= 0).assertTrue();
    });

    it('超范围的取值必须报错并指出是第几段', 0, () => {
      const minute = parseCronExpression('60 * * * *');
      expect(minute.ok).assertFalse();
      expect(minute.segmentIndex).assertEqual(0);
      expect(minute.failure.fieldKey).assertEqual(CronFieldKey.MINUTE);
      const hour = parseCronExpression('0 24 * * *');
      expect(hour.segmentIndex).assertEqual(1);
      const month = parseCronExpression('0 0 * 13 *');
      expect(month.segmentIndex).assertEqual(3);
      const weekday = parseCronExpression('0 0 * * 8');
      expect(weekday.segmentIndex).assertEqual(4);
    });

    it('倒着写的区间、步长为 0、空取值都要报错(防静默算出错时间)', 0, () => {
      const reversed = parseCronExpression('5-1 * * * *');
      expect(reversed.ok).assertFalse();
      expect(reversed.failure.fieldCode).assertEqual(CronFieldError.REVERSED_RANGE);
      const zeroStep = parseCronExpression('*/0 * * * *');
      expect(zeroStep.ok).assertFalse();
      expect(zeroStep.failure.fieldCode).assertEqual(CronFieldError.STEP_NOT_POSITIVE);
      const emptyItem = parseCronExpression('1,,3 * * * *');
      expect(emptyItem.ok).assertFalse();
      expect(emptyItem.failure.fieldCode).assertEqual(CronFieldError.EMPTY_ITEM);
      const illegal = parseCronExpression('abc * * * *');
      expect(illegal.ok).assertFalse();
    });

    it('「日」与「星期」都不是 * 时是「或」关系(经典坑，逐条锁死)', 0, () => {
      const days: CronField = new CronField(CronFieldKey.DAY_OF_MONTH, '15', [15], false, 0);
      const mondays: CronField = new CronField(CronFieldKey.DAY_OF_WEEK, '1', [1], false, 0);
      const anyDay: CronField = new CronField(CronFieldKey.DAY_OF_MONTH, '*', [1, 2, 3], true, 0);
      const anyWeekday: CronField = new CronField(CronFieldKey.DAY_OF_WEEK, '*', [0, 1, 2, 3, 4, 5, 6], true, 0);
      // 15 号是周一：两个条件都满足
      expect(cronDayMatches(15, 1, days, mondays)).assertTrue();
      // 15 号是周二：只满足「日」
      expect(cronDayMatches(15, 2, days, mondays)).assertTrue();
      // 16 号是周一：只满足「星期」
      expect(cronDayMatches(16, 1, days, mondays)).assertTrue();
      // 16 号是周二：都不满足
      expect(cronDayMatches(16, 2, days, mondays)).assertFalse();
      // 只有「星期」限定时，按「且」处理
      expect(cronDayMatches(15, 2, anyDay, mondays)).assertFalse();
      expect(cronDayMatches(15, 1, anyDay, mondays)).assertTrue();
      expect(cronDayMatches(15, 2, days, anyWeekday)).assertTrue();
    });

    it('「每月 1 号或每周一」必须取最近的那个(防当成「且」而永远算不出来)', 0, () => {
      // 2024-01-02 是周二：下一次应当是 2024-01-08（周一），而不是 2024-02-01
      const from: number = new Date(2024, 0, 2, 0, 0, 0, 0).getTime();
      // 2024-01-01 是周一，所以 1 月的周一依次是 8/15/22/29，之后才是 2 月 1 日
      const result: CronNextRunsResult = nextCronRuns('0 0 1 * 1', from, 5);
      expect(result.ok).assertTrue();
      expect(result.runs.length).assertEqual(5);
      const first: Date = result.runs[0];
      expect(first.getFullYear()).assertEqual(2024);
      expect(first.getMonth()).assertEqual(0);
      expect(first.getDate()).assertEqual(8);
      expect(first.getDay()).assertEqual(1);
      const second: Date = result.runs[1];
      expect(second.getMonth()).assertEqual(0);
      expect(second.getDate()).assertEqual(15);
      // 「或」的另一半：月份翻页后 1 号也会命中，且它并不是周一
      const fifth: Date = result.runs[4];
      expect(fifth.getMonth()).assertEqual(1);
      expect(fifth.getDate()).assertEqual(1);
      expect(fifth.getDay()).assertEqual(4);
    });

    it('闰年 2 月 29 日：从 2023 年 3 月出发应当落在 2024-02-29', 0, () => {
      const from: number = new Date(2023, 2, 1, 0, 0, 0, 0).getTime();
      const result: CronNextRunsResult = nextCronRuns('0 0 29 2 *', from, 2);
      expect(result.ok).assertTrue();
      expect(result.neverMatches).assertFalse();
      expect(result.runs.length).assertEqual(2);
      expect(result.runs[0].getFullYear()).assertEqual(2024);
      expect(result.runs[0].getMonth()).assertEqual(1);
      expect(result.runs[0].getDate()).assertEqual(29);
      expect(result.runs[1].getFullYear()).assertEqual(2028);
    });

    it('2 月 30 日这类永不成立的组合必须报告而不是空列表', 0, () => {
      const from: number = new Date(2024, 0, 1, 0, 0, 0, 0).getTime();
      const result: CronNextRunsResult = nextCronRuns('0 0 30 2 *', from, 5);
      expect(result.ok).assertTrue();
      expect(result.neverMatches).assertTrue();
      expect(result.runs.length).assertEqual(0);
    });

    it('「2 月 30 日或周一」因为「或」而真的会成立(反向验证经典坑)', 0, () => {
      const from: number = new Date(2024, 0, 1, 0, 0, 0, 0).getTime();
      const result: CronNextRunsResult = nextCronRuns('0 0 30 2 1', from, 1);
      expect(result.ok).assertTrue();
      expect(result.neverMatches).assertFalse();
      expect(result.runs.length).assertEqual(1);
      expect(result.runs[0].getMonth()).assertEqual(1);
      expect(result.runs[0].getDay()).assertEqual(1);
    });

    it('每分钟表达式必须逐分钟递增且严格晚于传入时刻', 0, () => {
      const from: number = new Date(2024, 5, 1, 10, 30, 30, 0).getTime();
      const result: CronNextRunsResult = nextCronRuns('* * * * *', from, 3);
      expect(result.ok).assertTrue();
      expect(result.runs.length).assertEqual(3);
      expect(result.runs[0].getHours()).assertEqual(10);
      expect(result.runs[0].getMinutes()).assertEqual(31);
      expect(result.runs[0].getSeconds()).assertEqual(0);
      expect(result.runs[1].getTime() - result.runs[0].getTime()).assertEqual(60000);
      // 整点传入时不能"补上"当前这一分钟
      const onTheMinute: number = new Date(2024, 5, 1, 10, 30, 0, 0).getTime();
      const next: CronNextRunsResult = nextCronRuns('* * * * *', onTheMinute, 1);
      expect(next.runs[0].getMinutes()).assertEqual(31);
    });

    it('每天 12:00 的执行时间跨天连续', 0, () => {
      const from: number = new Date(2024, 5, 1, 13, 0, 0, 0).getTime();
      const result: CronNextRunsResult = nextCronRuns('0 12 * * *', from, 3);
      expect(result.ok).assertTrue();
      expect(result.runs[0].getHours()).assertEqual(12);
      expect(result.runs[0].getMinutes()).assertEqual(0);
      expect(result.runs[0].getDate()).assertEqual(2);
      expect(result.runs[1].getDate()).assertEqual(3);
    });

    it('每年 1 月 1 日：6 月出发应当落到下一年', 0, () => {
      const from: number = new Date(2024, 5, 1, 0, 0, 0, 0).getTime();
      const result: CronNextRunsResult = nextCronRuns('0 0 1 1 *', from, 1);
      expect(result.ok).assertTrue();
      expect(result.runs[0].getFullYear()).assertEqual(2025);
      expect(result.runs[0].getMonth()).assertEqual(0);
      expect(result.runs[0].getDate()).assertEqual(1);
    });

    it('次数有上限，且非法次数退回默认 5 次(防界面被 10000 条卡死)', 0, () => {
      const from: number = new Date(2024, 5, 1, 0, 0, 0, 0).getTime();
      const capped: CronNextRunsResult = nextCronRuns('* * * * *', from, 10000);
      expect(capped.runs.length).assertEqual(CRON_MAX_RUNS);
      const fallback: CronNextRunsResult = nextCronRuns('* * * * *', from, 0);
      expect(fallback.runs.length).assertEqual(5);
      expect(fallback.runs.length).assertLess(CRON_MAX_RUNS);
    });

    it('星期 7 表示周日的求值结果确实是周日', 0, () => {
      const from: number = new Date(2024, 5, 1, 0, 0, 0, 0).getTime();
      const result: CronNextRunsResult = nextCronRuns('0 0 * * 7', from, 2);
      expect(result.ok).assertTrue();
      expect(result.runs[0].getDay()).assertEqual(0);
      expect(result.runs[1].getDay()).assertEqual(0);
    });

    it('非法表达式求值时返回错误而不是空列表', 0, () => {
      const result: CronNextRunsResult = nextCronRuns('* * *', 0, 5);
      expect(result.ok).assertFalse();
      expect(result.runs.length).assertEqual(0);
    });

    it('人话描述要覆盖分钟步长/整点/星期/日期四种形态', 0, () => {
      const desc: CronDescription = parseCronExpression('*/5 * * * *').description;
      expect(desc.basis).assertEqual(CronTimeBasis.EVERY_N_MINUTES);
      expect(desc.step).assertEqual(5);
      // 描述改成结构后，断言「按哪种基准 + 带哪些限定」而不是中文措辞
      const daily: CronDescription = parseCronExpression('0 3 * * *').description;
      expect(daily.basis).assertEqual(CronTimeBasis.AT_TIMES);
      expect(daily.hours[0]).assertEqual(3);
      const weekly: CronDescription = parseCronExpression('0 9 * * MON').description;
      expect(weekly.daysOfWeekRestricted).assertTrue();
      expect(weekly.daysOfWeek[0]).assertEqual(1);
      const monthly: CronDescription = parseCronExpression('0 0 1 * *').description;
      expect(monthly.daysOfMonthRestricted).assertTrue();
      expect(monthly.daysOfMonth[0]).assertEqual(1);
      const yearly: CronDescription = parseCronExpression('0 0 1 6 *').description;
      expect(yearly.monthsRestricted).assertTrue();
      expect(yearly.months[0]).assertEqual(6);
      expect(parseCronExpression('bad').description.basis).assertEqual(CronTimeBasis.NONE);
    });

    it('日与周同时限定时描述里必须出现「或」，并提供规则提示', 0, () => {
      const parsed: CronParseResult = parseCronExpression('0 0 1 * 1');
      expect(parsed.ok).assertTrue();
      expect(parsed.description.dayFieldsAreOr).assertTrue();
      expect(parsed.hasOrRule).assertTrue();
      const single: CronParseResult = parseCronExpression('0 0 1 * *');
      expect(single.hasOrRule).assertFalse();
    });

    it('执行时间的格式化口径固定(防时区/补零写错)', 0, () => {
      const date: Date = new Date(2024, 0, 8, 9, 5, 0, 0);
      expect(formatCronRun(date)).assertEqual('2024-01-08 09:05');
    });
  });
}