/**
 * IPv4 子网计算 —— 纯逻辑（零 import，可直接单测）。
 *
 * ## 两个必须讲清楚的实现要点
 *
 * ### 1. 为什么全程用「无符号 32 位」算术
 *
 * JavaScript/ArkTS 的位运算是有符号 32 位的：「0xFFFFFFFF | 0」 得到 **-1**，
 * 而不是 4294967295。子网计算里几乎每一步都碰到这个边界
 * （255.255.255.255、掩码全 1、广播地址），一旦混入负数，
 * 「可用主机数」会变成负数或荒谬的大数。
 *
 * 因此本模块**只在内部**用有符号 32 位做运算，每次运算后立刻 「>>> 0」
 * 归一到无符号区间；对外暴露的一切数值（地址、数量、掩码）都是无符号的。
 *
 * ### 2. 为什么「可用主机数」要按 RFC 口径分情况
 *
 * 教科书常说「可用主机数 = 2^n − 2」，但那句话只对 **前缀 1 ~ 30** 成立：
 * - **前缀 31**（RFC 3021 点对点链路）：两个地址都是可用的，是 2 而不是 0；
 * - **前缀 32**（单主机路由）：只有一个地址，它本身就是可用地址，是 1 而不是负数。
 * - **前缀 0**：2^32 个地址，减 2 后仍是有效数字，但没有「网络地址/广播地址」这一对
 *   能真正排掉，按 2^32 − 2 报会与常识冲突。
 *
 * 用 「2^n − 2」 硬套会在 /31 与 /32 上给出 0 或 −1，这是子网计算器最常见的错。
 * 本模块用 {@link usableHostCount} 把口径写成显式分支，并由单测钉住。
 *
 * @module tools/subnet-calc/SubnetCalc
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 点分十进制每一段的取值范围 */
const OCTET_MAX: number = 255;
/** IPv4 总位数 */
const IPV4_BITS: number = 32;
/** 掩码前缀长度范围 */
export const PREFIX_MIN: number = 0;
export const PREFIX_MAX: number = 32;

/** 掩码合法的点分十进制写法集合（只接受连续的 1 后接连续的 0） */
const VALID_MASKS: Array<number> = buildValidMasks();

function buildValidMasks(): Array<number> {
  const masks: Array<number> = [];
  for (let prefix: number = PREFIX_MIN; prefix <= PREFIX_MAX; prefix++) {
    masks.push(prefixToMaskValue(prefix));
  }
  return masks;
}

/** 前缀长度 → 无符号掩码数值（32 位全 1 左移，用 >>> 0 归一无符号） */
export function prefixToMaskValue(prefix: number): number {
  if (prefix <= 0) {
    return 0;
  }
  if (prefix >= IPV4_BITS) {
    return 0xFFFFFFFF;
  }
  // 先构造有符号的负数再 >>> 0 归一，避免 1 << 32 这类越界移位
  return (0xFFFFFFFF << (IPV4_BITS - prefix)) >>> 0;
}

/** 无符号数值 → 点分十进制 */
export function valueToIp(value: number): string {
  const normalized: number = value >>> 0;
  const a: number = (normalized >>> 24) & OCTET_MAX;
  const b: number = (normalized >>> 16) & OCTET_MAX;
  const c: number = (normalized >>> 8) & OCTET_MAX;
  const d: number = normalized & OCTET_MAX;
  return String(a) + '.' + String(b) + '.' + String(c) + '.' + String(d);
}

/** 点分十进制 → 无符号数值；非法返回 -1（-1 不是合法地址，可安全当哨兵） */
export function ipToValue(text: string): number {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return -1;
  }
  const parts: Array<string> = trimmed.split('.');
  // 只接受完整的四段写法。刻意**不**支持 "192.168.1" 这类简写：
  // 简写在不同工具里含义不一致（补 0 还是补 1），宁可让用户写全。
  if (parts.length !== 4) {
    return -1;
  }
  let value: number = 0;
  for (let i: number = 0; i < parts.length; i++) {
    const part: string = parts[i];
    if (part.length === 0 || part.length > 3) {
      return -1;
    }
    // 只允许十进制数字：不接受 0x10 这类写法，避免与「进制」混淆
    for (let j: number = 0; j < part.length; j++) {
      const code: number = part.charCodeAt(j);
      if (code < 48 || code > 57) {
        return -1;
      }
    }
    const octet: number = parseInt(part, 10);
    if (isNaN(octet) || octet < 0 || octet > OCTET_MAX) {
      return -1;
    }
    // 禁止 "01" 这类带前导零的写法：它们在部分系统里会被当成八进制
    if (part.length > 1 && part.charAt(0) === '0') {
      return -1;
    }
    value = ((value << 8) | octet) >>> 0;
  }
  return value;
}

/** 前缀长度是否合法（0..32 的整数） */
export function isValidPrefix(prefix: number): boolean {
  if (isNaN(prefix)) {
    return false;
  }
  if (Math.floor(prefix) !== prefix) {
    return false;
  }
  return prefix >= PREFIX_MIN && prefix <= PREFIX_MAX;
}

/**
 * 掩码的点分十进制写法是否合法。
 *
 * 判据不是「四段都在 0..255」，而是**必须是连续 1 后接连续 0**：
 * 255.0.255.0 每段都合法，但它不是一个掩码，按它算出来的网络地址毫无意义。
 */
export function maskIsContiguous(maskValue: number): boolean {
  const normalized: number = maskValue >>> 0;
  return VALID_MASKS.indexOf(normalized) >= 0;
}

/** 掩码数值 → 前缀长度；不合法返回 -1 */
export function maskToPrefix(maskValue: number): number {
  const normalized: number = maskValue >>> 0;
  return VALID_MASKS.indexOf(normalized);
}

/** 是否为 IPv6 写法（含冒号）：用于给出针对性提示，而不是笼统的「格式错误」 */
export function looksLikeIpv6(text: string): boolean {
  return text.indexOf(':') >= 0;
}

/** 解析失败的原因（分类给出人话，而不是统一的「格式错误」） */
export enum SubnetParseFailure {
  /** 空输入 */
  EMPTY = 'empty',
  /** 看起来是 IPv6 */
  IPV6 = 'ipv6',
  /** 地址本身不合法 */
  BAD_ADDRESS = 'bad_address',
  /** 前缀长度不合法 */
  BAD_PREFIX = 'bad_prefix',
  /** 掩码写法不合法（不是四段十进制） */
  BAD_MASK = 'bad_mask',
  /** 掩码每段都在范围内，但二进制不是「连续 1 后接连续 0」 */
  BAD_MASK_CONTIGUOUS = 'bad_mask_contiguous'
}

/**
 * 前缀长度 → 常识提示的**码**。
 *
 * 原先是 \`prefixRemark(prefix): string\` 直接返回中文句子。做双语时改成码：
 * 纯逻辑层不能 import ArkUI 的 \`$r()\`，拼不出多语言句子；
 * 而且「切口大小合不合理」这种判断才是值得单测的部分，措辞不是。
 */
export enum PrefixRemarkCode {
  /** 无需提示 */
  NONE = 'none',
  ALL_IPV4 = 'all_ipv4',
  SINGLE_HOST = 'single_host',
  POINT_TO_POINT_RFC3021 = 'p2p_rfc3021',
  POINT_TO_POINT_COMMON = 'p2p_common',
  VERY_LARGE = 'very_large',
  COMMON_LAN = 'common_lan'
}

/** 解析结果 */
export class SubnetParseResult {
  readonly ok: boolean;
  readonly failure: SubnetParseFailure;
  /**
   * 资源文案的占位符参数（顺序须与资源文案里 %s 一致）。
   *
   * 只有 BAD_PREFIX 用得到：它的文案里要写「0~32」这个范围，
   * 而那两个数字是常量——传参而不是写死在文案里，常量改了文案才不会过期。
   */
  readonly args: Array<string>;
  readonly addressValue: number;
  readonly prefix: number;

  constructor(
    ok: boolean,
    failure: SubnetParseFailure,
    args: Array<string>,
    addressValue: number,
    prefix: number
  ) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.addressValue = addressValue;
    this.prefix = prefix;
  }

  static success(addressValue: number, prefix: number): SubnetParseResult {
    return new SubnetParseResult(true, SubnetParseFailure.EMPTY, [], addressValue, prefix);
  }

  static fail(failure: SubnetParseFailure, args: Array<string>): SubnetParseResult {
    return new SubnetParseResult(false, failure, args, 0, 0);
  }
}

/**
 * 解析用户输入。接受两种形式：
 * - 「192.168.1.10/24」
 * - 「192.168.1.10/255.255.255.0」
 * 省略 / 前缀时按 /32（单主机）处理。
 */
export function parseSubnetInput(input: string): SubnetParseResult {
  const trimmed: string = input.trim();
  if (trimmed.length === 0) {
    return SubnetParseResult.fail(SubnetParseFailure.EMPTY, []);
  }
  if (looksLikeIpv6(trimmed)) {
    return SubnetParseResult.fail(SubnetParseFailure.IPV6, []);
  }

  const slashIndex: number = trimmed.indexOf('/');
  const addressText: string = slashIndex < 0 ? trimmed : trimmed.substring(0, slashIndex);
  const suffixText: string = slashIndex < 0 ? '' : trimmed.substring(slashIndex + 1).trim();

  const addressValue: number = ipToValue(addressText);
  if (addressValue < 0) {
    return SubnetParseResult.fail(SubnetParseFailure.BAD_ADDRESS, []);
  }

  // 没写前缀：按单主机处理（这是最容易让人意外的默认值，所以页面上要提示）
  if (slashIndex < 0 || suffixText.length === 0) {
    return SubnetParseResult.success(addressValue, IPV4_BITS);
  }

  // 后缀是点分十进制掩码
  if (suffixText.indexOf('.') >= 0) {
    const maskValue: number = ipToValue(suffixText);
    if (maskValue < 0) {
      return SubnetParseResult.fail(SubnetParseFailure.BAD_MASK, []);
    }
    if (!maskIsContiguous(maskValue)) {
      return SubnetParseResult.fail(SubnetParseFailure.BAD_MASK_CONTIGUOUS, []);
    }
    return SubnetParseResult.success(addressValue, maskToPrefix(maskValue));
  }

  // 后缀是前缀长度
  const prefix: number = parseInt(suffixText, 10);
  if (!isValidPrefix(prefix) || String(prefix) !== suffixText) {
    return SubnetParseResult.fail(SubnetParseFailure.BAD_PREFIX,
      [String(PREFIX_MIN), String(IPV4_BITS)]);
  }
  return SubnetParseResult.success(addressValue, prefix);
}

/**
 * 前缀长度 → 人话说明。
 *
 * 只对大范围前缀给出「这一刀切得对不对」的常识提示，
 * 不试图解释每个前缀——那会变成把 RFC 抄一遍。
 */
export function prefixRemark(prefix: number): PrefixRemarkCode {
  if (prefix === 0) {
    return PrefixRemarkCode.ALL_IPV4;
  }
  if (prefix === IPV4_BITS) {
    return PrefixRemarkCode.SINGLE_HOST;
  }
  if (prefix === 31) {
    return PrefixRemarkCode.POINT_TO_POINT_RFC3021;
  }
  if (prefix === 30) {
    return PrefixRemarkCode.POINT_TO_POINT_COMMON;
  }
  if (prefix <= 8) {
    return PrefixRemarkCode.VERY_LARGE;
  }
  if (prefix === 24) {
    return PrefixRemarkCode.COMMON_LAN;
  }
  return PrefixRemarkCode.NONE;
}

/**
 * 可用主机数。
 *
 * 口径见文件头说明：/31 与 /32 是 RFC 特例，不能套用 2^n − 2。
 */
export function usableHostCount(prefix: number): number {
  if (!isValidPrefix(prefix)) {
    return 0;
  }
  // /32：单个地址本身就是可用地址
  if (prefix === 32) {
    return 1;
  }
  // /31：RFC 3021 点对点，两个地址都可用
  if (prefix === 31) {
    return 2;
  }
  const hostBits: number = IPV4_BITS - prefix;
  // 用 2^hostBits 而不是位移：hostBits 最大 31，位移会落到符号位
  const total: number = Math.pow(2, hostBits);
  return total - 2;
}

/** 完整的子网信息 */
export class SubnetInfo {
  /** 用户输入的原始地址 */
  readonly inputAddress: string;
  /** 前缀长度 */
  readonly prefix: number;
  /** 掩码（点分十进制） */
  readonly mask: string;
  /** 反掩码 / 通配符掩码（点分十进制），ACL 与 OSPF 配置常用 */
  readonly wildcardMask: string;
  /** 网络地址（该网段第一个地址） */
  readonly network: string;
  /** 广播地址（该网段最后一个地址） */
  readonly broadcast: string;
  /** 第一个可用地址；无可用地址时为空串 */
  readonly firstUsable: string;
  /** 最后一个可用地址；无可用地址时为空串 */
  readonly lastUsable: string;
  /** 该网段地址总数（2^hostBits） */
  readonly totalAddresses: number;
  /** 可用主机数（口径见 usableHostCount） */
  readonly usableHosts: number;
  /** 输入的地址是否为网络地址本身 */
  readonly isNetworkAddress: boolean;
  /** 输入地址是否为广播地址 */
  readonly isBroadcastAddress: boolean;
  /** 所属网段的 CIDR 写法（标准化结果） */
  readonly cidr: string;
  /** 前缀的常识说明；无特别提示时为空串 */
  readonly remark: string;

  constructor(
    inputAddress: string,
    prefix: number,
    mask: string,
    wildcardMask: string,
    network: string,
    broadcast: string,
    firstUsable: string,
    lastUsable: string,
    totalAddresses: number,
    usableHosts: number,
    isNetworkAddress: boolean,
    isBroadcastAddress: boolean,
    cidr: string,
    remark: string
  ) {
    this.inputAddress = inputAddress;
    this.prefix = prefix;
    this.mask = mask;
    this.wildcardMask = wildcardMask;
    this.network = network;
    this.broadcast = broadcast;
    this.firstUsable = firstUsable;
    this.lastUsable = lastUsable;
    this.totalAddresses = totalAddresses;
    this.usableHosts = usableHosts;
    this.isNetworkAddress = isNetworkAddress;
    this.isBroadcastAddress = isBroadcastAddress;
    this.cidr = cidr;
    this.remark = remark;
  }
}

/**
 * 计算子网信息。
 *
 * 边界语义（单测逐条钉住）：
 * - /31 与 /32 没有「网络地址/广播地址」这一对，firstUsable/lastUsable
 *   直接给出该范围内的地址，而不是留空；
 * - /0 的广播地址是 255.255.255.255、网络地址是 0.0.0.0，也要能正确算出。
 */
export function computeSubnet(addressValue: number, prefix: number): SubnetInfo {
  const address: number = addressValue >>> 0;
  const maskValue: number = prefixToMaskValue(prefix);
  const networkValue: number = (address & maskValue) >>> 0;
  const hostBits: number = IPV4_BITS - prefix;
  const totalAddresses: number = Math.pow(2, hostBits);
  // 广播地址 = 网络地址 | 反掩码（把主机位全置 1）
  const broadcastValue: number = (networkValue | ((~maskValue) >>> 0)) >>> 0;
  const wildcardValue: number = ((~maskValue) >>> 0);

  let firstUsable: string = '';
  let lastUsable: string = '';
  if (prefix === 32) {
    // 单主机：就是它自己
    firstUsable = valueToIp(networkValue);
    lastUsable = valueToIp(networkValue);
  } else if (prefix === 31) {
    // RFC 3021：两个地址都可用，没有网络号/广播号
    firstUsable = valueToIp(networkValue);
    lastUsable = valueToIp(broadcastValue);
  } else {
    // 常规网段：排掉网络地址与广播地址
    firstUsable = valueToIp((networkValue + 1) >>> 0);
    lastUsable = valueToIp((broadcastValue - 1) >>> 0);
  }

  const isNetwork: boolean = address === networkValue;
  const isBroadcast: boolean = address === broadcastValue && prefix <= 30;

  return new SubnetInfo(
    valueToIp(address),
    prefix,
    valueToIp(maskValue),
    valueToIp(wildcardValue),
    valueToIp(networkValue),
    valueToIp(broadcastValue),
    firstUsable,
    lastUsable,
    totalAddresses,
    usableHostCount(prefix),
    isNetwork,
    isBroadcast,
    valueToIp(networkValue) + '/' + String(prefix),
    prefixRemark(prefix)
  );
}

/** 地址是否属于给定网段（含网络地址与广播地址） */
export function addressInSubnet(addressValue: number, networkValue: number, prefix: number): boolean {
  const maskValue: number = prefixToMaskValue(prefix);
  return ((addressValue >>> 0) & maskValue) >>> 0 === ((networkValue >>> 0) & maskValue) >>> 0;
}

/**
 * 判断两个网段是否重叠。
 *
 * 不是「网络地址是否相等」：10.0.0.0/8 与 10.1.0.0/16 网络地址不同，
 * 但后者完全落于前者之内，是重叠的。判据是「一方的网络地址落在另一方范围内」。
 */
export function subnetsOverlap(networkA: number, prefixA: number, networkB: number, prefixB: number): boolean {
  const inA: boolean = addressInSubnet(networkB, networkA, prefixA);
  const inB: boolean = addressInSubnet(networkA, networkB, prefixB);
  return inA || inB;
}

/** 常用私有网段与保留网段，用于在结果里标注「这是内网地址」这类常识 */
export class NGFWellKnownRange {
  /** 网段的中文/英文说法（纯数据层带双语，见 NGFLocalizedText 的说明） */
  readonly label: NGFLocalizedText;
  readonly network: string;
  readonly prefix: number;

  constructor(label: NGFLocalizedText, network: string, prefix: number) {
    this.label = label;
    this.network = network;
    this.prefix = prefix;
  }
}

/** 简写构造器：把「中文 / English」写成一行 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

/** 常用保留网段（RFC 1918 / 5735 / 6598 等），顺序按前缀从大到小给出更具体的优先 */
export function wellKnownRanges(): Array<NGFWellKnownRange> {
  const list: Array<NGFWellKnownRange> = [];
  list.push(new NGFWellKnownRange(l10n('回环地址', 'Loopback'), '127.0.0.0', 8));
  list.push(new NGFWellKnownRange(l10n('私有地址（10/8）', 'Private (10/8)'), '10.0.0.0', 8));
  list.push(new NGFWellKnownRange(l10n('运营商级 NAT（100.64/10）', 'Carrier-grade NAT (100.64/10)'),
    '100.64.0.0', 10));
  list.push(new NGFWellKnownRange(l10n('链路本地（169.254/16）', 'Link-local (169.254/16)'),
    '169.254.0.0', 16));
  list.push(new NGFWellKnownRange(l10n('私有地址（172.16/12）', 'Private (172.16/12)'),
    '172.16.0.0', 12));
  list.push(new NGFWellKnownRange(l10n('私有地址（192.168/16）', 'Private (192.168/16)'),
    '192.168.0.0', 16));
  list.push(new NGFWellKnownRange(l10n('组播地址', 'Multicast'), '224.0.0.0', 4));
  list.push(new NGFWellKnownRange(l10n('保留（240/4）', 'Reserved (240/4)'), '240.0.0.0', 4));
  return list;
}

/**
 * 判断某个地址属于哪些已知保留网段。
 *
 * @returns 命中的标签数组；命中多个时**更具体的排前面**（前缀更长优先），
 *          因为 127.0.0.0/8 ⊂ 0.0.0.0/0 这类包含关系会让「命中多个」失去意义——
 *          用户想知道的是「它最具体属于什么」。
 */
export function describeAddressKind(addressValue: number): Array<NGFLocalizedText> {
  const matched: Array<NGFWellKnownRange> = [];
  const ranges: Array<NGFWellKnownRange> = wellKnownRanges();
  for (let i: number = 0; i < ranges.length; i++) {
    const range: NGFWellKnownRange = ranges[i];
    const networkValue: number = ipToValue(range.network);
    if (addressInSubnet(addressValue, networkValue, range.prefix)) {
      matched.push(range);
    }
  }
  matched.sort((left: NGFWellKnownRange, right: NGFWellKnownRange): number => right.prefix - left.prefix);
  const labels: Array<NGFLocalizedText> = [];
  for (let i: number = 0; i < matched.length; i++) {
    labels.push(matched[i].label);
  }
  return labels;
}

/**
 * 由「需要多少台主机」反推最小够用的前缀长度。
 *
 * 这是子网规划里最实用的一个方向：用户知道要放 60 台机器，该切 /26 还是 /25。
 *
 * @returns 前缀长度；hosts 不合理（<1 或超出 IPv4 容量）时返回 -1
 */
export function prefixForHosts(hosts: number): number {
  if (isNaN(hosts) || hosts < 1) {
    return -1;
  }
  if (hosts > 0xFFFFFFFF - 2) {
    return -1;
  }

  // 两个端点先单独定，避免被下面的循环"顺手"答错：
  //
  // - 只要 **1 个地址**：唯一正确的答案是 /32（单主机路由）。
  //   若交给「从前缀从大到小找第一个够用的」逻辑，它会返回 /30 —— 虽然 /30 也
  //   「够用」（有 2 个可用地址），但那是**浪费**：为了 1 台机器切掉一个 4 地址网段。
  // - 要 **恰好 2 个地址**：给 /30 而不是 /31。/31 是 RFC 3021 点对点特例，
  //   很多设备的接口配置不接受它；做地址规划时业界惯例是 /30。
  if (hosts === 1) {
    return PREFIX_MAX;
  }
  if (hosts === 2) {
    return 30;
  }

  // 其余情况：找**能用得上的最小网段**，即最大的、可用地址数仍足够的那个前缀。
  // 从 /30 起（/31、/32 已在上面处理掉），逐级缩小网段直到刚够用。
  let best: number = -1;
  for (let prefix: number = 30; prefix >= 1; prefix--) {
    if (usableHostCount(prefix) >= hosts) {
      best = prefix;
      break;
    }
  }
  return best;
}

// formatSubnetReport 已搬到 UI 层（SubnetCalcMessages.ets）。
//
// 它产出的每一行都是「标签 + 值」，标签是文案（中文/英文写法不同），
// 而纯逻辑层拿不到设备语言。搬家后纯逻辑只负责算，措辞归 UI——
// 这正是这一轮在做的分层纠正。