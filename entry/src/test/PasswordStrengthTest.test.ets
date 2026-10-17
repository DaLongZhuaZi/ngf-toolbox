import { describe, expect, it } from '@ohos/hypium';
import {
  advicePriority,
  evaluateWithSummary,
  StrengthSummary
} from '../main/ets/tools/password-strength/PasswordStrengthLogic';
import { PasswordAdvice } from '../main/ets/tools/uuid-password/UuidPasswordLogic';

/**
 * 密码强度报告的单测：**手算基准**（score/summary 映射）+ 建议优先级。
 */
export default function passwordStrengthTest() {
  describe('passwordStrengthTest', () => {
    it('强密码：长混合 → summary=strong，无建议', 0, () => {
      const r = evaluateWithSummary('Xk9#mQ2$vL8p');
      expect(r.summary).assertEqual(StrengthSummary.STRONG);
      expect(r.strength.suggestions.length).assertEqual(0);
    });

    it('纯数字短密码 → weak + 多条建议', 0, () => {
      const r = evaluateWithSummary('123456');
      expect(r.summary).assertEqual(StrengthSummary.WEAK);
      let hasDigitsOnly = false;
      for (let i = 0; i < r.strength.suggestions.length; i++) {
        if (r.strength.suggestions[i] === PasswordAdvice.DIGITS_ONLY) {
          hasDigitsOnly = true;
        }
      }
      expect(hasDigitsOnly).assertEqual(true);
    });

    it('空输入 → weak + EMPTY_INPUT 建议', 0, () => {
      const r = evaluateWithSummary('');
      expect(r.summary).assertEqual(StrengthSummary.WEAK);
      expect(r.strength.suggestions[0]).assertEqual(PasswordAdvice.EMPTY_INPUT);
    });

    it('中等密码 score=2 → medium', 0, () => {
      // 两类字符、长度中等
      const r = evaluateWithSummary('abcdefgh12345678');
      expect(r.summary).assertEqual(StrengthSummary.MEDIUM);
    });

    it('建议优先级：长度类 0 < 字符类 1 < 模式类 2', 0, () => {
      expect(advicePriority(PasswordAdvice.TOO_SHORT)).assertEqual(0);
      expect(advicePriority(PasswordAdvice.DIGITS_ONLY)).assertEqual(1);
      expect(advicePriority(PasswordAdvice.SINGLE_CLASS)).assertEqual(1);
      expect(advicePriority(PasswordAdvice.TOO_MANY_REPEATS)).assertEqual(2);
      expect(advicePriority(PasswordAdvice.SEQUENTIAL)).assertEqual(2);
    });
  });
}
