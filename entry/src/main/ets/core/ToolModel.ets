/**
 * 工具注册表的领域模型。
 *
 * 本文件只描述「一个工具是什么」，不涉及任何 UI 实现——这是刻意的分层：
 * 注册表要知道工具的元数据（用于首页网格、搜索、分类），
 * 但**不应该**知道工具的页面长什么样。页面由工具模块自己提供，
 * 注册表只保存一个 `NGFWrappedBuilder` 句柄（见 ToolRegistry.ets）。
 *
 * 教学要点（本 App 是 NGF 官方样板，代码即文档）：
 * - 新增一件工具 = 新建一个 tools/<toolId>/ 目录 + 在本文件定义它的元数据 +
 *   在 ToolRegistry.ets 注册一行。首页、搜索、收藏、最近使用全部自动生效，
 *   不需要改首页代码。这就是产品定义稿 §一「工具可扩展架构」的落点。
 * - 因此**禁止**在首页（pages/Index.ets）里硬编码任何具体工具。
 *
 * @module core/ToolModel
 */

/** 工具唯一标识。全部小写 kebab-case，与目录名 tools/<toolId>/ 一致。 */
export type NGFToolId = string;

/**
 * 一段需要双语的文本。
 *
 * ## 为什么元数据的文案不能用 \`$r('app.string.…')\`
 *
 * `$r` 是 ArkUI 的资源引用能力，而本文件是**纯数据层**：它要能在本机单测里
 * 被直接构造和断言（注册表测试就是这么做的）。一旦这里 import ArkUI，
 * 整条注册表链路就没法在本机验证了。
 *
 * 所以元数据把两种语言**同时**带在身上，由调用方按当前 locale 取用。
 * 这与 \`ui/ToolSymbols.ets\` 的取舍同源：纯数据层不做设备能力的事。
 *
 * ## 为什么不是一个可空的 en
 *
 * 做成 \`en: string\`（缺省空串）+ \`forLocale\` 里回退，比 \`en?: string\`
 * 更好用：调用方永远拿到字符串，不必到处判 undefined。
 * **回退方向是刻意双向的**：英文环境缺英文时回退中文，中文环境缺中文时回退英文——
 * 有内容总比空白强，而「两种语言都缺」只在元数据写错时才会发生。
 */
export class NGFLocalizedText {
  readonly zh: string;
  readonly en: string;

  constructor(zh: string, en: string) {
    this.zh = zh;
    this.en = en;
  }

  /**
   * 按 locale 取值。
   *
   * @param locale 形如 \`zh-CN\` / \`en-US\` / \`en\`；大小写与分隔符都不敏感
   */
  forLocale(locale: string): string {
    if (isEnglishLocale(locale)) {
      return this.en.length > 0 ? this.en : this.zh;
    }
    return this.zh.length > 0 ? this.zh : this.en;
  }

  /** 两种语言都没有内容 */
  get isEmpty(): boolean {
    return this.zh.length === 0 && this.en.length === 0;
  }
}

/**
 * locale 是否属于英文。
 *
 * 判据只有一条：语言子标签是 \`en\`。因此 \`en\`、\`en-US\`、\`en_US\`、
 * \`EN-us\` 都算英文，而 \`zh-CN\`、\`ja-JP\` 都不算。
 * 刻意**不做**「非中文即英文」的推断：那样日语环境会显示英文，
 * 而更合理的默认是显示中文（本 App 的第一语言），见交接文档 §二.2 的分步计划。
 */
export function isEnglishLocale(locale: string): boolean {
  const normalized: string = locale.trim().toLowerCase();
  if (normalized.length < 2) {
    return false;
  }
  const head: string = normalized.substring(0, 2);
  if (head !== 'en') {
    return false;
  }
  // 必须是完整的语言子标签：`eng` 不算，`en` 与 `en-x` 算
  if (normalized.length === 2) {
    return true;
  }
  const separator: string = normalized.charAt(2);
  return separator === '-' || separator === '_';
}

/**
 * 工具分类。首页在工具数超过 12 件后按分类分组展示
 * （产品定义稿 §四：编解码 / 文本 / 网络 / 文件）。
 */
export enum NGFToolCategory {
  /** 文本与数据：正则、JSON、Diff、Cron 等 */
  TEXT = 'text',
  /** 编解码与计算：编解码套件、摘要、进制、颜色、时间戳、日期等 */
  COMPUTE = 'compute',
  /** 网络：端口测试、子网计算 */
  NETWORK = 'network',
  /** 文件与生成：二维码、代码查看 */
  FILE = 'file'
}

/**
 * 工具在 NGF 框架中所演示的能力层。
 *
 * 产品定义稿 §三 为每件工具指定了「演示的 NGF 层」，这个枚举把那个约定
 * 变成可查询的元数据：关于页与工具详情可以据此告诉读者「这件工具用到了框架的哪一层」，
 * 这正是样板应用的教学价值所在。字符串值与产品定义稿的层名一致。
 */
export class NGFToolLayer {
  static readonly UTILS: string = 'utils';
  static readonly CONTENT_WORKFLOW: string = 'contentWorkflow';
  static readonly CONTENT_SOURCE: string = 'contentSource';
  static readonly PLATFORM_OHOS: string = 'platformOhos';
  static readonly NETWORK: string = 'network';
  static readonly UI_THEME: string = 'uiTheme';
  static readonly DATA: string = 'data';
  static readonly SECURITY: string = 'security';
  static readonly UI_SHELL: string = 'uiShell';
}

/**
 * 一件工具的静态元数据（不可变）。
 *
 * 命名不用 I 前缀：它是数据类而非契约接口。
 */
export class NGFToolMeta {
  /** 唯一标识，与 tools/<id>/ 目录名一致 */
  readonly id: NGFToolId;
  /** 首页网格与搜索命中的显示名（中英双语） */
  readonly name: NGFLocalizedText;
  /** 分类 */
  readonly category: NGFToolCategory;
  /**
   * 一句话说明。首页网格与搜索都用它，
   * 所以必须「说人话」——写用户能搜的关键词，不要写内部术语。
   */
  readonly description: NGFLocalizedText;
  /**
   * 该工具**做不到什么**的诚实边界说明（产品定义稿 §七 强制要求）。
   * 空串表示暂未声明边界；工具上架前必须补齐。
   */
  readonly limitation: NGFLocalizedText;
  /** 演示的 NGF 层，取值见 NGFToolLayer */
  readonly layers: Array<string>;
  /** 首页图标（系统符号名，见 NGF SystemSymbolCatalog） */
  readonly symbol: string;
  /** 排序权重，越小越靠前；用于把高频工具排在网格前面 */
  readonly order: number;
  /** 是否需要在页内明示「本工具会联网」（保密红线：只有端口测试为 true） */
  readonly usesNetwork: boolean;

  constructor(
    id: NGFToolId,
    name: NGFLocalizedText,
    category: NGFToolCategory,
    description: NGFLocalizedText,
    limitation: NGFLocalizedText,
    layers: Array<string>,
    symbol: string,
    order: number,
    usesNetwork: boolean
  ) {
    this.id = id;
    this.name = name;
    this.category = category;
    this.description = description;
    this.limitation = limitation;
    this.layers = layers;
    this.symbol = symbol;
    this.order = order;
    this.usesNetwork = usesNetwork;
  }

  /**
   * 占位元数据。
   *
   * 存在的唯一理由：ArkTS 的 `@Component` 成员**必须带初值**，
   * 而本类没有「零值」概念。有了它，卡片组件内部就不必到处判空，
   * 也不用把成员声明成可空类型（那样反而要在 build 里写分支）。
   * 真实值一定会被父组件覆盖，所以占位内容不重要——**稳定**才重要。
   */
  static empty(): NGFToolMeta {
    const blank: NGFLocalizedText = new NGFLocalizedText('', '');
    return new NGFToolMeta('', blank, NGFToolCategory.TEXT, blank, blank,
      [], 'square_grid_2x2', 0, false);
  }
}

/**
 * 分类的展示名与固定展示顺序。
 *
 * 放在模型层而不是 UI 层：分类是**产品概念**（产品定义稿 §四 定死了四组），
 * 不是某个页面的样式细节；将来「分类页」与「首页分组」要共用同一份顺序。
 */
export class NGFToolCategoryInfo {
  readonly category: NGFToolCategory;
  readonly label: NGFLocalizedText;

  constructor(category: NGFToolCategory, label: NGFLocalizedText) {
    this.category = category;
    this.label = label;
  }

  /** 首页的分类展示顺序，与产品定义稿 §四 的措辞一致 */
  static ordered(): Array<NGFToolCategoryInfo> {
    const list: Array<NGFToolCategoryInfo> = [];
    list.push(new NGFToolCategoryInfo(NGFToolCategory.TEXT,
      new NGFLocalizedText('文本与数据', 'Text & Data')));
    list.push(new NGFToolCategoryInfo(NGFToolCategory.COMPUTE,
      new NGFLocalizedText('编解码与计算', 'Encode & Compute')));
    list.push(new NGFToolCategoryInfo(NGFToolCategory.NETWORK,
      new NGFLocalizedText('网络', 'Network')));
    list.push(new NGFToolCategoryInfo(NGFToolCategory.FILE,
      new NGFLocalizedText('文件与生成', 'File & Generate')));
    return list;
  }

  /** 取分类显示名；未知分类回退为空串而不是抛异常（首页不能因一件工具元数据写错而白屏）。 */
  static labelOf(category: NGFToolCategory, locale: string): string {
    const ordered: Array<NGFToolCategoryInfo> = NGFToolCategoryInfo.ordered();
    for (let i: number = 0; i < ordered.length; i++) {
      if (ordered[i].category === category) {
        return ordered[i].label.forLocale(locale);
      }
    }
    return '';
  }
}

/**
 * 搜索结果：一件工具 + 它的匹配得分。
 *
 * 之所以不直接返回 NGFToolMeta 数组：首页要按成绩排序，
 * 而排序依据（命中哪个字段）属于检索逻辑，不应该泄露给 UI 去重算。
 */
export class NGFToolSearchHit {
  readonly meta: NGFToolMeta;
  readonly score: number;

  constructor(meta: NGFToolMeta, score: number) {
    this.meta = meta;
    this.score = score;
  }
}
