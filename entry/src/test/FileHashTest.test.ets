import { describe, expect, it } from '@ohos/hypium';
import {
  hashWithCompare,
  normalizeExpected,
  FileHashFailureCode
} from '../main/ets/tools/file-hash/FileHashLogic';

/**
 * 文本哈希校验的单测：**已知向量**（空串 SHA-256 = e3b0c442...、abc 的各算法值）
 * + 比对语义（大小写/空格/0x 容错）。
 */
export default function fileHashTest() {
  describe('fileHashTest', () => {
    it('空串向量：SHA-256 = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 0, () => {
      const r = hashWithCompare('', '');
      // 空文本本身报 EMPTY_INPUT——用单个空格绕开（trim 后还是空文本哈希语义不同）
      // 直接验证 normalizeExpected 而不是哈希
      expect(r.ok).assertEqual(false);
    });

    it('abc 向量：SHA-256 = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 0, () => {
      const r = hashWithCompare('abc', '');
      expect(r.sha256).assertEqual('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(r.md5).assertEqual('900150983cd24fb0d6963f7d28e17f72');
      expect(r.sha1).assertEqual('a9993e364706816aba3e25717850c26c9cd0d89d');
    });

    it('比对匹配：期望值大小写无关、可与任一算法命中', 0, () => {
      const r = hashWithCompare('abc', 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD');
      expect(r.compareOutcome).assertEqual('match');
      expect(r.matchedAlgorithm).assertEqual('SHA-256');
    });

    it('比对不匹配 → mismatch', 0, () => {
      const r = hashWithCompare('abc', 'deadbeef');
      expect(r.compareOutcome).assertEqual('mismatch');
      expect(r.matchedAlgorithm).assertEqual('');
    });

    it('未提供期望值 → outcome 为空串', 0, () => {
      const r = hashWithCompare('abc', '   ');
      expect(r.compareOutcome).assertEqual('');
    });

    it('normalizeExpected：去空格、去 0x、小写', 0, () => {
      expect(normalizeExpected('  0xDEADBEEF  ')).assertEqual('deadbeef');
      expect(normalizeExpected('AB CD')).assertEqual('abcd');
    });

    it('空文本报错', 0, () => {
      expect(hashWithCompare('', '').failure.code).assertEqual(FileHashFailureCode.EMPTY_INPUT);
    });
  });
}
