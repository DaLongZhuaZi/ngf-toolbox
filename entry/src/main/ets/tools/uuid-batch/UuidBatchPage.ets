/**
 * UUID 批量生成工具页（薄封装 uuid-password 的 generateUuidBatch）。
 *
 * ## 布局：数量输入 + 格式开关 + 批量生成 + 结果列表（逐条复制 + 全部复制）
 *
 * @module tools/uuid-batch/UuidBatchPage
 */

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { NGFRandomByteSource, UuidBatchFailure } from '../uuid-password/UuidPasswordLogic';
import { generateUuidBatchChecked, UuidBatchCheckResult } from './UuidBatchLogic';

const TOOL_ID: string = 'uuid-batch';
const DRAFT_DEBOUNCE_MS: number = 500;

/**
 * 系统安全随机源（与 uuid-password 页面同款实现——安全约束一致：绝不降级 Math.random）。
 */
class CryptoFrameworkRandomSource extends NGFRandomByteSource {
  nextBytes(count: number): Uint8Array {
    try {
      const random: cryptoFramework.Random = cryptoFramework.createRandom();
      const blob: cryptoFramework.DataBlob = random.generateRandomSync(count);
      return blob.data;
    } catch (error) {
      const businessError = error as BusinessError;
      throw new Error('secure random unavailable: code=' + String(businessError.code));
    }
  }
}

@Builder
export function buildUuidBatchPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildUuidBatchContent })
}

@Builder
function buildUuidBatchContent() {
  UuidBatchToolBody()
}

@Component
struct UuidBatchToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private countText: string = '10';
  @State private uppercase: boolean = false;
  @State private hyphens: boolean = true;
  @State private uuids: Array<string> = [];
  @State private errorText: string = '';
  @State private copiedIndex: number = -1;
  @State private allCopied: boolean = false;
  private readonly source: NGFRandomByteSource = new CryptoFrameworkRandomSource();
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.countText = restored;
    this.run();
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.countText = saved;
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  private scheduleDraftSave(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout((): void => {
      this.flushDraft();
    }, DRAFT_DEBOUNCE_MS);
  }

  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.countText);
  }

  private failureText(failure: UuidBatchFailure): string {
    if (failure === UuidBatchFailure.COUNT_TOO_SMALL) {
      return ToolUiKit.text($r('app.string.ub_err_small'));
    }
    if (failure === UuidBatchFailure.COUNT_TOO_LARGE) {
      return ToolUiKit.text($r('app.string.ub_err_large'));
    }
    if (failure === UuidBatchFailure.COUNT_NOT_INTEGER) {
      return ToolUiKit.text($r('app.string.ub_err_integer'));
    }
    return ToolUiKit.text($r('app.string.ub_err_random'));
  }

  private run(): void {
    const count: number = parseInt(this.countText, 10);
    const r: UuidBatchCheckResult = generateUuidBatchChecked(this.source, count, this.uppercase, this.hyphens);
    if (r.ok) {
      this.uuids = r.result.uuids;
      this.errorText = '';
    } else {
      this.uuids = [];
      this.errorText = this.failureText(r.result.failure);
    }
    this.scheduleDraftSave();
  }

  private copyOne(index: number): void {
    ToolUiKit.copyText(this.uuids[index], ToolUiKit.text($r('app.string.ub_copied')));
    this.copiedIndex = index;
    setTimeout((): void => {
      this.copiedIndex = -1;
    }, 1500);
  }

  private copyAll(): void {
    const LF: string = String.fromCharCode(10);
    ToolUiKit.copyText(this.uuids.join(LF), ToolUiKit.text($r('app.string.ub_copied_all')));
    this.allCopied = true;
    setTimeout((): void => {
      this.allCopied = false;
    }, 1500);
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.countText, placeholder: $r('app.string.ub_label_count') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.countText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 16 }) {
          Row({ space: 6 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.uppercase })
              .onChange((on: boolean) => {
                this.uppercase = on;
              })
              .accessibilityText($r('app.string.ub_toggle_upper'))
            Text($r('app.string.ub_toggle_upper'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          }
          Row({ space: 6 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.hyphens })
              .onChange((on: boolean) => {
                this.hyphens = on;
              })
              .accessibilityText($r('app.string.ub_toggle_hyphen'))
            Text($r('app.string.ub_toggle_hyphen'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          }
          .layoutWeight(1)
        }
        .width('100%')
        Row({ space: 12 }) {
          Button($r('app.string.ub_action_generate'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.ub_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.uuids = [];
              this.errorText = '';
              this.flushDraft();
            })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }

      if (this.uuids.length > 0) {
        Row() {
          Text(ToolUiKit.text($r('app.string.ub_label_count_result')) + ': ' + String(this.uuids.length))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .layoutWeight(1)
          Text(this.allCopied ? $r('app.string.ub_copied_all') : $r('app.string.ub_action_copy_all'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.ub_copied_all')))
            .onClick(() => {
              this.copyAll();
            })
        }
        .width('100%')
        ForEach(this.uuids, (u: string, idx: number) => {
          Row({ space: 10 }) {
            Text(u)
              .fontSize(scaled(12))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .layoutWeight(1)
              .maxLines(1)
              .copyOption(CopyOptions.LocalDevice)
            Text(this.copiedIndex === idx ? $r('app.string.ub_copied') : $r('app.string.ub_action_copy'))
              .fontSize(scaled(11))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .scale({ x: this.copiedIndex >= 0 ? 1.08 : 1, y: this.copiedIndex >= 0 ? 1.08 : 1 })
              .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
              .onClick(() => {
                this.copyOne(idx);
              })
          }
          .width('100%')
          .padding(8)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(8)
          .alignItems(VerticalAlign.Center)
          .accessibilityText(u)
        }, (u: string, idx: number) => idx + ':' + u)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}