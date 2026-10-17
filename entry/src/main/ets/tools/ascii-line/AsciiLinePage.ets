/**
 * ASCII 分隔线生成工具页。
 *
 * ## 布局：样式/形态/前缀三组选择 + 宽度/文本 + 输出（等宽可复制）
 *
 * @module tools/ascii-line/AsciiLinePage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { AsciiFailureCode, AsciiResult, buildAscii } from './AsciiLineLogic';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'ascii-line';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildAsciiLinePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildAsciiContent })
}

@Builder
function buildAsciiContent() {
  AsciiToolBody()
}

@Component
struct AsciiToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private style: string = 'eq';
  @State private kind: string = 'line';
  @State private commentStyle: string = 'c';
  @State private widthText: string = '40';
  @State private text: string = '';
  @State private result: AsciiResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.text = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.text);
  }

  private run(): void {
    const r: AsciiResult = buildAscii(this.style, this.kind, this.commentStyle, this.widthText, this.text);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = r.failure.code === AsciiFailureCode.EMPTY_TEXT
        ? ToolUiKit.text($r('app.string.al_err_text'))
        : ToolUiKit.text($r('app.string.al_err_width'));
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.al_label_style'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.al_style_eq'), 'eq', 'style')
          this.chip($r('app.string.al_style_star'), 'star', 'style')
          this.chip($r('app.string.al_style_hash'), 'hash', 'style')
          this.chip($r('app.string.al_style_tilde'), 'tilde', 'style')
          this.chip($r('app.string.al_style_dash'), 'dash', 'style')
        }
        .width('100%')
        Text($r('app.string.al_label_kind'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.al_kind_line'), 'line', 'kind')
          this.chip($r('app.string.al_kind_banner'), 'banner', 'kind')
          this.chip($r('app.string.al_kind_box'), 'box', 'kind')
        }
        .width('100%')
        Text($r('app.string.al_label_comment'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.al_comment_c'), 'c', 'comment')
          this.chip($r('app.string.al_comment_hash'), 'hash', 'comment')
          this.chip($r('app.string.al_comment_sql'), 'sql', 'comment')
        }
        .width('100%')
        TextInput({ text: this.widthText, placeholder: $r('app.string.al_label_width') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.widthText = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.text, placeholder: $r('app.string.al_label_text') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.text = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.al_action_build'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.al_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.text = '';
              this.result = null;
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

      if (this.result !== null) {
        Row({ space: 10 }) {
          Text(this.result.output)
            .fontSize(scaled(12))
            .fontFamily('monospace')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .copyOption(CopyOptions.LocalDevice)
          Text(this.copied ? $r('app.string.al_copied') : $r('app.string.al_action_copy'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
            .onClick(() => {
              ToolUiKit.copyText(this.result === null ? '' : this.result.output,
                ToolUiKit.text($r('app.string.al_copied')));
              this.copied = true;
              setTimeout((): void => {
                this.copied = false;
              }, 1500);
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(VerticalAlign.Top)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private groupValue(group: string): string {
    if (group === 'style') {
      return this.style;
    }
    if (group === 'kind') {
      return this.kind;
    }
    return this.commentStyle;
  }

  private apply(group: string, value: string): void {
    if (group === 'style') {
      this.style = value;
    } else if (group === 'kind') {
      this.kind = value;
    } else {
      this.commentStyle = value;
    }
  }

  @Builder
  private chip(label: ResourceStr, value: string, group: string) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.groupValue(group) === value ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.groupValue(group) === value ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.apply(group, value);
      })
      .accessibilityText(ToolUiKit.text(label))
  }
}
