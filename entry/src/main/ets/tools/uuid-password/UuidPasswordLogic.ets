/**
 * UUID v4 与随机密码生成的纯逻辑实现。
 *
 * ## 随机数从哪来：依赖注入，而不是 import 设备能力
 *
 * 这是**安全相关**的工具，随机源必须用系统安全随机（`@ohos.security.cryptoFramework`
 * 的 `createRandom()`），绝不能用 `Math.random()`——后者的输出是可预测的，
 * 拿来生成密码等于没生成。
 *
 * 但纯逻辑层不能 import 设备能力（否则 `entry/src/test` 的本地单测跑不起来）。
 * 所以这里把随机源写成 {@link NGFRandomByteSource} 这个可继承的类：
 * - **页面**提供真实现（cryptoFramework）；
 * - **单测**提供确定性的假实现（固定字节序列），于是"UUID 的版本位对不对""密码是否覆盖了
 *   所选的全部字符类别"这类**真正会出错**的逻辑可以被逐条断言，而不只是"看起来随机"。
 *
 * ## 为什么不用取模选字符
 *
 * `byte % poolSize` 在 poolSize 不整除 256 时会引入偏差（前面的字符出现概率更高）。
 * 密码学上这叫模偏差，所以这里用**拒绝采样**：落在最后一个不完整区间里的字节直接丢弃重取。
 *
 * @module tools/uuid-password/UuidPasswordLogic
 */

/** 一次最多生成的 UUID 条数。上限存在的意义是别让界面在一次点击里渲染上万行文本 */
export const UUID_MAX_COUNT: number = 100;

/** 密码长度下限：再短就谈不上强度，也不够覆盖所选的全部字符类别 */
export const PASSWORD_MIN_LENGTH: number = 4;

/** 密码长度上限：再长用户也不会真去用，且这里每生成一个字符都要向系统随机源取字节 */
export const PASSWORD_MAX_LENGTH: number = 128;

/** 小写字母池 */
const LOWER_POOL: string = 'abcdefghijklmnopqrstuvwxyz';

/** 大写字母池 */
const UPPER_POOL: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/** 数字池 */
const DIGIT_POOL: string = '0123456789';

/** 符号池：只取键盘上常见的、复制粘贴不容易出问题的符号 */
const SYMBOL_POOL: string = '!@#$%^&*()-_=+[]{};:,.?/';

/** 易混字符：肉眼分不清，手抄密码时最容易出错的那几个 */
const CONFUSABLE_CHARS: string = '0O1lI';

/** 常见弱口令片段（出现即大幅扣分） */
const COMMON_WEAK_PARTS: string[] = ['password', 'passwd', 'admin', 'root', 'qwerty',
  'letmein', 'welcome', 'iloveyou', 'abc123', '123456', '111111', '000000', '888888'];

/**
 * 随机字节源。
 *
 * 生产实现由页面提供（cryptoFramework.createRandom）；单测提供确定性的假实现。
 * 之所以做成**类**而不是 interface：Node 的类型剥离是按文件做的，
 * `import { SomeInterface }` 在运行期会找不到导出——用类就没有这个坑。
 */
export class NGFRandomByteSource {
  /**
   * 取 count 个密码学安全随机字节。
   *
   * 实现方取不到随机数时**抛异常**（而不是返回全零），调用方会把异常转成用户可见的错误提示。
   */
  nextBytes(count: number): Uint8Array {
    // 开发者可见的契约错误（会带堆栈抛到开发期），不是用户界面文案——
    // 正常构建下页面一定会注入实现，这句永远不会出现在用户面前。
    throw new Error('随机源未实现：请由页面注入 cryptoFramework 实现'); // i18n-dev-error
  }
}

/** UUID 批量生成失败的原因码 */
export enum UuidBatchFailure {
  NONE = 'none',
  /** 条数不是整数 */
  COUNT_NOT_INTEGER = 'count_not_integer',
  /** 条数小于 1 */
  COUNT_TOO_SMALL = 'count_too_small',
  /** 条数超过上限 */
  COUNT_TOO_LARGE = 'count_too_large',
  /** 取不到系统安全随机数 */
  NO_RANDOM_SOURCE = 'no_random_source'
}

/** UUID 批量生成的结果 */
export class NGFUuidBatchResult {
  readonly ok: boolean;
  /** 失败原因；成功时为 NONE（**永不为 null**） */
  readonly failure: UuidBatchFailure;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;
  readonly uuids: string[];

  constructor(ok: boolean, failure: UuidBatchFailure, args: Array<string>, uuids: string[]) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.uuids = uuids;
  }

  static success(uuids: string[]): NGFUuidBatchResult {
    return new NGFUuidBatchResult(true, UuidBatchFailure.NONE, [], uuids);
  }

  static failure(failure: UuidBatchFailure, args: Array<string>): NGFUuidBatchResult {
    return new NGFUuidBatchResult(false, failure, args, []);
  }
}

/** 密码生成选项 */
export class NGFPasswordOptions {
  /** 长度（{@link PASSWORD_MIN_LENGTH}-{@link PASSWORD_MAX_LENGTH}） */
  readonly length: number;
  readonly lowercase: boolean;
  readonly uppercase: boolean;
  readonly digits: boolean;
  readonly symbols: boolean;
  /** 是否排除 0/O/1/l/I 这类易混字符 */
  readonly excludeConfusable: boolean;

  constructor(length: number, lowercase: boolean, uppercase: boolean, digits: boolean,
    symbols: boolean, excludeConfusable: boolean) {
    this.length = length;
    this.lowercase = lowercase;
    this.uppercase = uppercase;
    this.digits = digits;
    this.symbols = symbols;
    this.excludeConfusable = excludeConfusable;
  }
}

/** 密码生成失败的原因码 */
export enum PasswordFailure {
  NONE = 'none',
  /** 长度不是整数 */
  LENGTH_NOT_INTEGER = 'length_not_integer',
  /** 长度超出允许区间 */
  LENGTH_RANGE = 'length_range',
  /** 一种字符类别都没选 */
  NO_CHARSET = 'no_charset',
  /** 排除易混字符后没有可用字符 */
  ALL_EXCLUDED = 'all_excluded',
  /** 长度不足以覆盖所选的字符类别 */
  TOO_SHORT_FOR_POOLS = 'too_short_for_pools',
  /** 取不到系统安全随机数 */
  NO_RANDOM_SOURCE = 'no_random_source'
}

/** 密码生成结果 */
export class NGFPasswordResult {
  readonly ok: boolean;
  readonly failure: PasswordFailure;
  readonly args: Array<string>;
  readonly password: string;

  constructor(ok: boolean, failure: PasswordFailure, args: Array<string>, password: string) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.password = password;
  }

  static success(password: string): NGFPasswordResult {
    return new NGFPasswordResult(true, PasswordFailure.NONE, [], password);
  }

  static failure(failure: PasswordFailure, args: Array<string>): NGFPasswordResult {
    return new NGFPasswordResult(false, failure, args, '');
  }
}

/** 强度档位 */
export enum PasswordStrengthLevel {
  VERY_WEAK = 'very_weak',
  WEAK = 'weak',
  FAIR = 'fair',
  STRONG = 'strong',
  VERY_STRONG = 'very_strong'
}

/**
 * 改进建议的**码**。
 *
 * 每条建议是一句完整的话，措辞在 UI 层。用码而不是字符串还有一个好处：
 * 测试可以断言「这条密码给出了哪几条建议」，而文案改措辞不会让测试变红。
 */
export enum PasswordAdvice {
  EMPTY_INPUT = 'empty_input',
  DIGITS_ONLY = 'digits_only',
  LOWERCASE_ONLY = 'lowercase_only',
  SINGLE_CLASS = 'single_class',
  TOO_SHORT = 'too_short',
  TOO_MANY_REPEATS = 'too_many_repeats',
  CONSECUTIVE_REPEAT = 'consecutive_repeat',
  SEQUENTIAL = 'sequential',
  COMMON_WEAK = 'common_weak'
}

/** 密码强度评估结果 */
export class NGFPasswordStrength {
  /** 0-4 分 */
  readonly score: number;
  /** 档位（措辞在 UI 层） */
  readonly level: PasswordStrengthLevel;
  /** 估算熵值（比特，已扣掉结构性惩罚） */
  readonly entropyBits: number;
  /** 改进建议（可能为空） */
  readonly suggestions: PasswordAdvice[];

  constructor(score: number, level: PasswordStrengthLevel, entropyBits: number,
    suggestions: PasswordAdvice[]) {
    this.score = score;
    this.level = level;
    this.entropyBits = entropyBits;
    this.suggestions = suggestions;
  }
}

function hexByte(value: number): string {
  const text: string = (value & 0xff).toString(16);
  return text.length === 1 ? '0' + text : text;
}

/** 去掉池子里被指定排除的字符 */
function filterOut(pool: string, excluded: string): string {
  let result: string = '';
  for (let i: number = 0; i < pool.length; i++) {
    const ch: string = pool.charAt(i);
    if (excluded.indexOf(ch) < 0) {
      result += ch;
    }
  }
  return result;
}

/** 从随机源取一个字节；取不到（异常或空数组）返回 -1 */
function nextByte(source: NGFRandomByteSource): number {
  try {
    const bytes: Uint8Array = source.nextBytes(1);
    if (bytes.length === 0) {
      return -1;
    }
    return bytes[0];
  } catch (error) {
    return -1;
  }
}

/**
 * 在 [0, limit) 上均匀取一个下标（拒绝采样，消除模偏差）。
 *
 * 最多重试 64 次；极端情况下（随机源持续返回落在拒绝区间的字节）放弃重试并返回 -1，
 * 由调用方转成错误——**绝不**退化成取模，那是安全相关的降级。
 */
function uniformIndexBelow(source: NGFRandomByteSource, limit: number): number {
  if (limit <= 0) {
    return -1;
  }
  if (limit === 1) {
    return 0;
  }
  const acceptable: number = Math.floor(256 / limit) * limit;
  for (let attempt: number = 0; attempt < 64; attempt++) {
    const value: number = nextByte(source);
    if (value < 0) {
      return -1;
    }
    if (value < acceptable) {
      return value % limit;
    }
  }
  return -1;
}

/**
 * 生成一个 UUID v4。
 *
 * 版本位与变体位是**规范要求**、也是这个函数唯一容易写错的地方：
 * 第 7 个字节的高 4 位固定为 4（版本 4），第 9 个字节的高 2 位固定为 10（RFC 4122 变体）。
 * 忽略它们的话，字符串"看起来像 UUID"，但任何校验器都会认为它不是合法的 v4。
 *
 * @returns 小写、带连字符的 UUID；随机源不可用时返回空串
 */
export function generateUuidV4(source: NGFRandomByteSource): string {
  let bytes: Uint8Array;
  try {
    bytes = source.nextBytes(16);
  } catch (error) {
    return '';
  }
  if (bytes.length < 16) {
    return '';
  }
  const versioned: number = (bytes[6] & 0x0f) | 0x40;
  const variant: number = (bytes[8] & 0x3f) | 0x80;
  let hex: string = '';
  for (let i: number = 0; i < 16; i++) {
    if (i === 6) {
      hex += hexByte(versioned);
    } else if (i === 8) {
      hex += hexByte(variant);
    } else {
      hex += hexByte(bytes[i]);
    }
  }
  return formatUuid(hex, false, true);
}

/**
 * 把 32 位十六进制串格式化成 UUID 写法。
 *
 * @param hex 32 个十六进制字符（大小写均可）
 * @param uppercase 是否输出大写
 * @param hyphens 是否插入 8-4-4-4-12 的连字符
 */
export function formatUuid(hex: string, uppercase: boolean, hyphens: boolean): string {
  const normalized: string = uppercase ? hex.toUpperCase() : hex.toLowerCase();
  if (!hyphens) {
    return normalized;
  }
  if (normalized.length < 32) {
    return normalized;
  }
  return normalized.substring(0, 8) + '-' + normalized.substring(8, 12) + '-'
    + normalized.substring(12, 16) + '-' + normalized.substring(16, 20) + '-'
    + normalized.substring(20, 32);
}

/**
 * 批量生成 UUID v4。
 *
 * @param count 条数（1-{@link UUID_MAX_COUNT}）。超出上限直接报错而不是截断：
 *        静默截断会让用户以为拿到 10000 条，实际只有 100 条。
 */
export function generateUuidBatch(source: NGFRandomByteSource, count: number,
  uppercase: boolean, hyphens: boolean): NGFUuidBatchResult {
  if (isNaN(count) || Math.floor(count) !== count) {
    return NGFUuidBatchResult.failure(UuidBatchFailure.COUNT_NOT_INTEGER, []);
  }
  if (count <= 0) {
    return NGFUuidBatchResult.failure(UuidBatchFailure.COUNT_TOO_SMALL, []);
  }
  if (count > UUID_MAX_COUNT) {
    return NGFUuidBatchResult.failure(UuidBatchFailure.COUNT_TOO_LARGE,
      [String(UUID_MAX_COUNT)]);
  }
  const uuids: string[] = [];
  for (let i: number = 0; i < count; i++) {
    const uuid: string = generateUuidV4(source);
    if (uuid.length === 0) {
      return NGFUuidBatchResult.failure(UuidBatchFailure.NO_RANDOM_SOURCE, []);
    }
    uuids.push(formatUuid(uuid.split('-').join(''), uppercase, hyphens));
  }
  return NGFUuidBatchResult.success(uuids);
}

/** 按选项组装可用字符池；任一启用的类别为空都会返回空串 */
function buildPools(options: NGFPasswordOptions): string[] {
  const excluded: string = options.excludeConfusable ? CONFUSABLE_CHARS : '';
  const pools: string[] = [];
  if (options.lowercase) {
    pools.push(filterOut(LOWER_POOL, excluded));
  }
  if (options.uppercase) {
    pools.push(filterOut(UPPER_POOL, excluded));
  }
  if (options.digits) {
    pools.push(filterOut(DIGIT_POOL, excluded));
  }
  if (options.symbols) {
    pools.push(filterOut(SYMBOL_POOL, excluded));
  }
  return pools;
}

/**
 * 生成随机密码。
 *
 * 两条硬规则：
 * 1. **每个启用的字符类别至少出现一次**——否则"勾了数字却一位数字都没有"会发生，
 *    而用户是按勾选内容去满足网站口令策略的；
 * 2. 覆盖完之后整体洗牌，避免"前四位恰好就是各类别的第一个字符"这种可预测的模式。
 */
export function generatePassword(source: NGFRandomByteSource, options: NGFPasswordOptions): NGFPasswordResult {
  if (isNaN(options.length) || Math.floor(options.length) !== options.length) {
    return NGFPasswordResult.failure(PasswordFailure.LENGTH_NOT_INTEGER, []);
  }
  if (options.length < PASSWORD_MIN_LENGTH || options.length > PASSWORD_MAX_LENGTH) {
    return NGFPasswordResult.failure(PasswordFailure.LENGTH_RANGE,
      [String(PASSWORD_MIN_LENGTH), String(PASSWORD_MAX_LENGTH)]);
  }
  const pools: string[] = buildPools(options);
  if (pools.length === 0) {
    return NGFPasswordResult.failure(PasswordFailure.NO_CHARSET, []);
  }
  for (let i: number = 0; i < pools.length; i++) {
    if (pools[i].length === 0) {
      return NGFPasswordResult.failure(PasswordFailure.ALL_EXCLUDED, []);
    }
  }
  // 不变式守卫：下面会**从每个类别各取一个字符**，所以长度至少要等于类别数。
  //
  // 说明：以当前常量（PASSWORD_MIN_LENGTH = 4、最多 4 个类别）这条分支**不可达**——
  // 长度下限恰好等于类别数上限。留着它是因为它是真实的不变式：
  // 谁把 PASSWORD_MIN_LENGTH 改小到 3，没有这道守卫就会静默生成
  // 「选了 4 个类别但只用了 3 个」的密码。宁可留一句永不触发的守卫，
  // 也不要一个只有在改常量时才暴露的错答案。
  if (options.length < pools.length) {
    return NGFPasswordResult.failure(PasswordFailure.TOO_SHORT_FOR_POOLS,
      [String(pools.length)]);
  }

  let unionPool: string = '';
  for (let i: number = 0; i < pools.length; i++) {
    unionPool += pools[i];
  }

  const chars: string[] = [];
  for (let i: number = 0; i < pools.length; i++) {
    const index: number = uniformIndexBelow(source, pools[i].length);
    if (index < 0) {
      return NGFPasswordResult.failure(PasswordFailure.NO_RANDOM_SOURCE, []);
    }
    chars.push(pools[i].charAt(index));
  }
  while (chars.length < options.length) {
    const index: number = uniformIndexBelow(source, unionPool.length);
    if (index < 0) {
      return NGFPasswordResult.failure(PasswordFailure.NO_RANDOM_SOURCE, []);
    }
    chars.push(unionPool.charAt(index));
  }
  // Fisher–Yates 洗牌：保证"先放每类字符"这个生成顺序不会体现在最终结果里
  for (let i: number = chars.length - 1; i > 0; i--) {
    const j: number = uniformIndexBelow(source, i + 1);
    if (j < 0) {
      return NGFPasswordResult.failure(PasswordFailure.NO_RANDOM_SOURCE, []);
    }
    const swapped: string = chars[i];
    chars[i] = chars[j];
    chars[j] = swapped;
  }
  let password: string = '';
  for (let i: number = 0; i < chars.length; i++) {
    password += chars[i];
  }
  return NGFPasswordResult.success(password);
}

function countDistinct(password: string): number {
  let distinct: string = '';
  for (let i: number = 0; i < password.length; i++) {
    const ch: string = password.charAt(i);
    if (distinct.indexOf(ch) < 0) {
      distinct += ch;
    }
  }
  return distinct.length;
}

/** 是否存在 count 个及以上连续相同的字符 */
function hasRepeatedRun(password: string, runLength: number): boolean {
  let run: number = 1;
  for (let i: number = 1; i < password.length; i++) {
    if (password.charAt(i) === password.charAt(i - 1)) {
      run++;
      if (run >= runLength) {
        return true;
      }
    } else {
      run = 1;
    }
  }
  return false;
}

/** 是否存在 count 个及以上连续递增/递减的字符（如 abc、4321） */
function hasSequentialRun(password: string, runLength: number): boolean {
  let ascending: number = 1;
  let descending: number = 1;
  for (let i: number = 1; i < password.length; i++) {
    const difference: number = password.charCodeAt(i) - password.charCodeAt(i - 1);
    ascending = difference === 1 ? ascending + 1 : 1;
    descending = difference === -1 ? descending + 1 : 1;
    if (ascending >= runLength || descending >= runLength) {
      return true;
    }
  }
  return false;
}

function containsCommonPart(password: string): boolean {
  const lower: string = password.toLowerCase();
  for (let i: number = 0; i < COMMON_WEAK_PARTS.length; i++) {
    if (lower.indexOf(COMMON_WEAK_PARTS[i]) >= 0) {
      return true;
    }
  }
  return false;
}

/**
 * 「太短」的判定阈值（位）。
 *
 * 提出来是因为它同时出现在**判断**（penalty）与**文案参数**（「长度不足 N 位」）里：
 * 两处各写一个 8，改一处就漂移。
 */
const WEAK_LENGTH_THRESHOLD: number = 8;

function strengthLevelOf(score: number): PasswordStrengthLevel {
  if (score <= 0) {
    return PasswordStrengthLevel.VERY_WEAK;
  }
  if (score === 1) {
    return PasswordStrengthLevel.WEAK;
  }
  if (score === 2) {
    return PasswordStrengthLevel.FAIR;
  }
  if (score === 3) {
    return PasswordStrengthLevel.STRONG;
  }
  return PasswordStrengthLevel.VERY_STRONG;
}

/**
 * 评估密码强度。
 *
 * 口径说明（写在页面上，免得用户以为这是个"权威结论"）：
 * 熵值是**理论上界**——按"字符集大小 ^ 长度"估算，再按结构性问题扣分，
 * 它不检测"这个密码是否出现在泄露库里"，也不做字典攻击模拟。
 */
export function evaluatePasswordStrength(password: string): NGFPasswordStrength {
  const suggestions: PasswordAdvice[] = [];
  if (password.length === 0) {
    return new NGFPasswordStrength(0, PasswordStrengthLevel.VERY_WEAK, 0,
      [PasswordAdvice.EMPTY_INPUT]);
  }
  let poolSize: number = 0;
  let classCount: number = 0;
  let hasLower: boolean = false;
  let hasUpper: boolean = false;
  let hasDigit: boolean = false;
  let hasSymbol: boolean = false;
  let hasOther: boolean = false;
  for (let i: number = 0; i < password.length; i++) {
    const ch: string = password.charAt(i);
    if (LOWER_POOL.indexOf(ch) >= 0) {
      hasLower = true;
    } else if (UPPER_POOL.indexOf(ch) >= 0) {
      hasUpper = true;
    } else if (DIGIT_POOL.indexOf(ch) >= 0) {
      hasDigit = true;
    } else if (SYMBOL_POOL.indexOf(ch) >= 0) {
      hasSymbol = true;
    } else {
      hasOther = true;
    }
  }
  if (hasLower) {
    poolSize += LOWER_POOL.length;
    classCount++;
  }
  if (hasUpper) {
    poolSize += UPPER_POOL.length;
    classCount++;
  }
  if (hasDigit) {
    poolSize += DIGIT_POOL.length;
    classCount++;
  }
  if (hasSymbol) {
    poolSize += SYMBOL_POOL.length;
    classCount++;
  }
  if (hasOther) {
    poolSize += 33;
    classCount++;
  }
  const perCharBits: number = poolSize > 1 ? Math.log(poolSize) / Math.log(2) : 0;
  const rawBits: number = password.length * perCharBits;
  let penalty: number = 0;

  if (classCount <= 1) {
    penalty += 10;
    if (hasDigit) {
      suggestions.push(PasswordAdvice.DIGITS_ONLY);
    } else if (hasLower) {
      suggestions.push(PasswordAdvice.LOWERCASE_ONLY);
    } else {
      suggestions.push(PasswordAdvice.SINGLE_CLASS);
    }
  }
  if (password.length < WEAK_LENGTH_THRESHOLD) {
    penalty += 8;
    // 阈值同时用于判断与文案参数：只写一处，改阈值时提示不会过期
    suggestions.push(PasswordAdvice.TOO_SHORT);
  }
  if (countDistinct(password) * 2 <= password.length) {
    penalty += 12;
    suggestions.push(PasswordAdvice.TOO_MANY_REPEATS);
  }
  if (hasRepeatedRun(password, 3)) {
    penalty += 8;
    suggestions.push(PasswordAdvice.CONSECUTIVE_REPEAT);
  }
  if (hasSequentialRun(password, 3)) {
    penalty += 8;
    suggestions.push(PasswordAdvice.SEQUENTIAL);
  }
  if (containsCommonPart(password)) {
    penalty += 20;
    suggestions.push(PasswordAdvice.COMMON_WEAK);
  }
  const adjusted: number = rawBits - penalty > 0 ? rawBits - penalty : 0;
  let score: number = 0;
  if (adjusted >= 80) {
    score = 4;
  } else if (adjusted >= 60) {
    score = 3;
  } else if (adjusted >= 36) {
    score = 2;
  } else if (adjusted >= 28) {
    score = 1;
  }
  return new NGFPasswordStrength(score, strengthLevelOf(score),
    Math.round(adjusted * 10) / 10, suggestions);
}