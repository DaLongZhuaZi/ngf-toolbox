/**
 * 占位文本（Lorem Ipsum）生成的纯逻辑实现。
 *
 * ## 为什么用「种子随机」而不用 Math.random
 *
 * 设计目标之一是**可测**：同一种子必须产出同一串文本，单测才能断言。
 * Math.random 不可注入，所以这里实现一个可播种的伪随机数发生器
 * （mulberry32——32 位状态、单行乘法，分布足够均匀且无依赖）。
 *
 * ## 词表
 *
 * 经典 Lorem Ipsum 词表取前 50 个高频词（latin 词根），中文占位用
 * 「常用开发文档用词」40 个。生成段落 = 句子 = 词，句首大写、句末句号。
 *
 * ## 所有字符用 fromCharCode/字面量
 *
 * 模板写入器写不进字面转义序列（第 73 轮教训），本文件的句号、空格
 * 等字符用显式字符码或直接字面量（非转义）。
 *
 * @module tools/lorem-ipsum/LoremIpsum
 */

/** 失败原因码 */
export enum LoremFailureCode {
  NONE = 'none',
  /** 段落数或每段句数非法（<=0 或 > 50） */
  COUNT_OUT_OF_RANGE = 'count_out_of_range'
}

/** 一次失败的原因与文案参数 */
export class LoremFailure {
  readonly code: LoremFailureCode;
  readonly args: Array<string>;

  constructor(code: LoremFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 生成结果 */
export class LoremResult {
  readonly ok: boolean;
  readonly failure: LoremFailure;
  /** 段落列表（页面按段落渲染，可复制全部） */
  readonly paragraphs: Array<string>;
  /** 词数统计 */
  readonly words: number;

  constructor(ok: boolean, failure: LoremFailure, paragraphs: Array<string>, words: number) {
    this.ok = ok;
    this.failure = failure;
    this.paragraphs = paragraphs;
    this.words = words;
  }
}

/** 语言 */
export enum LoremLanguage {
  LATIN = 'latin',
  CHINESE = 'chinese'
}

/** mulberry32 伪随机数发生器：返回 0..1 的函数 */
function mulberry32(seed: number): () => number {
  let a: number = seed >>> 0;
  return (): number => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t: number = a;
    t = (t ^ (t >>> 15)) * (t | 1) >>> 0;
    t = (t ^ (t + (t ^ (t >>> 7)) * (t | 61))) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const LATIN_WORDS: Array<string> = [
  'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing', 'elit',
  'sed', 'do', 'eiusmod', 'tempor', 'incididunt', 'ut', 'labore', 'et',
  'dolore', 'magna', 'aliqua', 'enim', 'ad', 'minim', 'veniam', 'quis',
  'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi', 'aliquip', 'ex', 'ea',
  'commodo', 'consequat', 'duis', 'aute', 'irure', 'in', 'reprehenderit', 'voluptate',
  'velit', 'esse', 'cillum', 'eu', 'fugiat', 'nulla', 'pariatur', 'excepteur',
  'sint', 'occaecat'
];

const CHINESE_WORDS: Array<string> = [ // i18n-corpus-data: user-chosen Chinese corpus
  '开发', '工具箱', '测试', '占位', '文本', '样例', '内容', '数据', // i18n-corpus-data
  '接口', '返回', '结果', '字段', '配置', '模块', '组件', '页面', // i18n-corpus-data
  '样式', '布局', '动效', '交互', '体验', '性能', '稳定', '安全', // i18n-corpus-data
  '网络', '请求', '响应', '缓存', '更新', '版本', '发布', '验证', // i18n-corpus-data
  '覆盖', '回归', '脚本', '检查', '报告', '输出', '输入', '处理' // i18n-corpus-data
];

function pickWord(rand: () => number, table: Array<string>): string {
  const idx: number = Math.floor(rand() * table.length) % table.length;
  return table[idx];
}

function capitalizeFirst(s: string): string {
  if (s.length === 0) {
    return s;
  }
  return s.charAt(0).toUpperCase() + s.substring(1);
}

/**
 * 生成占位文本。
 *
 * @param paragraphs 段落数（1..20）
 * @param sentencesPer 每段句数（1..20）
 * @param seed 随机种子（同一种子同输出）
 * @param lang 词表语言
 */
export function generateLorem(paragraphs: number, sentencesPer: number,
  seed: number, lang: LoremLanguage): LoremResult {
  if (paragraphs < 1 || paragraphs > 20 || sentencesPer < 1 || sentencesPer > 20) {
    return new LoremResult(false,
      new LoremFailure(LoremFailureCode.COUNT_OUT_OF_RANGE, []), [], 0);
  }
  const table: Array<string> = lang === LoremLanguage.CHINESE ? CHINESE_WORDS : LATIN_WORDS;
  const rand: () => number = mulberry32(seed);
  const out: Array<string> = [];
  let words: number = 0;
  for (let p = 0; p < paragraphs; p++) {
    const sentences: Array<string> = [];
    for (let s = 0; s < sentencesPer; s++) {
      const len: number = 6 + Math.floor(rand() * 9);
      const wordsInSentence: Array<string> = [];
      for (let w = 0; w < len; w++) {
        wordsInSentence.push(pickWord(rand, table));
        words++;
      }
      let sentence: string = wordsInSentence.join(String.fromCharCode(32));
      if (lang === LoremLanguage.LATIN) {
        sentence = capitalizeFirst(sentence);
        sentence = sentence + String.fromCharCode(46);
      } else {
        sentence = sentence + String.fromCharCode(65292);
      }
      sentences.push(sentence);
    }
    let para: string = sentences.join(lang === LoremLanguage.LATIN ? String.fromCharCode(32) : '');
    if (lang === LoremLanguage.CHINESE) {
      // 中文最后用句号收尾（前面的逗号保留）
      para = para.substring(0, para.length - 1) + String.fromCharCode(65294);
    }
    out.push(para);
  }
  return new LoremResult(true, new LoremFailure(LoremFailureCode.NONE, []), out, words);
}
