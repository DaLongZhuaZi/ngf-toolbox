/**
 * 子网计算的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * ## 这一层为什么必须存在
 *
 * \`SubnetCalc.ets\` 是纯逻辑：不能 import ArkUI 的 \`$r()\`，所以拼不出多语言句子。
 * 它现在只回答**结构化的问题**：
 * - 解析失败是哪种（\`SubnetParseFailure\`）+ 文案要哪些参数；
 * - 这个前缀有什么可说的（\`PrefixRemarkCode\`）；
 * - 命中了哪些保留网段（\`NGFLocalizedText\` 数组，纯数据层自带双语）。
 *
 * 而「怎么说」——报告标签、反向规划建议、注意事项——全在这里。
 * \`formatSubnetReport\` 原先也住在纯逻辑层，它产出的每一行都是「标签 + 值」，
 * 标签是文案；搬到这一层之后纯逻辑只剩下算。
 *
 * @module tools/subnet-calc/SubnetCalcMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { NGFLocalizedText } from '../../core/ToolModel';
import {
  computeSubnet,
  prefixForHosts,
  PrefixRemarkCode,
  SubnetInfo,
  SubnetParseFailure
} from './SubnetCalc';

/** 解析失败翻译成人话 */
export function subnetParseFailureText(failure: SubnetParseFailure,
  args: Array<string>): string {
  if (failure === SubnetParseFailure.EMPTY) {
    return ToolUiKit.text($r('app.string.subnet_err_empty'));
  }
  if (failure === SubnetParseFailure.IPV6) {
    return ToolUiKit.text($r('app.string.subnet_err_ipv6'));
  }
  if (failure === SubnetParseFailure.BAD_ADDRESS) {
    return ToolUiKit.text($r('app.string.subnet_err_bad_address'));
  }
  if (failure === SubnetParseFailure.BAD_MASK) {
    return ToolUiKit.text($r('app.string.subnet_err_bad_mask'));
  }
  if (failure === SubnetParseFailure.BAD_MASK_CONTIGUOUS) {
    return ToolUiKit.text($r('app.string.subnet_err_bad_mask_contiguous'));
  }
  if (failure === SubnetParseFailure.BAD_PREFIX) {
    return ToolUiKit.stringOf($r('app.string.subnet_err_bad_prefix'), [args[0], args[1]]);
  }
  return '';
}

/** 前缀常识提示 */
export function prefixRemarkText(code: PrefixRemarkCode): string {
  if (code === PrefixRemarkCode.ALL_IPV4) {
    return ToolUiKit.text($r('app.string.subnet_remark_all_ipv4'));
  }
  if (code === PrefixRemarkCode.SINGLE_HOST) {
    return ToolUiKit.text($r('app.string.subnet_remark_single_host'));
  }
  if (code === PrefixRemarkCode.POINT_TO_POINT_RFC3021) {
    return ToolUiKit.text($r('app.string.subnet_remark_p2p_rfc3021'));
  }
  if (code === PrefixRemarkCode.POINT_TO_POINT_COMMON) {
    return ToolUiKit.text($r('app.string.subnet_remark_p2p_common'));
  }
  if (code === PrefixRemarkCode.VERY_LARGE) {
    return ToolUiKit.text($r('app.string.subnet_remark_very_large'));
  }
  if (code === PrefixRemarkCode.COMMON_LAN) {
    return ToolUiKit.text($r('app.string.subnet_remark_common_lan'));
  }
  return '';
}

/** 地址性质（命中多个保留段时用 " / " 连接；语言差异只影响标签本身） */
export function addressKindText(kinds: Array<NGFLocalizedText>, locale: string): string {
  const labels: Array<string> = [];
  for (let i: number = 0; i < kinds.length; i++) {
    labels.push(kinds[i].forLocale(locale));
  }
  return labels.join(' / ');
}

/**
 * 计算结果的格式化文本（供一键复制，字段顺序与页面展示一致）。
 *
 * 连「标签与值之间的冒号」都取自资源键：中文习惯全角「：」、英文习惯半角加空格「: 」。
 * 这类标点差异是最容易被忽略的一类本地化问题——它不是词，所以没人会想到去翻译它。
 */
export function formatSubnetReport(info: SubnetInfo, kinds: Array<NGFLocalizedText>,
  locale: string): string {
  const colon: string = ToolUiKit.text($r('app.string.subnet_field_separator'));
  const noUsable: string = ToolUiKit.text($r('app.string.subnet_no_usable'));
  const usableRange: string = info.firstUsable.length > 0
    ? info.firstUsable + ' ~ ' + info.lastUsable
    : noUsable;
  let report: string = '';
  report += ToolUiKit.text($r('app.string.subnet_field_input')) + colon + info.inputAddress + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_cidr')) + colon + info.cidr + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_mask')) + colon + info.mask + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_wildcard')) + colon + info.wildcardMask + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_network')) + colon + info.network + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_broadcast')) + colon + info.broadcast + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_usable')) + colon + usableRange + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_total')) + colon
    + String(info.totalAddresses) + '\n';
  report += ToolUiKit.text($r('app.string.subnet_field_hosts')) + colon
    + String(info.usableHosts) + '\n';
  const kindLabel: string = addressKindText(kinds, locale);
  if (kindLabel.length > 0) {
    report += ToolUiKit.text($r('app.string.subnet_field_kinds')) + colon + kindLabel + '\n';
  }
  return report;
}

/** 反向规划的结果文案（判断在纯逻辑层，措辞在这里） */
export function reversePlanText(wantedHosts: string): string {
  const text: string = wantedHosts.trim();
  if (text.length === 0) {
    return '';
  }
  const hosts: number = parseInt(text, 10);
  if (isNaN(hosts)) {
    return ToolUiKit.text($r('app.string.subnet_plan_not_int'));
  }
  const prefix: number = prefixForHosts(hosts);
  if (prefix < 0) {
    return ToolUiKit.text($r('app.string.subnet_plan_too_many'));
  }
  // 反推出的前缀再算一遍可用数，让用户直接看到「够不够」
  const sample: SubnetInfo = computeSubnet(0, prefix);
  return ToolUiKit.stringOf($r('app.string.subnet_plan_suggest'),
    [String(prefix), String(sample.totalAddresses), String(sample.usableHosts)]);
}

/**
 * 注意事项。
 *
 * 这几条是用户最容易踩的坑，而且**从数字上看不出来**：
 * 他把网络地址当成一台主机填进去，或者把一个 /24 当成只有 254 个地址可用。
 */
export function addressNoticeText(info: SubnetInfo): string {
  if (info.isNetworkAddress) {
    return ToolUiKit.stringOf($r('app.string.subnet_notice_network'),
      [info.network, info.firstUsable]);
  }
  if (info.isBroadcastAddress) {
    return ToolUiKit.stringOf($r('app.string.subnet_notice_broadcast'), [info.broadcast]);
  }
  if (info.prefix === 31) {
    return ToolUiKit.text($r('app.string.subnet_notice_rfc3021'));
  }
  if (info.prefix === 32) {
    return ToolUiKit.text($r('app.string.subnet_notice_single_host'));
  }
  return '';
}
