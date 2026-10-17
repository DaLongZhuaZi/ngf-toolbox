import { describe, expect, it } from '@ohos/hypium';
import {
  compareSemver,
  parseSemver,
  SemverFailureCode
} from '../main/ets/tools/semver-parse/SemverLogic';

/**
 * SemVer 解析的单测：**规范文档的经典例子**。
 * 比较链：1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta <
 *         1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
 */
export default function semverParseTest() {
  describe('semverParseTest', () => {
    it('基本解析：2.13.7 → major/minor/patch', 0, () => {
      const r = parseSemver('2.13.7');
      expect(r.ok).assertEqual(true);
      expect(r.major).assertEqual(2);
      expect(r.minor).assertEqual(13);
      expect(r.patch).assertEqual(7);
      expect(r.normalized).assertEqual('2.13.7');
    });

    it('v 前缀容错与先行版本/构建元数据拆解', 0, () => {
      const r = parseSemver('v1.0.0-alpha.1+build.5');
      expect(r.ok).assertEqual(true);
      expect(r.prerelease).assertEqual('alpha.1');
      expect(r.build).assertEqual('build.5');
      expect(r.normalized).assertEqual('1.0.0-alpha.1');
    });

    it('非法输入：缺段、非数字、坏标识符', 0, () => {
      expect(parseSemver('1.2').failure.code).assertEqual(SemverFailureCode.BAD_FORMAT);
      expect(parseSemver('1.2.x').failure.code).assertEqual(SemverFailureCode.BAD_FORMAT);
      expect(parseSemver('1.2.3-阿尔法').failure.code).assertEqual(SemverFailureCode.BAD_FORMAT);
      // 1.2.3-- 的先行版本是合法标识符（连字符在字符集内），不报错
      expect(parseSemver('').failure.code).assertEqual(SemverFailureCode.EMPTY_INPUT);
    });

    it('正式版 > 先行版', 0, () => {
      const rel = parseSemver('1.0.0');
      const pre = parseSemver('1.0.0-rc.1');
      expect(compareSemver(pre, rel) < 0).assertEqual(true);
      expect(compareSemver(rel, pre) > 0).assertEqual(true);
    });

    it('规范比较链：alpha < alpha.1 < alpha.beta < beta < beta.2 < beta.11 < rc.1 < 1.0.0', 0, () => {
      const chain: Array<string> = ['1.0.0-alpha', '1.0.0-alpha.1', '1.0.0-alpha.beta',
        '1.0.0-beta', '1.0.0-beta.2', '1.0.0-beta.11', '1.0.0-rc.1', '1.0.0'];
      for (let i = 1; i < chain.length; i++) {
        const a = parseSemver(chain[i - 1]);
        const b = parseSemver(chain[i]);
        expect(compareSemver(a, b) < 0).assertEqual(true);
      }
    });

    it('数字标识符按数值比较：beta.11 > beta.2（不是字典序）', 0, () => {
      const a = parseSemver('1.0.0-beta.11');
      const b = parseSemver('1.0.0-beta.2');
      expect(compareSemver(a, b) > 0).assertEqual(true);
    });

    it('相同版本返回 0（构建元数据不参与比较）', 0, () => {
      const a = parseSemver('1.2.3+build.1');
      const b = parseSemver('1.2.3+build.999');
      expect(compareSemver(a, b)).assertEqual(0);
    });
  });
}
