/**
 * 假数据生成的纯逻辑实现（本地规则表 + 可注入随机源）。
 *
 * ## 数据口径
 *
 * 姓氏表（常见 40 字）与名字表组合中文姓名；手机号用真实号段前缀；
 * 邮箱用 example.com 及其子域（保留域，不会误发邮件）。
 * 全部是假数据，不含真实个人信息。
 *
 * ## 随机源
 *
 * 可注入 NGFRandomByteSource（与 uuid-password 同一抽象）——测试用确定性源。
 *
 * @module tools/mock-data/MockDataLogic
 */

import { NGFRandomByteSource } from '../uuid-password/UuidPasswordLogic';

/** 失败原因码 */
export enum MockFailureCode {
  NONE = 'none',
  COUNT_INVALID = 'count_invalid',
  UNKNOWN_TYPE = 'unknown_type'
}

/** 一次失败的原因与文案参数 */
export class MockFailure {
  readonly code: MockFailureCode;
  readonly args: Array<string>;

  constructor(code: MockFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class MockResult {
  readonly ok: boolean;
  readonly failure: MockFailure;
  readonly values: Array<string>;

  constructor(ok: boolean, failure: MockFailure, values: Array<string>) {
    this.ok = ok;
    this.failure = failure;
    this.values = values;
  }
}

const SURNAMES: string = '王李张刘陈杨赵黄周吴徐孙马朱胡郭何林罗高郑梁谢宋唐许韩冯邓曹彭曾'; // i18n-corpus-data
const GIVEN: string = '伟芳娜敏静丽强磊军洋勇艳杰娟涛明超秀霞平刚桂华建文'; // i18n-corpus-data
const PHONE_PREFIXES: Array<string> = ['138', '139', '150', '151', '152', '157', '158', '159',
  '166', '170', '176', '177', '178', '180', '181', '182', '185', '186', '187', '188', '189',
  '198', '199'];
const MAIL_DOMAINS: Array<string> = ['example.com', 'test.example.com', 'demo.example.com'];
const MAX_COUNT: number = 200;

function nextInt(source: NGFRandomByteSource, max: number): number {
  const bytes: Uint8Array = source.nextBytes(2);
  const v: number = bytes[0] * 256 + bytes[1];
  return v % max;
}

/** 生成类型：name=中文姓名，phone=手机号，email=邮箱 */
export enum MockType {
  NAME = 'name',
  PHONE = 'phone',
  EMAIL = 'email'
}

/** 主入口 */
export function generateMock(source: NGFRandomByteSource, type: MockType,
  countText: string): MockResult {
  const count: number = parseInt(countText, 10);
  if (isNaN(count) || count <= 0 || count > MAX_COUNT) {
    return new MockResult(false, new MockFailure(MockFailureCode.COUNT_INVALID, []), []);
  }
  const values: Array<string> = [];
  for (let i = 0; i < count; i++) {
    if (type === MockType.NAME) {
      const surname: string = SURNAMES.charAt(nextInt(source, SURNAMES.length));
      const givenLen: number = 1 + nextInt(source, 2);
      let given: string = '';
      for (let k = 0; k < givenLen; k++) {
        given = given + GIVEN.charAt(nextInt(source, GIVEN.length));
      }
      values.push(surname + given);
    } else if (type === MockType.PHONE) {
      const prefix: string = PHONE_PREFIXES[nextInt(source, PHONE_PREFIXES.length)];
      let tail: string = '';
      for (let k = 0; k < 8; k++) {
        tail = tail + String(nextInt(source, 10));
      }
      values.push(prefix + tail);
    } else if (type === MockType.EMAIL) {
      const userLen: number = 6 + nextInt(source, 5);
      let user: string = '';
      for (let k = 0; k < userLen; k++) {
        user = user + String.fromCharCode(97 + nextInt(source, 26));
      }
      const domain: string = MAIL_DOMAINS[nextInt(source, MAIL_DOMAINS.length)];
      values.push(user + '@' + domain);
    } else {
      return new MockResult(false, new MockFailure(MockFailureCode.UNKNOWN_TYPE, []), []);
    }
  }
  return new MockResult(true, new MockFailure(MockFailureCode.NONE, []), values);
}