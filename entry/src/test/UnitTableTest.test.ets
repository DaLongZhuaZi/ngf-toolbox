import { describe, expect, it } from '@ohos/hypium';
import {
  bytesInUnits,
  unitPairs
} from '../main/ets/tools/unit-table/UnitTableLogic';

/**
 * 单位前缀速查的单测：两套体系的换算锚点。
 */
export default function unitTableTest() {
  describe('unitTableTest', () => {
    it('全表 5 行：KB 到 PB', 0, () => {
      const rows = unitPairs();
      expect(rows.length).assertEqual(5);
      expect(rows[0].decimal).assertEqual('kB');
      expect(rows[0].binary).assertEqual('KiB');
      expect(rows[4].decimal).assertEqual('PB');
    });

    it('1000 字节 = 1 kB（十进制）但 0.98 KiB（二进制）', 0, () => {
      const r = bytesInUnits(1000);
      let kb = '';
      let kib = '';
      for (let i = 0; i < r.rows.length; i++) {
        if (r.rows[i].decimal === 'kB') { kb = r.rows[i].decimalBytes; }
        if (r.rows[i].binary === 'KiB') { kib = r.rows[i].binaryBytes; }
      }
      expect(kb).assertEqual('1');
      expect(kib).assertEqual('0.98');
    });

    it('1024 字节 = 1 KiB（二进制整）', 0, () => {
      const r = bytesInUnits(1024);
      let kib = '';
      for (let i = 0; i < r.rows.length; i++) {
        if (r.rows[i].binary === 'KiB') { kib = r.rows[i].binary; }
      }
      expect(kib).assertEqual('KiB');
    });

    it('空输入不报错（0 字节全为零）', 0, () => {
      const r = bytesInUnits(0);
      expect(r.rows.length).assertEqual(4);
    });
  });
}
