/**
 * IP/CIDR 计算的纯逻辑实现（复用 subnet-calc 的 IP 数值转换）。
 *
 * ## 与 subnet-calc 的分工
 *
 * subnet-calc 面向「网段规划」（主机数、可用范围、地址类型）；
 * 本工具面向「CIDR 速查」（掩码/通配符/反掩码/网络地址/广播地址）——
 * 是网络设备配置时高频查的字段。复用 ipToValue/valueToIp/prefixToMaskValue，
 * 不复制实现。
 *
 * @module tools/ip-cidr/IpCidr
 */

import { ipToValue, prefixToMaskValue, valueToIp } from '../subnet-calc/SubnetCalc';

/** 失败原因码 */
export enum IpCidrFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 缺少 / 前缀部分 */
  MISSING_PREFIX = 'missing_prefix',
  /** IP 或前缀解析失败 */
  BAD_FORMAT = 'bad_format',
  /** 前缀超出 0-32 */
  PREFIX_OUT_OF_RANGE = 'prefix_out_of_range'
}

/** 一次失败的原因与文案参数 */
export class IpCidrFailure {
  readonly code: IpCidrFailureCode;
  readonly args: Array<string>;

  constructor(code: IpCidrFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** CIDR 信息结果 */
export class IpCidrInfo {
  readonly ok: boolean;
  readonly failure: IpCidrFailure;
  /** 规范化的 CIDR 表示（网络地址/前缀） */
  readonly cidr: string;
  readonly network: string;
  readonly broadcast: string;
  readonly mask: string;
  /** 通配符掩码（网络设备配置用） */
  readonly wildcard: string;
  readonly prefix: number;
  /** 总地址数（2^(32-prefix)，十进制字符串防丢精度——/0 时超 2^31） */
  readonly totalAddresses: string;

  constructor(ok: boolean, failure: IpCidrFailure, cidr: string, network: string,
    broadcast: string, mask: string, wildcard: string, prefix: number, totalAddresses: string) {
    this.ok = ok;
    this.failure = failure;
    this.cidr = cidr;
    this.network = network;
    this.broadcast = broadcast;
    this.mask = mask;
    this.wildcard = wildcard;
    this.prefix = prefix;
    this.totalAddresses = totalAddresses;
  }
}

/** 2 的幂（数学方式，避免移位运算符的运行器差异） */
function pow2(n: number): number {
  return Math.pow(2, n);
}

/** 主入口：解析 CIDR 并算全部速查字段 */
export function analyzeCidr(input: string): IpCidrInfo {
  const text: string = input.trim();
  if (text.length === 0) {
    return new IpCidrInfo(false, new IpCidrFailure(IpCidrFailureCode.EMPTY_INPUT, []),
      '', '', '', '', '', 0, '');
  }
  const slash: number = text.indexOf('/');
  if (slash < 0) {
    return new IpCidrInfo(false, new IpCidrFailure(IpCidrFailureCode.MISSING_PREFIX, []),
      '', '', '', '', '', 0, '');
  }
  const ipPart: string = text.substring(0, slash).trim();
  const prefixPart: string = text.substring(slash + 1).trim();
  const prefix: number = parseInt(prefixPart, 10);
  if (isNaN(prefix) || String(prefix) !== prefixPart) {
    return new IpCidrInfo(false, new IpCidrFailure(IpCidrFailureCode.BAD_FORMAT, []),
      '', '', '', '', '', 0, '');
  }
  if (prefix < 0 || prefix > 32) {
    return new IpCidrInfo(false,
      new IpCidrFailure(IpCidrFailureCode.PREFIX_OUT_OF_RANGE, [prefixPart]),
      '', '', '', '', '', 0, '');
  }
  const ipValue: number = ipToValue(ipPart);
  if (ipValue < 0) {
    return new IpCidrInfo(false, new IpCidrFailure(IpCidrFailureCode.BAD_FORMAT, []),
      '', '', '', '', '', 0, '');
  }
  const maskValue: number = prefixToMaskValue(prefix);
  // 网络地址 = IP 与掩码按位与（用除法拆高低位避开 >>> 差异）
  const networkValue: number = Math.floor(ipValue / pow2(32 - prefix)) * pow2(32 - prefix);
  const broadcastValue: number = networkValue + pow2(32 - prefix) - 1;
  const maskValueUnsigned: number = maskValue;
  const wildcardValue: number = pow2(32 - prefix) - 1;
  const cidrText: string = valueToIp(networkValue) + '/' + String(prefix);
  return new IpCidrInfo(true, new IpCidrFailure(IpCidrFailureCode.NONE, []),
    cidrText,
    valueToIp(networkValue),
    valueToIp(broadcastValue),
    valueToIp(maskValueUnsigned),
    valueToIp(wildcardValue),
    prefix,
    String(pow2(32 - prefix)));
}
