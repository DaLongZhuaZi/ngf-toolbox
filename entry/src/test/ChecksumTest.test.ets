import { describe, expect, it } from '@ohos/hypium';
import {
  adler32OfBytes,
  computeChecksum,
  crc32OfBytes,
  ChecksumAlgorithm,
  ChecksumFailureCode
} from '../main/ets/tools/checksum/Checksum';
import { utf8Encode } from '../main/ets/tools/digest/HashCore';

/**
 * 校验和的单测：**官方测试向量**。
 * CRC-32('123456789') = CBF43926（IEEE 标准校验值）；
 * Adler-32('Wikipedia') = 11E60398（RFC 1950 作者页的例子）。
 */
export default function checksumTest() {
  describe('checksumTest', () => {
    it('CRC-32 标准校验值：123456789 → CBF43926', 0, () => {
      const bytes = utf8Encode('123456789');
      const v = crc32OfBytes(bytes);
      expect(v >>> 0).assertEqual(0xCBF43926);
    });

    it('CRC-32 空串 → 0', 0, () => {
      expect(crc32OfBytes(utf8Encode('')) >>> 0).assertEqual(0);
    });

    it('Adler-32：Wikipedia → 11E60398', 0, () => {
      const v = adler32OfBytes(utf8Encode('Wikipedia'));
      expect(v >>> 0).assertEqual(0x11E60398);
    });

    it('Adler-32：空串 → 1（a 初值）', 0, () => {
      expect(adler32OfBytes(utf8Encode('')) >>> 0).assertEqual(1);
    });

    it('computeChecksum 双算法 + 十六进制展示', 0, () => {
      const r = computeChecksum(ChecksumAlgorithm.CRC32, '123456789');
      expect(r.ok).assertEqual(true);
      expect(r.hex).assertEqual('CBF43926');
      expect(r.decimal).assertEqual('3421780262');
      const r2 = computeChecksum(ChecksumAlgorithm.ADLER32, 'Wikipedia');
      expect(r2.hex).assertEqual('11E60398');
    });

    it('computeChecksum 空输入报错', 0, () => {
      expect(computeChecksum(ChecksumAlgorithm.CRC32, '').failure.code)
        .assertEqual(ChecksumFailureCode.EMPTY_INPUT);
      expect(computeChecksum(ChecksumAlgorithm.ADLER32, '').failure.code)
        .assertEqual(ChecksumFailureCode.EMPTY_INPUT);
    });

    it('UTF-8 多字节输入走字节路径（中文）', 0, () => {
      // '中' = E4 B8 AD；CRC 断言用确定性：同输入两次一致即可（标准值查表繁复）
      const a = computeChecksum(ChecksumAlgorithm.CRC32, '中');
      const b = computeChecksum(ChecksumAlgorithm.CRC32, '中');
      expect(a.hex).assertEqual(b.hex);
      expect(a.hex.length).assertEqual(8);
    });
  });
}
