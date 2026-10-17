import { describe, expect, it } from '@ohos/hypium';
import {
  executeBitOp,
  flipBit,
  parseBitInput,
  toBitPanel,
  BitOp,
  BitOpsFailureCode
} from '../main/ets/tools/bit-ops/BitOps';

/**
 * 32 位位运算的单测。
 *
 * 断言基准是「数学事实」而非实现：AND/OR/XOR/移位用手算值；
 * 0xFFFFFFFF（超 2^31）这类会触发有符号溢出的值重点覆盖。
 */
export default function bitOpsTest() {
  describe('bitOpsTest', () => {
    it('parseBitInput：十进制与 0x 十六进制、非法输入', 0, () => {
      expect(parseBitInput('255')).assertEqual(255);
      expect(parseBitInput('0xff')).assertEqual(255);
      expect(parseBitInput('0XFF')).assertEqual(255);
      expect(parseBitInput('0x')).assertEqual(-1);
      expect(parseBitInput('abc')).assertEqual(-1);
      expect(parseBitInput('-5')).assertEqual(-1);
    });

    it('0xFFFFFFFF 归一：输入 4294967295 应为全 1 位面板', 0, () => {
      const bits = toBitPanel(4294967295);
      let ones = 0;
      for (let i = 0; i < 32; i++) {
        ones = ones + bits[i];
      }
      expect(ones).assertEqual(32);
    });

    it('AND：0xF0 与 0x0F = 0', 0, () => {
      const r = executeBitOp(BitOp.AND, '0xF0', '0x0F');
      expect(r.ok).assertEqual(true);
      expect(r.value).assertEqual(0);
    });

    it('OR：0xF0 或 0x0F = 0xFF', 0, () => {
      const r = executeBitOp(BitOp.OR, '0xF0', '0x0F');
      expect(r.value).assertEqual(255);
    });

    it('XOR：同值异或为 0；0xFF 异或 0x0F = 0xF0', 0, () => {
      expect(executeBitOp(BitOp.XOR, '255', '255').value).assertEqual(0);
      expect(executeBitOp(BitOp.XOR, '255', '15').value).assertEqual(240);
    });

    it('NOT：0 反转成 0xFFFFFFFF（有符号溢出重点）', 0, () => {
      const r = executeBitOp(BitOp.NOT, '0', '');
      expect(r.ok).assertEqual(true);
      expect(r.value).assertEqual(4294967295);
      expect(r.bits[0]).assertEqual(1);
    });

    it('移位：1 << 31 = 0x80000000（超 2^31 的值）', 0, () => {
      const r = executeBitOp(BitOp.SHL, '1', '31');
      expect(r.ok).assertEqual(true);
      expect(r.value).assertEqual(2147483648);
      expect(r.bits[0]).assertEqual(1);
    });

    it('右移：0x80000000 >> 31 = 1', 0, () => {
      const r = executeBitOp(BitOp.SHR, '2147483648', '31');
      expect(r.value).assertEqual(1);
    });

    it('移位量越界（32、负数）报错', 0, () => {
      expect(executeBitOp(BitOp.SHL, '1', '32').failure.code)
        .assertEqual(BitOpsFailureCode.SHIFT_OUT_OF_RANGE);
      expect(executeBitOp(BitOp.SHR, '1', '-1').failure.code)
        .assertEqual(BitOpsFailureCode.SHIFT_OUT_OF_RANGE);
    });

    it('flipBit：翻转 bit0 与 bit31', 0, () => {
      expect(flipBit(0, 0)).assertEqual(1);
      expect(flipBit(0, 31)).assertEqual(2147483648);
      // 再翻回来
      expect(flipBit(flipBit(5, 2), 2)).assertEqual(5);
    });

    it('位面板与值互逆：随机几个值的往返', 0, () => {
      const values: Array<number> = [0, 1, 255, 256, 65535, 2147483648, 4294967295];
      for (let i = 0; i < values.length; i++) {
        const bits = toBitPanel(values[i]);
        // 由面板重建值
        let rebuilt: number = 0;
        for (let b = 0; b < 32; b++) {
          if (bits[31 - b] === 1) {
            rebuilt = rebuilt + Math.pow(2, b);
          }
        }
        expect(rebuilt).assertEqual(values[i]);
      }
    });

    it('空左操作数报错', 0, () => {
      expect(executeBitOp(BitOp.AND, '', '1').failure.code)
        .assertEqual(BitOpsFailureCode.EMPTY_LEFT);
    });
  });
}
