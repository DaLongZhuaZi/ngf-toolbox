import { describe, expect, it } from '@ohos/hypium';
import {
  buildEpochTable,
  buildEpochTableFromSeconds
} from '../main/ets/tools/epoch-table/EpochTable';

/**
 * Epoch 对照表的单测：**固定输入**（确定性——ms 由调用方传入）。
 */
export default function epochTableTest() {
  describe('epochTableTest', () => {
    it('已知毫秒值：1700000000000 → 秒 1700000000', 0, () => {
      const r = buildEpochTable(1700000000000);
      expect(r.rows[0].value).assertEqual('1700000000');
      expect(r.rows[1].value).assertEqual('1700000000000');
    });

    it('微秒 = 毫秒 × 1000（字符串拼接）', 0, () => {
      const r = buildEpochTable(1700000000000);
      expect(r.rows[2].value).assertEqual('1700000000000000');
    });

    it('天与小时换算：1700000000 秒 ≈ 19675 天', 0, () => {
      const r = buildEpochTableFromSeconds(1700000000);
      const days = Math.floor(1700000000 / 86400);
      expect(r.rows[3].value).assertEqual(String(days));
    });

    it('round-trip：秒表转回毫秒表一致', 0, () => {
      const fromMs = buildEpochTable(1700000000000);
      const fromSec = buildEpochTableFromSeconds(1700000000);
      expect(fromMs.rows[0].value).assertEqual(fromSec.rows[0].value);
    });

    it('零值边界：ms=0 → 全 0', 0, () => {
      const r = buildEpochTable(0);
      expect(r.rows[0].value).assertEqual('0');
      expect(r.rows[3].value).assertEqual('0');
    });

    it('行数固定 5 行', 0, () => {
      expect(buildEpochTable(0).rows.length).assertEqual(5);
    });
  });
}
