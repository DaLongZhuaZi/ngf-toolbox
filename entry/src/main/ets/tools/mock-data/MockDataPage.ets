/**
 * 假数据生成工具页。
 *
 * ## 布局：类型胶囊 + 数量 + 生成 + 结果列表（逐条复制 + 全部复制）
 *
 * @module tools/mock-data/MockDataPage
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
import { NGFRandomByteSource } from '../uuid-password/UuidPasswordLogic';
import { generateMock, MockResult, MockType } from './MockDataLogic';

const TOOL_ID: string = 'mock-data';
const DRAFT_DEBOUNCE_MS: number = 500;

/**
 * 系统安全随机源（与 uuid-password 页面同款实现）。
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
export function buildMockDataPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildMockContent })
}

@Builder
function buildMockContent() {
  MockToolBody()
}

@Component
struct MockToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private type: MockType = MockType.NAME;
  @State private countText: string = '10';
  @State private values: Array<string> = [];
  @State private errorText: string = '';
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

  private run(): void {
    const r: MockResult = generateMock(this.source, this.type, this.countText);
    if (r.ok) {
      this.values = r.values;
      this.errorText = '';
    } else {
      this.values = [];
      this.errorText = ToolUiKit.text($r('app.string.md_err_count'));
    }
    this.scheduleDraftSave();
  }

  private copyAll(): void {
    const LF: string = String.fromCharCode(10);
    ToolUiKit.copyText(this.values.join(LF), ToolUiKit.text($r('app.string.md_copied_all')));
    this.allCopied = true;
    setTimeout((): void => {
      this.allCopied = false;
    }, 1500);
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.md_type_name'), MockType.NAME)
          this.chip($r('app.string.md_type_phone'), MockType.PHONE)
          this.chip($r('app.string.md_type_email'), MockType.EMAIL)
        }
        .width('100%')
        TextInput({ text: this.countText, placeholder: $r('app.string.md_label_count') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.countText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.md_action_generate'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.md_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.values = [];
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

      if (this.values.length > 0) {
        Row() {
          Text(String(this.values.length))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .layoutWeight(1)
          Text(this.allCopied ? $r('app.string.md_copied_all') : $r('app.string.md_action_copy_all'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.md_copied_all')))
            .onClick(() => {
              this.copyAll();
            })
        }
        .width('100%')
        ForEach(this.values, (v: string, idx: number) => {
          Text(v)
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .width('100%')
            .padding(8)
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(8)
            .copyOption(CopyOptions.LocalDevice)
            .accessibilityText(v)
        }, (v: string, idx: number) => idx + ':' + v)
        Text($r('app.string.md_hint_fake'))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chip(label: ResourceStr, t: MockType) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.type === t ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.type === t ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.type = t;
      })
      .accessibilityText(ToolUiKit.text(label))
  }
}