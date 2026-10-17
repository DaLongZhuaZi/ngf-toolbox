/**
 * 四种摘要算法（MD5 / SHA-1 / SHA-256 / SHA-512）的纯逻辑实现。
 *
 * ## 为什么不直接用框架的 securityToolkit
 *
 * 框架能力（ngf_framework/src/main/ets/utils/SecurityToolkit.ets）只覆盖
 * SHA-256 / SHA-384 / SHA-512，这里有两个绕不开的问题：
 *
 * 1. **缺算法**：本工具要提供 MD5 与 SHA-1（校验下载文件、比对老指纹时最常用），
 *    框架没有这两种，硬凑不出来；
 * 2. **分层**：框架实现是 `async` 且依赖 `@kit.CryptoArchitectureKit`（设备能力）。
 *    纯逻辑一旦 import 它，`entry/src/test` 的本地单测就会因为缺少设备运行时跑不起来，
 *    而「纯逻辑必须有单测」是合入门禁（.agent-rules/project-rules.md PR-005）。
 *
 * 所以四种算法都在这里用纯算术实现——输入输出都是普通的值类型，单测可以直接驱动。
 * 页面另外提供「与框架 securityToolkit 交叉校验」按钮：用框架的 SHA-256/SHA-512
 * 结果对照本实现，让框架能力与本实现互为验证（见 DigestPage.ets）。
 *
 * ## 实现口径
 *
 * - 文本先按 UTF-8 编码；落单的代理码元（半个 emoji）按 W3C 编码规范替换成 U+FFFD，
 *   与浏览器 TextEncoder 一致，否则会产出非法字节序列、摘要值与其它工具对不上；
 * - 输出统一为小写十六进制：MD5 32 位、SHA-1 40 位、SHA-256 64 位、SHA-512 128 位；
 * - 采用 Merkle–Damgård 结构，64 位消息长度字段（SHA-512 为 128 位）。
 *   因此**不适用于流式超大文件**的增量摘要——本工具只处理输入框里的文本。
 *
 * @module tools/digest/HashCore
 */

/** MD5 每轮的循环左移位数（RFC 1321） */
const MD5_SHIFT: number[] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
];

/**
 * MD5 轮常量 K[i] = floor(|sin(i + 1)| * 2^32)。
 *
 * 这张表由脚本按公式生成后写入（不是手抄），单测用标准向量兜底：
 * 只要有一个数写错，空串与 'abc' 的摘要值立刻对不上。
 */
const MD5_K: number[] = [
  3614090360, 3905402710, 606105819, 3250441966, 4118548399, 1200080426, 2821735955, 4249261313,
  1770035416, 2336552879, 4294925233, 2304563134, 1804603682, 4254626195, 2792965006, 1236535329,
  4129170786, 3225465664, 643717713, 3921069994, 3593408605, 38016083, 3634488961, 3889429448,
  568446438, 3275163606, 4107603335, 1163531501, 2850285829, 4243563512, 1735328473, 2368359562,
  4294588738, 2272392833, 1839030562, 4259657740, 2763975236, 1272893353, 4139469664, 3200236656,
  681279174, 3936430074, 3572445317, 76029189, 3654602809, 3873151461, 530742520, 3299628645,
  4096336452, 1126891415, 2878612391, 4237533241, 1700485571, 2399980690, 4293915773, 2240044497,
  1873313359, 4264355552, 2734768916, 1309151649, 4149444226, 3174756917, 718787259, 3951481745
];

/** SHA-256 轮常量 K[i] = floor(frac(cbrt(第 i 个质数)) * 2^32)（FIPS 180-4） */
const SHA256_K: number[] = [
  1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
  3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
  3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
  2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
  666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
  2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
  430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
  1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298
];

/** SHA-256 初始链接值：floor(frac(sqrt(前 8 个质数)) * 2^32) */
const SHA256_H: number[] = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
];

/** SHA-512 轮常量高 32 位：K[i] = floor(frac(cbrt(第 i 个质数)) * 2^64) */
const SHA512_K_HI: number[] = [
  1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
  3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
  3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
  2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
  666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
  2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
  430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
  1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298,
  3391569614, 3515267271, 3940187606, 4118630271, 116418474, 174292421, 289380356, 460393269,
  685471733, 852142971, 1017036298, 1126000580, 1288033470, 1501505948, 1607167915, 1816402316];

/** SHA-512 轮常量低 32 位（与 {@link SHA512_K_HI} 配对） */
const SHA512_K_LO: number[] = [
  3609767458, 602891725, 3964484399, 2173295548, 4081628472, 3053834265, 2937671579, 3664609560,
  2734883394, 1164996542, 1323610764, 3590304994, 4068182383, 991336113, 633803317, 3479774868,
  2666613458, 944711139, 2341262773, 2007800933, 1495990901, 1856431235, 3175218132, 2198950837,
  3999719339, 766784016, 2566594879, 3203337956, 1034457026, 2466948901, 3758326383, 168717936,
  1188179964, 1546045734, 1522805485, 2643833823, 2343527390, 1014477480, 1206759142, 344077627,
  1290863460, 3158454273, 3505952657, 106217008, 3606008344, 1432725776, 1467031594, 851169720,
  3100823752, 1363258195, 3750685593, 3785050280, 3318307427, 3812723403, 2003034995, 3602036899,
  1575990012, 1125592928, 2716904306, 442776044, 593698344, 3733110249, 2999351573, 3815920427,
  3928383900, 566280711, 3454069534, 4000239992, 1914138554, 2731055270, 3203993006, 320620315,
  587496836, 1086792851, 365543100, 2618297676, 3409855158, 4234509866, 987167468, 1246189591];

/** SHA-512 初始链接值高 32 位：floor(frac(sqrt(前 8 个质数)) * 2^64) */
const SHA512_H_HI: number[] = [
  1779033703, 3144134277, 1013904242, 2773480762,
  1359893119, 2600822924, 528734635, 1541459225];

/** SHA-512 初始链接值低 32 位（与 {@link SHA512_H_HI} 配对） */
const SHA512_H_LO: number[] = [
  4089235720, 2227873595, 4271175723, 1595750129,
  2917565137, 725511199, 4215389547, 327033209];

/** 2^32。64 位拆成 hi/lo 两个 32 位整数后，进位要靠它算出来 */
const TWO_POW_32: number = 4294967296;

/**
 * 生成一个指定长度的全零 number 数组。
 *
 * 不用 `new Array<number>(n)`：ArkTS 的数组构造更倾向显式字面量，
 * 而 `push` 出来的数组长度可控、类型明确。
 */
function zeros(count: number): number[] {
  const out: number[] = [];
  for (let i: number = 0; i < count; i++) {
    out.push(0);
  }
  return out;
}

/** 32 位循环左移 */
function rotateLeft32(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0;
}

/** 32 位循环右移 */
function rotateRight32(value: number, bits: number): number {
  return ((value >>> bits) | (value << (32 - bits))) >>> 0;
}

/** 把 Uint8Array 转成小写十六进制串（摘要结果的统一输出格式） */
export function bytesToHex(bytes: Uint8Array): string {
  let hex: string = '';
  for (let i: number = 0; i < bytes.length; i++) {
    const value: number = bytes[i];
    const part: string = value.toString(16);
    hex += part.length === 1 ? '0' + part : part;
  }
  return hex;
}

/**
 * 把文本按 UTF-8 编码成字节数组。
 *
 * 为什么要自己写：ArkTS 的 TextEncoder 来自 `@kit.ArkTS`（设备能力），
 * 纯逻辑不能 import；而摘要工具必须先把文本变成确定的字节序列，否则
 * 同一个汉字在不同实现下会算出不同的摘要。
 */
export function utf8Encode(text: string): Uint8Array {
  const buffer: number[] = [];
  for (let i: number = 0; i < text.length; i++) {
    let codePoint: number = text.charCodeAt(i);
    if (codePoint >= 0xd800 && codePoint <= 0xdbff && i + 1 < text.length) {
      const low: number = text.charCodeAt(i + 1);
      if (low >= 0xdc00 && low <= 0xdfff) {
        codePoint = 0x10000 + ((codePoint - 0xd800) << 10) + (low - 0xdc00);
        i++;
      }
    }
    if (codePoint >= 0xd800 && codePoint <= 0xdfff) {
      // 落单代理码元不是合法码点：替换为 U+FFFD，与 W3C 编码标准/TextEncoder 一致
      codePoint = 0xfffd;
    }
    if (codePoint < 0x80) {
      buffer.push(codePoint);
    } else if (codePoint < 0x800) {
      buffer.push(0xc0 | (codePoint >> 6), 0x80 | (codePoint & 0x3f));
    } else if (codePoint < 0x10000) {
      buffer.push(0xe0 | (codePoint >> 12), 0x80 | ((codePoint >> 6) & 0x3f), 0x80 | (codePoint & 0x3f));
    } else {
      buffer.push(0xf0 | (codePoint >> 18), 0x80 | ((codePoint >> 12) & 0x3f),
        0x80 | ((codePoint >> 6) & 0x3f), 0x80 | (codePoint & 0x3f));
    }
  }
  const bytes: Uint8Array = new Uint8Array(buffer.length);
  for (let i: number = 0; i < buffer.length; i++) {
    bytes[i] = buffer[i];
  }
  return bytes;
}

/**
 * SHA-1 / SHA-256 的补位：0x80 + 若干 0 + 64 位**大端**比特长度，凑满 64 字节块。
 */
function padForSha1OrSha256(bytes: Uint8Array): Uint8Array {
  const byteLength: number = bytes.length;
  const bitLengthHigh: number = Math.floor(byteLength / 536870912);
  const bitLengthLow: number = (byteLength % 536870912) * 8;
  const zeroCount: number = (64 - ((byteLength + 9) % 64)) % 64;
  const total: number = byteLength + 1 + zeroCount + 8;
  const padded: Uint8Array = new Uint8Array(total);
  for (let i: number = 0; i < byteLength; i++) {
    padded[i] = bytes[i];
  }
  padded[byteLength] = 0x80;
  const tail: number = total - 8;
  padded[tail] = (bitLengthHigh >>> 24) & 0xff;
  padded[tail + 1] = (bitLengthHigh >>> 16) & 0xff;
  padded[tail + 2] = (bitLengthHigh >>> 8) & 0xff;
  padded[tail + 3] = bitLengthHigh & 0xff;
  padded[tail + 4] = (bitLengthLow >>> 24) & 0xff;
  padded[tail + 5] = (bitLengthLow >>> 16) & 0xff;
  padded[tail + 6] = (bitLengthLow >>> 8) & 0xff;
  padded[tail + 7] = bitLengthLow & 0xff;
  return padded;
}

/** MD5 的补位：0x80 + 若干 0 + 64 位**小端**比特长度（RFC 1321 与 SHA 家族的唯一差别） */
function padForMd5(bytes: Uint8Array): Uint8Array {
  const byteLength: number = bytes.length;
  const bitLengthHigh: number = Math.floor(byteLength / 536870912);
  const bitLengthLow: number = (byteLength % 536870912) * 8;
  const zeroCount: number = (64 - ((byteLength + 9) % 64)) % 64;
  const total: number = byteLength + 1 + zeroCount + 8;
  const padded: Uint8Array = new Uint8Array(total);
  for (let i: number = 0; i < byteLength; i++) {
    padded[i] = bytes[i];
  }
  padded[byteLength] = 0x80;
  const tail: number = total - 8;
  padded[tail] = bitLengthLow & 0xff;
  padded[tail + 1] = (bitLengthLow >>> 8) & 0xff;
  padded[tail + 2] = (bitLengthLow >>> 16) & 0xff;
  padded[tail + 3] = (bitLengthLow >>> 24) & 0xff;
  padded[tail + 4] = bitLengthHigh & 0xff;
  padded[tail + 5] = (bitLengthHigh >>> 8) & 0xff;
  padded[tail + 6] = (bitLengthHigh >>> 16) & 0xff;
  padded[tail + 7] = (bitLengthHigh >>> 24) & 0xff;
  return padded;
}

/**
 * SHA-512 的补位：块长 128 字节，长度字段 **128 位**大端。
 *
 * 长度字段的字节布局（这是最容易错的一处，写错会让所有摘要值都是错的）：
 * `[0..3] = 0`、`[4..7] = 比特长度 / 2^64`、`[8..11] = 比特长度 / 2^32`、
 * `[12..15] = 比特长度 % 2^32`。也就是说长度落在**低 64 位**，
 * 高 64 位只有超长输入（2^61 字节以上）才非零——那不是文本工具的场景。
 */
function padForSha512(bytes: Uint8Array): Uint8Array {
  const byteLength: number = bytes.length;
  const bitLengthHigh: number = Math.floor(byteLength / 2305843009213693952);
  const bitLengthMiddle: number = Math.floor(byteLength / 536870912);
  const bitLengthLow: number = (byteLength % 536870912) * 8;
  const zeroCount: number = (128 - ((byteLength + 17) % 128)) % 128;
  const total: number = byteLength + 1 + zeroCount + 16;
  const padded: Uint8Array = new Uint8Array(total);
  for (let i: number = 0; i < byteLength; i++) {
    padded[i] = bytes[i];
  }
  padded[byteLength] = 0x80;
  const tail: number = total - 16;
  padded[tail + 4] = (bitLengthHigh >>> 24) & 0xff;
  padded[tail + 5] = (bitLengthHigh >>> 16) & 0xff;
  padded[tail + 6] = (bitLengthHigh >>> 8) & 0xff;
  padded[tail + 7] = bitLengthHigh & 0xff;
  padded[tail + 8] = (bitLengthMiddle >>> 24) & 0xff;
  padded[tail + 9] = (bitLengthMiddle >>> 16) & 0xff;
  padded[tail + 10] = (bitLengthMiddle >>> 8) & 0xff;
  padded[tail + 11] = bitLengthMiddle & 0xff;
  padded[tail + 12] = (bitLengthLow >>> 24) & 0xff;
  padded[tail + 13] = (bitLengthLow >>> 16) & 0xff;
  padded[tail + 14] = (bitLengthLow >>> 8) & 0xff;
  padded[tail + 15] = bitLengthLow & 0xff;
  // tail + 0..3（长度的高 32 位）保持 new Uint8Array 的零值
  return padded;
}

/** 把 32 位值按小端写进字节数组（MD5 输出用） */
function writeUint32LittleEndian(target: Uint8Array, offset: number, value: number): void {
  target[offset] = value & 0xff;
  target[offset + 1] = (value >>> 8) & 0xff;
  target[offset + 2] = (value >>> 16) & 0xff;
  target[offset + 3] = (value >>> 24) & 0xff;
}

/** 把 32 位值按大端写进字节数组（SHA-1 / SHA-256 输出用） */
function writeUint32BigEndian(target: Uint8Array, offset: number, value: number): void {
  target[offset] = (value >>> 24) & 0xff;
  target[offset + 1] = (value >>> 16) & 0xff;
  target[offset + 2] = (value >>> 8) & 0xff;
  target[offset + 3] = value & 0xff;
}

/**
 * 计算 MD5 摘要（RFC 1321），返回小写十六进制。
 *
 * MD5 早已不适合做安全校验（已知碰撞），但校验下载文件完整性、
 * 比对服务端给的指纹仍然随处可见，所以工具箱要提供它——同时在页面上
 * 写清「MD5 不能用来判断文件是否被恶意篡改」。
 */
export function md5HexOfBytes(bytes: Uint8Array): string {
  const padded: Uint8Array = padForMd5(bytes);
  let stateA: number = 0x67452301;
  let stateB: number = 0xefcdab89;
  let stateC: number = 0x98badcfe;
  let stateD: number = 0x10325476;
  const words: number[] = zeros(16);
  for (let offset: number = 0; offset < padded.length; offset += 64) {
    for (let i: number = 0; i < 16; i++) {
      const j: number = offset + i * 4;
      words[i] = (padded[j] | (padded[j + 1] << 8) | (padded[j + 2] << 16) | (padded[j + 3] << 24)) >>> 0;
    }
    let a: number = stateA;
    let b: number = stateB;
    let c: number = stateC;
    let d: number = stateD;
    for (let i: number = 0; i < 64; i++) {
      let mixed: number = 0;
      let index: number = 0;
      if (i < 16) {
        mixed = (b & c) | (~b & d);
        index = i;
      } else if (i < 32) {
        mixed = (d & b) | (~d & c);
        index = (5 * i + 1) % 16;
      } else if (i < 48) {
        mixed = b ^ c ^ d;
        index = (3 * i + 5) % 16;
      } else {
        mixed = c ^ (b | ~d);
        index = (7 * i) % 16;
      }
      const swapped: number = d;
      d = c;
      c = b;
      // 四项相加可能超过 2^32，但远小于 2^53，double 能精确表示，再取低 32 位即可
      const sum: number = (a + mixed + MD5_K[i] + words[index]) | 0;
      b = (b + rotateLeft32(sum, MD5_SHIFT[i])) | 0;
      a = swapped;
    }
    stateA = (stateA + a) | 0;
    stateB = (stateB + b) | 0;
    stateC = (stateC + c) | 0;
    stateD = (stateD + d) | 0;
  }
  const digest: Uint8Array = new Uint8Array(16);
  writeUint32LittleEndian(digest, 0, stateA);
  writeUint32LittleEndian(digest, 4, stateB);
  writeUint32LittleEndian(digest, 8, stateC);
  writeUint32LittleEndian(digest, 12, stateD);
  return bytesToHex(digest);
}

/**
 * 计算 SHA-1 摘要（FIPS 180-4），返回小写十六进制。
 *
 * SHA-1 同样已被证明可构造碰撞，页面会明示「只适合做一致性比对，
 * 不要用它做签名或口令存储」。
 */
export function sha1HexOfBytes(bytes: Uint8Array): string {
  const padded: Uint8Array = padForSha1OrSha256(bytes);
  let stateA: number = 0x67452301;
  let stateB: number = 0xefcdab89;
  let stateC: number = 0x98badcfe;
  let stateD: number = 0x10325476;
  let stateE: number = 0xc3d2e1f0;
  const words: number[] = zeros(80);
  for (let offset: number = 0; offset < padded.length; offset += 64) {
    for (let i: number = 0; i < 16; i++) {
      const j: number = offset + i * 4;
      words[i] = ((padded[j] << 24) | (padded[j + 1] << 16) | (padded[j + 2] << 8) | padded[j + 3]) >>> 0;
    }
    for (let i: number = 16; i < 80; i++) {
      words[i] = rotateLeft32(words[i - 3] ^ words[i - 8] ^ words[i - 14] ^ words[i - 16], 1);
    }
    let a: number = stateA;
    let b: number = stateB;
    let c: number = stateC;
    let d: number = stateD;
    let e: number = stateE;
    for (let i: number = 0; i < 80; i++) {
      let mixed: number = 0;
      let constant: number = 0;
      if (i < 20) {
        mixed = (b & c) | (~b & d);
        constant = 0x5a827999;
      } else if (i < 40) {
        mixed = b ^ c ^ d;
        constant = 0x6ed9eba1;
      } else if (i < 60) {
        mixed = (b & c) | (b & d) | (c & d);
        constant = 0x8f1bbcdc;
      } else {
        mixed = b ^ c ^ d;
        constant = 0xca62c1d6;
      }
      const temp: number = (rotateLeft32(a, 5) + mixed + e + constant + words[i]) | 0;
      e = d;
      d = c;
      c = rotateLeft32(b, 30);
      b = a;
      a = temp;
    }
    stateA = (stateA + a) | 0;
    stateB = (stateB + b) | 0;
    stateC = (stateC + c) | 0;
    stateD = (stateD + d) | 0;
    stateE = (stateE + e) | 0;
  }
  const digest: Uint8Array = new Uint8Array(20);
  writeUint32BigEndian(digest, 0, stateA);
  writeUint32BigEndian(digest, 4, stateB);
  writeUint32BigEndian(digest, 8, stateC);
  writeUint32BigEndian(digest, 12, stateD);
  writeUint32BigEndian(digest, 16, stateE);
  return bytesToHex(digest);
}

/** 计算 SHA-256 摘要（FIPS 180-4），返回小写十六进制 */
export function sha256HexOfBytes(bytes: Uint8Array): string {
  const padded: Uint8Array = padForSha1OrSha256(bytes);
  const state: number[] = zeros(8);
  for (let i: number = 0; i < 8; i++) {
    state[i] = SHA256_H[i];
  }
  const words: number[] = zeros(64);
  for (let offset: number = 0; offset < padded.length; offset += 64) {
    for (let i: number = 0; i < 16; i++) {
      const j: number = offset + i * 4;
      words[i] = ((padded[j] << 24) | (padded[j + 1] << 16) | (padded[j + 2] << 8) | padded[j + 3]) >>> 0;
    }
    for (let i: number = 16; i < 64; i++) {
      const w15: number = words[i - 15];
      const w2: number = words[i - 2];
      const s0: number = rotateRight32(w15, 7) ^ rotateRight32(w15, 18) ^ (w15 >>> 3);
      const s1: number = rotateRight32(w2, 17) ^ rotateRight32(w2, 19) ^ (w2 >>> 10);
      words[i] = (words[i - 16] + s0 + words[i - 7] + s1) | 0;
    }
    let a: number = state[0];
    let b: number = state[1];
    let c: number = state[2];
    let d: number = state[3];
    let e: number = state[4];
    let f: number = state[5];
    let g: number = state[6];
    let h: number = state[7];
    for (let i: number = 0; i < 64; i++) {
      const sum1: number = rotateRight32(e, 6) ^ rotateRight32(e, 11) ^ rotateRight32(e, 25);
      const choose: number = (e & f) ^ (~e & g);
      const temp1: number = (h + sum1 + choose + SHA256_K[i] + words[i]) | 0;
      const sum0: number = rotateRight32(a, 2) ^ rotateRight32(a, 13) ^ rotateRight32(a, 22);
      const majority: number = (a & b) ^ (a & c) ^ (b & c);
      const temp2: number = (sum0 + majority) | 0;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) | 0;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) | 0;
    }
    state[0] = (state[0] + a) | 0;
    state[1] = (state[1] + b) | 0;
    state[2] = (state[2] + c) | 0;
    state[3] = (state[3] + d) | 0;
    state[4] = (state[4] + e) | 0;
    state[5] = (state[5] + f) | 0;
    state[6] = (state[6] + g) | 0;
    state[7] = (state[7] + h) | 0;
  }
  const digest: Uint8Array = new Uint8Array(32);
  for (let i: number = 0; i < 8; i++) {
    writeUint32BigEndian(digest, i * 4, state[i]);
  }
  return bytesToHex(digest);
}

// ── SHA-512：64 位运算的拆分实现 ────────────────────────────────────────
//
// SHA-512 的状态与常量都是 64 位。ArkTS 里没有可靠的 64 位整数运算
// （number 只有 53 位精确整数、BigInt 不在 ArkTS 支持子集内），
// 所以这里沿用「高 32 位 + 低 32 位」两个 number 表示一个 64 位字，
// 所有加法自己算进位，所有移位/旋转按 hi/lo 分别处理。
// 值的形状约定：成对出现时 `x[2i]` 是高位、`x[2i + 1]` 是低位。

/** 64 位循环右移的高位结果 */
function rotateRight64High(high: number, low: number, bits: number): number {
  if (bits < 32) {
    return ((high >>> bits) | (low << (32 - bits))) >>> 0;
  }
  if (bits === 32) {
    return low >>> 0;
  }
  const rest: number = bits - 32;
  return ((low >>> rest) | (high << (32 - rest))) >>> 0;
}

/** 64 位循环右移的低位结果 */
function rotateRight64Low(high: number, low: number, bits: number): number {
  if (bits < 32) {
    return ((low >>> bits) | (high << (32 - bits))) >>> 0;
  }
  if (bits === 32) {
    return high >>> 0;
  }
  const rest: number = bits - 32;
  return ((high >>> rest) | (low << (32 - rest))) >>> 0;
}

/** 64 位逻辑右移的低位结果 */
function shiftRight64Low(high: number, low: number, bits: number): number {
  if (bits < 32) {
    return ((low >>> bits) | (high << (32 - bits))) >>> 0;
  }
  if (bits === 32) {
    return high >>> 0;
  }
  return high >>> (bits - 32);
}

/** SHA-512 的压缩函数：把 128 字节块揉进 16 个 32 位半字表示的 8 个 64 位状态字 */
function sha512Compress(state: number[], words: number[]): void {
  // 消息扩展：W[t] = σ1(W[t-2]) + W[t-7] + σ0(W[t-15]) + W[t-16]
  for (let i: number = 16; i < 80; i++) {
    const h15: number = words[(i - 15) * 2];
    const l15: number = words[(i - 15) * 2 + 1];
    const sigma0High: number = (rotateRight64High(h15, l15, 1) ^ rotateRight64High(h15, l15, 8) ^ (h15 >>> 7)) >>> 0;
    const sigma0Low: number = (rotateRight64Low(h15, l15, 1) ^ rotateRight64Low(h15, l15, 8) ^ shiftRight64Low(h15, l15, 7)) >>> 0;
    const h2: number = words[(i - 2) * 2];
    const l2: number = words[(i - 2) * 2 + 1];
    const sigma1High: number = (rotateRight64High(h2, l2, 19) ^ rotateRight64High(h2, l2, 61) ^ (h2 >>> 6)) >>> 0;
    const sigma1Low: number = (rotateRight64Low(h2, l2, 19) ^ rotateRight64Low(h2, l2, 61) ^ shiftRight64Low(h2, l2, 6)) >>> 0;
    const sumLow: number = (words[(i - 16) * 2 + 1] >>> 0) + (sigma0Low >>> 0)
      + (words[(i - 7) * 2 + 1] >>> 0) + (sigma1Low >>> 0);
    const sumHigh: number = (words[(i - 16) * 2] >>> 0) + (sigma0High >>> 0)
      + (words[(i - 7) * 2] >>> 0) + (sigma1High >>> 0) + Math.floor(sumLow / TWO_POW_32);
    words[i * 2] = sumHigh >>> 0;
    words[i * 2 + 1] = sumLow >>> 0;
  }

  let aHigh: number = state[0];
  let aLow: number = state[1];
  let bHigh: number = state[2];
  let bLow: number = state[3];
  let cHigh: number = state[4];
  let cLow: number = state[5];
  let dHigh: number = state[6];
  let dLow: number = state[7];
  let eHigh: number = state[8];
  let eLow: number = state[9];
  let fHigh: number = state[10];
  let fLow: number = state[11];
  let gHigh: number = state[12];
  let gLow: number = state[13];
  let hHigh: number = state[14];
  let hLow: number = state[15];

  for (let i: number = 0; i < 80; i++) {
    // Σ1(e) = ROTR14 ^ ROTR18 ^ ROTR41
    const sum1High: number = (rotateRight64High(eHigh, eLow, 14)
      ^ rotateRight64High(eHigh, eLow, 18) ^ rotateRight64High(eHigh, eLow, 41)) >>> 0;
    const sum1Low: number = (rotateRight64Low(eHigh, eLow, 14)
      ^ rotateRight64Low(eHigh, eLow, 18) ^ rotateRight64Low(eHigh, eLow, 41)) >>> 0;
    // Ch(e, f, g)
    const chooseHigh: number = ((eHigh & fHigh) ^ ((~eHigh) & gHigh)) >>> 0;
    const chooseLow: number = ((eLow & fLow) ^ ((~eLow) & gLow)) >>> 0;
    // T1 = h + Σ1(e) + Ch(e,f,g) + K[i] + W[i]
    const t1LowRaw: number = (hLow >>> 0) + (sum1Low >>> 0) + (chooseLow >>> 0)
      + (SHA512_K_LO[i] >>> 0) + (words[i * 2 + 1] >>> 0);
    const temp1High: number = ((hHigh >>> 0) + (sum1High >>> 0) + (chooseHigh >>> 0)
      + (SHA512_K_HI[i] >>> 0) + (words[i * 2] >>> 0) + Math.floor(t1LowRaw / TWO_POW_32)) >>> 0;
    const temp1Low: number = t1LowRaw >>> 0;
    // Σ0(a) = ROTR28 ^ ROTR34 ^ ROTR39
    const sum0High: number = (rotateRight64High(aHigh, aLow, 28)
      ^ rotateRight64High(aHigh, aLow, 34) ^ rotateRight64High(aHigh, aLow, 39)) >>> 0;
    const sum0Low: number = (rotateRight64Low(aHigh, aLow, 28)
      ^ rotateRight64Low(aHigh, aLow, 34) ^ rotateRight64Low(aHigh, aLow, 39)) >>> 0;
    // Maj(a, b, c)
    const majorityHigh: number = ((aHigh & bHigh) ^ (aHigh & cHigh) ^ (bHigh & cHigh)) >>> 0;
    const majorityLow: number = ((aLow & bLow) ^ (aLow & cLow) ^ (bLow & cLow)) >>> 0;
    const t2LowRaw: number = (sum0Low >>> 0) + (majorityLow >>> 0);
    const temp2High: number = ((sum0High >>> 0) + (majorityHigh >>> 0) + Math.floor(t2LowRaw / TWO_POW_32)) >>> 0;
    const temp2Low: number = t2LowRaw >>> 0;
    // e = d + T1（用移位前的 d），a = T1 + T2
    const addedLowRaw: number = (dLow >>> 0) + (temp1Low >>> 0);
    const nextEHigh: number = ((dHigh >>> 0) + (temp1High >>> 0) + Math.floor(addedLowRaw / TWO_POW_32)) >>> 0;
    const nextELow: number = addedLowRaw >>> 0;
    const nextALowRaw: number = (temp1Low >>> 0) + (temp2Low >>> 0);
    const nextAHigh: number = ((temp1High >>> 0) + (temp2High >>> 0) + Math.floor(nextALowRaw / TWO_POW_32)) >>> 0;
    const nextALow: number = nextALowRaw >>> 0;

    hHigh = gHigh;
    hLow = gLow;
    gHigh = fHigh;
    gLow = fLow;
    fHigh = eHigh;
    fLow = eLow;
    eHigh = nextEHigh;
    eLow = nextELow;
    dHigh = cHigh;
    dLow = cLow;
    cHigh = bHigh;
    cLow = bLow;
    bHigh = aHigh;
    bLow = aLow;
    aHigh = nextAHigh;
    aLow = nextALow;
  }

  const updated: number[] = [
    aHigh, aLow, bHigh, bLow, cHigh, cLow, dHigh, dLow,
    eHigh, eLow, fHigh, fLow, gHigh, gLow, hHigh, hLow
  ];
  for (let i: number = 0; i < 16; i += 2) {
    const lowSum: number = (state[i + 1] >>> 0) + (updated[i + 1] >>> 0);
    state[i] = ((state[i] >>> 0) + (updated[i] >>> 0) + Math.floor(lowSum / TWO_POW_32)) >>> 0;
    state[i + 1] = lowSum >>> 0;
  }
}

/** 计算 SHA-512 摘要（FIPS 180-4），返回小写十六进制 */
export function sha512HexOfBytes(bytes: Uint8Array): string {
  const padded: Uint8Array = padForSha512(bytes);
  const state: number[] = zeros(16);
  for (let i: number = 0; i < 8; i++) {
    state[i * 2] = SHA512_H_HI[i];
    state[i * 2 + 1] = SHA512_H_LO[i];
  }
  const words: number[] = zeros(160);
  for (let offset: number = 0; offset < padded.length; offset += 128) {
    for (let i: number = 0; i < 16; i++) {
      const j: number = offset + i * 8;
      const high: number = ((padded[j] << 24) | (padded[j + 1] << 16) | (padded[j + 2] << 8) | padded[j + 3]) >>> 0;
      const low: number = ((padded[j + 4] << 24) | (padded[j + 5] << 16) | (padded[j + 6] << 8) | padded[j + 7]) >>> 0;
      words[i * 2] = high;
      words[i * 2 + 1] = low;
    }
    sha512Compress(state, words);
  }
  const digest: Uint8Array = new Uint8Array(64);
  for (let i: number = 0; i < 16; i++) {
    writeUint32BigEndian(digest, i * 4, state[i]);
  }
  return bytesToHex(digest);
}
