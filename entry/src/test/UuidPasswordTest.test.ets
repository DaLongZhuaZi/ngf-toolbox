import { describe, expect, it } from '@ohos/hypium';
import {
  evaluatePasswordStrength,
  formatUuid,
  generatePassword,
  generateUuidBatch,
  generateUuidV4,
  NGFPasswordOptions,
  NGFPasswordResult,
  NGFPasswordStrength,
  NGFRandomByteSource,
  NGFUuidBatchResult,
  PasswordAdvice,
  PasswordFailure,
  PasswordStrengthLevel,
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  UUID_MAX_COUNT,
  UuidBatchFailure
} from '../main/ets/tools/uuid-password/UuidPasswordLogic';

/**
 * UUID / 随机密码的纯逻辑单测。
 *
 * 随机性是测不了的，但**除了随机性之外的所有东西**都能测：版本位、变体位、格式化、
 * 数量与长度边界、字符类别覆盖、模偏差处理、强度评分。这些恰恰是用户真正会踩到的地方。
 * 随机源在这里被换成确定性实现——这正是把随机源做成可注入基类的意义。
 */

/** 递增字节源：0,1,2,...（确定性，便于断言版本位与格式） */
class CountingSource extends NGFRandomByteSource {
  private counter: number = 0;
  nextBytes(count: number): Uint8Array {
    const out: Uint8Array = new Uint8Array(count);
    for (let i: number = 0; i < count; i++) {
      out[i] = this.counter & 0xff;
      this.counter++;
    }
    return out;
  }
}

/** 固定字节源：每次都给同一个值（用于验证"版本位被改写"这类断言） */
class FixedSource extends NGFRandomByteSource {
  private value: number;
  constructor(value: number) {
    super();
    this.value = value;
  }
  nextBytes(count: number): Uint8Array {
    const out: Uint8Array = new Uint8Array(count);
    for (let i: number = 0; i < count; i++) {
      out[i] = this.value;
    }
    return out;
  }
}

/** 坏掉的随机源：模拟设备安全随机不可用 */
class BrokenSource extends NGFRandomByteSource {
  nextBytes(count: number): Uint8Array {
    throw new Error('crypto unavailable');
  }
}

/** 空字节源：返回长度不足的数组（模拟异常实现） */
class EmptySource extends NGFRandomByteSource {
  nextBytes(count: number): Uint8Array {
    return new Uint8Array(0);
  }
}

function isUuidShaped(value: string): boolean {
  if (value.length !== 36) {
    return false;
  }
  const groups: string[] = value.split('-');
  if (groups.length !== 5) {
    return false;
  }
  return groups[0].length === 8 && groups[1].length === 4 && groups[2].length === 4
    && groups[3].length === 4 && groups[4].length === 12;
}

function classify(password: string): string {
  let lower: number = 0;
  let upper: number = 0;
  let digit: number = 0;
  let symbol: number = 0;
  for (let i: number = 0; i < password.length; i++) {
    const ch: string = password.charAt(i);
    const code: number = password.charCodeAt(i);
    if (ch >= 'a' && ch <= 'z') {
      lower++;
    } else if (ch >= 'A' && ch <= 'Z') {
      upper++;
    } else if (code >= 48 && code <= 57) {
      digit++;
    } else {
      symbol++;
    }
  }
  return String(lower) + '/' + String(upper) + '/' + String(digit) + '/' + String(symbol);
}

export default function uuidPasswordTest() {
  describe('uuidPasswordTest', () => {
    it('UUID v4 的版本位与变体位必须符合 RFC 4122(防只拼随机十六进制)', 0, () => {
      const uuid: string = generateUuidV4(new CountingSource());
      // 第 7 字节 0x06 → 版本位写成 4（0x46）；第 9 字节 0x08 → 变体位写成 88
      expect(uuid).assertEqual('00010203-0405-4607-8809-0a0b0c0d0e0f');
      expect(uuid.charAt(14)).assertEqual('4');
      const variant: string = uuid.charAt(19);
      expect(variant === '8' || variant === '9' || variant === 'a' || variant === 'b').assertTrue();
      expect(isUuidShaped(uuid)).assertTrue();
      const zero: string = generateUuidV4(new FixedSource(0));
      expect(zero).assertEqual('00000000-0000-4000-8000-000000000000');
    });

    it('格式选项：大小写与连字符', 0, () => {
      const upper: string = generateUuidV4(new FixedSource(0xab));
      expect(generateUuidBatch(new FixedSource(0xab), 1, true, true).uuids[0])
        .assertEqual(upper.toUpperCase());
      const bare: string = generateUuidBatch(new FixedSource(0xab), 1, false, false).uuids[0];
      expect(bare.length).assertEqual(32);
      expect(bare.indexOf('-')).assertEqual(-1);
      expect(formatUuid('00112233445566778899aabbccddeeff', false, true))
        .assertEqual('00112233-4455-6677-8899-aabbccddeeff');
      expect(formatUuid('abc', false, true)).assertEqual('abc');
    });

    it('批量生成的条数上限必须显式拒绝(防一次渲染上万行卡死界面)', 0, () => {
      const ok: NGFUuidBatchResult = generateUuidBatch(new CountingSource(), UUID_MAX_COUNT, false, true);
      expect(ok.ok).assertTrue();
      expect(ok.uuids.length).assertEqual(UUID_MAX_COUNT);
      const tooMany: NGFUuidBatchResult = generateUuidBatch(new CountingSource(), UUID_MAX_COUNT + 1, false, true);
      expect(tooMany.ok).assertFalse();
      // 断言原因码与参数，而不是文案（文案已下移到 UI 层）
      expect(tooMany.failure).assertEqual(UuidBatchFailure.COUNT_TOO_LARGE);
      // 上限要跟着参数走，常量改了文案才不会过期
      expect(tooMany.args[0]).assertEqual(String(UUID_MAX_COUNT));
      expect(generateUuidBatch(new CountingSource(), 0, false, true).failure)
        .assertEqual(UuidBatchFailure.COUNT_TOO_SMALL);
      expect(generateUuidBatch(new CountingSource(), 1.5, false, true).failure)
        .assertEqual(UuidBatchFailure.COUNT_NOT_INTEGER);
    });

    it('批量生成的 UUID 必须互不相同(防随机源被复用成同一个值)', 0, () => {
      const batch: NGFUuidBatchResult = generateUuidBatch(new CountingSource(), 5, false, true);
      expect(batch.ok).assertTrue();
      const distinct: string = batch.uuids.join('|');
      for (let i: number = 0; i < batch.uuids.length; i++) {
        const first: number = distinct.indexOf(batch.uuids[i]);
        const last: number = distinct.lastIndexOf(batch.uuids[i]);
        expect(first).assertEqual(last);
      }
    });

    it('随机源不可用时要报错，绝不能退化成 Math.random', 0, () => {
      expect(generateUuidV4(new BrokenSource())).assertEqual('');
      const broken: NGFUuidBatchResult = generateUuidBatch(new BrokenSource(), 3, false, true);
      expect(broken.ok).assertFalse();
      expect(broken.failure).assertEqual(UuidBatchFailure.NO_RANDOM_SOURCE);
      const empty: NGFUuidBatchResult = generateUuidBatch(new EmptySource(), 3, false, true);
      expect(empty.ok).assertFalse();
    });

    it('密码长度上下限与整数校验', 0, () => {
      const base: NGFPasswordOptions = new NGFPasswordOptions(12, true, true, true, true, false);
      expect(generatePassword(new CountingSource(), base).ok).assertTrue();
      expect(generatePassword(new CountingSource(),
        new NGFPasswordOptions(PASSWORD_MAX_LENGTH, true, true, true, true, false)).ok).assertTrue();
      const tooShort: NGFPasswordResult = generatePassword(new CountingSource(),
        new NGFPasswordOptions(PASSWORD_MIN_LENGTH - 1, true, false, false, false, false));
      expect(tooShort.ok).assertFalse();
      // 注意：长度低于下限会先被 LENGTH_RANGE 拦住，
      // 所以 TOO_SHORT_FOR_POOLS（长度 < 类别数）在当前常量下不可达——
      // 它是一道不变式守卫，见 UuidPasswordLogic 里的说明。
      expect(tooShort.failure).assertEqual(PasswordFailure.LENGTH_RANGE);
      const tooLong: NGFPasswordResult = generatePassword(new CountingSource(),
        new NGFPasswordOptions(PASSWORD_MAX_LENGTH + 1, true, false, false, false, false));
      expect(tooLong.ok).assertFalse();
      expect(tooLong.failure).assertEqual(PasswordFailure.LENGTH_RANGE);
      expect(tooLong.args[0]).assertEqual(String(PASSWORD_MIN_LENGTH));
      expect(tooLong.args[1]).assertEqual(String(PASSWORD_MAX_LENGTH));
      expect(generatePassword(new CountingSource(),
        new NGFPasswordOptions(8.5, true, false, false, false, false)).failure)
        .assertEqual(PasswordFailure.LENGTH_NOT_INTEGER);
    });

    it('所有字符类别都关掉时必须拒绝并提示', 0, () => {
      const none: NGFPasswordResult = generatePassword(new CountingSource(),
        new NGFPasswordOptions(12, false, false, false, false, false));
      expect(none.ok).assertFalse();
      expect(none.failure).assertEqual(PasswordFailure.NO_CHARSET);
      expect(none.password).assertEqual('');
    });

    it('开启的每个字符类别都至少要出现一次(否则不满足网站口令策略)', 0, () => {
      const options: NGFPasswordOptions = new NGFPasswordOptions(12, true, true, true, true, false);
      for (let round: number = 0; round < 5; round++) {
        const result: NGFPasswordResult = generatePassword(new CountingSource(), options);
        expect(result.ok).assertTrue();
        expect(result.password.length).assertEqual(12);
        const parts: string[] = classify(result.password).split('/');
        expect(parts.length).assertEqual(4);
        // 小写 / 大写 / 数字 / 符号四类都必须至少出现一次
        expect(Number(parts[0]) > 0).assertTrue();
        expect(Number(parts[1]) > 0).assertTrue();
        expect(Number(parts[2]) > 0).assertTrue();
        expect(Number(parts[3]) > 0).assertTrue();
      }
    });

    it('排除易混字符后结果里不能出现 0 O 1 l I', 0, () => {
      const options: NGFPasswordOptions = new NGFPasswordOptions(16, true, true, true, true, true);
      for (let round: number = 0; round < 20; round++) {
        const result: NGFPasswordResult = generatePassword(new CountingSource(), options);
        expect(result.ok).assertTrue();
        expect(result.password.indexOf('0')).assertEqual(-1);
        expect(result.password.indexOf('O')).assertEqual(-1);
        expect(result.password.indexOf('1')).assertEqual(-1);
        expect(result.password.indexOf('l')).assertEqual(-1);
        expect(result.password.indexOf('I')).assertEqual(-1);
      }
    });

    it('随机源不可用时密码生成必须失败并说明原因', 0, () => {
      const result: NGFPasswordResult = generatePassword(new BrokenSource(),
        new NGFPasswordOptions(12, true, true, true, true, false));
      expect(result.ok).assertFalse();
      expect(result.failure).assertEqual(PasswordFailure.NO_RANDOM_SOURCE);
    });

    it('强度评估：纯数字/纯小写/重复字符都必须偏低分', 0, () => {
      expect(evaluatePasswordStrength('12345678').score).assertEqual(0);
      expect(evaluatePasswordStrength('aaaaaaaaaaaa').score).assertEqual(0);
      expect(evaluatePasswordStrength('abcdefgh').score).assertEqual(0);
      expect(evaluatePasswordStrength('password').score).assertEqual(0);
      expect(evaluatePasswordStrength('111111111111').score).assertEqual(0);
      // 档位现在是枚举，措辞在 UI 层——断言档位而不是中文
      expect(evaluatePasswordStrength('12345678').level)
        .assertEqual(PasswordStrengthLevel.VERY_WEAK);
    });

    it('强度评估：纯数字与纯小写要给出针对性的建议', 0, () => {
      const digits: NGFPasswordStrength = evaluatePasswordStrength('83920174');
      // 建议也是码：这样文案改措辞不会让测试变红，
      // 而「这条密码该给出哪几条建议」这个判断被钉住了。
      expect(digits.suggestions.length > 0).assertTrue();
      expect(digits.suggestions[0]).assertEqual(PasswordAdvice.DIGITS_ONLY);
      const lower: NGFPasswordStrength = evaluatePasswordStrength('mfxkzqwb');
      expect(lower.suggestions[0]).assertEqual(PasswordAdvice.LOWERCASE_ONLY);
      const repeated: NGFPasswordStrength = evaluatePasswordStrength('abababababab');
      expect(repeated.suggestions.indexOf(PasswordAdvice.TOO_MANY_REPEATS) >= 0).assertTrue();
    });

    it('强度评估：混合字符的长密码必须拿到高分且无建议', 0, () => {
      const medium: NGFPasswordStrength = evaluatePasswordStrength('Xk9#mQ2\$');
      expect(medium.score).assertEqual(2);
      const strong: NGFPasswordStrength = evaluatePasswordStrength('Xk9#mQ2\$vL7!');
      expect(strong.score).assertEqual(3);
      const veryStrong: NGFPasswordStrength = evaluatePasswordStrength('Xk9#mQ2\$vL7!pR4&');
      expect(veryStrong.score).assertEqual(4);
      expect(veryStrong.suggestions.length).assertEqual(0);
      expect(veryStrong.entropyBits > 80).assertTrue();
    });

    it('强度评估：常见弱口令片段要被识别', 0, () => {
      const common: NGFPasswordStrength = evaluatePasswordStrength('qwerty123456');
      expect(common.score <= 1).assertTrue();
      expect(common.suggestions.indexOf(PasswordAdvice.COMMON_WEAK) >= 0).assertTrue();
      const admin: NGFPasswordStrength = evaluatePasswordStrength('Admin@2024x');
      expect(admin.suggestions.indexOf(PasswordAdvice.COMMON_WEAK) >= 0).assertTrue();
    });

    it('强度评估：空密码返回 0 分并提示', 0, () => {
      const empty: NGFPasswordStrength = evaluatePasswordStrength('');
      expect(empty.score).assertEqual(0);
      expect(empty.entropyBits).assertEqual(0);
      expect(empty.suggestions[0]).assertEqual(PasswordAdvice.EMPTY_INPUT);
    });

    it('生成的密码本身应当得到与长度相称的评分', 0, () => {
      const options: NGFPasswordOptions = new NGFPasswordOptions(20, true, true, true, true, false);
      const result: NGFPasswordResult = generatePassword(new CountingSource(), options);
      expect(result.ok).assertTrue();
      const strength: NGFPasswordStrength = evaluatePasswordStrength(result.password);
      expect(strength.score >= 3).assertTrue();
    });
  });
}