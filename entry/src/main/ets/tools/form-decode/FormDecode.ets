/**
 * 表单编码解析的纯逻辑实现（薄封装 url-codec 的解码）。
 *
 * ## 与 url-codec 的分工
 *
 * url-codec 是「整串/任意文本」编解码；本工具专注 **application/x-www-form-urlencoded
 * 的表单语义**：逐参数拆解 + 每参数给「原始/解码」双视图 + **字段计数统计**。
 * 解码复用 decodeUrlText（+ 是空格的表单口径）。
 *
 * ## 重复键
 *
 * 表单允许同名字段（多选框）——解析成**多条**而不是覆盖。
 *
 * @module tools/form-decode/FormDecode
 */

import { decodeUrlText } from '../url-codec/UrlCodec';

/** 失败原因码 */
export enum FormDecodeFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 表单体以 ? 开头（那是 query 的形态，提示用户去掉） */
  LEADING_QUESTION_MARK = 'leading_question_mark'
}

/** 一次失败的原因与文案参数 */
export class FormDecodeFailure {
  readonly code: FormDecodeFailureCode;
  readonly args: Array<string>;

  constructor(code: FormDecodeFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 一个字段 */
export class FormField {
  readonly key: string;
  readonly value: string;
  readonly rawValue: string;

  constructor(key: string, value: string, rawValue: string) {
    this.key = key;
    this.value = value;
    this.rawValue = rawValue;
  }
}

/** 结果 */
export class FormDecodeResult {
  readonly ok: boolean;
  readonly failure: FormDecodeFailure;
  readonly fields: Array<FormField>;
  /** 唯一键数（与字段数的差 = 重复键） */
  readonly uniqueKeys: number;

  constructor(ok: boolean, failure: FormDecodeFailure, fields: Array<FormField>, uniqueKeys: number) {
    this.ok = ok;
    this.failure = failure;
    this.fields = fields;
    this.uniqueKeys = uniqueKeys;
  }
}

/** 主入口：解析表单体 */
export function decodeForm(input: string): FormDecodeResult {
  const text: string = input.trim();
  if (text.length === 0) {
    return new FormDecodeResult(false,
      new FormDecodeFailure(FormDecodeFailureCode.EMPTY_INPUT, []), [], 0);
  }
  if (text.charAt(0) === String.fromCharCode(63)) {
    return new FormDecodeResult(false,
      new FormDecodeFailure(FormDecodeFailureCode.LEADING_QUESTION_MARK, []), [], 0);
  }
  const fields: Array<FormField> = [];
  const segs: Array<string> = text.split('&');
  for (let i = 0; i < segs.length; i++) {
    const seg: string = segs[i];
    if (seg.length === 0) {
      continue;
    }
    const eq: number = seg.indexOf('=');
    const rawKey: string = eq < 0 ? seg : seg.substring(0, eq);
    const rawValue: string = eq < 0 ? '' : seg.substring(eq + 1);
    // 表单口径：+ 是空格
    const key: string = decodeUrlText(rawKey.split('+').join(' ')).text;
    const value: string = decodeUrlText(rawValue.split('+').join(' ')).text;
    fields.push(new FormField(key, value, rawValue));
  }
  const seen: Set<string> = new Set<string>();
  for (let i = 0; i < fields.length; i++) {
    seen.add(fields[i].key);
  }
  return new FormDecodeResult(true,
    new FormDecodeFailure(FormDecodeFailureCode.NONE, []), fields, seen.size);
}
