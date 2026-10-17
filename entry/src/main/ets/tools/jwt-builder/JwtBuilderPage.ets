/**
 * JWT 构建工具页。
 *
 * ## 布局：payload + secret + Token 输出（可复制）+ 演示提示
 *
 * @module tools/jwt-builder/JwtBuilderPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { buildJwt, JwtBuildFailureCode, JwtBuildResult } from './JwtBuilderLogic';

const TOOL_ID: string = 'jwt-builder';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildJwtBuilderPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildJwtBuilderContent })
}

@Builder
function buildJwtBuilderContent() {
  JwtBuilderToolBody()
}

@Component
struct JwtBuilderToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private payload: string = '';
  @State private secret: string = '';
  @State private result: JwtBuildResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.payload = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.payload);
  }

  private run(): void {
    const r: JwtBuildResult = buildJwt(this.payload, this.secret);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      if (r.failure.code === JwtBuildFailureCode.EMPTY_PAYLOAD) {
        this.errorText = ToolUiKit.text($r('app.string.jb_err_payload'));
      } else if (r.failure.code === JwtBuildFailureCode.EMPTY_SECRET) {
        this.errorText = ToolUiKit.text($r('app.string.jb_err_secret'));
      } else {
        this.errorText = ToolUiKit.text($r('app.string.jb_err_json'));
      }
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.jb_label_payload'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.payload, placeholder: $r('app.string.jb_label_payload') })
          .width('100%')
          .height(110)
          .fontSize(scaled(13))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.payload = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.secret, placeholder: $r('app.string.jb_label_secret') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.secret = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.jb_action_build'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.jb_action_clear'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .layoutWeight(1)
            .onClick(() => {
              this.payload = '';
              this.secret = '';
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
        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.jb_label_token'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(this.copied ? $r('app.string.jb_copied') : $r('app.string.jb_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                ToolUiKit.copyText(this.result === null ? '' : this.result.token,
                  ToolUiKit.text($r('app.string.jb_copied')));
                this.copied = true;
                setTimeout((): void => {
                  this.copied = false;
                }, 1500);
              })
          }
          .width('100%')
          Text(this.result.token)
            .fontSize(scaled(11))
            .fontFamily('monospace')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .width('100%')
            .constraintSize({ maxHeight: 180 })
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.jb_hint_demo'))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}