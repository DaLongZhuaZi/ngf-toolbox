/**
 * 摘要计算工具页。
 *
 * ## 这个页面为什么这么写
 *
 * 工具页只做三件事：拿输入、调纯逻辑、把结果摆出来并支持复制。
 * 所有算法与比对规则都在 {@link ./DigestAlgorithms} 里，页面不做任何计算——
 * 一旦页面开始"顺手算点什么"，那部分逻辑就再也测不到了。
 *
 * 页面另外承担两件**只有页面能做的事**：
 * 1. 草稿：输入自动存到本机（data 层），杀进程不丢（产品定义稿 §四）；
 * 2. 与框架 capacity 交叉校验：调用 `securityToolkit`（@kit.CryptoArchitectureKit）
 *    再算一遍 SHA-256/SHA-512，与本实现对照。框架能力只能在页面层碰
 *    （纯逻辑 import 设备能力会导致本地单测跑不起来），所以这一条留在这里。
 *
 * @module tools/digest/DigestPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import {
  NGFColorToken, logger, NGFHashAlgorithm, securityToolkit } from 'ngf_framework';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  compareFingerprint,
  digestAllOfText,
  digestHexOfText,
  normalizeFingerprint,
  NGFDigestAlgorithm,
  NGFDigestResult,
  NGFFingerprintCompareResult
} from './DigestAlgorithms';
import { digestCompareText, digestCrossCheckText } from './DigestMessages';

const TAG: string = 'DigestPage';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'digest';

/** 草稿写入防抖（毫秒）：每敲一个键就写一次 Preferences 会让输入变卡 */
const DRAFT_DEBOUNCE_MS: number = 400;

@Builder
export function buildDigestPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildDigestContent })
}

@Builder
function buildDigestContent() {
  DigestToolBody()
}

@Component
struct DigestToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private results: NGFDigestResult[] = [];
  @State private expected: string = '';
  @State private compareMessage: string = '';
  @State private compareMatched: boolean = false;
  @State private crossCheckMessage: string = '';
  @State private crossCheckOk: boolean = false;
  /** 待写入草稿的定时器句柄；-1 表示没有待写入任务 */
  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.input = restored;

  }


  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()

      if (this.results.length > 0) {
        this.buildResultSection()
      }

      this.buildCompareSection()
      this.buildCrossCheckSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 输入区：文本 + 计算/清空 */
  @Builder
  private buildInputSection() {
    Column({ space: 8 }) {
      Text($r('app.string.digest_label_input'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextArea({ text: this.input, placeholder: $r('app.string.digest_placeholder_input') })
        .width('100%')
        .height(140)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .padding(12)
        .onChange((value: string) => {
          this.input = value;
          this.scheduleDraftSave(value);
        })

      Row({ space: 12 }) {
        Button($r('app.string.digest_action_compute'))
          .layoutWeight(1)
          .onClick(() => {
            this.compute();
          })

        Button($r('app.string.shell_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 结果区：四种算法各一行，点右侧「复制」拿走 */
  @Builder
  private buildResultSection() {
    Column({ space: 8 }) {
      Text($r('app.string.digest_label_result'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      ForEach(this.results, (item: NGFDigestResult) => {
        Column({ space: 6 }) {
          Row() {
            Text(item.label)
              .fontSize(scaled(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Blank()
            Text($r('app.string.shell_action_copy'))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                ToolUiKit.copyText(item.hex,
                  ToolUiKit.stringOf($r('app.string.digest_copied'), [item.label]));
              })
          }
          .width('100%')

          Text(item.grouped)
            .fontSize(scaled(13))
            .lineHeight(20)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .borderRadius(12)
      }, (item: NGFDigestResult) => item.algorithm)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 指纹比对区：忽略大小写与分隔符，比不了时给出原因 */
  @Builder
  private buildCompareSection() {
    Column({ space: 8 }) {
      Text($r('app.string.digest_label_fingerprint'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Text($r('app.string.digest_fingerprint_hint'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      TextInput({ text: this.expected, placeholder: $r('app.string.digest_placeholder_fingerprint') })
        .width('100%')
        .height(44)
        .fontSize(scaled(14))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.expected = value;
          if (this.results.length > 0) {
            this.refreshCompare();
          }
        })

      if (this.compareMessage.length > 0) {
        Text(this.compareMessage)
          .fontSize(scaled(13))
          .fontColor(this.compareMatched ? colorOf(NGFColorToken.SUCCESS) : colorOf(NGFColorToken.ERROR_COLOR))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 交叉校验区：用框架能力复算，证明本实现与框架口径一致 */
  @Builder
  private buildCrossCheckSection() {
    Column({ space: 8 }) {
      Text($r('app.string.digest_label_cross_check'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Text($r('app.string.digest_cross_check_hint'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      Button($r('app.string.digest_action_cross_check'))
        .width('100%')
        .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .onClick(() => {
          // 方法的异常已在内部处理；这里再挂一条链只为消除「未处理的 Promise」告警
          this.runCrossCheck().then(() => {
            logger.info(TAG, '框架交叉校验流程结束');
          }).catch((error: Error) => {
            logger.warn(TAG, '交叉校验回调异常');
          });
        })

      if (this.crossCheckMessage.length > 0) {
        Text(this.crossCheckMessage)
          .fontSize(scaled(13))
          .fontColor(this.crossCheckOk ? colorOf(NGFColorToken.SUCCESS) : colorOf(NGFColorToken.ERROR_COLOR))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 计算四种摘要；若已有比对输入或比对结论，顺手刷新比对结果 */
  private compute(): void {
    this.results = digestAllOfText(this.input);
    this.flushDraft();
    if (this.expected.length > 0) {
      this.refreshCompare();
    }
  }

  /**
   * 用「期望指纹的长度」自动挑一条本地摘要来比对。
   *
   * 为什么按长度挑而不是让用户先选算法：摘要长度本身就是算法的指纹
   * （32=MD5、40=SHA-1、64=SHA-256、128=SHA-512），让用户再选一次是多余的手续。
   * 长度对不上任何一条时退回 SHA-256，好让提示说清「期望 X 位、实际 64 位」。
   */
  private refreshCompare(): void {
    const normalizedExpected: string = normalizeFingerprint(this.expected);
    let candidate: string = '';
    for (let i: number = 0; i < this.results.length; i++) {
      if (this.results[i].hex.length === normalizedExpected.length) {
        candidate = this.results[i].hex;
      }
    }
    if (candidate.length === 0) {
      for (let i: number = 0; i < this.results.length; i++) {
        if (this.results[i].algorithm === NGFDigestAlgorithm.SHA256) {
          candidate = this.results[i].hex;
        }
      }
    }
    const outcome: NGFFingerprintCompareResult = compareFingerprint(this.expected, candidate);
    this.compareMatched = outcome.matched;
    this.compareMessage = digestCompareText(outcome.outcome);
  }

  /** 与框架 securityToolkit 交叉校验（异步；失败只降级提示，不影响本地结果） */
  private async runCrossCheck(): Promise<void> {
    const text: string = this.input;
    const localSha256: string = digestHexOfText(NGFDigestAlgorithm.SHA256, text);
    const localSha512: string = digestHexOfText(NGFDigestAlgorithm.SHA512, text);
    this.crossCheckMessage = digestCrossCheckText('running', false, false);
    try {
      const frameworkSha256: string = await securityToolkit.shaHash(text, NGFHashAlgorithm.SHA256);
      const frameworkSha512: string = await securityToolkit.shaHash(text, NGFHashAlgorithm.SHA512);
      const sameSha256: boolean = frameworkSha256 === localSha256;
      const sameSha512: boolean = frameworkSha512 === localSha512;
      this.crossCheckOk = sameSha256 && sameSha512;
      if (this.crossCheckOk) {
        this.crossCheckMessage = digestCrossCheckText('match', true, true);
      } else {
        this.crossCheckMessage = digestCrossCheckText('diff', sameSha256, sameSha512);
      }
    } catch (error) {
      this.crossCheckOk = false;
      this.crossCheckMessage = digestCrossCheckText('unavailable', false, false);
      logger.warn(TAG, '框架交叉校验失败');
    }
  }

  /** 清空输入、结果、比对与草稿 */
  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.input = '';
    this.results = [];
    this.expected = '';
    this.compareMessage = '';
    this.compareMatched = false;
    this.crossCheckMessage = '';
    this.crossCheckOk = false;
    toolStateStore.clearDraft(TOOL_ID);
  }

  /** 防抖写草稿：连续输入时只写最后一次 */
  private scheduleDraftSave(text: string): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      toolStateStore.writeDraft(TOOL_ID, text);
    }, DRAFT_DEBOUNCE_MS);
  }

  /** 立即落盘当前输入（离开页面或点「计算摘要」时调用） */
  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }
}