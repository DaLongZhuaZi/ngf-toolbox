/**
 * 二维码内容构造 —— 纯逻辑（零 import，可直接单测）。
 *
 * ## 这个模块负责什么、不负责什么
 *
 * 二维码的**绘制**由 ArkUI 内置的 QRCode 组件完成（这是框架能力，不需要我们实现编码算法）。
 * 而「二维码里到底放什么字符串」是纯粹的文本构造，也是一件二维码工具真正容易出错的地方：
 *
 * - Wi-Fi 二维码的格式是 \`WIFI:T:WPA;S:名称;P:密码;;\`，其中 \`;\` \`,\` \`:\` \`\\\`
 *   在名称与密码里**必须转义**，否则扫码会失败或解析出错误的密码；
 * - vCard 的换行必须是 CRLF，且字段里的换行与逗号也要转义；
 * - 电话号码、短信、邮件的 URI 格式各有各的规则。
 *
 * 这些都是「写错了也能生成一张看着没问题的二维码，但扫出来是错的」——
 * 正是最该被单测钉住的部分。因此本模块把每种内容类型的**格式构造与校验**
 * 全部收在纯逻辑里，页面只负责把结果显示出来。
 *
 * ## 为什么不做图片导出
 *
 * 把二维码存成图片需要组件截图（componentSnapshot）+ 文件读写 + 相册写入，
 * 那是一条依赖多个平台能力的链路。本工具选择只做「生成 + 复制文本 + 系统分享文本」，
 * 并在工具边界里**明说做不到导出图片**——把边界说清楚，比给一个半可用的导出按钮诚实。
 *
 * @module tools/qrcode/QrPayload
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 简写构造器：把「中文 / English」写成一行 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

/**
 * 二维码内容的类型。
 *
 * 取值同时用作页面上的选择项标识，因此是稳定的英文字符串。
 */
export enum QrContentKind {
  TEXT = 'text',
  URL = 'url',
  WIFI = 'wifi',
  VCARD = 'vcard',
  PHONE = 'phone',
  SMS = 'sms',
  EMAIL = 'email'
}

/** 一个内容类型的展示信息 */
export class QrKindInfo {
  readonly kind: QrContentKind;
  /** 类型名（双语数据，按 locale 取） */
  readonly label: NGFLocalizedText;
  /** 这个类型需要用户填哪些字段（用于页面动态渲染输入框） */
  readonly fields: Array<string>;

  constructor(kind: QrContentKind, label: NGFLocalizedText, fields: Array<string>) {
    this.kind = kind;
    this.label = label;
    this.fields = fields;
  }
}

/** 字段标识 */
export class QrField {
  static readonly TEXT: string = 'text';
  static readonly URL: string = 'url';
  static readonly SSID: string = 'ssid';
  static readonly PASSWORD: string = 'password';
  static readonly SECURITY: string = 'security';
  static readonly HIDDEN: string = 'hidden';
  static readonly NAME: string = 'name';
  static readonly ORG: string = 'org';
  static readonly TITLE: string = 'title';
  static readonly TEL: string = 'tel';
  static readonly EMAIL: string = 'email';
  static readonly ADDRESS: string = 'address';
  static readonly NOTE: string = 'note';
  static readonly PHONE: string = 'phone';
  static readonly BODY: string = 'body';
  static readonly SUBJECT: string = 'subject';
}

/** 全部内容类型及其字段 */
export function qrKinds(): Array<QrKindInfo> {
  const list: Array<QrKindInfo> = [];
  list.push(new QrKindInfo(QrContentKind.TEXT, l10n('纯文本', 'Plain text'),
    [QrField.TEXT]));
  list.push(new QrKindInfo(QrContentKind.URL, l10n('网址', 'URL'),
    [QrField.URL]));
  list.push(new QrKindInfo(QrContentKind.WIFI, l10n('Wi-Fi', 'Wi-Fi'),
    [QrField.SSID, QrField.PASSWORD, QrField.SECURITY]));
  list.push(new QrKindInfo(QrContentKind.VCARD, l10n('名片', 'Contact card'),
    [QrField.NAME, QrField.TEL, QrField.EMAIL, QrField.ORG, QrField.TITLE, QrField.ADDRESS]));
  list.push(new QrKindInfo(QrContentKind.PHONE, l10n('电话', 'Phone'),
    [QrField.PHONE]));
  list.push(new QrKindInfo(QrContentKind.SMS, l10n('短信', 'SMS'),
    [QrField.PHONE, QrField.BODY]));
  list.push(new QrKindInfo(QrContentKind.EMAIL, l10n('邮件', 'Email'),
    [QrField.EMAIL, QrField.SUBJECT, QrField.BODY]));
  return list;
}

/** Wi-Fi 加密方式 */
export class QrWifiSecurity {
  static readonly WPA: string = 'WPA';
  static readonly WEP: string = 'WEP';
  static readonly NONE: string = 'nopass';
}

/** 一种类型需要的全部输入（用 Map 而不是展开参数：字段数量不一，且页面是动态表单） */
export class QrInput {
  private readonly values: Map<string, string> = new Map<string, string>();

  set(field: string, value: string): QrInput {
    this.values.set(field, value);
    return this;
  }

  get(field: string): string {
    const value: string | undefined = this.values.get(field);
    return value === undefined ? '' : value;
  }

  /** 取字段并去掉首尾空白（绝大多数字段都该 trim） */
  trimmed(field: string): string {
    return this.get(field).trim();
  }
}

/** 构造失败的原因码 */
export enum QrPayloadFailure {
  NONE = 'none',
  WIFI_SSID_REQUIRED = 'wifi_ssid_required',
  WIFI_PASSWORD_REQUIRED = 'wifi_password_required',
  VCARD_NAME_REQUIRED = 'vcard_name_required',
  URL_REQUIRED = 'url_required',
  URL_INVALID = 'url_invalid',
  TEXT_REQUIRED = 'text_required',
  PHONE_REQUIRED = 'phone_required',
  PHONE_NO_DIGITS = 'phone_no_digits',
  SMS_PHONE_REQUIRED = 'sms_phone_required',
  EMAIL_REQUIRED = 'email_required',
  EMAIL_INVALID = 'email_invalid'
}

/**
 * 构造结果。
 *
 * 注意这里**没有** `kindLabel` 了：原先成功结果要带上「扫出来会被识别成什么」的一句话，
 * 但那句话就是请求里那个 kind 的显示名，页面本来就知道 kind。
 * 让纯逻辑回传一个已经翻译好的字符串，等于把 UI 的活挪进了逻辑层。
 */
export class QrPayloadResult {
  readonly ok: boolean;
  readonly failure: QrPayloadFailure;
  readonly args: Array<string>;
  readonly payload: string;

  constructor(ok: boolean, failure: QrPayloadFailure, args: Array<string>, payload: string) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.payload = payload;
  }

  static success(payload: string): QrPayloadResult {
    return new QrPayloadResult(true, QrPayloadFailure.NONE, [], payload);
  }

  static fail(failure: QrPayloadFailure): QrPayloadResult {
    return new QrPayloadResult(false, failure, [], '');
  }
}

/**
 * 转义 Wi-Fi 字段里的特殊字符。
 *
 * ## 这是本模块最要紧的一个函数
 *
 * Wi-Fi 二维码的字段分隔符是 \`;\`，键值分隔符是 \`:\`，列表分隔符是 \`,\`，
 * 转义符是 \`\\\`。如果用户的路由器密码里含有这些字符（很常见，例如 \`abc;123\`），
 * 不转义就会让解析方在错误的位置截断——扫出来的密码是错的，
 * 而用户看到的只是一张「生成成功」的二维码，很难联想到是转义问题。
 *
 * 转义顺序也重要：必须**先转义反斜杠**，再转义其它字符，
 * 否则会把刚加上的转义符再转义一遍。
 */
export function escapeWifiValue(value: string): string {
  let result: string = '';
  for (let i: number = 0; i < value.length; i++) {
    const ch: string = value.charAt(i);
    if (ch === '\\' || ch === ';' || ch === ',' || ch === ':' || ch === '"') {
      result += '\\' + ch;
    } else {
      result += ch;
    }
  }
  return result;
}

/**
 * 构造 Wi-Fi 二维码内容。
 *
 * 格式：\`WIFI:T:<加密>;S:<名称>;P:<密码>;H:<是否隐藏>;;\`
 * 末尾的两个分号是格式的一部分（表示记录结束），漏掉它部分扫码器会解析失败。
 */
export function buildWifiPayload(input: QrInput): QrPayloadResult {
  const ssid: string = input.trimmed(QrField.SSID);
  if (ssid.length === 0) {
    return QrPayloadResult.fail(QrPayloadFailure.WIFI_SSID_REQUIRED);
  }
  const security: string = input.trimmed(QrField.SECURITY);
  const effectiveSecurity: string = security.length === 0 ? QrWifiSecurity.WPA : security;
  const password: string = input.get(QrField.PASSWORD);

  if (effectiveSecurity !== QrWifiSecurity.NONE && password.length === 0) {
    return QrPayloadResult.fail(QrPayloadFailure.WIFI_PASSWORD_REQUIRED);
  }

  let payload: string = 'WIFI:T:' + effectiveSecurity + ';';
  payload += 'S:' + escapeWifiValue(ssid) + ';';
  if (effectiveSecurity !== QrWifiSecurity.NONE) {
    payload += 'P:' + escapeWifiValue(password) + ';';
  }
  if (input.trimmed(QrField.HIDDEN).length > 0) {
    payload += 'H:true;';
  }
  payload += ';';
  return QrPayloadResult.success(payload);
}

/**
 * 转义 vCard 字段值。
 *
 * vCard 里需要转义的是 \`\\\` \`;\` \`,\` 与换行。
 */
export function escapeVCardValue(value: string): string {
  let result: string = '';
  for (let i: number = 0; i < value.length; i++) {
    const ch: string = value.charAt(i);
    if (ch === '\\' || ch === ';' || ch === ',') {
      result += '\\' + ch;
      continue;
    }
    if (ch === '\r') {
      continue;
    }
    if (ch === '\n') {
      result += '\\n';
      continue;
    }
    result += ch;
  }
  return result;
}

/**
 * 构造 vCard 3.0 名片内容。
 *
 * ## 为什么是 CRLF
 *
 * vCard 规范要求行分隔符是 \`\r\n\`（不是 \`\n\`）。用 \`\n\` 时，
 * 严格一点的解析器会把整张名片当成一行，结果只识别出姓名字段——
 * 用户看到的是「扫码只出来一个名字」，很难猜到是行尾的问题。
 */
export function buildVCardPayload(input: QrInput): QrPayloadResult {
  const name: string = input.trimmed(QrField.NAME);
  if (name.length === 0) {
    return QrPayloadResult.fail(QrPayloadFailure.VCARD_NAME_REQUIRED);
  }
  const tel: string = input.trimmed(QrField.TEL);
  const email: string = input.trimmed(QrField.EMAIL);
  const org: string = input.trimmed(QrField.ORG);
  const title: string = input.trimmed(QrField.TITLE);
  const address: string = input.trimmed(QrField.ADDRESS);

  const lines: Array<string> = [];
  lines.push('BEGIN:VCARD');
  lines.push('VERSION:3.0');
  lines.push('FN:' + escapeVCardValue(name));
  // N 是结构化姓名（姓;名），这里没有分开收集，按「整串当姓」给出，
  // 保证至少有一个合法值（缺 N 字段时部分解析器会拒收整张名片）。
  lines.push('N:' + escapeVCardValue(name) + ';');
  if (org.length > 0) {
    lines.push('ORG:' + escapeVCardValue(org));
  }
  if (title.length > 0) {
    lines.push('TITLE:' + escapeVCardValue(title));
  }
  if (tel.length > 0) {
    lines.push('TEL;TYPE=CELL:' + escapeVCardValue(tel));
  }
  if (email.length > 0) {
    lines.push('EMAIL:' + escapeVCardValue(email));
  }
  if (address.length > 0) {
    lines.push('ADR:;;' + escapeVCardValue(address) + ';;;;');
  }
  lines.push('END:VCARD');
  return QrPayloadResult.success(lines.join('\r\n'));
}

/**
 * 补全网址的协议前缀。
 *
 * 用户输入 \`example.com\` 时，很多扫码器会把它当成纯文本而不是链接。
 * 补上 \`https://\` 让扫码结果可点。**只**在完全没有协议时补，
 * 且保留用户自己写的 \`http://\`（内网服务常用 http，不能擅自改成 https）。
 */
export function normalizeUrl(raw: string): string {
  const trimmed: string = raw.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const lower: string = trimmed.toLowerCase();
  if (lower.indexOf('http://') === 0 || lower.indexOf('https://') === 0) {
    return trimmed;
  }
  // 其它协议（例如 mailto:、tel:、ftp:）原样保留
  if (lower.indexOf('://') > 0 || lower.indexOf(':') > 0 && lower.indexOf(':') < 12) {
    return trimmed;
  }
  return 'https://' + trimmed;
}

/** 构造网址内容 */
export function buildUrlPayload(input: QrInput): QrPayloadResult {
  const raw: string = input.trimmed(QrField.URL);
  if (raw.length === 0) {
    return QrPayloadResult.fail(QrPayloadFailure.URL_REQUIRED);
  }
  // 判据必须看**用户原文**，不能看补全后的结果：
  // normalizeUrl 会给任何东西补上 'https://'，补完之后一定含 '.' 与 ':'，
  // 拿补全结果做判断等于永远放行（第一版就是这么错的，'notaurl' 也通过了）。
  // 原文里既没有点也没有冒号，那基本不是网址。
  if (raw.indexOf('.') < 0 && raw.indexOf(':') < 0) {
    return QrPayloadResult.fail(QrPayloadFailure.URL_INVALID);
  }
  return QrPayloadResult.success(normalizeUrl(raw));
}

/** 构造纯文本内容 */
export function buildTextPayload(input: QrInput): QrPayloadResult {
  const text: string = input.get(QrField.TEXT);
  if (text.length === 0) {
    return QrPayloadResult.fail(QrPayloadFailure.TEXT_REQUIRED);
  }
  return QrPayloadResult.success(text);
}

/**
 * 去除电话号码里的分隔符。
 *
 * 用户从通讯录拷来的号码常带空格、短横线、括号。
 * 但**保留开头的 +**：那是国际区号标记，去掉会改变号码含义。
 */
export function normalizePhone(raw: string): string {
  const trimmed: string = raw.trim();
  let result: string = '';
  for (let i: number = 0; i < trimmed.length; i++) {
    const ch: string = trimmed.charAt(i);
    if (ch === '+' && result.length === 0) {
      result += '+';
      continue;
    }
    const code: number = trimmed.charCodeAt(i);
    if (code >= 48 && code <= 57) {
      result += ch;
    }
  }
  return result;
}

/** 构造电话号码内容 */
export function buildPhonePayload(input: QrInput): QrPayloadResult {
  const normalized: string = normalizePhone(input.trimmed(QrField.PHONE));
  if (normalized.length === 0) {
    return QrPayloadResult.fail(QrPayloadFailure.PHONE_REQUIRED);
  }
  // 只有 + 没有数字
  if (normalized === '+') {
    return QrPayloadResult.fail(QrPayloadFailure.PHONE_NO_DIGITS);
  }
  return QrPayloadResult.success('tel:' + normalized);
}

/** 构造短信内容 */
export function buildSmsPayload(input: QrInput): QrPayloadResult {
  const phone: string = normalizePhone(input.trimmed(QrField.PHONE));
  if (phone.length === 0 || phone === '+') {
    return QrPayloadResult.fail(QrPayloadFailure.SMS_PHONE_REQUIRED);
  }
  const body: string = input.get(QrField.BODY);
  if (body.length === 0) {
    return QrPayloadResult.success('SMSTO:' + phone);
  }
  // SMSTO 用冒号分隔号码与正文；正文里的冒号不需要特殊处理（取第一个冒号之后都是正文）
  return QrPayloadResult.success('SMSTO:' + phone + ':' + body);
}

/** 构造邮件内容 */
export function buildEmailPayload(input: QrInput): QrPayloadResult {
  const email: string = input.trimmed(QrField.EMAIL);
  if (email.length === 0) {
    return QrPayloadResult.fail(QrPayloadFailure.EMAIL_REQUIRED);
  }
  // 只做最基本的形状检查：必须有 @ 且两边都不为空
  const at: number = email.indexOf('@');
  if (at <= 0 || at >= email.length - 1) {
    return QrPayloadResult.fail(QrPayloadFailure.EMAIL_INVALID);
  }
  const subject: string = input.get(QrField.SUBJECT);
  const body: string = input.get(QrField.BODY);
  let payload: string = 'mailto:' + email;
  const params: Array<string> = [];
  if (subject.length > 0) {
    params.push('subject=' + encodeUrlComponent(subject));
  }
  if (body.length > 0) {
    params.push('body=' + encodeUrlComponent(body));
  }
  if (params.length > 0) {
    payload += '?' + params.join('&');
  }
  return QrPayloadResult.success(payload);
}

/**
 * URL 编码（mailto 的查询参数需要）。
 *
 * 自己实现而不是用 \`encodeURIComponent\`：后者是宿主环境的实现，
 * 在纯逻辑层调用它会让本模块的行为依赖运行环境。
 * 这里只编码 RFC 3986 里「非 unreserved」的字符，规则固定且可单测。
 */
export function encodeUrlComponent(value: string): string {
  const digits: string = '0123456789ABCDEF';
  let result: string = '';
  let i: number = 0;
  while (i < value.length) {
    const code: number = value.charCodeAt(i);

    // ASCII 快速路径：字母数字与 RFC 3986 的 unreserved 字符原样保留。
    if (code < 0x80) {
      const ch: string = value.charAt(i);
      const isAlphaNumeric: boolean =
        (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
      const isUnreserved: boolean = ch === '-' || ch === '_' || ch === '.' || ch === '~';
      if (isAlphaNumeric || isUnreserved) {
        result += ch;
      } else {
        result += '%' + digits.charAt(Math.floor(code / 16)) + digits.charAt(code % 16);
      }
      i += 1;
      continue;
    }

    // 非 ASCII：必须按**码点**取 UTF-8 字节，而不是按 UTF-16 码元逐个取。
    //
    // 这是本函数唯一容易写错的地方：emoji 这类字符在 UTF-16 里占两个码元（代理对），
    // 若对每个码元分别编码，会得到 %ED%A0%BC%ED%BE%89 这种「把两个代理各自编码」的结果，
    // 而不是正确的四字节 %F0%9F%8E%89。它与正确结果长得挺像，肉眼极难发现，
    // 但接收方解码出来是乱码或直接失败。
    let unitLength: number = 1;
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length) {
      const next: number = value.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        unitLength = 2;
      }
    }
    const chunk: string = value.substring(i, i + unitLength);
    const bytes: Array<number> = utf8BytesOf(chunk);
    for (let k: number = 0; k < bytes.length; k++) {
      const byte: number = bytes[k];
      result += '%' + digits.charAt(Math.floor(byte / 16)) + digits.charAt(byte % 16);
    }
    i += unitLength;
  }
  return result;
}

/** 取一个字符的 UTF-8 字节序列（本模块内部用，不依赖任何设备能力） */
function utf8BytesOf(text: string): Array<number> {
  const bytes: Array<number> = [];
  for (let i: number = 0; i < text.length; i++) {
    let code: number = text.charCodeAt(i);
    // 代理对：把高低代理合成真正的码点
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < text.length) {
      const next: number = text.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        code = 0x10000 + ((code - 0xD800) << 10) + (next - 0xDC00);
        i++;
      }
    }
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xC0 | (code >> 6));
      bytes.push(0x80 | (code & 0x3F));
    } else if (code < 0x10000) {
      bytes.push(0xE0 | (code >> 12));
      bytes.push(0x80 | ((code >> 6) & 0x3F));
      bytes.push(0x80 | (code & 0x3F));
    } else {
      bytes.push(0xF0 | (code >> 18));
      bytes.push(0x80 | ((code >> 12) & 0x3F));
      bytes.push(0x80 | ((code >> 6) & 0x3F));
      bytes.push(0x80 | (code & 0x3F));
    }
  }
  return bytes;
}

/**
 * 按类型构造二维码内容。
 *
 * 这是页面唯一需要调用的入口；每种类型的细节都在上面各自的函数里。
 */
export function buildPayload(kind: QrContentKind, input: QrInput): QrPayloadResult {
  if (kind === QrContentKind.WIFI) {
    return buildWifiPayload(input);
  }
  if (kind === QrContentKind.VCARD) {
    return buildVCardPayload(input);
  }
  if (kind === QrContentKind.URL) {
    return buildUrlPayload(input);
  }
  if (kind === QrContentKind.PHONE) {
    return buildPhonePayload(input);
  }
  if (kind === QrContentKind.SMS) {
    return buildSmsPayload(input);
  }
  if (kind === QrContentKind.EMAIL) {
    return buildEmailPayload(input);
  }
  return buildTextPayload(input);
}

/**
 * 内容长度提示。
 *
 * 二维码容量随纠错级别与编码方式变化，没有一条对所有扫码器都成立的硬上限；
 * 但太长会显著降低识别率，且很多扫码器在几百字符后就开始失败。
 * 因此这里只给**提示**而不拒绝——用户要放长文本是他的选择，
 * 但界面有责任让他知道「这么长可能扫不出来」。
 */
export const QR_COMFORTABLE_LENGTH: number = 300;

/**
 * 长度提示的**结构化**结果。
 *
 * 原先 lengthNotice 直接返回拼好的一句中文，超出时才有内容、没超出返回空串。
 * 现在返回布尔量 + 两个数字，措辞归 UI 层——
 * 「内容有 N 个字符，已超出……（约 M 字符）」这句话里的数字位置与量词
 * 中英不一样，而且 N 与 M 的**顺序**在译文里可能反过来。
 */
export class QrLengthNotice {
  readonly tooLong: boolean;
  readonly length: number;
  readonly comfortable: number;

  constructor(tooLong: boolean, length: number, comfortable: number) {
    this.tooLong = tooLong;
    this.length = length;
    this.comfortable = comfortable;
  }
}

/** 缩短建议的码 */
export enum QrHintCode {
  NONE = 'none',
  /** 网址太长，建议换个短地址 */
  LONG_URL = 'long_url',
  /** 内容是网址但选了「纯文本」，建议改用「网址」类型 */
  COULD_BE_URL = 'could_be_url'
}

/** 长度提示文案；不需要提示时返回空串 */
export function lengthNotice(payload: string): QrLengthNotice {
  if (payload.length <= QR_COMFORTABLE_LENGTH) {
    return new QrLengthNotice(false, payload.length, QR_COMFORTABLE_LENGTH);
  }
  return new QrLengthNotice(true, payload.length, QR_COMFORTABLE_LENGTH);
}

/**
 * 生成同样内容的一种「更短写法」建议。
 *
 * 只针对最常见的一种情况给建议：纯文本里放了很长的网址——
 * 那通常可以用短链代替。**不联网做短链**（本 App 不提供该能力），
 * 所以这里只是提示用户自己去缩短，不给具体链接。
 */
export function shorteningHint(kind: QrContentKind, payload: string): QrHintCode {
  if (payload.length <= QR_COMFORTABLE_LENGTH) {
    return QrHintCode.NONE;
  }
  if (kind === QrContentKind.URL) {
    return QrHintCode.LONG_URL;
  }
  if (kind === QrContentKind.TEXT) {
    return QrHintCode.COULD_BE_URL;
  }
  return QrHintCode.NONE;
}