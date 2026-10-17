/**
 * 字符频率统计的纯逻辑实现。
 *
 * ## 功能
 *
 * 统计文本中每个字符的出现次数，输出按次数降序的清单（含占比）。
 * 可选忽略大小写与忽略空白。
 *
 * @module tools/char-frequency/CharFreqLogic
 */

/** 失败原因码 */
export enum CharFreqFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class CharFreqFailure {
  readonly code: CharFreqFailureCode;
  readonly args: Array<string>;

  constructor(code: CharFreqFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}
/** 一个频率项 */
export class CharFreqItem {
  readonly char: string;
  readonly count: number;
  /** 占比（百分比，两位小数） */
  readonly percent: string;

  constructor(char: string, count: number, percent: string) {
    this.char = char;
    this.count = count;
    this.percent = percent;
  }
}

/** 结果 */
export class CharFreqResult {
  readonly ok: boolean;
  readonly failure: CharFreqFailure;
  readonly items: Array<CharFreqItem>;
  /** 参与统计的总字符数 */
  readonly total: number;
  /** 不同字符种数 */
  readonly unique: number;

  constructor(ok: boolean, failure: CharFreqFailure, items: Array<CharFreqItem>,
    total: number, unique: number) {
    this.ok = ok;
    this.failure = failure;
    this.items = items;
    this.total = total;
    this.unique = unique;
  }
}
/** 主入口：ignoreCase 忽略大小写，ignoreWhitespace 跳过空白 */
export function analyzeFrequency(input: string, ignoreCase: boolean,
  ignoreWhitespace: boolean): CharFreqResult {
  if (input.length === 0) {
    return new CharFreqResult(false, new CharFreqFailure(CharFreqFailureCode.EMPTY_INPUT, []), [], 0, 0);
  }
  const counts: Map<string, number> = new Map<string, number>();
  let total: number = 0;
  for (let i = 0; i < input.length; i++) {
    let ch: string = input.charAt(i);
    if (ignoreWhitespace && (ch === ' ' || ch === String.fromCharCode(9) ||
      ch === String.fromCharCode(10) || ch === String.fromCharCode(13))) {
      continue;
    }
    if (ignoreCase) {
      ch = ch.toLowerCase();
    }
    total++;
    const cur: number | undefined = counts.get(ch);
    if (cur === undefined) {
      counts.set(ch, 1);
    } else {
      counts.set(ch, cur + 1);
    }
  }
  const items: Array<CharFreqItem> = [];
  const entries: Array<string> = Array.from(counts.keys());
  const sorted: Array<string> = entries.sort((a: string, b: string): number => {
    const ca: number = counts.get(a) as number;
    const cb: number = counts.get(b) as number;
    if (ca !== cb) {
      return cb - ca;
    }
    return a.charCodeAt(0) - b.charCodeAt(0);
  });
  for (let i = 0; i < sorted.length; i++) {
    const ch: string = sorted[i];
    const c: number = counts.get(ch) as number;
    const pct: string = String(Math.round(c * 10000 / total) / 100);
    items.push(new CharFreqItem(ch, c, pct));
  }
  return new CharFreqResult(true, new CharFreqFailure(CharFreqFailureCode.NONE, []),
    items, total, sorted.length);
}