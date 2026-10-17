import { describe, expect, it } from '@ohos/hypium';
import {
  BITWISE_WIDTH,
  bitwiseOperation,
  convertDigits,
  convertRadix,
  isValidRadix,
  NGFBitwiseOperation,
  parseRadixValue,
  RADIX_MAX,
  RADIX_MIN,
  radixPrefix,
  RadixConvertResult,
  RadixFailure,
  RadixFailureCode,
  RadixValue
} from '../main/ets/tools/radix-convert/RadixConvert';

/**
 * 进制转换与位运算的纯逻辑单测。
 *
 * 重点在两处最容易出错、又最难肉眼发现的地方：
 * 1. **大数**：超过 2^53 之后 Number 会静默丢精度，所以断言必须用「多位数字的字面量」而不是算出来的数；
 * 2. **位运算的符号与字宽**：64 位有符号语义下，`-1 & 255` 是 255、`~0` 是 -1，
 *    写错符号位处理会得到"看起来也说得通"的错答案。
 */
export default function radixConvertTest() {
  describe('radixConvertTest', () => {
    it('2/8/10/16 互转的常规路径', 0, () => {
      expect(convertRadix('255', 10, 16).digits).assertEqual('ff');
      expect(convertRadix('255', 10, 2).digits).assertEqual('11111111');
      expect(convertRadix('255', 10, 8).digits).assertEqual('377');
      expect(convertRadix('ff', 16, 10).digits).assertEqual('255');
      expect(convertRadix('1010', 2, 10).digits).assertEqual('10');
      expect(convertRadix('377', 8, 16).digits).assertEqual('ff');
    });

    it('任意进制(2-36)都能互转，最大进制用满 0-9a-z', 0, () => {
      expect(convertRadix('1295', 10, 36).digits).assertEqual('zz');
      expect(convertRadix('zz', 36, 10).digits).assertEqual('1295');
      expect(convertRadix('100', 36, 10).digits).assertEqual('1296');
      expect(convertRadix('35', 10, 36).digits).assertEqual('z');
      expect(convertDigits('0', 10, 16)).assertEqual('0');
    });

    it('超出 2^53 的大数必须精确(防用 Number 丢精度)', 0, () => {
      // 2^64 = 18446744073709551616，用 Number 表示会变成 18446744073709552000
      expect(convertRadix('18446744073709551616', 10, 16).digits).assertEqual('10000000000000000');
      expect(convertRadix('10000000000000000', 16, 10).digits).assertEqual('18446744073709551616');
      expect(convertRadix('99999999999999999999999999', 10, 16).digits).assertEqual('52b7d2dcc80cd2e3ffffff');
    });

    it('负号保留，零的负号要被消掉(防 -0 这种输出)', 0, () => {
      const negative: RadixConvertResult = convertRadix('-255', 10, 16);
      expect(negative.ok).assertTrue();
      expect(negative.negative).assertTrue();
      expect(negative.digits).assertEqual('ff');
      expect(negative.prefixed).assertEqual('-0xff');
      const zero: RadixConvertResult = convertRadix('-0', 10, 16);
      expect(zero.negative).assertFalse();
      expect(zero.digits).assertEqual('0');
      const plus: RadixConvertResult = convertRadix('+255', 10, 16);
      expect(plus.negative).assertFalse();
    });

    it('前导零与十六进制大小写都要接受', 0, () => {
      expect(convertRadix('000ff', 16, 10).digits).assertEqual('255');
      expect(convertRadix('FF', 16, 10).digits).assertEqual('255');
      expect(convertRadix('0xFF', 16, 10).digits).assertEqual('255');
      expect(convertRadix('0XFF', 16, 10).digits).assertEqual('255');
      expect(convertRadix('0b1111', 2, 10).digits).assertEqual('15');
      expect(convertRadix('0o17', 8, 10).digits).assertEqual('15');
    });

    it('下划线与空格分隔的粘贴习惯要能吃掉', 0, () => {
      expect(convertRadix('1 000', 10, 16).digits).assertEqual('3e8');
      expect(convertRadix('1_000', 10, 16).digits).assertEqual('3e8');
      expect(convertRadix('1111 0000', 2, 16).digits).assertEqual('f0');
    });

    it('非法字符要指出是哪个字符(防静默算出别的数)', 0, () => {
      const bad: RadixConvertResult = convertRadix('12g', 16, 10);
      expect(bad.ok).assertFalse();
      expect(bad.failure.code).assertEqual(RadixFailureCode.INVALID_DIGIT);
      expect(bad.failure.args[0]).assertEqual('g');
      const chinese: RadixConvertResult = convertRadix('12进', 10, 16);
      expect(chinese.ok).assertFalse();
      expect(chinese.failure.code).assertEqual(RadixFailureCode.INVALID_DIGIT);
      expect(chinese.failure.args[0]).assertEqual('进');
    });

    it('空串与纯分隔符都要报错', 0, () => {
      expect(convertRadix('', 10, 16).ok).assertFalse();
      expect(convertRadix('   ', 10, 16).ok).assertFalse();
      expect(convertRadix('___', 10, 16).ok).assertFalse();
      expect(convertRadix('  ', 10, 16).failure.code).assertEqual(RadixFailureCode.EMPTY_INPUT);
    });

    it('进制越界(含非整数)必须拒绝', 0, () => {
      expect(isValidRadix(RADIX_MIN)).assertTrue();
      expect(isValidRadix(RADIX_MAX)).assertTrue();
      expect(isValidRadix(RADIX_MIN - 1)).assertFalse();
      expect(isValidRadix(RADIX_MAX + 1)).assertFalse();
      expect(isValidRadix(2.5)).assertFalse();
      expect(isValidRadix(NaN)).assertFalse();
      expect(convertRadix('10', 1, 10).ok).assertFalse();
      expect(convertRadix('10', 10, 37).ok).assertFalse();
      expect(convertRadix('10', 37, 10).failure.code).assertEqual(RadixFailureCode.RADIX_OUT_OF_RANGE);
    });

    it('前缀只在进制匹配时剥离，否则按非法字符处理', 0, () => {
      const mismatch: RadixConvertResult = convertRadix('0x1f', 10, 16);
      expect(mismatch.ok).assertFalse();
      expect(mismatch.failure.code).assertEqual(RadixFailureCode.INVALID_DIGIT);
      expect(mismatch.failure.args[0]).assertEqual('x');
    });

    it('radixPrefix 只给常见的三种进制加前缀', 0, () => {
      expect(radixPrefix(2)).assertEqual('0b');
      expect(radixPrefix(8)).assertEqual('0o');
      expect(radixPrefix(16)).assertEqual('0x');
      expect(radixPrefix(10)).assertEqual('');
      expect(radixPrefix(36)).assertEqual('');
    });

    it('parseRadixValue 暴露符号与规范化后的数字串', 0, () => {
      const parsed: RadixValue = parseRadixValue(' -00FF ', 16);
      expect(parsed.ok).assertTrue();
      expect(parsed.negative).assertTrue();
      expect(parsed.digits).assertEqual('ff');
      expect(parsed.radix).assertEqual(16);
    });

    it('位运算 AND / OR / XOR 的基本行为', 0, () => {
      expect(bitwiseOperation('0f', 'f0', NGFBitwiseOperation.AND, 16, 0).digits).assertEqual('0');
      expect(bitwiseOperation('0f', 'f0', NGFBitwiseOperation.OR, 16, 0).digits).assertEqual('ff');
      expect(bitwiseOperation('0f', 'ff', NGFBitwiseOperation.XOR, 16, 0).digits).assertEqual('f0');
      // 12 & 10 = 1100b & 1010b = 1000b = 8
      expect(bitwiseOperation('12', '10', NGFBitwiseOperation.AND, 10, 0).digits).assertEqual('8');
    });

    it('负数参与位运算按 64 位补码语义(防按幅值算)', 0, () => {
      const and: RadixConvertResult = bitwiseOperation('-1', '255', NGFBitwiseOperation.AND, 10, 0);
      expect(and.negative).assertFalse();
      expect(and.digits).assertEqual('255');
      const xor: RadixConvertResult = bitwiseOperation('-1', '0', NGFBitwiseOperation.XOR, 10, 0);
      expect(xor.negative).assertTrue();
      expect(xor.digits).assertEqual('1');
      const or: RadixConvertResult = bitwiseOperation('-2', '1', NGFBitwiseOperation.OR, 10, 0);
      expect(or.negative).assertTrue();
      expect(or.digits).assertEqual('1');
    });

    it('取反按 64 位语义：~0 = -1，~-1 = 0', 0, () => {
      const zero: RadixConvertResult = bitwiseOperation('0', '', NGFBitwiseOperation.NOT, 10, 0);
      expect(zero.negative).assertTrue();
      expect(zero.digits).assertEqual('1');
      const minusOne: RadixConvertResult = bitwiseOperation('-1', '', NGFBitwiseOperation.NOT, 10, 0);
      expect(minusOne.negative).assertFalse();
      expect(minusOne.digits).assertEqual('0');
    });

    it('移位：左移补零、算术右移保留符号', 0, () => {
      expect(bitwiseOperation('1', '', NGFBitwiseOperation.SHIFT_LEFT, 10, 4).digits).assertEqual('16');
      expect(bitwiseOperation('-16', '', NGFBitwiseOperation.SHIFT_RIGHT, 10, 2).digits).assertEqual('4');
      expect(bitwiseOperation('-16', '', NGFBitwiseOperation.SHIFT_RIGHT, 10, 2).negative).assertTrue();
      expect(bitwiseOperation('1', '', NGFBitwiseOperation.SHIFT_RIGHT, 10, 1).digits).assertEqual('0');
      expect(bitwiseOperation('1', '', NGFBitwiseOperation.SHIFT_LEFT, 16, 63).digits).assertEqual('8000000000000000');
    });

    it('移位越界与非法运算名必须报错', 0, () => {
      const tooFar: RadixConvertResult = bitwiseOperation('1', '', NGFBitwiseOperation.SHIFT_LEFT, 10, BITWISE_WIDTH);
      expect(tooFar.ok).assertFalse();
      expect(tooFar.failure.code).assertEqual(RadixFailureCode.SHIFT_OUT_OF_RANGE);
      expect(tooFar.failure.args[0]).assertEqual('0');
      expect(bitwiseOperation('1', '', NGFBitwiseOperation.SHIFT_LEFT, 10, -1).ok).assertFalse();
      const unknown: RadixConvertResult = bitwiseOperation('1', '1', 'NAND', 10, 0);
      expect(unknown.ok).assertFalse();
      expect(unknown.failure.code).assertEqual(RadixFailureCode.UNSUPPORTED_OPERATION);
      expect(unknown.failure.args[0]).assertEqual('NAND');
    });

    it('超过 64 位的输入要被截断并标记出来(不能假装算对了)', 0, () => {
      const truncated: RadixConvertResult = bitwiseOperation('fffffffffffffffff', '0', NGFBitwiseOperation.AND, 16, 0);
      expect(truncated.ok).assertTrue();
      expect(truncated.truncated).assertTrue();
      expect(truncated.digits).assertEqual('0');
      const normal: RadixConvertResult = bitwiseOperation('ff', 'ff', NGFBitwiseOperation.AND, 16, 0);
      expect(normal.truncated).assertFalse();
      // 左移把有效位推出 64 位也要标记
      const overflow: RadixConvertResult = bitwiseOperation('1', '', NGFBitwiseOperation.SHIFT_LEFT, 16, 63);
      expect(overflow.truncated).assertFalse();
      const shifted: RadixConvertResult = bitwiseOperation('3', '', NGFBitwiseOperation.SHIFT_LEFT, 16, 63);
      expect(shifted.truncated).assertTrue();
    });

    it('位运算结果同样带前缀写法，便于直接粘贴', 0, () => {
      const result: RadixConvertResult = bitwiseOperation('f0', '0f', NGFBitwiseOperation.OR, 16, 0);
      expect(result.prefixed).assertEqual('0xff');
    });
  });
}