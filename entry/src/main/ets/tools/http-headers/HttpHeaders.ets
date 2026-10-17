/**
 * HTTP 头速查的纯逻辑实现（本地数据表，与 http-status 同构）。
 *
 * ## 数据口径
 *
 * 收录**开发调试高频**的请求/响应头（约 24 个），不是 RFC 全量：
 * 每条带「方向（请求/响应/两者）+ 含义 + 常见值示例」。
 *
 * ## 查询
 *
 * 关键词模糊匹配头名与中文含义，忽略大小写；另可按方向过滤。
 *
 * @module tools/http-headers/HttpHeaders
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 头的方向 */
export enum HttpHeaderDirection {
  REQUEST = 'request',
  RESPONSE = 'response',
  BOTH = 'both'
}

/** 一个头的条目 */
export class HttpHeaderEntry {
  readonly name: string;
  readonly direction: HttpHeaderDirection;
  readonly meaning: NGFLocalizedText;
  readonly example: string;

  constructor(name: string, direction: HttpHeaderDirection, meaning: NGFLocalizedText, example: string) {
    this.name = name;
    this.direction = direction;
    this.meaning = meaning;
    this.example = example;
  }
}

/** 查询结果 */
export class HttpHeadersQueryResult {
  readonly entries: Array<HttpHeaderEntry>;

  constructor(entries: Array<HttpHeaderEntry>) {
    this.entries = entries;
  }
}

function buildTable(): Array<HttpHeaderEntry> {
  const list: Array<HttpHeaderEntry> = [];
  const add = (name: string, d: HttpHeaderDirection, meaning: NGFLocalizedText, example: string): void => {
  list.push(new HttpHeaderEntry(name, d, meaning, example));
  };
  add('Authorization', HttpHeaderDirection.REQUEST, new NGFLocalizedText('认证凭证（Bearer/Basic）', 'Auth credentials (Bearer/Basic)'), 'Bearer eyJhbGci...');
  add('Content-Type', HttpHeaderDirection.BOTH, new NGFLocalizedText('请求体的媒体类型', 'Media type of the body'), 'application/json; charset=utf-8');
  add('Content-Length', HttpHeaderDirection.BOTH, new NGFLocalizedText('请求体字节数', 'Body size in bytes'), '1024');
  add('Accept', HttpHeaderDirection.REQUEST, new NGFLocalizedText('客户端可接受的响应类型', 'Response types the client accepts'), 'application/json');
  add('Accept-Language', HttpHeaderDirection.REQUEST, new NGFLocalizedText('可接受的语言', 'Languages the client accepts'), 'zh-CN, en;q=0.8');
  add('Accept-Encoding', HttpHeaderDirection.REQUEST, new NGFLocalizedText('可接受的压缩算法', 'Accepted compression methods'), 'gzip, deflate, br');
  add('Cookie', HttpHeaderDirection.REQUEST, new NGFLocalizedText('客户端存储的 Cookie', 'Cookies stored by the client'), 'session=abc123');
  add('User-Agent', HttpHeaderDirection.REQUEST, new NGFLocalizedText('客户端标识', 'Client identifier'), 'Mozilla/5.0 ...');
  add('Cache-Control', HttpHeaderDirection.BOTH, new NGFLocalizedText('缓存策略', 'Caching policy'), 'no-cache / max-age=3600');
  add('If-None-Match', HttpHeaderDirection.REQUEST, new NGFLocalizedText('协商缓存：比对 ETag', 'Conditional request by ETag'), String.fromCharCode(34) + 'abc123' + String.fromCharCode(34));
  add('If-Modified-Since', HttpHeaderDirection.REQUEST, new NGFLocalizedText('协商缓存：比对修改时间', 'Conditional request by date'), 'Wed, 01 Jan 2025 00:00:00 GMT');
  add('Origin', HttpHeaderDirection.REQUEST, new NGFLocalizedText('跨域请求的来源', 'Origin of the cross-site request'), 'https://example.test');
  add('ETag', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('资源指纹（协商缓存）', 'Resource fingerprint (conditional caching)'), String.fromCharCode(34) + 'abc123' + String.fromCharCode(34));
  add('Location', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('重定向的目标地址', 'Redirect target URL'), 'https://example.test/new');
  add('Set-Cookie', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('服务端下发 Cookie', 'Cookies set by the server'), 'session=abc123; HttpOnly');
  add('Retry-After', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('限流后建议的重试间隔', 'Suggested retry after throttling'), '30');
  add('X-Request-Id', HttpHeaderDirection.BOTH, new NGFLocalizedText('链路追踪 ID', 'Trace correlation ID'), 'b7ad-4c2e-9f1a');
  add('X-Forwarded-For', HttpHeaderDirection.REQUEST, new NGFLocalizedText('经过的代理链客户端 IP', 'Client IP through the proxy chain'), '203.0.113.5, 70.41.3.18');
  add('Access-Control-Allow-Origin', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('CORS 允许的来源', 'CORS allowed origins'), '* 或 https://example.test');
  add('Access-Control-Allow-Methods', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('CORS 允许的方法', 'CORS allowed methods'), 'GET, POST, PUT');
  add('WWW-Authenticate', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('认证挑战（401 时返回）', 'Auth challenge (returned with 401)'), 'Bearer realm=' + String.fromCharCode(34) + 'api' + String.fromCharCode(34));
  add('Strict-Transport-Security', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('强制 HTTPS（HSTS）', 'Force HTTPS (HSTS)'), 'max-age=31536000; includeSubDomains');
  add('X-Content-Type-Options', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('禁止 MIME 嗅探', 'Disable MIME sniffing'), 'nosniff');
  add('Server', HttpHeaderDirection.RESPONSE, new NGFLocalizedText('服务器软件标识', 'Server software identifier'), 'nginx/1.25.0');
  return list;
}

const TABLE: Array<HttpHeaderEntry> = buildTable();

/** 全表 */
export function allHeaderEntries(): Array<HttpHeaderEntry> {
  return TABLE;
}

/** 头名数（README 引用） */
export function headerCount(): number {
  return TABLE.length;
}

/** 查询：空关键词全表；文本模糊匹配头名/中文含义；方向可选过滤 */
export function queryHeaders(keyword: string, direction: HttpHeaderDirection | null): HttpHeadersQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<HttpHeaderEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: HttpHeaderEntry = TABLE[i];
    if (direction !== null && e.direction !== direction && e.direction !== HttpHeaderDirection.BOTH) {
      continue;
    }
    if (text.length === 0 ||
      e.name.toLowerCase().indexOf(text) >= 0 || e.meaning.zh.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new HttpHeadersQueryResult(out);
}
