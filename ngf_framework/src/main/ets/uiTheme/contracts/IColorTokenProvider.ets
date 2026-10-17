/**
 * 语义化颜色 Token 枚举
 */
export enum NGFColorToken {
  PRIMARY = 'primary',
  ON_PRIMARY = 'on_primary',
  PRIMARY_CONTAINER = 'primary_container',
  ON_PRIMARY_CONTAINER = 'on_primary_container',
  SECONDARY = 'secondary',
  ON_SECONDARY = 'on_secondary',
  SECONDARY_CONTAINER = 'secondary_container',
  ON_SECONDARY_CONTAINER = 'on_secondary_container',
  TERTIARY = 'tertiary',
  ON_TERTIARY = 'on_tertiary',
  SURFACE = 'surface',
  ON_SURFACE = 'on_surface',
  SURFACE_VARIANT = 'surface_variant',
  ON_SURFACE_VARIANT = 'on_surface_variant',
  BACKGROUND = 'background',
  ON_BACKGROUND = 'on_background',
  ERROR_COLOR = 'error',
  ON_ERROR = 'on_error',
  OUTLINE = 'outline',
  OUTLINE_VARIANT = 'outline_variant',
  // ⚠️ 以下 5 个是**本仓先行补充**，需回来源仓（airwavefootprints）同步。
  //
  // 原因：MD3 基准的 20 个 Token 里没有「错误容器 / 警告 / 警告容器 / 成功」，
  // 而工具类应用恰恰最依赖状态反馈色——自建 color.json 里就有
  // error_background / warning / warning_background / success 四个键，
  // 迁移时无处安放，只能被迫留一份自建色表，那就失去了「统一走 Token」的意义。
  //
  // 其中 ERROR_CONTAINER / ON_ERROR_CONTAINER 是 **MD3 规范本就有**的槽位
  // （errorContainer / onErrorContainer），属补齐遗漏；
  // WARNING / WARNING_CONTAINER / SUCCESS 是通用应用语义色，HDS 设计体系亦有定义。
  ERROR_CONTAINER = 'error_container',
  ON_ERROR_CONTAINER = 'on_error_container',
  WARNING = 'warning',
  WARNING_CONTAINER = 'warning_container',
  SUCCESS = 'success'
}

/**
 * 颜色值 (包含 light/dark 两个模式的值)
 */
export class NGFColorValue {
  readonly token: NGFColorToken;
  readonly light: string;
  readonly dark: string;

  constructor(token: NGFColorToken, light: string, dark: string) {
    this.token = token;
    this.light = light;
    this.dark = dark;
  }
}

/**
 * 颜色 Token 提供者接口
 */
export interface IColorTokenProvider {
  resolveColor(token: NGFColorToken): string;
  resolveColorValue(token: NGFColorToken): NGFColorValue;
  registerColor(value: NGFColorValue): void;
  registerDefaults(): void;
}
