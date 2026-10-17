/**
 * Git 命令速查表的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 收录高频 Git 命令（约 30 条）按场景分组：基础/分支/远程/撤销/暂存/查看。
 * 每条带「命令 + 中文说明」。查询：关键词模糊 + 场景过滤。
 *
 * @module tools/git-cheatsheet/GitCheatsheetLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个条目 */
export class GitEntry {
  readonly command: string;
  readonly meaning: NGFLocalizedText;
  readonly category: string;

  constructor(command: string, meaning: NGFLocalizedText, category: string) {
    this.command = command;
    this.meaning = meaning;
    this.category = category;
  }
}

/** 查询结果 */
export class GitQueryResult {
  readonly entries: Array<GitEntry>;

  constructor(entries: Array<GitEntry>) {
    this.entries = entries;
  }
}

function buildTable(): Array<GitEntry> {
  const list: Array<GitEntry> = [];
  const add = (command: string, meaning: NGFLocalizedText, category: string): void => {
  list.push(new GitEntry(command, meaning, category));
  };
  // 基础
  add('git init', new NGFLocalizedText('初始化仓库', 'Initialize a repository'), 'basic');
  add('git clone <url>', new NGFLocalizedText('克隆远程仓库', 'Clone a remote repository'), 'basic');
  add('git add .', new NGFLocalizedText('暂存所有改动', 'Stage all changes'), 'basic');
  add('git commit -m "msg"', new NGFLocalizedText('提交', 'Commit'), 'basic');
  add('git status', new NGFLocalizedText('查看工作区状态', 'Show working tree status'), 'basic');
  add('git log --oneline', new NGFLocalizedText('单行历史', 'Compact history'), 'view');
  add('git diff', new NGFLocalizedText('未暂存的改动', 'Unstaged changes'), 'view');
  add('git diff --staged', new NGFLocalizedText('已暂存的改动', 'Staged changes'), 'view');
  add('git show <commit>', new NGFLocalizedText('查看某次提交', 'Show one commit'), 'view');
  add('git blame <file>', new NGFLocalizedText('逐行追究改动来源', 'Who changed each line'), 'view');
  // 分支
  add('git branch', new NGFLocalizedText('列出本地分支', 'List local branches'), 'branch');
  add('git checkout -b <name>', new NGFLocalizedText('创建并切换分支', 'Create and switch to a branch'), 'branch');
  add('git switch <name>', new NGFLocalizedText('切换分支（新语法）', 'Switch branch (modern syntax)'), 'branch');
  add('git merge <name>', new NGFLocalizedText('合并分支', 'Merge a branch'), 'branch');
  add('git rebase <name>', new NGFLocalizedText('变基（线性历史）', 'Rebase (linear history)'), 'branch');
  add('git branch -d <name>', new NGFLocalizedText('删除已合并分支', 'Delete a merged branch'), 'branch');
  // 远程
  add('git pull', new NGFLocalizedText('拉取并合并', 'Fetch and merge'), 'remote');
  add('git fetch --all', new NGFLocalizedText('只取不合并', 'Fetch without merging'), 'remote');
  add('git push origin <name>', new NGFLocalizedText('推送分支', 'Push a branch'), 'remote');
  add('git remote -v', new NGFLocalizedText('查看远程地址', 'Show remote URLs'), 'remote');
  add('git remote set-url origin <url>', new NGFLocalizedText('改远程地址', 'Change a remote URL'), 'remote');
  // 撤销
  add('git restore <file>', new NGFLocalizedText('丢弃工作区改动', 'Discard working tree changes'), 'undo');
  add('git restore --staged <file>', new NGFLocalizedText('取消暂存', 'Unstage'), 'undo');
  add('git reset --soft HEAD~1', new NGFLocalizedText('撤销上次提交（保留改动）', 'Undo last commit (keep changes)'), 'undo');
  add('git revert <commit>', new NGFLocalizedText('生成反向提交（安全撤销）', 'Revert commit (safe undo)'), 'undo');
  add('git commit --amend', new NGFLocalizedText('修补上次提交', 'Amend the last commit'), 'undo');
  add('git reflog', new NGFLocalizedText('找回丢失的提交', 'Recover lost commits'), 'undo');
  // 暂存
  add('git stash', new NGFLocalizedText('暂存当前改动', 'Stash current changes'), 'stash');
  add('git stash pop', new NGFLocalizedText('恢复最近暂存', 'Pop the latest stash'), 'stash');
  add('git stash list', new NGFLocalizedText('暂存清单', 'List stashes'), 'stash');
  return list;
}

const TABLE: Array<GitEntry> = buildTable();

/** 全表 */
export function allGitEntries(): Array<GitEntry> {
  return TABLE;
}

/** 场景列表（保持首次出现顺序） */
export function gitCategories(): Array<string> {
  const seen: Set<string> = new Set<string>();
  const out: Array<string> = [];
  for (let i = 0; i < TABLE.length; i++) {
    if (!seen.has(TABLE[i].category)) {
      seen.add(TABLE[i].category);
      out.push(TABLE[i].category);
    }
  }
  return out;
}

/** 查询：空关键词全表（受场景过滤）；文本模糊匹配命令与说明 */
export function queryGit(keyword: string, category: string | null): GitQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<GitEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: GitEntry = TABLE[i];
    if (category !== null && e.category !== category) {
      continue;
    }
    if (text.length === 0 || e.command.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.toLowerCase().indexOf(text) >= 0 || e.meaning.zh.indexOf(keyword.trim()) >= 0) {
      out.push(e);
    }
  }
  return new GitQueryResult(out);
}