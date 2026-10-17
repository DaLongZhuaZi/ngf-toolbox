import { describe, expect, it } from '@ohos/hypium';
import {
  generateChangelog,
  ChangelogFailureCode
} from '../main/ets/tools/changelog-gen/ChangelogLogic';

/**
 * Changelog 生成的单测：归类正确性 + 分节顺序 + Other 兜底。
 */
const LF = String.fromCharCode(10);

export default function changelogGenTest() {
  describe('changelogGenTest', () => {
    it('feat 排最前、fix 次之，subject 首字母大写', 0, () => {
      const r = generateChangelog('fix: login crash' + LF + 'feat: add dark mode toggle');
      expect(r.ok).assertEqual(true);
      const idxFeat = r.markdown.indexOf('### Features');
      const idxFix = r.markdown.indexOf('### Bug Fixes');
      expect(idxFeat >= 0 && idxFix > idxFeat).assertEqual(true);
      expect(r.markdown.indexOf('- Add dark mode toggle') >= 0).assertEqual(true);
      expect(r.classifiedCount).assertEqual(2);
    });

    it('scope 被拆除', 0, () => {
      const r = generateChangelog('feat(api): add search endpoint');
      expect(r.markdown.indexOf('- Add search endpoint') >= 0).assertEqual(true);
      expect(r.markdown.indexOf('api') < 0).assertEqual(true);
    });

    it('非规范行归 Other', 0, () => {
      const r = generateChangelog('feat: x' + LF + '随手写的提交' + LF + 'update stuff');
      expect(r.otherCount).assertEqual(2);
      expect(r.markdown.indexOf('### Other') >= 0).assertEqual(true);
      expect(r.markdown.indexOf('- 随手写的提交') >= 0).assertEqual(true);
    });

    it('未知 type 归 Other', 0, () => {
      const r = generateChangelog('custom: something');
      expect(r.otherCount).assertEqual(1);
      expect(r.classifiedCount).assertEqual(0);
    });

    it('空行被跳过', 0, () => {
      const r = generateChangelog('feat: a' + LF + LF + 'fix: b');
      expect(r.classifiedCount).assertEqual(2);
      expect(r.otherCount).assertEqual(0);
    });

    it('空输入报错', 0, () => {
      expect(generateChangelog('').failure.code).assertEqual(ChangelogFailureCode.EMPTY_INPUT);
      expect(generateChangelog('   ').failure.code).assertEqual(ChangelogFailureCode.EMPTY_INPUT);
    });

    it('十一种已知类型全覆盖', 0, () => {
      const input = 'feat: a' + LF + 'fix: b' + LF + 'docs: c' + LF + 'style: d' + LF +
        'refactor: e' + LF + 'perf: f' + LF + 'test: g' + LF + 'build: h' + LF +
        'ci: i' + LF + 'chore: j' + LF + 'revert: k';
      const r = generateChangelog(input);
      expect(r.classifiedCount).assertEqual(11);
      expect(r.markdown.indexOf('### Documentation') >= 0).assertEqual(true);
      expect(r.markdown.indexOf('### Reverts') >= 0).assertEqual(true);
    });
  });
}