/**
 * Epoch 对照表工具页。
 *
 * ## 布局：输入毫秒值 + 五行对照表
 *
 * @module tools/epoch-table/EpochTablePage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { buildEpochTable, EpochRow, EpochTableResult } from './EpochTable';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'epoch-table';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildEpochTablePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildEpochContent })
}

@Builder
function buildEpochContent() {
  EpochToolBody()
}

@Component
struct EpochToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: EpochTableResult | null = null;
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
    const ms: number = parseInt(this.input, 10);
    if (isNaN(ms)) {
      this.result = null;
      return;
    }
    this.result = buildEpochTable(ms);
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.input, placeholder: $r('app.string.et_placeholder_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.input = v;
            this.run();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.result !== null) {
        Column({ space: 8 }) {
          ForEach(this.result.rows, (row: EpochRow, idx: number) => {
            Row({ space: 10 }) {
              Text(row.label.forLocale(this.locale))
                .fontSize(scaled(12))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
                .width(150)
              Text(row.value)
                .fontSize(scaled(13))
                .fontWeight(FontWeight.Medium)
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
                .layoutWeight(1)
                .maxLines(2)
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
            .accessibilityText(row.label.forLocale(this.locale) + ': ' + row.value)
          }, (row: EpochRow, idx: number) => idx + ':' + row.value)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
