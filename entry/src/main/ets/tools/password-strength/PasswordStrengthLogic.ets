/**
 * 密码强度报告的纯逻辑（薄封装 uuid-password 的评估器）。
 *
 * ## 本工具的增量
 *
 * 在评估结果之上给「分级总结」：score 0-4 映射到三档总结（弱/中/强），
 * 并把建议码按优先级排序（长度类优先于字符类）。措辞仍在 UI 层。
 *
 * @module tools/password-strength/PasswordStrengthLogic
 */

import {
  evaluatePasswordStrength,
  NGFPasswordStrength,
  PasswordAdvice
} from '../uuid-password/UuidPasswordLogic';

/** 三档总结 */
export enum StrengthSummary {
  WEAK = 'weak',
  MEDIUM = 'medium',
  STRONG = 'strong'
}

/** 报告 */
export class StrengthReport {
  readonly strength: NGFPasswordStrength;
  readonly summary: StrengthSummary;

  constructor(strength: NGFPasswordStrength, summary: StrengthSummary) {
    this.strength = strength;
    this.summary = summary;
  }
}

/** 评估并生成报告 */
export function evaluateWithSummary(password: string): StrengthReport {
  const strength: NGFPasswordStrength = evaluatePasswordStrength(password);
  let summary: StrengthSummary = StrengthSummary.WEAK;
  if (strength.score >= 3) {
    summary = StrengthSummary.STRONG;
  } else if (strength.score >= 2) {
    summary = StrengthSummary.MEDIUM;
  }
  return new StrengthReport(strength, summary);
}

/** 建议优先级：长度类 < 字符类 < 模式类（数值越小越优先） */
export function advicePriority(advice: PasswordAdvice): number {
  if (advice === PasswordAdvice.TOO_SHORT || advice === PasswordAdvice.EMPTY_INPUT) {
    return 0;
  }
  if (advice === PasswordAdvice.DIGITS_ONLY || advice === PasswordAdvice.LOWERCASE_ONLY ||
    advice === PasswordAdvice.SINGLE_CLASS) {
    return 1;
  }
  return 2;
}
