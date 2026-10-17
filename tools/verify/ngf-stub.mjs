/**
 * `ngf_framework` 的本地验证替身。
 *
 * 只提供**纯逻辑**模块真正用到的那几个符号（logger / StringUtils /
 * ngfSettingsStoreFacade / ngfI18nManagerFacade）。UI 与设备相关的门面一律不提供——
 * 用到它们的文件本来就不是纯逻辑，不该在本地验证里跑。
 *
 * `ngfSettingsStoreFacade` 这里用一份内存 Map 实现，语义与框架的
 * Preferences 版本一致（同步读、异步写、isReady 之前读默认值）。
 * 这样 ToolStateStore 的「未就绪时拒绝写入」逻辑可以在本机被真实验证，
 * 而不是只能靠读代码确认。
 */

/**
 * 存储内容通过 `globalThis.__NGF_STUB_STORE__` 暴露给本地验证脚本。
 *
 * 为什么走 globalThis 而不是 export：测试文件 import 的是虚拟模块
 * `'ngf_framework'`，它无法直接拿到替身模块的真实路径；
 * 而「注入一个可控的存储」是验证「未就绪时必须拒绝写入」这条关键逻辑的前提。
 * 这份耦合**只存在于本地验证工具链**，不进入 App 代码。
 */
const sharedState = globalThis.__NGF_STUB_STORE__ || { memory: new Map(), ready: false };
globalThis.__NGF_STUB_STORE__ = sharedState;

const memory = sharedState.memory;

export const logger = {
  debug: () => {},
  info: () => {},
  warn: () => {},
  error: () => {},
  fatal: () => {},
  lifecycle: () => {},
  startup: () => {},
  stateChange: () => {}
};

export class StringUtils {
  static isNullOrEmpty(value) {
    return value === null || value === undefined || value.length === 0;
  }
  static isNullOrWhitespace(value) {
    return value === null || value === undefined || value.trim().length === 0;
  }
  static containsIgnoreCase(haystack, needle) {
    if (needle.length === 0) {
      return true;
    }
    if (haystack.length === 0) {
      return false;
    }
    return haystack.toLowerCase().indexOf(needle.toLowerCase()) >= 0;
  }
}

export const ngfSettingsStoreFacade = {
  // 必须每次都读 sharedState.ready，不能缓存到局部变量：
  // 缓存会让「外部把 ready 置为 true」这件事对 facade 不可见，
  // 于是所有「就绪后应当成功」的用例都会失败（本文件最初的写法就踩了这个坑）。
  isReady: () => sharedState.ready,
  getString: (key, defaultValue) => (memory.has(key) ? memory.get(key) : defaultValue),
  getNumber: (key, defaultValue) => (memory.has(key) ? memory.get(key) : defaultValue),
  getBoolean: (key, defaultValue) => (memory.has(key) ? memory.get(key) : defaultValue),
  setString: (key, value) => { memory.set(key, value); },
  setNumber: (key, value) => { memory.set(key, value); },
  setBoolean: (key, value) => { memory.set(key, value); }
};

export const ngfI18nManagerFacade = {
  resolveString: (key) => (typeof key === 'string' ? key : 'Resource'),
  resolveStringWithArgs: (key) => (typeof key === 'string' ? key : 'Resource')
};

export const ngfOverlayManagerFacade = {
  showToast: () => {}
};


/**
 * 颜色 Token 枚举（**镜像** `ngf_framework` 的 `uiTheme/contracts/IColorTokenProvider`）。
 *
 * 为什么本地验证需要它：`core/ToolboxPalette.ets` 是**纯数据**模块（要能被
 * 对比度门禁直接 import 来审计），但它必须用真实的枚举名，否则调色板和
 * 注册进框架的 Token 会对不上。桩在这里提供同名同值的枚举，
 * 让调色板在 Node 里也能加载。
 *
 * ⚠️ **镜像必须与框架保持同步**：框架的 `NGFColorToken` 增删成员时，
 * 这里要一起改，否则本地门禁会审一份过时的色表。
 * 后 5 个（error_container 起）是本仓先行补充的语义色，见 VENDORED.md。
 */
export const NGFColorToken = {
  PRIMARY: 'primary',
  ON_PRIMARY: 'on_primary',
  PRIMARY_CONTAINER: 'primary_container',
  ON_PRIMARY_CONTAINER: 'on_primary_container',
  SECONDARY: 'secondary',
  ON_SECONDARY: 'on_secondary',
  SECONDARY_CONTAINER: 'secondary_container',
  ON_SECONDARY_CONTAINER: 'on_secondary_container',
  TERTIARY: 'tertiary',
  ON_TERTIARY: 'on_tertiary',
  SURFACE: 'surface',
  ON_SURFACE: 'on_surface',
  SURFACE_VARIANT: 'surface_variant',
  ON_SURFACE_VARIANT: 'on_surface_variant',
  BACKGROUND: 'background',
  ON_BACKGROUND: 'on_background',
  ERROR_COLOR: 'error',
  ON_ERROR: 'on_error',
  OUTLINE: 'outline',
  OUTLINE_VARIANT: 'outline_variant',
  ERROR_CONTAINER: 'error_container',
  ON_ERROR_CONTAINER: 'on_error_container',
  WARNING: 'warning',
  WARNING_CONTAINER: 'warning_container',
  SUCCESS: 'success'
};

/** 颜色 Token 的明/暗取值。字段名与框架的 NGFColorValue 一致。 */
export class NGFColorValue {
  constructor(token, light, dark) {
    this.token = token;
    this.light = light;
    this.dark = dark;
  }
}

/** 测试辅助：把替身存储切到「已就绪」 */
export function __setStoreReady(value) {
  sharedState.ready = value;
}

/** 测试辅助：清空存储内容 */
export function __clearStore() {
  memory.clear();
}

/** 测试辅助：直接读某条存储内容（绕过 facade 的 isReady 保护） */
export function __peekStore(key) {
  return memory.get(key);
}
