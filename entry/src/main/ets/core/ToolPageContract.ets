/**
 * 工具页面的上下文契约（**纯数据**，刻意不依赖 ArkUI）。
 *
 * 放在 core 而不是 ui 目录，是因为工具模块里「纯逻辑」那一半也要用到工具标识
 * （例如按工具 id 存草稿、按工具 id 拼资源名）。若把契约放进 ui 层，
 * 纯逻辑就被迫 import ArkUI，单测跑不起来。
 *
 * @module core/ToolPageContract
 */

import { NGFToolMeta } from './ToolModel';


/**
 * 工具页面的上下文。
 *
 * 工具页面**必须**只依赖这一份上下文（而不是自己去读全局状态或路由参数）：
 * 这样同一件工具在「正常打开」与「将来被嵌入其它页面」两种场景下行为一致，
 * 也让工具页面可以在预览/测试里直接被构造出来。
 */
export class ToolContext {
  /** 工具标识，与 NGFToolMeta.id 一致 */
  readonly toolId: string;
  /** 工具显示名，避免工具页再查一次注册表 */
  readonly toolName: string;
  /** 该工具做不到什么（帮助区展示，产品定义稿 §七 强制要求） */
  readonly limitation: string;
  /** 是否需要页内明示联网（保密红线：只有端口测试为 true） */
  readonly usesNetwork: boolean;

  constructor(toolId: string, toolName: string, limitation: string, usesNetwork: boolean) {
    this.toolId = toolId;
    this.toolName = toolName;
    this.limitation = limitation;
    this.usesNetwork = usesNetwork;
  }

  /**
   * 从注册表元数据构造（宿主页统一走这里，保证字段口径一致）。
   *
   * @param locale 工具名与边界说明按它取语言；由 UI 层从框架 i18n 门面传入，
   *               这样契约层不必依赖任何设备能力（本文件是纯数据）。
   */
  static fromMeta(meta: NGFToolMeta, locale: string): ToolContext {
    return new ToolContext(meta.id, meta.name.forLocale(locale),
      meta.limitation.forLocale(locale), meta.usesNetwork);
  }
}

/** 工具页面构建器收到的参数包 */
export class ToolPageParams {
  readonly context: ToolContext;

  constructor(context: ToolContext) {
    this.context = context;
  }
}