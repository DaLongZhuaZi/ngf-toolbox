/**
 * IDE 快捷键速查表的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 收录高频快捷键（约 26 条）按场景分组：导航/编辑/重构/运行与调试/搜索。
 * 以 Android Studio/IntelliJ 键位为准（Windows/Linux 口径）。
 *
 * @module tools/keyseq-doc/KeyseqDocLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个条目 */
export class KeyseqEntry {
  readonly keys: string;
  readonly meaning: NGFLocalizedText;
  readonly category: string;

  constructor(keys: string, meaning: NGFLocalizedText, category: string) {
    this.keys = keys;
    this.meaning = meaning;
    this.category = category;
  }
}

/** 查询结果 */
export class KeyseqQueryResult {
  readonly entries: Array<KeyseqEntry>;

  constructor(entries: Array<KeyseqEntry>) {
    this.entries = entries;
  }
}

function buildTable(): Array<KeyseqEntry> {
  const list: Array<KeyseqEntry> = [];
  const add = (keys: string, meaning: NGFLocalizedText, category: string): void => {
  list.push(new KeyseqEntry(keys, meaning, category));
  };
  // 导航
  add('Ctrl+N', new NGFLocalizedText('查找类', 'Find'), 'nav');
  add('Ctrl+Shift+N', new NGFLocalizedText('查找文件', 'Find file'), 'nav');
  add('Ctrl+B', new NGFLocalizedText('跳到声明', 'Go to declaration'), 'nav');
  add('Ctrl+Alt+Left', new NGFLocalizedText('返回上一个位置', 'Back to previous location'), 'nav');
  add('Alt+F7', new NGFLocalizedText('查找用法', 'Find usages'), 'nav');
  // 编辑
  add('Ctrl+D', new NGFLocalizedText('复制当前行', 'Duplicate current line'), 'edit');
  add('Ctrl+Y', new NGFLocalizedText('删除当前行', 'Delete current line'), 'edit');
  add('Ctrl+/', new NGFLocalizedText('行注释', 'Line comment'), 'edit');
  add('Ctrl+Shift+/', new NGFLocalizedText('块注释', 'Block comment'), 'edit');
  add('Ctrl+Alt+L', new NGFLocalizedText('格式化代码', 'Reformat code'), 'edit');
  add('Shift+Enter', new NGFLocalizedText('下方新起一行', 'Start new line below'), 'edit');
  add('Ctrl+Shift+J', new NGFLocalizedText('合并行', 'Join lines'), 'edit');
  // 重构
  add('Shift+F6', new NGFLocalizedText('重命名（全项目引用）', 'Rename (all references)'), 'refactor');
  add('Ctrl+Alt+V', new NGFLocalizedText('提取变量', 'Extract variable'), 'refactor');
  add('Ctrl+Alt+M', new NGFLocalizedText('提取方法', 'Extract method'), 'refactor');
  add('Ctrl+Alt+F', new NGFLocalizedText('提取字段', 'Extract field'), 'refactor');
  add('Alt+Enter', new NGFLocalizedText('快速修复/意图操作', 'Quick fix or intention action'), 'refactor');
  // 运行与调试
  add('Shift+F10', new NGFLocalizedText('运行', 'Run'), 'run');
  add('Shift+F9', new NGFLocalizedText('调试', 'Debug'), 'run');
  add('F8', new NGFLocalizedText('单步跳过', 'Step over'), 'run');
  add('F7', new NGFLocalizedText('单步进入', 'Step into'), 'run');
  add('Ctrl+F8', new NGFLocalizedText('切换断点', 'Toggle breakpoint'), 'run');
  // 搜索
  add('Double Shift', new NGFLocalizedText('全局搜索（Search Everywhere）', 'Search everywhere'), 'search');
  add('Ctrl+F', new NGFLocalizedText('当前文件查找', 'Find in file'), 'search');
  add('Ctrl+Shift+F', new NGFLocalizedText('全项目查找', 'Find in project'), 'search');
  add('Ctrl+R', new NGFLocalizedText('当前文件替换', 'Replace in file'), 'search');
  return list;
}

const TABLE: Array<KeyseqEntry> = buildTable();

/** 全表 */
export function allKeyseqEntries(): Array<KeyseqEntry> {
  return TABLE;
}

/** 场景列表 */
export function keyseqCategories(): Array<string> {
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

/** 查询：空关键词全表（受场景过滤）；文本模糊 */
export function queryKeyseq(keyword: string, category: string | null): KeyseqQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<KeyseqEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: KeyseqEntry = TABLE[i];
    if (category !== null && e.category !== category) {
      continue;
    }
    if (text.length === 0 || e.keys.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.toLowerCase().indexOf(text) >= 0 || e.meaning.zh.indexOf(keyword.trim()) >= 0) {
      out.push(e);
    }
  }
  return new KeyseqQueryResult(out);
}