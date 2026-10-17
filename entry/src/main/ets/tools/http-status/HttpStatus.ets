/**
 * HTTP 状态码速查的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 只收录**开发调试高频**的状态码（约 30 个），不是 RFC 全量 60+：
 * 表太长会让页面变成需要搜索的清单。每条带「含义 + 常见原因」两句。
 *
 * ## 查询
 *
 * 支持按数字（如 404）或关键词（如 not found 的模糊匹配）查询。
 * 关键词匹配忽略大小写，命中 name 或含义的任一语言。
 *
 * @module tools/http-status/HttpStatus
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个状态码条目 */
export class HttpStatusEntry {
  readonly code: number;
  /** 英文标准名 */
  readonly name: string;
  /** 中文含义 */
  readonly meaning: NGFLocalizedText;
  /** 中文常见原因 */
  readonly cause: NGFLocalizedText;
  /** 分类（1xx 信息 / 2xx 成功 / 3xx 重定向 / 4xx 客户端 / 5xx 服务端） */
  readonly category: number;

  constructor(code: number, name: string, meaning: NGFLocalizedText, cause: NGFLocalizedText, category: number) {
    this.code = code;
    this.name = name;
    this.meaning = meaning;
    this.cause = cause;
    this.category = category;
  }
}

/** 查询结果 */
export class HttpStatusQueryResult {
  readonly ok: boolean;
  readonly failureCode: string;
  readonly entries: Array<HttpStatusEntry>;

  constructor(ok: boolean, failureCode: string, entries: Array<HttpStatusEntry>) {
    this.ok = ok;
    this.failureCode = failureCode;
    this.entries = entries;
  }
}

function buildTable(): Array<HttpStatusEntry> {
  const list: Array<HttpStatusEntry> = [];
  const add = (code: number, name: string, meaning: NGFLocalizedText, cause: NGFLocalizedText, category: number): void => {
  list.push(new HttpStatusEntry(code, name, meaning, cause, category));
  };
  add(100, 'Continue', new NGFLocalizedText('继续', 'Continue'), new NGFLocalizedText('客户端应继续发送请求体', 'The client should continue sending the body'), 1);
  add(200, 'OK', new NGFLocalizedText('成功', 'OK'), new NGFLocalizedText('请求成功，响应体含预期内容', 'The request succeeded with the expected body'), 2);
  add(201, 'Created', new NGFLocalizedText('已创建', 'Created'), new NGFLocalizedText('资源创建成功，常用于 POST/PUT', 'The resource was created, usually by POST or PUT'), 2);
  add(204, 'No Content', new NGFLocalizedText('无内容', 'No content'), new NGFLocalizedText('成功但无响应体，常用于 DELETE', 'Success with no body, common with DELETE'), 2);
  add(301, 'Moved Permanently', new NGFLocalizedText('永久重定向', 'Moved permanently'), new NGFLocalizedText('资源已永久迁移，应更新书签与缓存', 'The resource moved for good, update bookmarks and cache'), 3);
  add(302, 'Found', new NGFLocalizedText('临时重定向', 'Found'), new NGFLocalizedText('资源临时在别的位置，缓存不应更新', 'The resource is temporarily elsewhere, do not cache'), 3);
  add(304, 'Not Modified', new NGFLocalizedText('未修改', 'Not modified'), new NGFLocalizedText('协商缓存命中，客户端用本地副本', 'Conditional cache hit, use the local copy'), 3);
  add(400, 'Bad Request', new NGFLocalizedText('请求无效', 'Bad request'), new NGFLocalizedText('参数格式错误或请求体不合法', 'Malformed parameters or body'), 4);
  add(401, 'Unauthorized', new NGFLocalizedText('未认证', 'Unauthorized'), new NGFLocalizedText('缺少或无效的认证凭证（如 Bearer Token 过期）', 'Missing or invalid credentials, such as an expired token'), 4);
  add(403, 'Forbidden', new NGFLocalizedText('已禁止', 'Forbidden'), new NGFLocalizedText('已认证但无权限访问该资源', 'Authenticated but not allowed to access'), 4);
  add(404, 'Not Found', new NGFLocalizedText('未找到', 'Not found'), new NGFLocalizedText('资源不存在或路径拼写错误', 'The resource does not exist or the path is wrong'), 4);
  add(405, 'Method Not Allowed', new NGFLocalizedText('方法不允许', 'Method not allowed'), new NGFLocalizedText('该资源不接受此 HTTP 方法', 'The resource rejects this HTTP method'), 4);
  add(408, 'Request Timeout', new NGFLocalizedText('请求超时', 'Request timeout'), new NGFLocalizedText('客户端发送请求体超时', 'The client took too long to send the body'), 4);
  add(409, 'Conflict', new NGFLocalizedText('冲突', 'Conflict'), new NGFLocalizedText('与资源当前状态冲突（如版本号过期）', 'Conflicts with the resource state, such as a stale version'), 4);
  add(413, 'Payload Too Large', new NGFLocalizedText('请求体过大', 'Payload too large'), new NGFLocalizedText('请求体超过服务端限制', 'The body exceeds the server limit'), 4);
  add(415, 'Unsupported Media Type', new NGFLocalizedText('不支持的媒体类型', 'Unsupported media type'), new NGFLocalizedText('Content-Type 不被接受', 'The Content-Type is not accepted'), 4);
  add(422, 'Unprocessable Entity', new NGFLocalizedText('无法处理的实体', 'Unprocessable entity'), new NGFLocalizedText('语法正确但语义校验失败', 'Valid syntax but failed semantic checks'), 4);
  add(429, 'Too Many Requests', new NGFLocalizedText('请求过多', 'Too many requests'), new NGFLocalizedText('触发限流，需退避重试', 'Rate limited, back off and retry'), 4);
  add(500, 'Internal Server Error', new NGFLocalizedText('服务器内部错误', 'Internal server error'), new NGFLocalizedText('服务端未捕获的异常', 'An uncaught server-side exception'), 5);
  add(501, 'Not Implemented', new NGFLocalizedText('未实现', 'Not implemented'), new NGFLocalizedText('服务端不支持该功能', 'The server does not support this feature'), 5);
  add(502, 'Bad Gateway', new NGFLocalizedText('网关错误', 'Bad gateway'), new NGFLocalizedText('上游服务返回无效响应', 'The upstream returned an invalid response'), 5);
  add(503, 'Service Unavailable', new NGFLocalizedText('服务不可用', 'Service unavailable'), new NGFLocalizedText('过载或维护中', 'Overloaded or under maintenance'), 5);
  add(504, 'Gateway Timeout', new NGFLocalizedText('网关超时', 'Gateway timeout'), new NGFLocalizedText('上游服务响应超时', 'The upstream took too long to respond'), 5);
  return list;
}

const TABLE: Array<HttpStatusEntry> = buildTable();

/** 全表（页面初始化展示用） */
export function allStatusEntries(): Array<HttpStatusEntry> {
  return TABLE;
}

/**
 * 查询：空关键词返回全表；
 * 纯数字按码精确匹配（含前缀模糊，如 40 匹配 400/401/403/404/405/408/409/429）；
 * 文本按关键词模糊匹配 name 与中文含义。
 */
export function queryStatus(keyword: string): HttpStatusQueryResult {
  const text: string = keyword.trim().toLowerCase();
  if (text.length === 0) {
    return new HttpStatusQueryResult(true, 'none', TABLE);
  }
  const isNumeric: boolean = /^[0-9]+$/.test(text);
  const out: Array<HttpStatusEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: HttpStatusEntry = TABLE[i];
    if (isNumeric) {
      if (String(e.code).indexOf(text) === 0) {
        out.push(e);
      }
    } else if (e.name.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.toLowerCase().indexOf(text) >= 0 || e.cause.zh.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new HttpStatusQueryResult(true, 'none', out);
}
