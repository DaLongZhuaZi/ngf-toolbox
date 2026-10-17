import { describe, expect, it } from '@ohos/hypium';
import { NGFRandomByteSource, UuidBatchFailure } from '../main/ets/tools/uuid-password/UuidPasswordLogic';
import { generateUuidBatchChecked } from '../main/ets/tools/uuid-batch/UuidBatchLogic';

/**
 * UUID 批量生成的单测（uuid-batch 工具复用本模块——确定性伪随机源）。
 */
class FixedSource extends NGFRandomByteSource {
  private counter: number = 0;
  private seed2: number = 12345;

  nextBytes(count: number): Uint8Array {
    const out: Uint8Array = new Uint8Array(count);
    for (let i = 0; i < count; i++) {
      this.counter = (this.counter * 1103515245 + 12345) % 2147483647;
      this.seed2 = (this.seed2 * 48271) % 2147483647;
      out[i] = (this.counter ^ this.seed2) % 256;
    }
    return out;
  }
}

export default function uuidBatchTest() {
  describe('uuidBatchTest', () => {
    it('批量 10 条全部合法且互不相同', 0, () => {
      const r = generateUuidBatchChecked(new FixedSource(), 10, false, true);
      expect(r.ok).assertEqual(true);
      expect(r.result.uuids.length).assertEqual(10);
      const seen = new Set<string>();
      for (let i = 0; i < r.result.uuids.length; i++) {
        expect(seen.has(r.result.uuids[i])).assertEqual(false);
        seen.add(r.result.uuids[i]);
      }
      expect(r.duplicates.length).assertEqual(0);
    });

    it('count=0 与负数报错', 0, () => {
      expect(generateUuidBatchChecked(new FixedSource(), 0, false, true).result.failure)
        .assertEqual(UuidBatchFailure.COUNT_TOO_SMALL);
      expect(generateUuidBatchChecked(new FixedSource(), -1, false, true).result.failure)
        .assertEqual(UuidBatchFailure.COUNT_TOO_SMALL);
    });

    it('非整数报错', 0, () => {
      expect(generateUuidBatchChecked(new FixedSource(), 2.5, false, true).result.failure)
        .assertEqual(UuidBatchFailure.COUNT_NOT_INTEGER);
    });

    it('大写与连字符选项生效', 0, () => {
      const r = generateUuidBatchChecked(new FixedSource(), 3, true, false);
      expect(r.result.uuids[0].indexOf('-')).assertEqual(-1);
      expect(r.result.uuids[0] === r.result.uuids[0].toUpperCase()).assertEqual(true);
    });
  });
}
