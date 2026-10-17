import { describe, expect, it } from '@ohos/hypium';
import {
  analyzeBase64Image,
  ImgB64FailureCode
} from '../main/ets/tools/img-base64/ImgBase64Logic';

/**
 * Base64 图片的单测：**已知 Base64 向量**（1x1 PNG 前缀 iVBOR…）+ 体积估算。
 */
export default function imgBase64Test() {
  describe('imgBase64Test', () => {
    it('PNG data URI：MIME 解析 + dataUri 规范化', 0, () => {
      // 1x1 透明 PNG 的完整 Base64（标准向量）
      const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      const r = analyzeBase64Image('data:image/png;base64,' + png);
      expect(r.ok).assertEqual(true);
      expect(r.mime).assertEqual('image/png');
      expect(r.dataUri).assertEqual('data:image/png;base64,' + png);
    });

    it('裸 Base64 魔数猜 MIME：iVBOR → png、/9j/ → jpeg', 0, () => {
      const r1 = analyzeBase64Image('iVBORw0KGgo=');
      expect(r1.mime).assertEqual('image/png');
      const r2 = analyzeBase64Image('/9j/4AAQ');
      expect(r2.mime).assertEqual('image/jpeg');
    });

    it('体积估算：4 字符 Base64 = 3 字节', 0, () => {
      // 'QUJD' 是 'ABC' 的 Base64（3 字节）
      const r = analyzeBase64Image('QUJD');
      expect(r.originalBytes).assertEqual(3);
      expect(r.base64Length).assertEqual(4);
    });

    it('填充修正：1 个 = 减 1 字符、2 个 = 减 2', 0, () => {
      // 'QQ==' 是 'A'（1 字节）
      const r = analyzeBase64Image('QQ==');
      expect(r.originalBytes).assertEqual(1);
      // 'QUI=' 是 'AB'（2 字节）
      const r2 = analyzeBase64Image('QUI=');
      expect(r2.originalBytes).assertEqual(2);
    });

    it('非法字符报错', 0, () => {
      expect(analyzeBase64Image('!!!!').failure.code).assertEqual(ImgB64FailureCode.BAD_BASE64);
      expect(analyzeBase64Image('data:image/png;base64,').failure.code)
        .assertEqual(ImgB64FailureCode.BAD_BASE64);
    });

    it('空输入报错', 0, () => {
      expect(analyzeBase64Image('').failure.code).assertEqual(ImgB64FailureCode.EMPTY_INPUT);
    });
  });
}
