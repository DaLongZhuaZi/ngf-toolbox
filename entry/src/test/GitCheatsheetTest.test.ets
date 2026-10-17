import { describe, expect, it } from '@ohos/hypium';
import {
  allGitEntries,
  gitCategories,
  queryGit
} from '../main/ets/tools/git-cheatsheet/GitCheatsheetLogic';

/**
 * Git 速查的单测：表内容事实断言 + 查询语义。
 */
export default function gitCheatsheetTest() {
  describe('gitCheatsheetTest', () => {
    it('全表 30 条且命令唯一', 0, () => {
      const all = allGitEntries();
      expect(all.length).assertEqual(30);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].command)).assertEqual(false);
        seen.add(all[i].command);
      }
    });

    it('六大场景齐全', 0, () => {
      expect(gitCategories().length).assertEqual(6);
    });

    it('关键词：rebase 命中变基', 0, () => {
      const r = queryGit('rebase', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].command.indexOf('rebase') >= 0).assertEqual(true);
    });

    it('中文：撤销 命中撤销类多条', 0, () => {
      const r = queryGit('撤销', null);
      expect(r.entries.length >= 2).assertEqual(true);
    });

    it('场景过滤：stash 只返回暂存条目', 0, () => {
      const r = queryGit('', 'stash');
      expect(r.entries.length).assertEqual(3);
      for (let i = 0; i < r.entries.length; i++) {
        expect(r.entries[i].category).assertEqual('stash');
      }
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryGit('', null).entries.length).assertEqual(30);
      expect(queryGit('zzzz', null).entries.length).assertEqual(0);
    });
  });
}
