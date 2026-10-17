/**
 * 摘要算法的**交叉验证**：把工具箱自己实现的哈希与 Node 的 crypto 对拍。
 *
 * ## 为什么需要它（而 hypium 单测还不够）
 *
 * `entry/src/test/DigestTest.test.ets` 里的期望值是**人写下来的常量**
 * （例如空串的 MD5 = d41d8cd9...）。如果写常量时抄错了，
 * 实现和测试就一起错，测试仍然全绿——这类「同源错误」是摘要类工具最大的风险，
 * 而它偏偏是安全相关工具，报出一个错误的指纹会直接误导用户。
 *
 * 这里换一个**独立来源**做裁判：Node 内置的 crypto（OpenSSL 实现）。
 * 两边算法完全独立实现，同时出错的概率可以忽略。
 *
 * ## 额外覆盖
 *
 * 刻意选了一组长度落在**分组填充边界**上的输入（55/56/64/119/120 字节）。
 * 哈希实现最容易错的地方就是「消息长度刚好卡在分组末尾」时的补齐与长度字段，
 * 而这类 bug 在常规短文本上完全看不出来。
 *
 * 用法：node --import ./tools/verify/register.mjs tools/verify/cross-verify-hash.mjs
 * 退出码 0 = 全部一致。
 */

import { createHash } from 'node:crypto';
import { digestHexOfText, NGFDigestAlgorithm } from '../../entry/src/main/ets/tools/digest/DigestAlgorithms';

/** 待验证的输入：常规样例 + 分组边界长度 */
const SAMPLES = [
  '',
  'abc',
  'hello',
  'The quick brown fox jumps over the lazy dog',
  '中文与 emoji 🎉',
  // 分组填充边界：MD5/SHA-1/SHA-256 的分组是 64 字节，SHA-512 是 128 字节。
  // 55/56 卡在「长度字段能否塞进当前分组」，119/120 是 128 字节分组的同一个边界。
  'a'.repeat(55),
  'a'.repeat(56),
  'a'.repeat(63),
  'a'.repeat(64),
  'a'.repeat(119),
  'a'.repeat(120),
  'a'.repeat(127),
  'a'.repeat(128),
  'a'.repeat(1000)
];

/** 待验证的算法：工具箱枚举 ←→ Node 算法名 */
const PAIRS = [
  { algorithm: NGFDigestAlgorithm.MD5, nodeName: 'md5' },
  { algorithm: NGFDigestAlgorithm.SHA1, nodeName: 'sha1' },
  { algorithm: NGFDigestAlgorithm.SHA256, nodeName: 'sha256' },
  { algorithm: NGFDigestAlgorithm.SHA512, nodeName: 'sha512' }
];

let checked = 0;
const mismatches = [];

for (const pair of PAIRS) {
  for (const sample of SAMPLES) {
    const expected = createHash(pair.nodeName).update(Buffer.from(sample, 'utf8')).digest('hex');
    let actual = '';
    try {
      actual = digestHexOfText(pair.algorithm, sample);
    } catch (error) {
      actual = 'THREW: ' + (error && error.message ? error.message : String(error));
    }
    checked += 1;
    if (String(actual).toLowerCase() !== expected) {
      mismatches.push({
        algorithm: pair.nodeName,
        length: sample.length,
        actual,
        expected
      });
    }
  }
  console.log('  ' + pair.nodeName + ' 比对完成（' + SAMPLES.length + ' 组）');
}

console.log('');
console.log('共比对 ' + checked + ' 组，不一致 ' + mismatches.length + ' 组');
for (const item of mismatches) {
  console.log('  ✗ ' + item.algorithm + ' 输入长度=' + item.length);
  console.log('      实际: ' + item.actual);
  console.log('      期望: ' + item.expected);
}
process.exitCode = mismatches.length === 0 ? 0 : 1;
