/**
 * SemVer 解析工具页。
 *
 * ## 布局：输入 + 七行拆解表 + 可选比较器
 *
 * @module tools/semver-parse/SemverPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { compareSemver, parseSemver, SemverFailureCode, SemverInfo } from './SemverLogic';

const TOOL_ID: string = 'semver-parse';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildSemverPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildSemverContent })
}

@Builder
function buildSemverContent() {
  SemverToolBody()
}

@Component
struct SemverToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private other: string = '';
  @State private info: SemverInfo | null = null;
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
    const r: SemverInfo = parseSemver(this.input);
    if (r.ok) {
      this.info = r;
      this.errorText = '';
    } else {
      this.info = null;
      this.errorText = r.failure.code === SemverFailureCode.EMPTY_INPUT
        ? ''
        : r.failure.code === SemverFailureCode.BAD_FORMAT
          ? 'bad'
          : '';
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.input, placeholder: $r('app.string.sv_placeholder_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            this.run();
          })
        TextInput({ text: this.other, placeholder: $r('app.string.sv_label_compare') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.other = v;
            this.run();
          })
        Button($r('app.string.sv_action_clear'))
          .width('100%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.input = '';
            this.other = '';
            this.info = null;
            this.errorText = '';
            this.flushDraft();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.info !== null) {
        Column({ space: 8 }) {
          this.infoRow($r('app.string.sv_label_major'), String(this.info.major))
          this.infoRow($r('app.string.sv_label_minor'), String(this.info.minor))
          this.infoRow($r('app.string.sv_label_patch'), String(this.info.patch))
          if (this.info.prerelease.length > 0) {
            this.infoRow($r('app.string.sv_label_pre'), this.info.prerelease)
          }
          if (this.info.build.length > 0) {
            this.infoRow($r('app.string.sv_label_build'), this.info.build)
          }
          this.infoRow($r('app.string.sv_label_normalized'), this.info.normalized)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      }

      if (this.errorText === 'bad') {
        Text($r('app.string.sv_err_format'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }

      if (this.compareRowVisible()) {
        this.compareRow(this.compareResult())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private compareRowVisible(): boolean {
    if (this.info === null || this.other.trim().length === 0) {
      return false;
    }
    return parseSemver(this.other).ok;
  }

  private compareResult(): number {
    const otherInfo: SemverInfo = parseSemver(this.other);
    if (otherInfo.ok && this.info !== null) {
      return compareSemver(this.info, otherInfo);
    }
    return 0;
  }

  @Builder
  private compareRow(cmp: number) {
    Row({ space: 10 }) {
      Text(this.input)
        .fontSize(scaled(12))
        .fontFamily('monospace')
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      Text(cmp < 0 ? '<' : (cmp > 0 ? '>' : '='))
        .fontSize(scaled(16))
        .fontWeight(FontWeight.Bold)
        .fontColor(colorOf(NGFColorToken.PRIMARY))
      Text(this.other)
        .fontSize(scaled(12))
        .fontFamily('monospace')
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private infoRow(label: ResourceStr, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(90)
      Text(value)
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
        .maxLines(2)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityText(ToolUiKit.text(label) + ': ' + value)
  }
}
