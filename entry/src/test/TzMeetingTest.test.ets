import { describe, expect, it } from '@ohos/hypium';
import {
  meetingTimes,
  tzCityNames,
  TzFailureCode
} from '../main/ets/tools/tz-meeting/TzLogic';

/**
 * 时区对照的单测：**手算锚点**（UTC 偏移固定，无夏令时）。
 * 北京(480) 20:00 = UTC 12:00 = 伦敦(0) 12:00 = 纽约(-300) 07:00 = 悉尼(600) 23:00。
 */
export default function tzMeetingTest() {
  describe('tzMeetingTest', () => {
    it('北京 20:00 → 伦敦 12:00、纽约 07:00', 0, () => {
      const r = meetingTimes('20:00', 480);
      expect(r.ok).assertEqual(true);
      expect(r.rows.length).assertEqual(8);
      let london = '';
      let newYork = '';
      for (let i = 0; i < r.rows.length; i++) {
        if (r.rows[i].city.zh === '伦敦') { london = r.rows[i].timeText; }
        if (r.rows[i].city.zh === '纽约') { newYork = r.rows[i].timeText; }
      }
      expect(london).assertEqual('12:00');
      expect(newYork).assertEqual('07:00');
    });

    it('工作时段标记：北京 20:00 → 伦敦合理（12 点）、悉尼不合理（23 点）', 0, () => {
      const r = meetingTimes('20:00', 480);
      for (let i = 0; i < r.rows.length; i++) {
        if (r.rows[i].city.zh === '伦敦') {
          expect(r.rows[i].reasonable).assertEqual(true);
        }
        if (r.rows[i].city.zh === '悉尼') {
          expect(r.rows[i].reasonable).assertEqual(false);
        }
      }
    });

    it('城市表 8 个且名称唯一', 0, () => {
      const names = tzCityNames();
      expect(names.length).assertEqual(8);
      const seen = new Set<string>();
      for (let i = 0; i < names.length; i++) {
        expect(seen.has(names[i])).assertEqual(false);
        seen.add(names[i]);
      }
    });

    it('非法时刻报错：缺冒号、超范围', 0, () => {
      expect(meetingTimes('2000', 480).failure.code).assertEqual(TzFailureCode.BAD_TIME);
      expect(meetingTimes('25:00', 480).failure.code).assertEqual(TzFailureCode.BAD_TIME);
      expect(meetingTimes('12:60', 480).failure.code).assertEqual(TzFailureCode.BAD_TIME);
      expect(meetingTimes('', 480).failure.code).assertEqual(TzFailureCode.EMPTY_INPUT);
    });

    it('基准时区可换：伦敦 12:00 视角 = 北京 20:00', 0, () => {
      const r = meetingTimes('12:00', 0);
      for (let i = 0; i < r.rows.length; i++) {
        if (r.rows[i].city.zh === '北京') {
          expect(r.rows[i].timeText).assertEqual('20:00');
        }
      }
    });
  });
}
