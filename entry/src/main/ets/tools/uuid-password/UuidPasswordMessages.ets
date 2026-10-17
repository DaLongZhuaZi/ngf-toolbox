/**
 * UUID / 密码工具的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑（\`UuidPasswordLogic.ets\`）只给：失败原因码、强度**档位**、建议**码**。
 * 措辞全在这里——因为纯逻辑层不能 import ArkUI 的 \`$r()\`。
 *
 * 强度与建议改用码而不是字符串，还有一个测试上的好处：
 * 可以断言「这条密码给出了哪几条建议」，而文案改措辞不会让测试变红。
 *
 * @module tools/uuid-password/UuidPasswordMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  evaluatePasswordStrength,
  NGFPasswordStrength,
  PasswordAdvice,
  PasswordFailure,
  PasswordStrengthLevel,
  UuidBatchFailure
} from './UuidPasswordLogic';

/** 单个开关字段的标识常量（见\`UuidPasswordPage\` 里 toggleClass 的说明） */
export const FIELD_LOWERCASE: string = 'lowercase';
export const FIELD_UPPERCASE: string = 'uppercase';
export const FIELD_DIGITS: string = 'digits';
export const FIELD_SYMBOLS: string = 'symbols';

/** UUID 批量生成失败翻译成人话 */
export function uuidFailureText(failure: UuidBatchFailure, args: Array<string>): string {
  if (failure === UuidBatchFailure.COUNT_NOT_INTEGER) {
    return ToolUiKit.text($r('app.string.uuidpwd_err_uuid_count_not_integer'));
  }
  if (failure === UuidBatchFailure.COUNT_TOO_SMALL) {
    return ToolUiKit.text($r('app.string.uuidpwd_err_uuid_count_too_small'));
  }
  if (failure === UuidBatchFailure.COUNT_TOO_LARGE) {
    return ToolUiKit.stringOf($r('app.string.uuidpwd_err_uuid_count_too_large'), [args[0]]);
  }
  if (failure === UuidBatchFailure.NO_RANDOM_SOURCE) {
    return ToolUiKit.text($r('app.string.uuidpwd_err_no_random_uuid'));
  }
  return '';
}

/** 密码生成失败翻译成人话 */
export function passwordFailureText(failure: PasswordFailure, args: Array<string>): string {
  if (failure === PasswordFailure.LENGTH_NOT_INTEGER) {
    return ToolUiKit.text($r('app.string.uuidpwd_err_pwd_length_not_integer'));
  }
  if (failure === PasswordFailure.LENGTH_RANGE) {
    return ToolUiKit.stringOf($r('app.string.uuidpwd_err_pwd_length_range'), [args[0], args[1]]);
  }
  if (failure === PasswordFailure.NO_CHARSET) {
    return ToolUiKit.text($r('app.string.uuidpwd_err_pwd_no_charset'));
  }
  if (failure === PasswordFailure.ALL_EXCLUDED) {
    return ToolUiKit.text($r('app.string.uuidpwd_err_pwd_all_excluded'));
  }
  if (failure === PasswordFailure.TOO_SHORT_FOR_POOLS) {
    return ToolUiKit.stringOf($r('app.string.uuidpwd_err_pwd_too_short_for_pools'), [args[0]]);
  }
  if (failure === PasswordFailure.NO_RANDOM_SOURCE) {
    return ToolUiKit.text($r('app.string.uuidpwd_err_pwd_no_random'));
  }
  return '';
}

/** 强度档位名 */
export function strengthLevelText(level: PasswordStrengthLevel): string {
  if (level === PasswordStrengthLevel.VERY_WEAK) {
    return ToolUiKit.text($r('app.string.uuidpwd_level_very_weak'));
  }
  if (level === PasswordStrengthLevel.WEAK) {
    return ToolUiKit.text($r('app.string.uuidpwd_level_weak'));
  }
  if (level === PasswordStrengthLevel.FAIR) {
    return ToolUiKit.text($r('app.string.uuidpwd_level_fair'));
  }
  if (level === PasswordStrengthLevel.STRONG) {
    return ToolUiKit.text($r('app.string.uuidpwd_level_strong'));
  }
  return ToolUiKit.text($r('app.string.uuidpwd_level_very_strong'));
}

/** 单条改进建议 */
export function passwordAdviceText(advice: PasswordAdvice, minLength: number): string {
  if (advice === PasswordAdvice.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.uuidpwd_advice_empty'));
  }
  if (advice === PasswordAdvice.DIGITS_ONLY) {
    return ToolUiKit.text($r('app.string.uuidpwd_advice_digits_only'));
  }
  if (advice === PasswordAdvice.LOWERCASE_ONLY) {
    return ToolUiKit.text($r('app.string.uuidpwd_advice_lowercase_only'));
  }
  if (advice === PasswordAdvice.SINGLE_CLASS) {
    return ToolUiKit.text($r('app.string.uuidpwd_advice_single_class'));
  }
  if (advice === PasswordAdvice.TOO_SHORT) {
    return ToolUiKit.stringOf($r('app.string.uuidpwd_advice_too_short'), [String(minLength)]);
  }
  if (advice === PasswordAdvice.TOO_MANY_REPEATS) {
    return ToolUiKit.text($r('app.string.uuidpwd_advice_too_many_repeats'));
  }
  if (advice === PasswordAdvice.CONSECUTIVE_REPEAT) {
    return ToolUiKit.text($r('app.string.uuidpwd_advice_consecutive_repeat'));
  }
  if (advice === PasswordAdvice.SEQUENTIAL) {
    return ToolUiKit.text($r('app.string.uuidpwd_advice_sequential'));
  }
  return ToolUiKit.text($r('app.string.uuidpwd_advice_common_weak'));
}

/**
 * 强度那一行的完整文案。
 *
 * 「强度：<档位>（估算熵 N 比特）」整句做成一个资源键、档位与熵值走 %s：
 * 括号、冒号、量词位置在中英之间都不一样，拼接必然要推倒重写。
 */
export function strengthLineText(strength: NGFPasswordStrength, minLength: number): string {
  return ToolUiKit.stringOf($r('app.string.uuidpwd_pwd_strength'),
    [strengthLevelText(strength.level), String(strength.entropyBits)]);
}

/** 建议清单（已翻译），供页面逐条显示 */
export function passwordAdviceList(strength: NGFPasswordStrength, minLength: number): Array<string> {
  const list: Array<string> = [];
  for (let i: number = 0; i < strength.suggestions.length; i++) {
    list.push(passwordAdviceText(strength.suggestions[i], minLength));
  }
  return list;
}
