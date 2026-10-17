/**
 * 工具注册表（工具箱的可扩展架构核心）。
 *
 * ## 为什么要有注册表
 *
 * 产品定义稿 §一 把「工具可扩展架构（注册表式，本身就是框架卖点）」列为三大差异化之一。
 * 如果没有注册表，首页就会变成一排写死的跳转——每加一件工具都要改首页，
 * 首页会随工具数增长而腐化。有了注册表：
 *
 * - 首页只认识 {@link NGFToolMeta}（任意件工具），不认识任何一件**具体**工具；
 * - 收藏、最近使用、搜索、分类分组全部由注册表统一供给，工具模块零成本获得。
 *
 * 因此本文件**禁止**出现任何 tools/<toolId> 的 import。
 *
 * ## 分层：为什么这里没有页面构建器
 *
 * 「工具页面怎么渲染」是 UI 层的事，而本文件属于纯逻辑层
 * （它必须能被 entry/src/test 的单测直接 import，不能拉进 ArkUI 运行时）。
 * 因此页面构建器放在 `ui/ToolPageRegistry.ets`，与元数据注册表**同源但分居两层**：
 * 两者都用同一份 {@link NGFToolMeta}，靠 toolId 关联。
 *
 * 这个拆分的代价是多了一个文件；收益是「搜索、排序、分组」这些
 * 真正会出 bug 的逻辑可以在单测里覆盖，而不需要真机。
 *
 * ## 新增一件工具
 *
 * 1. 新建 `entry/src/main/ets/tools/<toolId>/`（纯逻辑 + 页面组件）；
 * 2. 在 `ToolsCatalog.ets` 登记元数据；
 * 3. 在 `ui/ToolPageRegistry.ets` 登记该工具的页面构建器。
 *
 * @module core/ToolRegistry
 */

import {
  NGFLocalizedText,
  NGFToolCategory,
  NGFToolCategoryInfo,
  NGFToolMeta,
  NGFToolSearchHit
} from './ToolModel';

/**
 * 搜索打分权重的集中定义。
 *
 * 抽成类常量而不是散落在 if 里：搜索结果排序是**用户可感知的产品行为**，
 * 需要能在一处调参，而不是去猜分数是怎么攒出来的。
 */
export class NGFToolSearchWeights {
  /** 完全等于工具名 */
  static readonly NAME_EXACT: number = 100;
  /** 工具名以其开头 */
  static readonly NAME_PREFIX: number = 60;
  /** 工具名包含 */
  static readonly NAME_CONTAINS: number = 40;
  /** 工具 id 包含（开发者会直接敲 'json' 这类 id） */
  static readonly ID_CONTAINS: number = 30;
  /** 一句话说明包含（最弱，因为说明文字长、容易误命中） */
  static readonly DESC_CONTAINS: number = 15;
  /** 「做不到什么」说明包含 */
  static readonly LIMITATION_CONTAINS: number = 8;
}

/** 双语文本里是否有一侧包含关键词（needle 必须已小写） */
function containsEither(text: NGFLocalizedText, needle: string): boolean {
  return text.zh.toLowerCase().indexOf(needle) >= 0 || text.en.toLowerCase().indexOf(needle) >= 0;
}

/** 注册表内部的一条记录 */
class NGFToolRegistration {
  readonly meta: NGFToolMeta;
  /** true 表示元数据已登记但页面尚未实现（规划中的工具，首页显示为「建设中」） */
  readonly isPlaceholder: boolean;

  constructor(meta: NGFToolMeta, isPlaceholder: boolean) {
    this.meta = meta;
    this.isPlaceholder = isPlaceholder;
  }
}

/**
 * 工具注册表。
 *
 * 刻意**不做成单例**：本类将来要支持多实例（单测需要干净实例；
 * 生产使用的地方通过 {@link toolRegistry} 这个全局单例访问），
 * 而单例一旦写进类里就没法在测试里隔离。
 */
export class ToolRegistry {
  private readonly registrations: Map<string, NGFToolRegistration> = new Map<string, NGFToolRegistration>();
  private builtinsRegistered: boolean = false;

  /** 注册一件**已实现**的工具（元数据即可；页面在 ui 层的页面注册表登记） */
  register(meta: NGFToolMeta): boolean {
    return this.registerInternal(meta, false);
  }

  /**
   * 登记一件**规划中**的工具：只有元数据，没有页面，首页显示「建设中」。
   *
   * 这不是偷懒的占位：产品定义稿 §三 首发 16 件是公开承诺，
   * 把未完成的那几件以明确的「建设中」状态展示，
   * 比让用户看到 16 个入口点进去全是空白要诚实。
   */
  registerPlaceholder(meta: NGFToolMeta): boolean {
    return this.registerInternal(meta, true);
  }

  private registerInternal(meta: NGFToolMeta, isPlaceholder: boolean): boolean {
    const id: string = meta.id.trim();
    // id 为空的元数据是编程错误，但注册表不抛异常——首页不能因一条元数据写错而白屏。
    if (id.length === 0) {
      return false;
    }
    // 重复注册被忽略而不是覆盖，避免后注册者悄悄顶掉先注册者的元数据。
    if (this.registrations.has(id)) {
      return false;
    }
    this.registrations.set(id, new NGFToolRegistration(meta, isPlaceholder));
    return true;
  }

  /** 是否已注册该工具 */
  has(id: string): boolean {
    return this.registrations.has(id.trim());
  }

  /** 取元数据；未注册返回 null（调用方负责兜底，注册表不抛异常） */
  getMeta(id: string): NGFToolMeta | null {
    const registration: NGFToolRegistration | undefined = this.registrations.get(id.trim());
    return registration ? registration.meta : null;
  }

  /** 该工具是否已实现（false 时首页显示「建设中」） */
  isImplemented(id: string): boolean {
    const registration: NGFToolRegistration | undefined = this.registrations.get(id.trim());
    if (!registration) {
      return false;
    }
    return !registration.isPlaceholder;
  }

  /** 全部工具：已实现的在前，同状态按 order 升序，最后 id 升序保证稳定 */
  listAll(): Array<NGFToolMeta> {
    const all: Array<NGFToolMeta> = [];
    this.registrations.forEach((registration: NGFToolRegistration): void => {
      all.push(registration.meta);
    });
    all.sort((left: NGFToolMeta, right: NGFToolMeta): number => {
      return this.compareMeta(left, right);
    });
    return all;
  }

  /** 按分类取工具，顺序同 {@link listAll} */
  listByCategory(category: NGFToolCategory): Array<NGFToolMeta> {
    const matched: Array<NGFToolMeta> = [];
    const all: Array<NGFToolMeta> = this.listAll();
    for (let i: number = 0; i < all.length; i++) {
      if (all[i].category === category) {
        matched.push(all[i]);
      }
    }
    return matched;
  }

  /** 已实现工具数量 */
  implementedCount(): number {
    let count: number = 0;
    this.registrations.forEach((registration: NGFToolRegistration): void => {
      if (!registration.isPlaceholder) {
        count += 1;
      }
    });
    return count;
  }

  /** 注册的工具总数（含规划中） */
  totalCount(): number {
    return this.registrations.size;
  }

  /**
   * 搜索。
   *
   * 设计取舍：这**不是**模糊搜索，也不做拼音/首字母。理由是工具箱只有几十件工具，
   * 用户要么记得名字、要么会扫一眼整个网格；引入模糊匹配反而会让
   * 「输入 r 却把不相关的排在前面」成为常态。宁可搜不到，也不要搜错。
   * 大小写不敏感是唯一被允许的宽松处理。
   *
   * @param keyword 关键词；空白串返回空数组（由调用方决定「空关键词显示全部」）
   */
  search(keyword: string): Array<NGFToolSearchHit> {
    const needle: string = keyword.trim().toLowerCase();
    if (needle.length === 0) {
      return [];
    }

    const hits: Array<NGFToolSearchHit> = [];
    this.registrations.forEach((registration: NGFToolRegistration): void => {
      const score: number = ToolRegistry.scoreMeta(registration.meta, needle);
      if (score > 0) {
        hits.push(new NGFToolSearchHit(registration.meta, score));
      }
    });

    hits.sort((left: NGFToolSearchHit, right: NGFToolSearchHit): number => {
      if (left.score !== right.score) {
        return right.score - left.score;
      }
      return this.compareMeta(left.meta, right.meta);
    });
    return hits;
  }

  /** 注册内置工具清单。幂等：重复调用只生效一次。 */
  ensureBuiltinsRegistered(): void {
    if (this.builtinsRegistered) {
      return;
    }
    this.builtinsRegistered = true;
    if (catalogFiller !== null) {
      catalogFiller(this);
    }
  }

  /**
   * 排序规则：已实现的排在规划中的前面，然后 order 升序，最后 id 升序保证稳定。
   *
   * 「已实现优先」是刻意的：用户不该在网格第一屏看到一堆「建设中」。
   */
  private compareMeta(left: NGFToolMeta, right: NGFToolMeta): number {
    const leftReady: boolean = this.isImplemented(left.id);
    const rightReady: boolean = this.isImplemented(right.id);
    if (leftReady !== rightReady) {
      return leftReady ? -1 : 1;
    }
    if (left.order !== right.order) {
      return left.order - right.order;
    }
    if (left.id === right.id) {
      return 0;
    }
    return left.id < right.id ? -1 : 1;
  }

  /**
   * 给一件工具打分。返回 0 表示不命中。
   *
   * 取「最高分」而不是「累加」：累加会让描述长、提到很多关键词的工具
   * 无脑排在前面，用户搜「json」时反而看不到真正叫「JSON 工具」的那件。
   */
  private static scoreMeta(meta: NGFToolMeta, needle: string): number {
    // 双语字段各自算分，取**较高**的那个。
    //
    // 为什么不是「按当前语言只匹配一种」：这样两种语言的用户都能搜到。
    // 中文用户敲 'json'、英文用户敲 '时间戳' 都应该有结果——
    // 工具只有十几件，多匹配一种语言的代价几乎为零，
    // 而「搜不到」的代价是用户以为没有这件工具。
    const names: Array<string> = [
      meta.name.zh.toLowerCase(),
      meta.name.en.toLowerCase()
    ];
    let best: number = 0;
    for (let i: number = 0; i < names.length; i++) {
      const name: string = names[i];
      if (name.length === 0) {
        continue;
      }
      let score: number = 0;
      if (name === needle) {
        score = NGFToolSearchWeights.NAME_EXACT;
      } else if (name.indexOf(needle) === 0) {
        score = NGFToolSearchWeights.NAME_PREFIX;
      } else if (name.indexOf(needle) >= 0) {
        score = NGFToolSearchWeights.NAME_CONTAINS;
      }
      if (score > best) {
        best = score;
      }
    }
    if (best >= NGFToolSearchWeights.NAME_EXACT) {
      // 已经是最高档，后面的字段不可能更高，直接返回
      return best;
    }
    if (meta.id.toLowerCase().indexOf(needle) >= 0) {
      return NGFToolSearchWeights.ID_CONTAINS > best ? NGFToolSearchWeights.ID_CONTAINS : best;
    }
    if (containsEither(meta.description, needle)) {
      return NGFToolSearchWeights.DESC_CONTAINS > best ? NGFToolSearchWeights.DESC_CONTAINS : best;
    }
    if (containsEither(meta.limitation, needle)) {
      return NGFToolSearchWeights.LIMITATION_CONTAINS > best
        ? NGFToolSearchWeights.LIMITATION_CONTAINS : best;
    }
    return best;
  }
}

/** 工具清单填充函数：由 ToolsCatalog 在模块加载时注入（见 installToolCatalog） */
export type NGFToolCatalogFiller = (registry: ToolRegistry) => void;

let catalogFiller: NGFToolCatalogFiller | null = null;

/**
 * 注入工具清单。
 *
 * 为什么用注入而不是直接 import：工具页面要 import core（拿 ToolContext 与页面模板），
 * 若 core 反过来 import 工具目录就会形成循环依赖。让 core 只持有一个函数句柄，
 * 依赖方向就变成单向的：core ← tools。
 */
export function installToolCatalog(filler: NGFToolCatalogFiller): void {
  catalogFiller = filler;
}

/** 进程内全局单例。生产代码一律用它；单测自己 new ToolRegistry() 拿干净实例。 */
export const toolRegistry: ToolRegistry = new ToolRegistry();

/** 分类分组结果：一个分类 + 它下面的工具 */
export class NGFToolCategoryGroup {
  readonly label: string;
  readonly category: NGFToolCategory;
  readonly tools: Array<NGFToolMeta>;

  constructor(category: NGFToolCategory, tools: Array<NGFToolMeta>, locale: string) {
    this.category = category;
    this.label = NGFToolCategoryInfo.labelOf(category, locale);
    this.tools = tools;
  }
}

/**
 * 按产品定义稿 §四 的固定顺序把工具分组，空分组会被丢弃。
 *
 * @param locale 分类名按它取语言；调用方（UI 层）从框架 i18n 门面拿
 */
export function groupToolsByCategory(
  registry: ToolRegistry,
  locale: string
): Array<NGFToolCategoryGroup> {
  const groups: Array<NGFToolCategoryGroup> = [];
  const ordered: Array<NGFToolCategoryInfo> = NGFToolCategoryInfo.ordered();
  for (let i: number = 0; i < ordered.length; i++) {
    const tools: Array<NGFToolMeta> = registry.listByCategory(ordered[i].category);
    if (tools.length > 0) {
      groups.push(new NGFToolCategoryGroup(ordered[i].category, tools, locale));
    }
  }
  return groups;
}