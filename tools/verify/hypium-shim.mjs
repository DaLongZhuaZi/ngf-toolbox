/**
 * `@ohos/hypium` 的本地验证替身。
 *
 * ## 为什么可以这样做
 *
 * 单测文件用的是 hypium 的 `describe / it / expect` 接口，而这套接口的语义很薄
 * （注册用例 + 断言）。在本机临时提供一份等价实现，就能让**同一份**
 * `entry/src/test/*.test.ets` 既能在真机 hypium 下跑，也能在本机 Node 下跑，
 * 不需要为本地验证单独维护一套测试——那样两套迟早会不一致，
 * 而「本地全绿、CI 全红」比没有本地验证更浪费时间。
 *
 * ## 边界
 *
 * 这是**本地开发工具**，不参与构建、不进 HAP。
 * 断言失败会抛异常（hypium 在真机上也是失败即中断该用例）。
 */

const cases = [];

function describe(name, body) {
  const previous = cases.length;
  body();
  // 记录本次 describe 新增的用例数，便于汇总
  return cases.length - previous;
}

function it(name, level, body) {
  cases.push({ name, level, body });
}

function fail(message) {
  throw new Error(message);
}

function format(value) {
  if (typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (value === null) {
    return 'null';
  }
  if (value === undefined) {
    return 'undefined';
  }
  if (Array.isArray(value)) {
    return '[' + value.map(format).join(', ') + ']';
  }
  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch (error) {
      return Object.prototype.toString.call(value);
    }
  }
  return String(value);
}

function assertEqual(actual, expected) {
  if (actual !== expected) {
    fail('期望 ' + format(expected) + '，实际 ' + format(actual));
  }
}

function assertTrue(actual) {
  if (actual !== true) {
    fail('期望 true，实际 ' + format(actual));
  }
}

function assertFalse(actual) {
  if (actual !== false) {
    fail('期望 false，实际 ' + format(actual));
  }
}

function assertContain(actual, expected) {
  if (typeof actual !== 'string' || actual.indexOf(expected) < 0) {
    fail('期望 ' + format(actual) + ' 包含 ' + format(expected));
  }
}

function assertNull(actual) {
  if (actual !== null) {
    fail('期望 null，实际 ' + format(actual));
  }
}

function assertUndefined(actual) {
  if (actual !== undefined) {
    fail('期望 undefined，实际 ' + format(actual));
  }
}

function assertThrowError(fn) {
  let threw = false;
  try {
    fn();
  } catch (error) {
    threw = true;
  }
  if (!threw) {
    fail('期望抛出异常，但没有');
  }
}

function assertInstanceOf(actual, expected) {
  if (!(actual instanceof expected)) {
    fail('期望是 ' + expected.name + ' 的实例，实际 ' + format(actual));
  }
}

function assertDeepEquals(actual, expected) {
  const a = JSON.stringify(actual);
  const b = JSON.stringify(expected);
  if (a !== b) {
    fail('深度比较不一致：期望 ' + b + '，实际 ' + a);
  }
}

function assertLarger(actual, expected) {
  if (!(actual > expected)) {
    fail('期望 ' + format(actual) + ' > ' + format(expected));
  }
}

function assertLess(actual, expected) {
  if (!(actual < expected)) {
    fail('期望 ' + format(actual) + ' < ' + format(expected));
  }
}

function assertClose(actual, expected, delta) {
  if (Math.abs(actual - expected) > delta) {
    fail('期望 ' + format(actual) + ' ≈ ' + format(expected) + '（容差 ' + delta + '）');
  }
}

export { describe, it, expect, afterEach, beforeEach, beforeAll, afterAll };
export const hypiumCases = cases;

function expect(actual) {
  return {
    assertEqual: (expected) => assertEqual(actual, expected),
    assertTrue: () => assertTrue(actual),
    assertFalse: () => assertFalse(actual),
    assertContain: (expected) => assertContain(actual, expected),
    assertNull: () => assertNull(actual),
    assertUndefined: () => assertUndefined(actual),
    assertThrowError: (fn) => assertThrowError(fn),
    assertInstanceOf: (expected) => assertInstanceOf(actual, expected),
    assertDeepEquals: (expected) => assertDeepEquals(actual, expected),
    assertLarger: (expected) => assertLarger(actual, expected),
    assertLess: (expected) => assertLess(actual, expected),
    assertClose: (expected, delta) => assertClose(actual, expected, delta)
  };
}

function beforeEach() {}
function afterEach() {}
function beforeAll() {}
function afterAll() {}
