import { describe, expect, it } from '@ohos/hypium';
import {
  generateMock,
  MockFailureCode,
  MockType
} from '../main/ets/tools/mock-data/MockDataLogic';
import { NGFRandomByteSource } from '../main/ets/tools/uuid-password/UuidPasswordLogic';

/**
 * 确定性伪随机源（宽周期双 LCG）。
 */
class FixedSource extends NGFRandomByteSource {
  private s1: number = 12345;
  private s2: number = 67890;

  nextBytes(count: number): Uint8Array {
    const out: Uint8Array = new Uint8Array(count);
    for (let i = 0; i < count; i++) {
      this.s1 = (this.s1 * 1103515245 + 12345) % 2147483647;
      this.s2 = (this.s2 * 48271) % 2147483647;
      out[i] = (this.s1 ^ this.s2) % 256;
    }
    return out;
  }
}

/**
 * 假数据生成的单测：**格式断言**（姓名/手机号/邮箱的结构）与边界。
 */
export default function mockDataTest() {
  describe('mockDataTest', () => {
    it('中文姓名：2-3 字且姓氏在表内', 0, () => {
      const r = generateMock(new FixedSource(), MockType.NAME, '20');
      expect(r.ok).assertEqual(true);
      expect(r.values.length).assertEqual(20);
      const surnames: string = '王李张刘陈杨赵黄周吴徐孙马朱胡郭何林罗高郑梁谢宋唐许韩冯邓曹彭曾';
      for (let i = 0; i < r.values.length; i++) {
        expect(r.values[i].length >= 2 && r.values[i].length <= 3).assertEqual(true);
        expect(surnames.indexOf(r.values[i].charAt(0)) >= 0).assertEqual(true);
      }
    });

    it('手机号：11 位且号段前缀合法', 0, () => {
      const r = generateMock(new FixedSource(), MockType.PHONE, '15');
      expect(r.values.length).assertEqual(15);
      const prefixes: string = '138,139,150,151,152,157,158,159,166,170,176,177,178,180,181,182,185,186,187,188,189,198,199';
      for (let i = 0; i < r.values.length; i++) {
        expect(r.values[i].length).assertEqual(11);
        expect(prefixes.indexOf(r.values[i].substring(0, 3)) >= 0).assertEqual(true);
      }
    });

    it('邮箱：@ 前后都有内容且域是保留域', 0, () => {
      const r = generateMock(new FixedSource(), MockType.EMAIL, '10');
      for (let i = 0; i < r.values.length; i++) {
        const at: number = r.values[i].indexOf('@');
        expect(at > 0).assertEqual(true);
        const domain: string = r.values[i].substring(at + 1);
        expect(domain === 'example.com' || domain === 'test.example.com' ||
          domain === 'demo.example.com').assertEqual(true);
      }
    });

    it('count 边界：0、负数、超 200、非数字全部报错', 0, () => {
      expect(generateMock(new FixedSource(), MockType.NAME, '0').failure.code)
        .assertEqual(MockFailureCode.COUNT_INVALID);
      expect(generateMock(new FixedSource(), MockType.NAME, '-5').failure.code)
        .assertEqual(MockFailureCode.COUNT_INVALID);
      expect(generateMock(new FixedSource(), MockType.NAME, '201').failure.code)
        .assertEqual(MockFailureCode.COUNT_INVALID);
      expect(generateMock(new FixedSource(), MockType.NAME, 'abc').failure.code)
        .assertEqual(MockFailureCode.COUNT_INVALID);
    });

    it('上限 200 恰好可生成', 0, () => {
      const r = generateMock(new FixedSource(), MockType.PHONE, '200');
      expect(r.values.length).assertEqual(200);
    });
  });
}
