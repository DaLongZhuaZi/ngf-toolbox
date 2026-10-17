/**
 * IP/CIDR 计算器工具页。
 *
 * ## 布局：输入 + 七行速查表（规范化 CIDR/网络/广播/掩码/通配符/前缀/总数）
 *
 * 速查表用「标签 + 值 + 复制」行——网络设备配置时逐字段抄，复制按钮按行给。
 *
 * @module tools/ip-cidr/IpCidrPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { analyzeCidr, IpCidrInfo } from './IpCidr';
import { ipCidrFailureText } from './IpCidrMessages';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';

const TOOL_ID: string = 'ip-cidr';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildIpCidrPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildIpCidrContent })
}

@Builder
function buildIpCidrContent() {
  IpCidrToolBody()
}

@Component
struct IpCidrToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private info: IpCidrInfo | null = null;
  @State private errorText: string = '';
  @State private copied: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.input = restored;
    this.run();
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.run();
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
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }

  private run(): void {
    const r: IpCidrInfo = analyzeCidr(this.input);
    if (r.ok) {
      this.errorText = '';
      this.info = r;
    } else {
      this.errorText = ipCidrFailureText(r.failure);
      this.info = null;
    }
    this.scheduleDraftSave();
  }

  private copyWith(label: string, value: string): void {
    ToolUiKit.copyText(value, ToolUiKit.text($r('app.string.ic_copied')));
    this.copied = label;
    setTimeout((): void => {
      this.copied = '';
    }, 1500);
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }
      if (this.info !== null) {
        this.buildInfoSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      TextInput({ text: this.input, placeholder: $r('app.string.ic_placeholder_input') })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
        .onChange((v: string) => {
          this.input = v;
          this.scheduleDraftSave();
        })
      Row({ space: 12 }) {
        Button($r('app.string.ic_action_analyze'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.ic_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.input = '';
            this.info = null;
            this.errorText = '';
            this.flushDraft();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInfoSection() {
    Column({ space: 8 }) {
      this.infoRow($r('app.string.ic_label_cidr'), this.info === null ? '' : this.info.cidr)
      this.infoRow($r('app.string.ic_label_network'), this.info === null ? '' : this.info.network)
      this.infoRow($r('app.string.ic_label_broadcast'), this.info === null ? '' : this.info.broadcast)
      this.infoRow($r('app.string.ic_label_mask'), this.info === null ? '' : this.info.mask)
      this.infoRow($r('app.string.ic_label_wildcard'), this.info === null ? '' : this.info.wildcard)
      this.infoRow($r('app.string.ic_label_prefix'), this.info === null ? '' : '/' + String(this.info.prefix))
      this.infoRow($r('app.string.ic_label_total'), this.info === null ? '' : this.info.totalAddresses)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }

  @Builder
  private infoRow(label: ResourceStr, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(110)
      Text(value)
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
        .maxLines(2)
      Text(this.copied === value ? $r('app.string.ic_copied') : $r('app.string.ic_action_copy'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
          .scale({ x: this.copied !== '' ? 1.08 : 1, y: this.copied !== '' ? 1.08 : 1 })
          .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
        .onClick(() => {
          this.copyWith(value, value);
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityText(ToolUiKit.text(label) + ': ' + value)
  }
}
