import { describe, expect, it } from '@ohos/hypium';
import {
  addWorkdays,
  SprintFailureCode
} from '../main/ets/tools/sprint-calc/SprintLogic';

/**
 * 工作日计算的单测：**手算锚点**（2026-01-05 是周一）。
 * 周一到周五各 +1 工作日 = 次日；周五 +1 = 下周一。
 */
export default function sprintCalcTest() {
  describe('sprintCalcTest', () => {
    it('周一 +1 工作日 = 周二', 0, () => {
      const r = addWorkdays('2026-01-05', '1');
      expect(r.ok).assertEqual(true);
      expect(r.resultDate).assertEqual('2026-01-06');
      expect(r.resultWeekday).assertEqual(2);
      expect(r.naturalDays).assertEqual(1);
    });

    it('周五 +1 工作日 = 下周一（跳过周末）', 0, () => {
      // 2026-01-09 是周五
      const r = addWorkdays('2026-01-09', '1');
      expect(r.resultDate).assertEqual('2026-01-12');
      expect(r.resultWeekday).assertEqual(1);
      expect(r.naturalDays).assertEqual(3);
    });

    it('一周 = 5 工作日：周一 +5 = 下周一', 0, () => {
      const r = addWorkdays('2026-01-05', '5');
      expect(r.resultDate).assertEqual('2026-01-12');
      expect(r.naturalDays).assertEqual(7);
    });

    it('负数：向前（周一 -1 工作日 = 上周五）', 0, () => {
      const r = addWorkdays('2026-01-05', '-1');
      expect(r.resultDate).assertEqual('2026-01-02');
      expect(r.resultWeekday).assertEqual(5);
    });

    it('两周冲刺：周一 +10 工作日 = 三周后的周一', 0, () => {
      const r = addWorkdays('2026-01-05', '10');
      expect(r.resultDate).assertEqual('2026-01-19');
    });

    it('错误路径：坏日期/非数字/超大天数/空输入', 0, () => {
      expect(addWorkdays('2026-13-01', '1').failure.code).assertEqual(SprintFailureCode.BAD_DATE);
      expect(addWorkdays('bad-date-x', '1').failure.code).assertEqual(SprintFailureCode.BAD_DATE);
      expect(addWorkdays('2026-01-05', 'abc').failure.code).assertEqual(SprintFailureCode.DAYS_TOO_LARGE);
      expect(addWorkdays('2026-01-05', '0').failure.code).assertEqual(SprintFailureCode.DAYS_TOO_LARGE);
      expect(addWorkdays('', '').failure.code).assertEqual(SprintFailureCode.EMPTY_INPUT);
    });
  });
}
