import { describe, expect, it } from '@ohos/hypium';
import {
  compareFingerprint,
  DigestCompareCode,
  digestAllOfText,
  digestHexByLabel,
  digestHexOfText,
  groupHex,
  isHexFingerprint,
  normalizeFingerprint,
  NGFDigestAlgorithm,
  NGFDigestResult,
  NGFFingerprintCompareResult
} from '../main/ets/tools/digest/DigestAlgorithms';

/**
 * 摘要计算的纯逻辑单测。
 *
 * 期望值全部来自**独立参考实现**（Node/OpenSSL 的 crypto），不是「跑一遍记下来」：
 * 标准空串与 'abc' 向量是公开已知答案，中英文/emoji/长文本向量由参考实现算出后写死。
 * 这样只要本地实现有任何一位算错，这里就会红——而摘要算法恰恰是「错一位也看不出来」的典型。
 */
export default function digestTest() {
  describe('digestTest', () => {
    it('四种算法的空串摘要必须等于标准值(防常量表/填充写错)', 0, () => {
      expect(digestHexByLabel('MD5', '')).assertEqual('d41d8cd98f00b204e9800998ecf8427e');
      expect(digestHexByLabel('SHA-1', '')).assertEqual('da39a3ee5e6b4b0d3255bfef95601890afd80709');
      expect(digestHexByLabel('SHA-256', '')).assertEqual(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(digestHexByLabel('SHA-512', '')).assertEqual(
        'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce'
        + '47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e');
    });

    it("'abc' 摘要必须等于公开测试向量(防轮函数/消息扩展写错)", 0, () => {
      expect(digestHexByLabel('MD5', 'abc')).assertEqual('900150983cd24fb0d6963f7d28e17f72');
      expect(digestHexByLabel('SHA-1', 'abc')).assertEqual('a9993e364706816aba3e25717850c26c9cd0d89d');
      expect(digestHexByLabel('SHA-256', 'abc')).assertEqual(
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(digestHexByLabel('SHA-512', 'abc')).assertEqual(
        'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a'
        + '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f');
    });

    it('中文按 UTF-8 计算(防按 UTF-16/Latin-1 编码导致中文摘要错)', 0, () => {
      expect(digestHexByLabel('MD5', '中文')).assertEqual('a7bac2239fcdcb3a067903d8077c4a07');
      expect(digestHexByLabel('SHA-1', '中文')).assertEqual('7be2d2d20c106eee0836c9bc2b939890a78e8fb3');
      expect(digestHexByLabel('SHA-256', '中文')).assertEqual(
        '72726d8818f693066ceb69afa364218b692e62ea92b385782363780f47529c21');
    });

    it('emoji(代理对)必须合成一个码点再编码(防只算半个代理)', 0, () => {
      expect(digestHexByLabel('MD5', '😀')).assertEqual('2a02eac39d716a70ecf37579185927b6');
      expect(digestHexByLabel('SHA-256', '😀')).assertEqual(
        'f0443a342c5ef54783a111b51ba56c938e474c32324d90c3a60c9c8e3a37e2d9');
      expect(digestHexByLabel('SHA-512', '😀')).assertEqual(
        '9b1ce8b6649e678e1cb7bca85afeaae750add5cfb0668d25ebba5e7f0038f1b6'
        + 'bdcc4bacd909049e752be2a3a3c0158c0f2bb5a33d8101b2ed5d74a66ece2425');
    });

    it('中文与 emoji 混排仍要稳定(防多字节与代理对交叉出错)', 0, () => {
      expect(digestHexByLabel('MD5', '摘要😀混合')).assertEqual('86cc6dae256e3a9a2c038cd57bc29920');
      expect(digestHexByLabel('SHA-256', '摘要😀混合')).assertEqual(
        '49fca29a4bb28398702ed9438f05c3963a9d36b61fda1e3f107c5fc0a3af9079');
    });

    it('56 字节输入落在补位边界上(防补位长度算错)', 0, () => {
      expect(digestHexByLabel('MD5', 'a'.repeat(56))).assertEqual('3b0c8ac703f828b04c6c197006d17218');
      expect(digestHexByLabel('SHA-256', 'a'.repeat(56))).assertEqual(
        'b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a');
      expect(digestHexByLabel('SHA-512', 'a'.repeat(56))).assertEqual(
        '962b64aae357d2a4fee3ded8b539bdc9d325081822b0bfc55583133aab44f18b'
        + 'afe11d72a7ae16c79ce2ba620ae2242d5144809161945f1367f41b3972e26e04');
    });

    it('64 字节整块输入(防末块处理与长度字段写错)', 0, () => {
      expect(digestHexByLabel('MD5', 'a'.repeat(64))).assertEqual('014842d480b571495a4a0363793f7367');
      expect(digestHexByLabel('SHA-1', 'a'.repeat(64))).assertEqual('0098ba824b5c16427bd7a1122a5a442a25ec644d');
      expect(digestHexByLabel('SHA-512', 'a'.repeat(64))).assertEqual(
        '01d35c10c6c38c2dcf48f7eebb3235fb5ad74a65ec4cd016e2354c637a8fb49b'
        + '695ef3c1d6f7ae4cd74d78cc9c9bcac9d4f23a73019998a7f73038a5c9b2dbde');
    });

    it('10000 字符长文本不能算崩或截断(防只处理首块的实现)', 0, () => {
      const long: string = 'a'.repeat(10000);
      expect(digestHexByLabel('MD5', long)).assertEqual('0d0c9c4db6953fee9e03f528cafd7d3e');
      expect(digestHexByLabel('SHA-256', long)).assertEqual(
        '27dd1f61b867b6a0f6e9d8a41c43231de52107e53ae424de8f847b821db4b711');
      expect(digestHexByLabel('SHA-512', long)).assertEqual(
        '0593036f4f479d2eb8078ca26b1d59321a86bdfcb04cb40043694f1eb0301b8a'
        + 'cd20b936db3c916ebcc1b609400ffcf3fa8d569d7e39293855668645094baf0e');
    });

    it('digestAllOfText 固定返回四种算法且长度正确(防界面少算一种)', 0, () => {
      const results: NGFDigestResult[] = digestAllOfText('abc');
      expect(results.length).assertEqual(4);
      expect(results[0].label).assertEqual('MD5');
      expect(results[1].label).assertEqual('SHA-1');
      expect(results[2].label).assertEqual('SHA-256');
      expect(results[3].label).assertEqual('SHA-512');
      expect(results[0].hex.length).assertEqual(32);
      expect(results[1].hex.length).assertEqual(40);
      expect(results[2].hex.length).assertEqual(64);
      expect(results[3].hex.length).assertEqual(128);
    });

    it('未知算法名返回空串而不是抛异常(防界面崩页)', 0, () => {
      expect(digestHexByLabel('SHA-3', 'abc')).assertEqual('');
      expect(digestHexByLabel('', 'abc')).assertEqual('');
      expect(digestHexOfText(NGFDigestAlgorithm.SHA256, 'abc')).assertEqual(
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });

    it('normalizeFingerprint 去掉空白/冒号/连字符并小写化', 0, () => {
      expect(normalizeFingerprint(' D41D8CD9 8F00B204 ')).assertEqual('d41d8cd98f00b204');
      expect(normalizeFingerprint('D4:1D\t8C\nD9-8F00B204')).assertEqual('d41d8cd98f00b204');
      expect(normalizeFingerprint('0xABCDEF')).assertEqual('abcdef');
      expect(normalizeFingerprint('   ')).assertEqual('');
    });

    it('isHexFingerprint 只接受纯十六进制(防把说明文字当成指纹)', 0, () => {
      expect(isHexFingerprint('d41d8cd98f00b204')).assertTrue();
      expect(isHexFingerprint('')).assertFalse();
      expect(isHexFingerprint('d41d8cdg')).assertFalse();
      expect(isHexFingerprint('摘要 d41d')).assertFalse();
    });

    it('groupHex 只插入分隔空格、不丢字符(防展示时截断摘要)', 0, () => {
      expect(groupHex('abcdefghij', 4)).assertEqual('abcd efgh ij');
      expect(groupHex('abc', 8)).assertEqual('abc');
      expect(groupHex('abcdefgh', 0)).assertEqual('abcdefgh');
      expect(groupHex('abcdefghij', 4).split(' ').join('')).assertEqual('abcdefghij');
    });

    it('指纹比对忽略大小写、空格与冒号分隔', 0, () => {
      const result: NGFFingerprintCompareResult = compareFingerprint(
        'D4:1D:8C:D9 8F:00:B2:04', 'd41d8cd98f00b204');
      expect(result.matched).assertTrue();
      expect(result.outcome.code).assertEqual(DigestCompareCode.MATCH);
      expect(result.expectedNormalized).assertEqual('d41d8cd98f00b204');
    });

    it('指纹比对：长度不同必须判不一致并提示可能选错算法', 0, () => {
      const result: NGFFingerprintCompareResult = compareFingerprint(
        '900150983cd24fb0d6963f7d28e17f72', 'a9993e364706816aba3e25717850c26c9cd0d89d');
      expect(result.matched).assertFalse();
      expect(result.expectedValid).assertTrue();
      expect(result.outcome.code).assertEqual(DigestCompareCode.LENGTH_MISMATCH);
      // 参数顺序必须与资源文案里的 %s 一致：期望位数在前、实际位数在后
      expect(result.outcome.args[0]).assertEqual('32');
      expect(result.outcome.args[1]).assertEqual('40');
    });

    it('指纹比对：非十六进制输入必须被识别为非法而不是判「一致」', 0, () => {
      const result: NGFFingerprintCompareResult = compareFingerprint('md5 值待补', 'd41d8cd98f00b204');
      expect(result.matched).assertFalse();
      expect(result.expectedValid).assertFalse();
      expect(result.outcome.code).assertEqual(DigestCompareCode.NON_HEX);
    });

    it('指纹比对：两边都空时给出提示且不判一致(防误报成功)', 0, () => {
      const emptyExpected: NGFFingerprintCompareResult = compareFingerprint('', 'd41d8cd98f00b204');
      expect(emptyExpected.matched).assertFalse();
      expect(emptyExpected.outcome.code).assertEqual(DigestCompareCode.EMPTY_EXPECTED);
      const emptyActual: NGFFingerprintCompareResult = compareFingerprint('d41d8cd98f00b204', '');
      expect(emptyActual.matched).assertFalse();
      expect(emptyActual.outcome.code).assertEqual(DigestCompareCode.NO_ACTUAL);
    });

    it('指纹比对：等长但不同必须报不一致', 0, () => {
      const result: NGFFingerprintCompareResult = compareFingerprint(
        'd41d8cd98f00b204e9800998ecf8427e', 'd41d8cd98f00b204e9800998ecf8427f');
      expect(result.matched).assertFalse();
      expect(result.outcome.code).assertEqual(DigestCompareCode.MISMATCH);
    });
  });
}