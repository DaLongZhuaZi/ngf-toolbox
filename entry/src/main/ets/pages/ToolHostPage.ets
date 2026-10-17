/**
 * 工具宿主页 —— 所有工具共用的路由入口。
 *
 * ## 为什么是「一个页面 + 注册表」而不是「每件工具一个页面」
 *
 * 产品定义稿要求工具箱能持续追加到 30+ 件。若每件工具都注册成一个页面路由，
 * 就需要同时维护 main_pages.json、路由常量、以及每件工具自己的导航栏，
 * 而且「建设中」这种横切状态要在 30 个页面里各写一遍。
 *
 * 改成宿主页之后：
 * - main_pages.json 里**只有一条**工具路由（pages/ToolHostPage）；
 * - 工具的页面构建器从注册表按 id 取（ui/ToolPageRegistry.ets）；
 * - 导航栏、返回、收藏、「建设中」兜底只实现一次。
 *
 * ## 为什么参数只传 id 不传整个上下文
 *
 * 路由参数会经过系统序列化，传对象既容易丢字段，也会随元数据变化而失配。
 * 只传 id，上下文由宿主页从注册表现取——**单一数据源**，
 * 元数据改了以后所有入口自动一致。
 *
 * @module pages/ToolHostPage（组件名 ToolHostView）
 */


import { ngfNavigationShellFacade } from 'ngf_framework';
import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../ui/FontScaleSource';
import { colorOf, TOOLBOX_DARK_KEY } from '../ui/ThemeSource';
import {
  NGFColorToken, logger } from 'ngf_framework';
import { NGFToolMeta } from '../core/ToolModel';
import { toolRegistry } from '../core/ToolRegistry';
import { ToolContext, ToolPageParams } from '../core/ToolPageContract';
import { toolStateStore } from '../core/ToolStateStore';
import { currentLocale } from '../ui/LocaleSource';
import { NGFToolPageBuilder, toolPageBuilderOf } from '../ui/ToolPageRegistry';

const TAG: string = 'ToolHostView';

@Component
export struct ToolHostView {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 工具 id，从路由参数带入 */
  @Prop toolId: string = '';
  // （由路由分发器从导航参数解出后传入，见本文件末尾的说明）
  @State private ready: boolean = false;
  @State private context: ToolContext = new ToolContext('', '工具箱', '', false);
  /** 已解析到的页面构建器；null 表示该工具尚未实现 */
  @State private builder: NGFToolPageBuilder | null = null;
  /** 传给工具页的参数包。构建器要的是**实例**而不是对象字面量——
   *  ArkTS 禁止无类型对象字面量（arkts-no-untyped-obj-literals）。 */
  @State private params: ToolPageParams = new ToolPageParams(new ToolContext('', '', '', false));

  aboutToAppear(): void {
    this.resolveTool();
  }

  /**
   * 解析路由参数并准备上下文。
   *
   * 所有失败路径都退化为「建设中」页面而不是抛异常：
   * 用户可能通过收藏、最近使用或搜索结果点进一件工具，
   * 而这些入口在数据被改坏（例如旧版本写入的 id）时会指向不存在的工具，
   * 那时给出明确提示远好于崩溃。
   */
  private resolveTool(): void {
    const id: string = this.toolId.trim();
    if (id.length === 0) {
      logger.warn(TAG, '缺少工具 id 参数');
      this.ready = true;
      return;
    }

    const meta: NGFToolMeta | null = toolRegistry.getMeta(id);
    if (meta === null) {
      logger.warn(TAG, '未注册的工具 id: ' + id);
      this.ready = true;
      return;
    }

    this.toolId = meta.id;
    // 语言由 UI 层读出来后作为参数传入：契约层是纯数据，不读设备能力。
    this.context = ToolContext.fromMeta(meta, currentLocale());
    this.params = new ToolPageParams(this.context);
    this.builder = toolPageBuilderOf(meta.id);
    this.ready = true;

    // 记录最近使用：只在真的打开工具时记，而不是在首页渲染网格时记，
    // 否则「最近使用」会等价于「首页显示过的全部工具」，失去意义。
    toolStateStore.markUsed(meta.id);
  }

  build() {
    // 不再自己套 Navigation：导航栈与标题由**根页面**（pages/Index.ets）统一持有，
    // 本组件渲染在路由分发出来的 NavDestination 里。
    // 再套一层会变成 Navigation 嵌套 Navigation，ArkUI 运行时会报错。
    if (this.builder !== null) {
      ToolPageOutlet({ builder: this.builder, params: this.params })
    } else {
      this.buildPlaceholder()
    }
  }

  /** 「建设中」占位：说清楚 + 给出退路，不留白 */
  @Builder
  private buildPlaceholder() {
    Column({ space: 12 }) {
      Text(this.toolId.length > 0
        ? $r('app.string.host_placeholder_title')
        : $r('app.string.host_missing_title'))
        .fontSize(scaled(18))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      Text(this.toolId.length > 0
        ? $r('app.string.host_placeholder_hint')
        : $r('app.string.host_missing_hint'))
        .fontSize(scaled(14))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .textAlign(TextAlign.Center)
      Button($r('app.string.shell_back'))
        .margin({ top: 12 })
        .onClick(() => {
          // 走框架门面出栈，**不能**用 router.back()：
          // 导航已经切到 NavPathStack，页面 Router 的栈是空的，那个调用不会有反应。
          ngfNavigationShellFacade.pop();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }
}

/**
 * 工具页面出口：按注册表里的构建器渲染工具内容。
 *
 * ## 为什么单独抽一个组件，而不是在宿主页里直接调用构建器
 *
 * ArkUI 的 `@Builder` 参数需要**静态可知**才能被编译器正确展开；
 * 把构建器存进 `Map` 再取出属于运行期动态派发。抽出独立组件后：
 * - 宿主页只负责「查注册表 + 兜底」，逻辑线性可读；
 * - 这一处集中承载动态派发，将来若 ArkUI 收紧限制，需要改的只有这里，
 *   而不是 30 件工具。
 * 这是本项目里**唯一**一处运行期构建器派发点，请勿在别处复制这个写法。
 */
@Component
struct ToolPageOutlet {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  builder: NGFToolPageBuilder | null = null;
  params: ToolPageParams = new ToolPageParams(new ToolContext('', '', '', false));

  build() {
    Column() {
      if (this.builder !== null) {
        // WrappedBuilder 的调用入口是它的 `.builder` 属性，且必须在 UI 构建上下文里调用。
        // 写 `this.builder(params)` 会被判为「不是 UI 组件语法」。
        this.builder.builder(this.params)
      }
    }
    .width('100%')
    .height('100%')
  }
}
