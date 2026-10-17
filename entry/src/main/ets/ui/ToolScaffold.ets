/**
 * 工具页统一骨架 —— 产品定义稿 §四「工具页统一模板」的唯一实现。
 *
 * ## 为什么必须收口成一个组件
 *
 * 产品定义稿要求每件工具遵循同一套交互：输入区 → 处理 → 输出区 → 复制/清空，
 * 并且「错误就地红字说明」「大字体不溢出」「全部支持深色」。这十六条要求
 * 如果让 16 件工具各自实现，一定会漂移——最后用户看到的是 16 个手感不同的页面，
 * 而样板应用最不能承受的就是「样板本身不统一」。
 *
 * 因此本组件负责**结构性**的部分（标题、滚动、帮助区、边界说明、收藏入口），
 * 工具只负责**内容**部分（自己的输入与输出）。工具用 `@Builder` 把内容传进来。
 *
 * ## 工具页面必须写成什么样
 *
 * ```typescript
 * @Builder
 * export function buildMyToolPage(params: ToolPageParams) {
 *   ToolScaffold({ context: params.context, content: buildMyToolContent })
 * }
 *
 * @Builder
 * function buildMyToolContent() {
 *   // 只有这件工具自己的输入/输出
 * }
 * ```
 *
 * @module ui/ToolScaffold
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from './FontScaleSource';
import { logger, NGFColorToken, NGFImmersiveTopChromeUnderlay } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from './ThemeSource';
import { publishHistoryPick } from './HistoryPick';
import { CHROME_UNDERLAY_HEIGHT, chromeContentTop, chromeSpecFor, TOP_SAFE_INSET } from './ImmersiveChrome';
import { loadDynamicInsets } from './WindowChrome';
import { ToolContext } from '../core/ToolPageContract';
import { toolStateStore } from '../core/ToolStateStore';

/** 日志 tag（真机验证用，见 aboutToAppear） */
const TAG: string = 'ToolScaffold';

/** 内容区左右留白：与首页网格对齐，避免两页视觉上「错开一档」 */
const PAGE_PADDING: number = 16;
/** 正文最大行宽（vp）。平板/2in1 上不让长行拉到难以阅读 */
const CONTENT_MAX_WIDTH: number = 720;

@Component
export struct ToolScaffold {
  /** 工具上下文，由工具页面从路由参数透传进来 */
  context: ToolContext = new ToolContext('', '', '', false);
  /**
   * 工具自己的输入/输出内容。
   *
   * **必须是 `@BuilderParam`**：写成普通的 `() => void` 字段时，在 `build()` 里
   * `this.content()` 会被判为「不是 UI 组件语法」——普通函数调用不能出现在
   * 组件树里。`@BuilderParam` 才是「这个属性是一段 UI」的声明方式。
   */
  @BuilderParam content: () => void = this.defaultContent;
  /** 是否已收藏（首页与工具页共用同一份状态） */
  @State private favorited: boolean = false;
  /**
   * 订阅主题深浅。
   *
   * **这个字段不是拿来用的，是用来触发重渲染的。**
   * \`colorOf()\` 是运行时取色，主题变了它不会自己通知 ArkUI；
   * \`@StorageProp\` 订阅的键一变，本组件就会重新 build，
   * 届时 \`colorOf()\` 才取到新色。少了它，切主题界面不刷新。
   */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;

  /** 历史面板是否展开 */
  /** 顶部内容避让（vp）＝实测状态栏高度 + 底板高度 */
  @State private topInsetVp: number = chromeContentTop();
  @State private showHistory: boolean = false;
  /**
   * 当前展示的历史条目。
   *
   * 打开面板时**读一次**并存在这里，而不是每帧读：`readHistory` 会做一次
   * 存储读取 + 「定型」判定，放在 `build()` 里会被反复调用。
   */
  @State private historyEntries: Array<string> = [];

  /** 未传 content 时的兜底（`@BuilderParam` 需要初始值） */
  @Builder
  defaultContent() {
  }

  aboutToAppear(): void {
    // 真机验证用：每打开一件工具都留下一条带 toolId 的日志。
    // 这样「16 件工具是否都能进」可以直接读日志判定，不必靠截图猜像素。
    logger.info(TAG, '工具页已打开: ' + this.context.toolId);
    // 顶部避让用**实测**状态栏高度，不是 chromeContentTop() 里那个经验值。
    loadDynamicInsets(this.getUIContext(), TOP_SAFE_INSET, 0, (top: number, bottom: number): void => {
      this.topInsetVp = top + CHROME_UNDERLAY_HEIGHT;
    });
    // 收藏状态从单一数据源读，不要在页面里各存一份，否则首页与工具页会不一致。
    this.favorited = toolStateStore.isFavorite(this.context.toolId);
    this.reloadHistory();
  }

  /**
   * 重新读历史条目。
   *
   * 传 `Date.now()` 进去而不是让数据层自己取时间：`readHistory` 要靠
   * 「这个输入值多久没变过」判断它是否已定型（见 `ToolStateStore.readHistory`），
   * 时间由调用方给，单测才能构造「已定型」场景而不必真等 1.5 秒。
   */
  private reloadHistory(): void {
    this.historyEntries = toolStateStore.readHistory(this.context.toolId, Date.now());
  }

  /** 展开/收起历史面板；展开时重新读一次（刚才那次输入可能刚定型） */
  private toggleHistory(): void {
    if (!this.showHistory) {
      this.reloadHistory();
    }
    this.showHistory = !this.showHistory;
  }

  /**
   * 选中一条历史：写回草稿 → 递增序号 → 收起面板。
   *
   * 为什么是「写草稿」而不是直接赋给输入框：壳层够不着工具体的 `@State`，
   * 中间那条路见 {@link publishHistoryPick}。
   */
  private pickHistory(entry: string): void {
    toolStateStore.writeDraft(this.context.toolId, entry);
    publishHistoryPick();
    this.showHistory = false;
  }

  /** 清空本工具的历史 */
  private clearHistory(): void {
    if (toolStateStore.clearHistory(this.context.toolId)) {
      this.historyEntries = [];
      this.showHistory = false;
    }
  }

  build() {
    // 本组件不再自己套 NavDestination：它现在渲染在**路由分发出来的 NavDestination 里**
    // （见 pages/Index.ets 的 destination 分发）。再套一层就成了
    // NavDestination 嵌套 NavDestination，ArkUI 运行时会报错。
    //
    // Stack 而不是直接 Scroll：沉浸式底板要**浮在内容之上**且不随滚动移动。
    // 底板会向状态栏方向扩展（expandSafeArea），所以内容必须向下避让
    // chromeContentTop()——写死数字会把首个元素压进覆盖带里（框架注释里的事故）。
    Stack({ alignContent: Alignment.TopStart }) {
      NGFImmersiveTopChromeUnderlay({ spec: chromeSpecFor(this.isDark) })

      Scroll() {
        Column({ space: 0 }) {
          // ── 标题区 ──────────────────────────────────────────
          this.buildHeader()

          // ── 历史面板（展开时才占位） ─────────────────────────
          if (this.showHistory) {
            this.buildHistoryPanel()
          }

          // ── 工具自己的内容 ───────────────────────────────────
          this.content()

          // ── 「做不到什么」：产品定义稿 §七 强制要求，每件工具都要写 ──
          this.buildLimitation()

          // 底部留白，避免最后一行贴着屏幕边缘
          Blank().height(32)
        }
        .width('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: this.topInsetVp })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      // 键盘弹起时收缩而不是顶起整页：输入框集中在顶部，收缩后仍可见
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(colorOf(NGFColorToken.BACKGROUND))
  }

  /** 标题 + 收藏按钮 + 联网明示（若是端口测试那类工具） */
  @Builder
  private buildHeader() {
    Row() {
      // 右对齐：工具名已移交给框架顶栏，本行只剩操作按钮

      // ⚠️ 这里**不再画工具名**——它已由框架的 HdsNavDestination 顶栏显示
      // （见 pages/Index.ets 的 destBuilder）。自绘一份会和框架标题重复。
      // 背景是恒深色的沉浸底板，而本组件的文字走主题 Token，
      // 所以这一行只放图标按钮（它们用的是框架的强调色，深浅底都读得出来），
      // 并靠 `justifyContent` 把它们推到右边——**不要**用 `Blank()`：
      // 后面那个 `{ ... }` 按钮块会被 DSL 解析成 Blank 的子节点，直接编译报错。
      

      // 历史：图标用系统符号。
      //
      // ⚠️ **必须常显**，不能写成「有记录才显示」——那会造成死锁：
      // 记录只在 readHistory 里产生，而打开面板才会调 readHistory。
      // 首次使用时没有记录 → 按钮不出现 → 打不开面板 → 永远没有记录。
      // 空态交给面板里的 shell_history_empty 文案承担。
      //
      // ⚠️ 这里**不能**用裸的 `{ ... }` 把图标包起来（曾经是那样写的）。
      // 真机实测：包在裸块里的按钮**根本不渲染**——工具页右上角只剩收藏图标，
      // 历史入口整个消失。去掉包裹后与旁边的收藏按钮写法一致即可。
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(scaled(24))
        .fontColor([colorOf(this.showHistory ? NGFColorToken.PRIMARY : NGFColorToken.ON_SURFACE_VARIANT)])
        .margin({ right: 12 })
        .onClick(() => {
          this.toggleHistory();
        })
        .accessibilityText($r('app.string.shell_action_history'))

      // 收藏开关：图标用系统符号，选中/未选中态明确
      SymbolGlyph(this.favorited ? $r('sys.symbol.checkmark_square') : $r('sys.symbol.square_on_square_fill'))
        .fontSize(scaled(24))
        .fontColor([this.favorited ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT)])
        .onClick(() => {
          const next: boolean = !this.favorited;
          if (toolStateStore.toggleFavorite(this.context.toolId)) {
            this.favorited = next;
          }
        })
        .accessibilityText(this.favorited
          ? $r('app.string.shell_unfavorite')
          : $r('app.string.shell_favorite'))
    }
    .justifyContent(FlexAlign.End)
    .width('100%')
    .padding({ top: 8, bottom: 16 })
    .alignItems(VerticalAlign.Center)

    // 联网明示：只在工具确实会联网时出现（保密红线要求页内明示）
    if (this.context.usesNetwork) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(scaled(16))
          .fontColor([colorOf(NGFColorToken.WARNING)])
        Text($r('app.string.shell_network_disclosure'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .layoutWeight(1)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
      .borderRadius(12)
      .margin({ bottom: 16 })
    }
  }

  /** 历史面板：最近输入的可点列表 */
  @Builder
  private buildHistoryPanel() {
    Column({ space: 0 }) {
      Row() {
        Text($r('app.string.shell_history_title'))
          .fontSize(scaled(13))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .layoutWeight(1)
        Text($r('app.string.shell_history_clear'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            this.clearHistory();
          })
          .accessibilityText($r('app.string.shell_history_clear'))
          .accessibilityLevel('yes')
      }
      .width('100%')
      .padding({ bottom: 8 })

      if (this.historyEntries.length === 0) {
        // 空态：说清「为什么这里是空的」，而不是只显示一个空框
        Text($r('app.string.shell_history_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .lineHeight(20)
          .width('100%')
      } else {
        ForEach(this.historyEntries, (entry: string) => {
          Text(entry)
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            // 历史里可能存着长文本（JSON、日志），**必须**截断——
            // 否则一条历史就能把整个面板撑到几十屏高
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .onClick(() => {
              this.pickHistory(entry);
            })
            .accessibilityText(entry)
            .accessibilityLevel('yes')
          Divider()
            .color(colorOf(NGFColorToken.OUTLINE_VARIANT))
        }, (entry: string, index: number) => index + ':' + entry)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .margin({ bottom: 16 })
  }

  /** 「做不到什么」帮助区 */
  @Builder
  private buildLimitation() {
    if (this.context.limitation.length > 0) {
      Column({ space: 6 }) {
        Text($r('app.string.shell_help_limitation'))
          .fontSize(scaled(13))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Text(this.context.limitation)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.SURFACE))
      .borderRadius(12)
      .margin({ top: 20, bottom: 8 })
    }
  }
}
