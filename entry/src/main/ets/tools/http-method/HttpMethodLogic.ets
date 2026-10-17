/**
 * HTTP 方法速查表的纯逻辑实现（本地数据表，与 http-status 配对）。
 *
 * ## 数据口径
 *
 * 收录九个标准方法（GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS/TRACE/CONNECT），
 * 每条「语义 + 幂等性 + 常见状态码」。查询：关键词模糊。
 *
 * @module tools/http-method/HttpMethodLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个条目 */
export class HttpMethodEntry {
  readonly method: string;
  readonly meaning: NGFLocalizedText;
  /** 幂等（重复请求效果相同） */
  readonly idempotent: boolean;
  /** 常见成功状态码 */
  readonly commonStatus: string;

  constructor(method: string, meaning: NGFLocalizedText, idempotent: boolean, commonStatus: string) {
    this.method = method;
    this.meaning = meaning;
    this.idempotent = idempotent;
    this.commonStatus = commonStatus;
  }
}

/** 查询结果 */
export class HttpMethodQueryResult {
  readonly entries: Array<HttpMethodEntry>;

  constructor(entries: Array<HttpMethodEntry>) {
    this.entries = entries;
  }
}

function buildTable(): Array<HttpMethodEntry> {
  const list: Array<HttpMethodEntry> = [];
  const add = (method: string, meaning: NGFLocalizedText, idempotent: boolean, commonStatus: string): void => {
    list.push(new HttpMethodEntry(method, meaning, idempotent, commonStatus));
  };
  add('GET', new NGFLocalizedText('读取资源（不改变状态）', 'Read a resource (no state change)'), true, '200 / 304 / 404');
  add('POST', new NGFLocalizedText('创建资源或触发处理', 'Create a resource or trigger processing'), false, '200 / 201 / 422');
  add('PUT', new NGFLocalizedText('整体替换资源', 'Replace a resource entirely'), true, '200 / 204 / 409');
  add('PATCH', new NGFLocalizedText('部分更新资源', 'Update part of a resource'), false, '200 / 204 / 409');
  add('DELETE', new NGFLocalizedText('删除资源', 'Delete a resource'), true, '200 / 204 / 404');
  add('HEAD', new NGFLocalizedText('同 GET 但只要响应头', 'Like GET but only the response headers'), true, '200 / 304');
  add('OPTIONS', new NGFLocalizedText('查询支持的方法（CORS 预检用）', 'Query supported methods (CORS preflight)'), true, '200 / 204');
  add('TRACE', new NGFLocalizedText('回显请求（诊断用）', 'Echo the request (diagnostics)'), true, '200');
  add('CONNECT', new NGFLocalizedText('建立隧道（HTTPS 代理用）', 'Tunnel for HTTPS proxies'), false, '200');
  return list;
}

const TABLE: Array<HttpMethodEntry> = buildTable();

/** 全表 */
export function allMethodEntries(): Array<HttpMethodEntry> {
  return TABLE;
}

/** 查询：空关键词全表；文本模糊匹配方法名与语义 */
export function queryMethods(keyword: string): HttpMethodQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<HttpMethodEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: HttpMethodEntry = TABLE[i];
    if (text.length === 0 || e.method.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.indexOf(keyword.trim()) >= 0 || e.meaning.en.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new HttpMethodQueryResult(out);
}