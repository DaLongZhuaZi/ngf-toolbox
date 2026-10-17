/**
 * 端口测试工具的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑只给失败码、结果状态、说明种类与数字。措辞全在这里。
 *
 * 特别说明 \`preflightSkip\` 那几条：它们是「参数不合法所以**一个包都没发**」的
 * 结果——本工具的隐私红线就落在这里，提示文案要让用户看懂「不是网络问题」。
 *
 * @module tools/port-tester/PortMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { NGFLocalizedText } from '../../core/ToolModel';
import {
  localAddressNotice,
  PortDetail,
  PortNotice,
  PortParseFailure,
  PortPreset,
  PortResult,
  PortState,
  PortSummary,
  serviceLabelOf
} from './PortTester';

/** 解析失败翻译成人话 */
export function portParseFailureText(failure: PortParseFailure, args: Array<string>): string {
  if (failure === PortParseFailure.EMPTY) {
    return ToolUiKit.text($r('app.string.port_err_empty'));
  }
  if (failure === PortParseFailure.TOO_LONG) {
    return ToolUiKit.text($r('app.string.port_err_too_long'));
  }
  if (failure === PortParseFailure.PROTOCOL_PREFIX) {
    return ToolUiKit.text($r('app.string.port_err_protocol_prefix'));
  }
  if (failure === PortParseFailure.IPV6_UNCLOSED) {
    return ToolUiKit.text($r('app.string.port_err_ipv6_unclosed'));
  }
  if (failure === PortParseFailure.MULTIPLE_COLONS) {
    return ToolUiKit.text($r('app.string.port_err_multiple_colons'));
  }
  if (failure === PortParseFailure.BAD_HOST) {
    return ToolUiKit.text($r('app.string.port_err_bad_host'));
  }
  if (failure === PortParseFailure.NO_PORT) {
    return ToolUiKit.text($r('app.string.port_err_no_port'));
  }
  if (failure === PortParseFailure.BAD_PORT) {
    return ToolUiKit.text($r('app.string.port_err_bad_port'));
  }
  if (failure === PortParseFailure.TOO_MANY_PORTS) {
    return ToolUiKit.stringOf($r('app.string.port_err_too_many'), [args[0], args[1]]);
  }
  if (failure === PortParseFailure.RANGE_SYNTAX) {
    return ToolUiKit.text($r('app.string.port_err_range_syntax'));
  }
  if (failure === PortParseFailure.RANGE_REVERSED) {
    return ToolUiKit.stringOf($r('app.string.port_err_range_reversed'), [args[0], args[1]]);
  }
  if (failure === PortParseFailure.RANGE_TOO_MANY) {
    return ToolUiKit.stringOf($r('app.string.port_err_range_too_many'), [args[0], args[1]]);
  }
  if (failure === PortParseFailure.PORT_NOT_INTEGER) {
    return ToolUiKit.stringOf($r('app.string.port_err_port_not_integer'),
      [args[0], args[1], args[2]]);
  }
  return '';
}

/** 端口用途名（双语数据按 locale 取）；没有对应预设时返回空串 */
export function serviceLabelText(port: number, locale: string): string {
  const label: NGFLocalizedText | null = serviceLabelOf(port);
  return label === null ? '' : label.forLocale(locale);
}

/** 预设按钮上的文字 */
export function presetLabelText(preset: PortPreset, locale: string): string {
  return preset.label.forLocale(locale);
}

/**
 * 单个结果的说明。
 *
 * 连通时显示耗时；否则按种类取文案。跳过类的那三句要写清楚
 * 「没联网」——否则用户会以为是自己网络的问题。
 */
export function portDetailText(result: PortResult): string {
  if (result.detail === PortDetail.RUNNING) {
    return ToolUiKit.text($r('app.string.port_detail_running'));
  }
  if (result.detail === PortDetail.OPEN) {
    return ToolUiKit.stringOf($r('app.string.port_detail_open'),
      [String(result.elapsedMs)]);
  }
  if (result.detail === PortDetail.SKIP_BAD_PORT) {
    return ToolUiKit.text($r('app.string.port_detail_skip_bad_port'));
  }
  if (result.detail === PortDetail.SKIP_BAD_HOST) {
    return ToolUiKit.text($r('app.string.port_detail_skip_bad_host'));
  }
  if (result.detail === PortDetail.SKIP_DUPLICATE) {
    return ToolUiKit.text($r('app.string.port_detail_skip_duplicate'));
  }
  if (result.detail === PortDetail.ERR_REFUSED) {
    return ToolUiKit.text($r('app.string.port_err_refused'));
  }
  if (result.detail === PortDetail.ERR_DNS) {
    return ToolUiKit.text($r('app.string.port_err_dns'));
  }
  if (result.detail === PortDetail.ERR_TIMEOUT) {
    return ToolUiKit.text($r('app.string.port_err_timeout'));
  }
  if (result.detail === PortDetail.ERR_TIMEOUT_QUIET) {
    return ToolUiKit.text($r('app.string.port_err_timeout_quiet'));
  }
  if (result.detail === PortDetail.ERR_UNREACHABLE) {
    return ToolUiKit.text($r('app.string.port_err_unreachable'));
  }
  if (result.detail === PortDetail.ERR_OFFLINE) {
    return ToolUiKit.text($r('app.string.port_err_offline'));
  }
  if (result.detail === PortDetail.ERR_NO_PERMISSION) {
    return ToolUiKit.text($r('app.string.port_err_no_permission'));
  }
  if (result.detail === PortDetail.ERR_OTHER) {
    return ToolUiKit.stringOf($r('app.string.port_err_other'), [result.detailArgs[0]]);
  }
  if (result.detail === PortDetail.ERR_CODE) {
    return ToolUiKit.stringOf($r('app.string.port_err_code'), [result.detailArgs[0]]);
  }
  return '';
}

/** 结果表里那个短标记（连通/不通/跳过/未测） */
export function portMarkText(state: PortState): string {
  if (state === PortState.OPEN) {
    return ToolUiKit.text($r('app.string.port_mark_open'));
  }
  if (state === PortState.CLOSED) {
    return ToolUiKit.text($r('app.string.port_mark_closed'));
  }
  if (state === PortState.SKIPPED) {
    return ToolUiKit.text($r('app.string.port_mark_skipped'));
  }
  if (state === PortState.RUNNING) {
    return ToolUiKit.text($r('app.string.port_mark_running'));
  }
  return ToolUiKit.text($r('app.string.port_mark_pending'));
}

/**
 * 小结。
 *
 * 拆成「N 个连通」「、M 个不通」这样的**独立片段**再拼：
 * 中文用顿号连接、括号收尾，英文用逗号与 "of N total"——整句做一个资源键
 * 反而会让某些语言读起来别扭，而这里每段都是完整的词组。
 */
export function portSummaryText(summary: PortSummary): string {
  if (summary.total === 0) {
    return '';
  }
  if (summary.open === 0 && summary.closed === 0) {
    return ToolUiKit.text($r('app.string.port_summary_not_started'));
  }
  let text: string = ToolUiKit.stringOf($r('app.string.port_summary_open'),
    [String(summary.open)]);
  if (summary.closed > 0) {
    text += ToolUiKit.stringOf($r('app.string.port_summary_closed'),
      [String(summary.closed)]);
  }
  if (summary.skipped > 0) {
    text += ToolUiKit.stringOf($r('app.string.port_summary_skipped'),
      [String(summary.skipped)]);
  }
  return text + ToolUiKit.stringOf($r('app.string.port_summary_total'),
    [String(summary.total)]);
}

/** 结果的可复制文本 */
export function portResultsText(results: Array<PortResult>, locale: string): string {
  let text: string = '';
  for (let i: number = 0; i < results.length; i++) {
    const result: PortResult = results[i];
    text += result.target.display;
    const service: string = serviceLabelText(result.target.port, locale);
    if (service.length > 0) {
      text += ToolUiKit.stringOf($r('app.string.port_result_service'), [service]);
    }
    text += '  ' + portMarkText(result.state) + '  ' + portDetailText(result) + '\n';
  }
  return text;
}

/** 本地/保留地址提示；没有提示时返回空串 */
export function portNoticeText(host: string): string {
  const notice: PortNotice = localAddressNotice(host);
  if (notice === PortNotice.LOCALHOST) {
    return ToolUiKit.text($r('app.string.port_notice_localhost'));
  }
  if (notice === PortNotice.LOOPBACK) {
    return ToolUiKit.text($r('app.string.port_notice_loopback'));
  }
  if (notice === PortNotice.PRIVATE) {
    return ToolUiKit.text($r('app.string.port_notice_private'));
  }
  return '';
}
