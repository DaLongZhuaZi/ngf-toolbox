import { describe, expect, it } from '@ohos/hypium';
import {
  allShellEntries,
  queryShell,
  shellCategories
} from '../main/ets/tools/shell-cheatsheet/ShellCheatsheetLogic';

/**
 * Shell 速查的单测：表内容事实断言（双栏完整）+ 查询语义 + 安全边界。
 */
export default function shellCheatsheetTest() {
  describe('shellCheatsheetTest', () => {
    it('全表 19 条且 bash/pwsh 双栏非空', 0, () => {
      const all = allShellEntries();
      expect(all.length).assertEqual(19);
      for (let i = 0; i < all.length; i++) {
        expect(all[i].bash.length > 0).assertEqual(true);
        expect(all[i].pwsh.length > 0).assertEqual(true);
      }
    });

    it('五大分类齐全', 0, () => {
      expect(shellCategories().length).assertEqual(5);
    });

    it('安全边界：不含删除类危险命令', 0, () => {
      const all = allShellEntries();
      for (let i = 0; i < all.length; i++) {
        expect(all[i].bash.indexOf('rm ') < 0).assertEqual(true);
        expect(all[i].bash.indexOf('rm -') < 0).assertEqual(true);
        expect(all[i].pwsh.indexOf('Remove-Item') < 0).assertEqual(true);
        expect(all[i].pwsh.indexOf('Format-') < 0).assertEqual(true);
      }
    });

    it('中文任务搜索：端口 命中 netstat', 0, () => {
      const r = queryShell('端口', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].bash.indexOf('netstat') >= 0).assertEqual(true);
    });

    it('分类过滤：git 类只返回 git 条目（bash 与 pwsh 同款）', 0, () => {
      const r = queryShell('', 'git');
      expect(r.entries.length).assertEqual(3);
      for (let i = 0; i < r.entries.length; i++) {
        expect(r.entries[i].bash.indexOf('git') === 0).assertEqual(true);
      }
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryShell('', null).entries.length).assertEqual(19);
      expect(queryShell('zzzz', null).entries.length).assertEqual(0);
    });
  });
}
