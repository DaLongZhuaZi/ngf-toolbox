import { describe, expect, it } from '@ohos/hypium';
import {
  diffDates,
  parseIsoDate,
  DateDiffFailureCode
} from '../main/ets/tools/date-diff/DateDiffLogic';

/**
 * 日期差的单测：手算锚点（2026-01-05 周一）。
 */
export default function dateDiffTest() {
  describe('dateDiffTest', () => {
    it('同日差为 0', 0, () => {
      const r = diffDates('2026-01-05', '2026-01-05');
      expect(r.naturalDays).assertEqual(0);
      expect(r.workdays).assertEqual(0);
    });

    it('一周：7 自然日 5 工作日', 0, () => {
      const r = diffDates('2026-01-05', '2026-01-12');
      expect(r.naturalDays).assertEqual(7);
      expect(r.workdays).assertEqual(5);
      expect(r.weeks).assertEqual(1);
    });

    it('方向：start 晚于 end 为负', 0, () => {
      const r = diffDates('2026-01-12', '2026-01-05');
      expect(r.naturalDays).assertEqual(-7);
      expect(r.workdays).assertEqual(-5);
    });

    it('跨月：2026-01-31 到 2026-03-01 = 29 自然日', 0, () => {
      const r = diffDates('2026-01-31', '2026-03-01');
      expect(r.naturalDays).assertEqual(29);
    });

    it('错误路径：坏日期与空输入', 0, () => {
      expect(diffDates('bad-date-x', '2026-01-05').failure.code).assertEqual(DateDiffFailureCode.BAD_DATE);
      expect(diffDates('2026-01-05', '').failure.code).assertEqual(DateDiffFailureCode.EMPTY_INPUT);
    });

    it('parseIsoDate：合法与非法', 0, () => {
      expect(isNaN(parseIsoDate('2026-13-01'))).assertEqual(true);
      expect(isNaN(parseIsoDate('short'))).assertEqual(true);
      expect(parseIsoDate('2026-01-05') > 0).assertEqual(true);
    });
  });
}
