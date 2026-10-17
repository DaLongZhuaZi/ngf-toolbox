/**
 * 键盘符号名称速查表的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 收录 Mac 键盘符号（⌘⌥⌃⇧⏎⌫⎋ 等 14 个）与 Windows/Linux 等价键对照——
 * 读国外文档/快捷键表时的「符号翻译器」。
 *
 * @module tools/keyboard-symbols/KeyboardSymbolsLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

function wrapWin(win: string): NGFLocalizedText {
  return new NGFLocalizedText(win, win);
}
/** 一个条目 */
export class KeySymbolEntry {
  readonly symbol: string;
  readonly name: string;
  readonly nameZh: NGFLocalizedText;
  readonly winEquivalent: NGFLocalizedText;

  constructor(symbol: string, name: string, nameZh: NGFLocalizedText, winEquivalent: NGFLocalizedText) {
    this.symbol = symbol;
    this.name = name;
    this.nameZh = nameZh;
    this.winEquivalent = winEquivalent;
  }
}

/** 查询结果 */
export class KeySymbolResult {
  readonly entries: Array<KeySymbolEntry>;

  constructor(entries: Array<KeySymbolEntry>) {
    this.entries = entries;
  }
}
function buildTable(): Array<KeySymbolEntry> {
  const list: Array<KeySymbolEntry> = [];
  const add = (symbol: string, name: string, nameZh: NGFLocalizedText, win: string): void => {
    list.push(new KeySymbolEntry(symbol, name, nameZh, wrapWin(win)));
  };
  list.push(new KeySymbolEntry(String.fromCharCode(8984), 'Command',
    new NGFLocalizedText('Mac 命令键（花键）', 'Command key (cloverleaf)'),
    new NGFLocalizedText('Ctrl（多数场景）', 'Ctrl (most cases)')));
  add(String.fromCharCode(8997), 'Option / Alt', new NGFLocalizedText('Mac 选项键', 'Option key'), 'Alt');
  add(String.fromCharCode(9417), 'Control', new NGFLocalizedText('Mac 控制键', 'Control key'), 'Ctrl');
  add(String.fromCharCode(8679), 'Shift', new NGFLocalizedText('上档键', 'Shift key'), 'Shift');
  add(String.fromCharCode(9166), 'Return', new NGFLocalizedText('回车', 'Return key'), 'Enter');
  add(String.fromCharCode(9003), 'Delete / Backspace', new NGFLocalizedText('删除（向后）', 'Delete (backspace)'), 'Backspace');
  add(String.fromCharCode(9099), 'Escape', new NGFLocalizedText('退出键', 'Escape key'), 'Esc');
  add(String.fromCharCode(8617), 'Tab', new NGFLocalizedText('制表键', 'Tab key'), 'Tab');
  add(String.fromCharCode(8682), 'Caps Lock', new NGFLocalizedText('大写锁定', 'Caps Lock'), 'Caps Lock');
  add(String.fromCharCode(8678), 'Left Arrow', new NGFLocalizedText('左方向', 'Left arrow'), 'Left Arrow');
  add(String.fromCharCode(8680), 'Right Arrow', new NGFLocalizedText('右方向', 'Right arrow'), 'Right Arrow');
  add(String.fromCharCode(8679) + String.fromCharCode(8680), 'Shift+Right', new NGFLocalizedText('上档+右方向', 'Shift plus Right'), 'Shift+Right');
  add(String.fromCharCode(9126), 'Page Up', new NGFLocalizedText('向上翻页', 'Page up'), 'Page Up');
  add(String.fromCharCode(9135), 'Page Down', new NGFLocalizedText('向下翻页', 'Page down'), 'Page Down');
  add(String.fromCharCode(8999), 'Clear', new NGFLocalizedText('清除', 'Clear'), 'Num Lock');
  return list;
}

const TABLE: Array<KeySymbolEntry> = buildTable();
/** 全表 */
export function allKeySymbols(): Array<KeySymbolEntry> {
  return TABLE;
}

/** 查询：空关键词全表；文本模糊匹配符号名/中文/等价键 */
export function queryKeySymbols(keyword: string): KeySymbolResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<KeySymbolEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: KeySymbolEntry = TABLE[i];
    if (text.length === 0 || e.name.toLowerCase().indexOf(text) >= 0 ||
      e.nameZh.zh.indexOf(keyword.trim()) >= 0 || e.nameZh.en.toLowerCase().indexOf(text) >= 0 || e.winEquivalent.zh.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new KeySymbolResult(out);
}