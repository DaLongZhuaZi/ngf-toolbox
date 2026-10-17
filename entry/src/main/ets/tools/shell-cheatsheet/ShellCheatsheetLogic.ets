/**
 * Shell 命令速查表的纯逻辑实现（本地数据表，bash 与 PowerShell 双栏）。
 *
 * ## 数据口径与安全边界
 *
 * 收录高频只读/低风险操作（文件查看、进程查看、端口查看、文本处理），
 * 每条 bash 与 pwsh 各一列。**不收录**删除、格式化、提权类危险操作——
 * 速查表的价值在于「常用且安全」。
 *
 * @module tools/shell-cheatsheet/ShellCheatsheetLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个条目 */
export class ShellEntry {
  readonly task: NGFLocalizedText;
  readonly bash: string;
  readonly pwsh: string;
  readonly category: string;

  constructor(task: NGFLocalizedText, bash: string, pwsh: string, category: string) {
    this.task = task;
    this.bash = bash;
    this.pwsh = pwsh;
    this.category = category;
  }
}

/** 查询结果 */
export class ShellQueryResult {
  readonly entries: Array<ShellEntry>;

  constructor(entries: Array<ShellEntry>) {
    this.entries = entries;
  }
}

function buildTable(): Array<ShellEntry> {
  const list: Array<ShellEntry> = [];
  const add = (task: NGFLocalizedText, bash: string, pwsh: string, category: string): void => {
    list.push(new ShellEntry(task, bash, pwsh, category));
  };
  // 文件查看
  add(new NGFLocalizedText('列出文件', 'List files'), 'ls -la', 'Get-ChildItem -Force', 'file');
  add(new NGFLocalizedText('查看文件内容', 'Show file contents'), 'cat file.txt', 'Get-Content file.txt', 'file');
  add(new NGFLocalizedText('查看前 20 行', 'Show first 20 lines'), 'head -20 file.txt', 'Get-Content file.txt -TotalCount 20', 'file');
  add(new NGFLocalizedText('查找文件', 'Find files'), 'find . -name "*.ts"', 'Get-ChildItem -Recurse -Filter *.ts', 'file');
  add(new NGFLocalizedText('当前目录', 'Current directory'), 'pwd', 'Get-Location', 'file');
  // 文本处理
  add(new NGFLocalizedText('文本搜索', 'Search text'), 'grep -rn "todo" src/', 'Select-String -Path src/* -Pattern todo', 'text');
  add(new NGFLocalizedText('统计行数', 'Count lines'), 'wc -l file.txt', '(Get-Content file.txt).Count', 'text');
  add(new NGFLocalizedText('去重', 'Deduplicate lines'), 'sort file.txt | uniq', 'Get-Content file.txt | Sort-Object -Unique', 'text');
  // 进程与系统
  add(new NGFLocalizedText('查看进程', 'Show processes'), 'ps aux', 'Get-Process', 'sys');
  add(new NGFLocalizedText('按名找进程', 'Find process by name'), 'ps aux | grep node', 'Get-Process node', 'sys');
  add(new NGFLocalizedText('磁盘用量', 'Disk usage'), 'df -h', 'Get-PSDrive', 'sys');
  add(new NGFLocalizedText('环境变量', 'Environment variables'), 'env', 'Get-ChildItem env:', 'sys');
  // 网络
  add(new NGFLocalizedText('端口占用', 'Port usage'), 'netstat -tlnp', 'netstat -ano', 'net');
  add(new NGFLocalizedText('ping 主机', 'Ping a host'), 'ping -c 4 host', 'ping host', 'net');
  add(new NGFLocalizedText('DNS 解析', 'DNS lookup'), 'dig host', 'Resolve-DnsName host', 'net');
  add(new NGFLocalizedText('下载文件', 'Download a file'), 'curl -O url', 'Invoke-WebRequest url', 'net');
  // Git 辅助
  add(new NGFLocalizedText('最近提交', 'Recent commits'), 'git log --oneline -10', 'git log --oneline -10', 'git');
  add(new NGFLocalizedText('当前分支', 'Current branch'), 'git branch --show-current', 'git branch --show-current', 'git');
  add(new NGFLocalizedText('工作区状态', 'Working tree status'), 'git status -s', 'git status -s', 'git');
  return list;
}

const TABLE: Array<ShellEntry> = buildTable();

/** 全表 */
export function allShellEntries(): Array<ShellEntry> {
  return TABLE;
}

/** 分类列表 */
export function shellCategories(): Array<string> {
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

/** 查询 */
export function queryShell(keyword: string, category: string | null): ShellQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<ShellEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: ShellEntry = TABLE[i];
    if (category !== null && e.category !== category) {
      continue;
    }
    if (text.length === 0 || e.task.zh.indexOf(keyword.trim()) >= 0 || e.task.en.toLowerCase().indexOf(text) >= 0 ||
      e.bash.toLowerCase().indexOf(text) >= 0 || e.pwsh.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new ShellQueryResult(out);
}