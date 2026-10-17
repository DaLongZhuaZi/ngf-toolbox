/**
 * 工具箱自己的 UI 门面：把框架能力包成工具页面最好用的形状。
 *
 * 为什么不直接在每件工具里 import 框架：因为「复制后 toast」「错误就地红字」
 * 是产品定义稿 §四 对**所有**工具的统一规范。如果让 16 件工具各自调
 * `ngfOverlayManagerFacade.showToast(...)`，这条规范就会以 16 份不同措辞实现，
 * 将来改文案要改 16 处。这里收口成一个出口，规范才守得住。
 *
 * @module ui/ToolUiKit
 */

import { logger, ngfOverlayManagerFacade } from 'ngf_framework';
import { resolveText } from './LocaleSource';
import pasteboard from '@ohos.pasteboard';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = 'ToolUiKit';

/** 复制成功提示的显示时长（毫秒）。短于系统默认，避免打断连续操作。 */
const TOAST_DURATION_MS: number = 1500;

/**
 * 工具箱 UI 门面。
 *
 * 全部方法**不抛异常**：工具页面的交互反馈失败（剪贴板被占用、无 UIContext）
 * 不应该让一个已经算出结果的工具整页崩掉——用户宁可没有提示，
 * 也不能丢失刚算出来的东西。
 */
export class ToolUiKit {
  /**
   * 复制文本到系统剪贴板并提示。
   *
   * @param text 要复制的内容；空串直接返回 false（复制空内容只会让用户困惑）
   * @param successMessage 成功提示文案
   * @returns 是否复制成功
   */
  static copyText(text: string, successMessage: string | Resource): boolean {
    if (text.length === 0) {
      return false;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setDataSync(data);
      ToolUiKit.toast(successMessage);
      return true;
    } catch (error) {
      const businessError = error as BusinessError;
      logger.warn(TAG, '复制到剪贴板失败: code=' + String(businessError.code));
      ToolUiKit.toast($r('app.string.shell_copy_failed'));
      return false;
    }
  }

  /**
   * 显示一条短提示。无 UIContext（例如单元测试环境）时静默忽略。
   *
   * 入参放宽到 `string | Resource`：调用方写 `$r('app.string.x')` 时拿到的是
   * **Resource 而不是 string**（这是本仓踩过的一个坑——本机门禁只剥类型、不查类型，
   * 所以这类不匹配只有真编译才报）。这里统一解析，调用方不必各自包一层。
   */
  static toast(message: string | Resource): void {
    const resolved: string = typeof message === 'string' ? message : ToolUiKit.text(message);
    if (resolved.length === 0) {
      return;
    }
    try {
      ngfOverlayManagerFacade.showToast(resolved, { duration: TOAST_DURATION_MS });
    } catch (error) {
      logger.warn(TAG, 'toast 显示失败');
    }
  }

  /**
  // readClipboardText 已移除：读剪贴板需要 ohos.permission.READ_PASTEBOARD，
  // 与本 App「只声明 INTERNET」的权限红线冲突。详见 TextDiffPage 里的说明。

  /**
   * 解析字符串资源并按参数格式化。
   *
   * ## 为什么需要这个出口，而不是在 Text 里直接写 \`$r()\`
   *
   * 工具页的**错误文案**是运行期由「失败码 + 参数」拼出来的（例如「第 12 行第 5 列」），
   * 而 \`$r('app.string.x')\` 的键必须是**字面量**——运行期才能知道是哪个码，
   * 所以没法把 \`$r()\` 直接写进 \`Text(...)\`。
   *
   * 做法是：先用字面量 \`$r('app.string.err_x')\` 拿到 \`Resource\`（键仍是字面量，
   * 因此构建期能改写、\`check-resources.mjs\` 也能核对），再交给本方法按参数格式化。
   *
   * ## 为什么用 Resource 重载而不是 \`$r(key, args)\`
   *
   * \`$r()\` 的带参形式把占位符代入交给 ArkUI 渲染器；而这条路径走的是
   * \`resourceManager.getStringSync(resource.id, ...args)\`——框架里已经写好
   * （见 \`I18nManagerFacade.resolveStringWithArgs\`），且社区样例与框架自身都在用。
   * 选已有实现，而不是押一个本机无法验证的新用法。
   *
   * @param key 资源引用（字面量 \`$r('app.string.x')\`）或资源裸名
   * @param args 占位符参数，顺序必须与资源文案里 \`%s\` 的出现顺序一致
   * @returns 解析结果；失败时返回 key 本身，便于一眼看出漏了哪条资源
   */
  static stringOf(key: string | Resource, args: Array<string | number>): string {
    // 解析实现收在 LocaleSource（四个基础能力出口之一），
    // 本类只提供「从 UI 组件里方便地调到它」这一层薄封装。
    return resolveText(key, args);
  }

  /** 无参数版本的字符串解析 */
  static text(key: string | Resource): string {
    return ToolUiKit.stringOf(key, []);
  }
}
