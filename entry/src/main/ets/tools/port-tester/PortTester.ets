/**
 * 端口测试 —— 纯逻辑（零 import，可直接单测）。
 *
 * ## 本工具是全 App 唯一会联网的功能
 *
 * 产品定义稿 §四 与项目规则 PR-002/PR-003 只允许「端口测试」连接网络，
 * 且必须在页面内明示。因此本模块的设计原则是：**把一切能离线判定的东西都离线判定**。
 *
 * 具体地说，真正需要设备的只有「建立 TCP 连接」那一步。而下面这些全部是纯逻辑，
 * 可以在本机单测：
 * - 输入解析（host:port、批量端口、端口范围）；
 * - 目标合法性判定（非法主机名、端口越界、超长输入）；
 * - 我们自己就能给出的结论（端口 0 无意义、保留端口提示、同一目标重复）；
 * - 超时与并发上限的夹取；
 * - 错误码到人话的翻译。
 *
 * 这样做的收益不只是「好测试」：**能在联网前挡掉的输入就一定不联网**，
 * 用户的隐私与流量都省下来了，也避免了对无效目标白等超时。
 *
 * @module tools/port-tester/PortTester
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 合法端口范围 */
export const PORT_MIN: number = 1;
export const PORT_MAX: number = 65535;

/** 超时范围（毫秒）：低于 300ms 在移动网络上几乎必然误判为不通，高于 10s 用户已经走开了 */
export const TIMEOUT_MIN_MS: number = 300;
export const TIMEOUT_MAX_MS: number = 10000;
export const TIMEOUT_DEFAULT_MS: number = 3000;

/**
 * 单次批量测试的端口上限。
 *
 * 为什么是 64：这是「够用」与「不滥用」之间的线。
 * 一次测几十个端口是排查服务的正常需求；一次测几千个端口，
 * 无论用户意图如何，客观上已经是在做端口扫描了——本工具明确不做那件事
 * （见工具边界），所以在这里也要挡住。
 */
export const BATCH_PORT_LIMIT: number = 64;

/** 主机名最大长度（DNS 域名上限 253，留点余量给误输入但也不要无限长） */
export const HOST_MAX_LENGTH: number = 253;

/** 一个待测目标 */
export class PortTarget {
  /** 用户输入的主机（原样保留，用于展示与错误信息） */
  readonly host: string;
  readonly port: number;
  /** 若该端口来自常用端口预设，这里是它的用途说明，否则空串 */
  // serviceLabel 已移除：用途名是文案，页面在渲染时按端口号取（见 PortMessages）

  constructor(host: string, port: number) {
    this.host = host;
    this.port = port;
  }

  /** 用于展示的 host:port；IPv6 字面量加方括号 */
  get display(): string {
    const needsBrackets: boolean = this.host.indexOf(':') >= 0;
    return (needsBrackets ? '[' + this.host + ']' : this.host) + ':' + String(this.port);
  }
}

/** 解析失败的原因 */
export enum PortParseFailure {
  EMPTY = 'empty',
  NO_PORT = 'no_port',
  BAD_HOST = 'bad_host',
  BAD_PORT = 'bad_port',
  PORT_RANGE = 'port_range',
  TOO_MANY_PORTS = 'too_many_ports',
  TOO_LONG = 'too_long',
  /** 带 http:// 这类协议前缀（最常见的粘错方式） */
  PROTOCOL_PREFIX = 'protocol_prefix',
  /** IPv6 字面量没加方括号（以 [ 开头但没找到 ]） */
  IPV6_UNCLOSED = 'ipv6_unclosed',
  /** 主句里有多个冒号，多半是没加括号的 IPv6 */
  MULTIPLE_COLONS = 'multiple_colons',
  /** 端口区间写法不对（应为 起始-结束） */
  RANGE_SYNTAX = 'range_syntax',
  /** 端口区间起始大于结束 */
  RANGE_REVERSED = 'range_reversed',
  /** 端口区间展开后超过一次上限 */
  RANGE_TOO_MANY = 'range_too_many',
  /** 端口不是整数或超出 1-65535 */
  PORT_NOT_INTEGER = 'port_not_integer'
}

/** 解析结果 */
export class PortParseResult {
  readonly ok: boolean;
  readonly failure: PortParseFailure;
  /** 资源文案的占位符参数（顺序须与资源文案里 %s 一致） */
  readonly args: Array<string>;
  readonly targets: Array<PortTarget>;

  constructor(ok: boolean, failure: PortParseFailure, args: Array<string>,
    targets: Array<PortTarget>) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.targets = targets;
  }

  static success(targets: Array<PortTarget>): PortParseResult {
    return new PortParseResult(true, PortParseFailure.EMPTY, [], targets);
  }

  static fail(failure: PortParseFailure, args: Array<string>): PortParseResult {
    return new PortParseResult(false, failure, args, []);
  }
}

/** 常用端口预设：端口 + 用途 */
export class PortPreset {
  readonly port: number;
  /** 用途名（双语数据，按 locale 取） */
  readonly label: NGFLocalizedText;

  constructor(port: number, label: NGFLocalizedText) {
    this.port = port;
    this.label = label;
  }
}

/** 简写构造器：把「中文 / English」写成一行 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

/**
 * 常用端口清单。
 *
 * 只收录「开发者会去连」的端口（Web、数据库、缓存、消息队列、远程登录、常见开发服务），
 * 不收录任何扫描器式的清单（例如各类漏洞服务的端口）。
 * 这不是技术限制，而是产品边界：本工具是「测我自己的服务通不通」，
 * 不是「找一个能打的端口」。
 */
export function portPresets(): Array<PortPreset> {
  const list: Array<PortPreset> = [];
  list.push(new PortPreset(80, l10n('HTTP', 'HTTP')));
  list.push(new PortPreset(443, l10n('HTTPS', 'HTTPS')));
  list.push(new PortPreset(8080, l10n('HTTP 备用', 'HTTP alternative')));
  list.push(new PortPreset(8443, l10n('HTTPS 备用', 'HTTPS alternative')));
  list.push(new PortPreset(22, l10n('SSH', 'SSH')));
  list.push(new PortPreset(21, l10n('FTP', 'FTP')));
  list.push(new PortPreset(23, l10n('Telnet', 'Telnet')));
  list.push(new PortPreset(25, l10n('SMTP', 'SMTP')));
  list.push(new PortPreset(53, l10n('DNS', 'DNS')));
  list.push(new PortPreset(3306, l10n('MySQL', 'MySQL')));
  list.push(new PortPreset(5432, l10n('PostgreSQL', 'PostgreSQL')));
  list.push(new PortPreset(6379, l10n('Redis', 'Redis')));
  list.push(new PortPreset(27017, l10n('MongoDB', 'MongoDB')));
  list.push(new PortPreset(9200, l10n('Elasticsearch', 'Elasticsearch')));
  list.push(new PortPreset(5672, l10n('RabbitMQ', 'RabbitMQ')));
  list.push(new PortPreset(9092, l10n('Kafka', 'Kafka')));
  list.push(new PortPreset(3000, l10n('前端开发服务', 'Front-end dev server')));
  list.push(new PortPreset(5000, l10n('开发服务', 'Dev server')));
  list.push(new PortPreset(8000, l10n('开发服务', 'Dev server')));
  list.push(new PortPreset(9000, l10n('开发服务', 'Dev server')));
  return list;
}

/** 按端口号查用途说明；没有则返回空串 */
export function serviceLabelOf(port: number): NGFLocalizedText | null {
  const list: Array<PortPreset> = portPresets();
  for (let i: number = 0; i < list.length; i++) {
    if (list[i].port === port) {
      return list[i].label;
    }
  }
  // 返回 null 而不是空串：类型上说清楚「没有这个预设」，
  // 免得调用方对一个 string 调 forLocale 才在运行期炸。
  return null;
}

/**
 * 判断主机名是否「看起来合法」。
 *
 * 刻意**宽松**：真正的主机名合法性只有 DNS 解析才知道，
 * 在这里做严格校验（例如禁止下划线）会误伤内网主机名与容器服务名。
 * 这里只挡住明显不可能的东西：空白、控制字符、以及纯符号。
 */
export function isValidHost(host: string): boolean {
  const trimmed: string = host.trim();
  if (trimmed.length === 0 || trimmed.length > HOST_MAX_LENGTH) {
    return false;
  }
  // 不允许任何空白（含中间）：出现空白基本是把两段输入粘在了一起
  for (let i: number = 0; i < trimmed.length; i++) {
    const code: number = trimmed.charCodeAt(i);
    if (code <= 32 || code === 127) {
      return false;
    }
  }
  // 至少要有一个字母或数字
  let hasAlphanumeric: boolean = false;
  for (let i: number = 0; i < trimmed.length; i++) {
    const ch: string = trimmed.charAt(i);
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')) {
      hasAlphanumeric = true;
      break;
    }
  }
  return hasAlphanumeric;
}

/** 端口号是否合法 */
export function isValidPort(port: number): boolean {
  if (isNaN(port) || Math.floor(port) !== port) {
    return false;
  }
  return port >= PORT_MIN && port <= PORT_MAX;
}

/** 把超时夹到允许范围 */
export function clampTimeout(timeoutMs: number): number {
  if (isNaN(timeoutMs)) {
    return TIMEOUT_DEFAULT_MS;
  }
  if (timeoutMs < TIMEOUT_MIN_MS) {
    return TIMEOUT_MIN_MS;
  }
  return timeoutMs > TIMEOUT_MAX_MS ? TIMEOUT_MAX_MS : timeoutMs;
}

/**
 * 解析用户输入。
 *
 * 支持的写法（刻意多收几种，因为用户会从各处粘）：
 * - \`example.com:443\`
 * - \`example.com:80,443,8080\`（逗号分隔）
 * - \`example.com:8000-8010\`（范围，上限见 {@link BATCH_PORT_LIMIT}）
 * - \`example.com 443\`（空格分隔）
 * - \`[::1]:443\`（IPv6 字面量，用方括号包起来）
 */
export function parseTargets(input: string): PortParseResult {
  const trimmed: string = input.trim();
  if (trimmed.length === 0) {
    return PortParseResult.fail(PortParseFailure.EMPTY, []);
  }
  if (trimmed.length > 512) {
    return PortParseResult.fail(PortParseFailure.TOO_LONG, []);
  }
  // 带协议前缀是最常见的粘错方式（从浏览器地址栏复制）。
  // 必须**明确拒绝**而不是让它蒙混过去：'http://example.com:443' 里的第一个冒号会把
  // host 解析成 'http'，那是个合法形状的主机名，于是本工具会去连一个叫 "http" 的主机——
  // 既不报错也连不通，用户只会以为"网络有问题"。
  if (trimmed.indexOf('://') > 0) {
    return PortParseResult.fail(PortParseFailure.PROTOCOL_PREFIX, []);
  }

  // 拆出主机与端口部分
  let host: string = '';
  let portText: string = '';
  if (trimmed.charAt(0) === '[') {
    // IPv6 字面量：[::1]:443
    const closeBracket: number = trimmed.indexOf(']');
    if (closeBracket < 0) {
      return PortParseResult.fail(PortParseFailure.IPV6_UNCLOSED, []);
    }
    host = trimmed.substring(1, closeBracket);
    const rest: string = trimmed.substring(closeBracket + 1);
    if (rest.length === 0 || (rest.charAt(0) !== ':' && rest.charAt(0) !== ' ')) {
      return PortParseResult.fail(PortParseFailure.NO_PORT, []);
    }
    portText = rest.substring(1).trim();
  } else {
    const separator: number = findSeparator(trimmed);
    if (separator === -2) {
      // 主机里出现多个冒号又没有方括号：基本是没加括号的 IPv6 字面量
      return PortParseResult.fail(PortParseFailure.MULTIPLE_COLONS, []);
    }
    if (separator < 0) {
      return PortParseResult.fail(PortParseFailure.NO_PORT, []);
    }
    host = trimmed.substring(0, separator).trim();
    portText = trimmed.substring(separator + 1).trim();
  }

  if (!isValidHost(host)) {
    return PortParseResult.fail(PortParseFailure.BAD_HOST, []);
  }
  if (portText.length === 0) {
    return PortParseResult.fail(PortParseFailure.NO_PORT, []);
  }

  const ports: Array<number> = [];
  const failure: PortParseResult | null = collectPorts(portText, ports);
  if (failure !== null) {
    return failure;
  }
  if (ports.length === 0) {
    return PortParseResult.fail(PortParseFailure.BAD_PORT, []);
  }
  if (ports.length > BATCH_PORT_LIMIT) {
    return PortParseResult.fail(PortParseFailure.TOO_MANY_PORTS,
      [String(BATCH_PORT_LIMIT), String(ports.length)]);
  }

  const targets: Array<PortTarget> = [];
  for (let i: number = 0; i < ports.length; i++) {
    targets.push(new PortTarget(host, ports[i]));
  }
  return PortParseResult.success(targets);
}

/** 找主机与端口之间的分隔符（: 或空白），返回下标；找不到返回 -1 */
function findSeparator(input: string): number {
  // 优先用冒号；没有冒号时接受空白（用户从文档里拷 "example.com 443" 很常见）
  const colon: number = input.indexOf(':');
  if (colon >= 0) {
    // 主机里有多个冒号且没有方括号 ⇒ 大概是没加括号的 IPv6
    if (input.indexOf(':', colon + 1) >= 0) {
      return -2;
    }
    return colon;
  }
  for (let i: number = 0; i < input.length; i++) {
    const code: number = input.charCodeAt(i);
    if (code === 32 || code === 9) {
      return i;
    }
  }
  return -1;
}

/** 把端口文本解析成端口数组；出错时返回失败结果，成功返回 null 并填充 out */
function collectPorts(portText: string, out: Array<number>): PortParseResult | null {
  const parts: Array<string> = portText.split(',');
  for (let i: number = 0; i < parts.length; i++) {
    const part: string = parts[i].trim();
    if (part.length === 0) {
      continue;
    }
    // 范围写法 8000-8010
    const dash: number = part.indexOf('-');
    if (dash > 0) {
      const fromText: string = part.substring(0, dash).trim();
      const toText: string = part.substring(dash + 1).trim();
      const from: number = parsePortNumber(fromText);
      const to: number = parsePortNumber(toText);
      if (from < 0 || to < 0) {
        return PortParseResult.fail(PortParseFailure.RANGE_SYNTAX, []);
      }
      if (from > to) {
        return PortParseResult.fail(PortParseFailure.RANGE_REVERSED,
          [String(from), String(to)]);
      }
      // 范围本身可能很大，先按上限截断判断，避免展开一个巨大的数组
      const count: number = to - from + 1;
      if (count > BATCH_PORT_LIMIT) {
        return PortParseResult.fail(PortParseFailure.RANGE_TOO_MANY,
          [String(count), String(BATCH_PORT_LIMIT)]);
      }
      for (let value: number = from; value <= to; value++) {
        out.push(value);
      }
      continue;
    }
    const port: number = parsePortNumber(part);
    if (port < 0) {
      return PortParseResult.fail(PortParseFailure.PORT_NOT_INTEGER,
        [String(PORT_MIN), String(PORT_MAX), part]);
    }
    out.push(port);
  }
  return null;
}

/** 解析单个端口号；非法返回 -1 */
function parsePortNumber(text: string): number {
  if (text.length === 0) {
    return -1;
  }
  for (let i: number = 0; i < text.length; i++) {
    const code: number = text.charCodeAt(i);
    if (code < 48 || code > 57) {
      return -1;
    }
  }
  const value: number = parseInt(text, 10);
  return isValidPort(value) ? value : -1;
}

// ── 测试结果 ─────────────────────────────────────────────────

/** 单个目标的测试状态 */
export enum PortState {
  /** 尚未测试 */
  PENDING = 'pending',
  /** 正在测试 */
  RUNNING = 'running',
  /** 连通 */
  OPEN = 'open',
  /** 明确不通（连接被拒绝 / 超时 / 解析失败等） */
  CLOSED = 'closed',
  /** 测不了（参数被我们自己挡下来了，没联网） */
  SKIPPED = 'skipped'
}

/**
 * 结果的「说明」——统一成一个枚举。
 *
 * 原先 PortResult.detail 是一句拼好的中文（连通时是耗时，否则是原因）。
 * 跳过原因与 socket 错误本来是两类，但它们**互斥**（一个结果只会是其中一种），
 * 合成一个枚举比塞两个字段更清楚。措辞归 UI 层。
 */
export enum PortDetail {
  NONE = 'none',
  /** 正在连接中 */
  RUNNING = 'running',
  /** 连通（耗时另见 elapsedMs） */
  OPEN = 'open',
  /** 参数被我们自己挡下：端口号不合法 */
  SKIP_BAD_PORT = 'skip_bad_port',
  /** 参数被我们自己挡下：主机名不合法 */
  SKIP_BAD_HOST = 'skip_bad_host',
  /** 与前面的目标重复 */
  SKIP_DUPLICATE = 'skip_duplicate',
  /** 连接被拒绝 */
  ERR_REFUSED = 'err_refused',
  /** 无法解析主机名 */
  ERR_DNS = 'err_dns',
  /** 连接超时 */
  ERR_TIMEOUT = 'err_timeout',
  /** 连接超时（没有更具体的错误码） */
  ERR_TIMEOUT_QUIET = 'err_timeout_quiet',
  /** 网络不可达 */
  ERR_UNREACHABLE = 'err_unreachable',
  /** 网络未连接 */
  ERR_OFFLINE = 'err_offline',
  /** 缺少网络权限 */
  ERR_NO_PERMISSION = 'err_no_permission',
  /** 其它失败（带原始消息） */
  ERR_OTHER = 'err_other',
  /** 其它失败（只有错误码） */
  ERR_CODE = 'err_code'
}

/** 单个目标的测试结果 */
export class PortResult {
  readonly target: PortTarget;
  readonly state: PortState;
  /** 说明的**种类**（措辞在 UI 层） */
  readonly detail: PortDetail;
  /** 资源文案的占位符参数 */
  readonly detailArgs: Array<string>;
  /** 连通时的连接耗时（毫秒）；未连通为 -1 */
  readonly elapsedMs: number;

  constructor(target: PortTarget, state: PortState, detail: PortDetail,
    detailArgs: Array<string>, elapsedMs: number) {
    this.target = target;
    this.state = state;
    this.detail = detail;
    this.detailArgs = detailArgs;
    this.elapsedMs = elapsedMs;
  }

  get isOpen(): boolean {
    return this.state === PortState.OPEN;
  }
}

/**
 * 把 socket 错误码翻译成人话。
 *
 * 为什么值得单独做：用户看到「连接失败」和看到「连接被拒绝：目标主机在，但那个端口没有服务在听」
 * 的下一步动作完全不同——前者会去查网络，后者会去查服务有没有起来。
 * 把错误码翻译准，就是在替用户省一次排查。
 */
export class SocketDetail {
  readonly kind: PortDetail;
  readonly args: Array<string>;

  constructor(kind: PortDetail, args: Array<string>) {
    this.kind = kind;
    this.args = args;
  }
}

export function describeSocketError(code: number, message: string): SocketDetail {
  if (code === 2300007) {
    return new SocketDetail(PortDetail.ERR_REFUSED, []);
  }
  if (code === 2300006) {
    return new SocketDetail(PortDetail.ERR_DNS, []);
  }
  if (code === 2300007 + 1) {
    return new SocketDetail(PortDetail.ERR_TIMEOUT_QUIET, []);
  }
  if (code === 2300028) {
    return new SocketDetail(PortDetail.ERR_TIMEOUT, []);
  }
  if (code === 2300003) {
    return new SocketDetail(PortDetail.ERR_UNREACHABLE, []);
  }
  if (code === 2300004) {
    return new SocketDetail(PortDetail.ERR_OFFLINE, []);
  }
  if (code === 201) {
    return new SocketDetail(PortDetail.ERR_NO_PERMISSION, []);
  }
  if (message.length > 0) {
    return new SocketDetail(PortDetail.ERR_OTHER, [message]);
  }
  return new SocketDetail(PortDetail.ERR_CODE, [String(code)]);
}

/** 一批结果的小结 */
export class PortSummary {
  readonly total: number;
  readonly open: number;
  readonly closed: number;
  readonly skipped: number;

  constructor(total: number, open: number, closed: number, skipped: number) {
    this.total = total;
    this.open = open;
    this.closed = closed;
    this.skipped = skipped;
  }

  /** 全通 */
  get allOpen(): boolean {
    return this.total > 0 && this.open === this.total;
  }
}

/** 汇总一批结果 */
export function summarize(results: Array<PortResult>): PortSummary {
  let open: number = 0;
  let closed: number = 0;
  let skipped: number = 0;
  for (let i: number = 0; i < results.length; i++) {
    const state: PortState = results[i].state;
    if (state === PortState.OPEN) {
      open++;
    } else if (state === PortState.SKIPPED) {
      skipped++;
    } else if (state === PortState.PENDING || state === PortState.RUNNING) {
      // 还没测完的不计入任何一方，避免小结出现「总数对不上」的观感
      continue;
    } else {
      closed++;
    }
  }
  return new PortSummary(results.length, open, closed, skipped);
}

/**
 * 联网前的自检：能离线判定的问题一律不联网。
 *
 * 返回需要跳过测试的结果（空数组表示全部可以正常测试）。
 * 这是本模块最重要的一个函数——它是「隐私红线」在代码层面的落点：
 * 只要输入有问题，就一个包都不发出去。
 */
export function preflightSkip(targets: Array<PortTarget>): Array<PortResult> {
  const skipped: Array<PortResult> = [];
  const seen: Set<string> = new Set<string>();
  for (let i: number = 0; i < targets.length; i++) {
    const target: PortTarget = targets[i];
    if (!isValidPort(target.port)) {
      skipped.push(new PortResult(target, PortState.SKIPPED,
        PortDetail.SKIP_BAD_PORT, [], -1));
      continue;
    }
    if (!isValidHost(target.host)) {
      skipped.push(new PortResult(target, PortState.SKIPPED,
        PortDetail.SKIP_BAD_HOST, [], -1));
      continue;
    }
    // 同一个目标重复出现时只测一次，重复的直接给结论，省一次网络往返
    const key: string = target.display;
    if (seen.has(key)) {
      skipped.push(new PortResult(target, PortState.SKIPPED,
        PortDetail.SKIP_DUPLICATE, [], -1));
      continue;
    }
    seen.add(key);
  }
  return skipped;
}

/**
 * 本地地址与保留地址提示。
 *
 * 这些地址**测不出通不通不代表服务有问题**：192.168.x.x 与 127.0.0.1 只在
 * 特定网络里可达。提前提示能避免用户误判成「我的服务挂了」。
 */
/** 本地/保留地址提示的种类（措辞在 UI 层） */
export enum PortNotice {
  NONE = 'none',
  /** localhost */
  LOCALHOST = 'localhost',
  /** 127.0.0.0/8 回环 */
  LOOPBACK = 'loopback',
  /** RFC 1918 私有地址 */
  PRIVATE = 'private'
}

export function localAddressNotice(host: string): PortNotice {
  const trimmed: string = host.trim().toLowerCase();
  if (trimmed === 'localhost') {
    return PortNotice.LOCALHOST;
  }
  if (trimmed === '127.0.0.1' || trimmed.indexOf('127.') === 0) {
    return PortNotice.LOOPBACK;
  }
  if (isPrivateIpv4(trimmed)) {
    return PortNotice.PRIVATE;
  }
  return PortNotice.NONE;
}

/**
 * 是否为 RFC 1918 私有 IPv4 地址。
 *
 * ## 为什么按「八位组数值」判断而不是拼字符串前缀
 *
 * 第一版用 `host.indexOf('172.2') === 0` 这类前缀判断，问题是前缀既会**误判**也会**漏判**：
 * - `172.2` 会把 172.20 ~ 172.29 判成私有，但私有段其实覆盖到 172.31；
 *   它也把 172.2x 之外的 172.30/172.31 漏掉了（当时靠额外几个前缀补，逻辑很脆）；
 * - 反过来，`10.` 这类判断对主机名 `10.example.com` 会误判成内网——
 *   真实主机名里出现 `10.` 开头并不罕见。
 *
 * 按数值判断就没有这些问题：解析出四个八位组，再对 10/8、172.16/12、192.168/16
 * 做**范围**比较。顺带要求四段都是纯数字，主机名自然被排除在外。
 */
function isPrivateIpv4(host: string): boolean {
  const parts: Array<string> = host.split('.');
  if (parts.length !== 4) {
    return false;
  }
  const octets: Array<number> = [];
  for (let i: number = 0; i < parts.length; i++) {
    const part: string = parts[i];
    if (part.length === 0 || part.length > 3) {
      return false;
    }
    for (let j: number = 0; j < part.length; j++) {
      const code: number = part.charCodeAt(j);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    const value: number = parseInt(part, 10);
    if (isNaN(value) || value > 255) {
      return false;
    }
    octets.push(value);
  }
  if (octets[0] === 10) {
    return true;
  }
  if (octets[0] === 192 && octets[1] === 168) {
    return true;
  }
  // 172.16.0.0/12 => 第二段 16~31
  if (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) {
    return true;
  }
  return false;
}