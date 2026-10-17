/**
 * 表单编码解析工具页。
 *
 * ## 布局：输入 + 字段列表（键=值 + 原始值）+ 统计行
 *
 * @module tools/form-decode/FormDecodePage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { decodeForm, FormDecodeResult, FormField } from './FormDecode';
import { formDecodeFailureText } from './FormDecodeMessages';

const TOOL_ID: string = 'form-decode';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildFormDecodePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildFormContent })
}

@Builder
function buildFormContent() {
  FormToolBody()
}

@Component
struct FormToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: FormDecodeResult | null = null;
  @State private errorText: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
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
    const r: FormDecodeResult = decodeForm(this.input);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = formDecodeFailureText(r.failure);
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.input, placeholder: $r('app.string.fd_placeholder_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            this.run();
          })
        Row({ space: 12 }) {
          Button($r('app.string.fd_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.input = '';
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

      if (this.result !== null && this.result.fields.length > 0) {
        Text(ToolUiKit.text($r('app.string.fd_label_count')) + ': ' + String(this.result.uniqueKeys))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        ForEach(this.result.fields, (f: FormField, idx: number) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(f.key)
                .fontSize(scaled(13))
                .fontWeight(FontWeight.Medium)
                .fontColor(colorOf(NGFColorToken.PRIMARY))
                .layoutWeight(1)
                .maxLines(2)
              Text(f.value)
                .fontSize(scaled(13))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
                .layoutWeight(2)
                .maxLines(2)
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            if (f.rawValue !== f.value) {
              Text(f.rawValue)
                .fontSize(scaled(11))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
                .maxLines(2)
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(f.key + ': ' + f.value)
        }, (f: FormField, idx: number) => idx + ':' + f.key + ':' + f.rawValue)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
