/**
 * 存储单位速查工具页。
 *
 * ## 布局：字节数输入 + 双体系对照表 + 7% 差异提示
 *
 * @module tools/unit-table/UnitTablePage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { bytesInUnits, UnitPair, UnitTableResult } from './UnitTableLogic';

const TOOL_ID: string = 'unit-table';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildUnitTablePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildUnitTableContent })
}

@Builder
function buildUnitTableContent() {
  UnitTableToolBody()
}

@Component
struct UnitTableToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private bytesText: string = '';
  @State private result: UnitTableResult | null = null;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.bytesText = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.bytesText);
  }

  private run(): void {
    const bytes: number = parseInt(this.bytesText, 10);
    if (isNaN(bytes)) {
      this.result = null;
      return;
    }
    this.result = bytesInUnits(bytes);
    this.scheduleDraftSave();
  }

  @Builder
  private rowOf(pair: UnitPair) {
    Row({ space: 10 }) {
      Text(pair.decimal + ' (' + pair.decimalBytes + ')')
        .fontSize(scaled(12))
        .fontFamily('monospace')
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1);
      Text(pair.binary + ' (' + pair.binaryBytes + ')')
        .fontSize(scaled(12))
        .fontFamily('monospace')
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .layoutWeight(1);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.bytesText, placeholder: $r('app.string.ut_label_bytes') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.bytesText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.ut_action_calc'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.ut_action_clear'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .layoutWeight(1)
            .onClick(() => {
              this.bytesText = '';
              this.result = null;
              this.flushDraft();
            })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.result !== null) {
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Text($r('app.string.ut_col_decimal'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text($r('app.string.ut_col_binary'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
          }
          .width('100%')
          ForEach(this.result.rows, (pair: UnitPair) => {
            this.rowOf(pair)
          }, (pair: UnitPair) => pair.decimal)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.ut_hint_disk'))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
