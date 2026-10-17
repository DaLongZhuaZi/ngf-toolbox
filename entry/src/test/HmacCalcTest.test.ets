import { describe, expect, it } from '@ohos/hypium';
import {
  computeHmac,
  HmacAlgorithm,
  HmacFailureCode
} from '../main/ets/tools/hmac-calc/HmacCalc';

/**
 * HMAC 的单测：**RFC 2104 / 4231 的官方测试向量**。
 *
 * 这些期望值是标准文档里的，不是“算出来对比自己”——算法错了向量必挂。
 * 覆盖三个算法 + 长密钥（>64 字节先哈希）+ 边界。
 */
export default function hmacCalcTest() {
  describe('hmacCalcTest', () => {
    it('RFC 4231 用例 2：HMAC-SHA256(key=jefe, data=what do ya want)', 0, () => {
      const r = computeHmac(HmacAlgorithm.SHA256, 'what do ya want for nothing?', 'Jefe');
      expect(r.ok).assertEqual(true);
      expect(r.hex.toLowerCase()).assertEqual('5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843');
    });

    it('HMAC-MD5 已知向量（RFC 2202 用例 1）', 0, () => {
      const r = computeHmac(HmacAlgorithm.MD5, 'Hi There', String.fromCharCode(11).repeat(16));
      // RFC 2202 #1: 9294727a3638bb1c13f48ef8158bfc9d
      expect(r.hex.toLowerCase()).assertEqual('9294727a3638bb1c13f48ef8158bfc9d');
    });

    it('HMAC-SHA1 已知向量（RFC 2202 用例 1）', 0, () => {
      const r = computeHmac(HmacAlgorithm.SHA1, 'Hi There', String.fromCharCode(11).repeat(20));
      // RFC 2202 #1: b617318655057264e28bc0b6fb378c8ef146be00
      expect(r.hex.toLowerCase()).assertEqual('b617318655057264e28bc0b6fb378c8ef146be00');
    });

    it('HMAC-SHA256 短密钥已知向量（RFC 4231 用例 1）', 0, () => {
      const key: string = String.fromCharCode(11).repeat(20);
      const r = computeHmac(HmacAlgorithm.SHA256, 'Hi There', key);
      // RFC 4231 #1: b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7
      expect(r.hex.toLowerCase()).assertEqual('b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');
    });

    it('长密钥（>64 字节）先哈希再补零', 0, () => {
      const key: string = 'k'.repeat(100);
      const r = computeHmac(HmacAlgorithm.SHA256, 'm', key);
      expect(r.ok).assertEqual(true);
      expect(r.hex.length).assertEqual(64);
    });

    it('确定性：同输入两次结果一致', 0, () => {
      const a = computeHmac(HmacAlgorithm.SHA256, 'msg', 'key');
      const b = computeHmac(HmacAlgorithm.SHA256, 'msg', 'key');
      expect(a.hex).assertEqual(b.hex);
    });

    it('空消息与空密钥各自报错', 0, () => {
      expect(computeHmac(HmacAlgorithm.SHA256, '', 'k').failure.code)
        .assertEqual(HmacFailureCode.EMPTY_MESSAGE);
      expect(computeHmac(HmacAlgorithm.SHA256, 'm', '').failure.code)
        .assertEqual(HmacFailureCode.EMPTY_KEY);
    });
  });
}
