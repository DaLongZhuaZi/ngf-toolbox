/**
 * 子网计算工具页。
 *
 * ## 页面只做三件事
 *
 * 1. 收一个 IPv4 输入（CIDR 或点分十进制掩码两种写法都收）；
 * 2. 把 {@link SubnetCalc} 算出来的每个字段**并列**展示（而不是挤成一行）；
 * 3. 给一个「按主机数反推前缀」的反向规划入口。
 *
 * 所有判断（地址合法性、掩码连续性、/31 与 /32 的特殊口径）都在纯逻辑里并有单测。
 * 页面这一层刻意不写任何网络计算，这样真机上的问题只会是「显示不对」，不会是「算得不对」。
 *
 * ## 为什么结果要「并列」而不是拼一行
 *
 * 子网计算器的结果是**拿去照着配网络**的：用户会逐项抄写。
 * 拼成一行的结果串虽然好复制（页面也提供了一键复制），但抄的时候容易串行错位，
 * 所以屏幕上必须是「标签 — 值」逐行的形式。
 *
 * @module tools/subnet-calc/SubnetCalcPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import {
  ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { NGFLocalizedText } from '../../core/ToolModel';
import { currentLocale, FALLBACK_LOCALE } from '../../ui/LocaleSource';
import {
  computeSubnet,
  describeAddressKind,
  parseSubnetInput,
  prefixRemark,
  SubnetInfo,
  SubnetParseResult
} from './SubnetCalc';
import {
  addressKindText,
  addressNoticeText,
  formatSubnetReport,
  prefixRemarkText,
  reversePlanText,
  subnetParseFailureText
} from './SubnetCalcMessages';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'subnet-calc';

/** 草稿写入防抖（毫秒）：Preferences 同步写盘，每个按键都写会拖慢输入 */
const DRAFT_DEBOUNCE_MS: number = 400;

/** 常用输入示例（点一下即填入，比让用户回忆格式更快） */
const EXAMPLES: string[] = [
  '192.168.1.10/24',
  '10.0.0.1/8',
  '172.16.5.5/255.255.0.0',
  '192.168.1.1/30'
];

/** 结果里的一行：标签 + 值 */
class ResultRow {
  /** 字段标签。类型是 ResourceStr 而不是 string：标签走资源键 */
  readonly label: ResourceStr;
  readonly value: string;
  /** true 表示这是需要用户注意的值（例如「你填的是网络地址」） */
  readonly highlight: boolean;

  constructor(label: ResourceStr, value: string, highlight: boolean) {
    this.label = label;
    this.value = value;
    this.highlight = highlight;
  }
}

@Builder
export function buildSubnetCalcPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildSubnetCalcContent })
}

@Builder
function buildSubnetCalcContent() {
  SubnetCalcToolBody()
}

@Component
struct SubnetCalcToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private errorText: string = '';
  @State private info: SubnetInfo | null = null;
  /** 命中的保留网段（双语数据，按 locale 取） */
  @State private kinds: Array<NGFLocalizedText> = [];
  /** 当前语言：地址性质这类双语数据按它取 */
  @State private locale: string = FALLBACK_LOCALE;
  @State private report: string = '';
  @State private noticeText: string = '';
  /** 反向规划：需要多少台主机 */
  @State private wantedHosts: string = '';

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
    this.locale = currentLocale();
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.recalculate();
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
      if (this.errorText.length > 0) {
        this.buildError()
      }
      if (this.info !== null) {
        this.buildResultSection()
      }
      this.buildReversePlanSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 输入区 */
  @Builder
  private buildInputSection() {
    Column({ space: 8 }) {
      Text($r('app.string.subnet_label_input'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextInput({ text: this.input, placeholder: $r('app.string.subnet_placeholder_input') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.input = value;
          this.scheduleDraftSave(value);
          this.recalculate();
        })

      Text($r('app.string.subnet_input_hint'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.shell_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')

      // 常用示例：点一下填入，省去回忆格式
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(EXAMPLES, (example: string) => {
          Text(example)
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text(example))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.input = example;
              this.scheduleDraftSave(example);
              this.recalculate();
            })
        }, (example: string) => example)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 错误提示：就地红字，并说明原因 */
  @Builder
  private buildError() {
    Text(this.errorText)
      .fontSize(scaled(13))
      .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      .width('100%')
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
      .borderRadius(12)
  }

  /** 结果区：逐行「标签 — 值」 */
  @Builder
  private buildResultSection() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.subnet_label_result'))
          .fontSize(scaled(15))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Blank()
        Text($r('app.string.shell_action_copy_all'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
          .onClick(() => {
            ToolUiKit.copyText(this.report, ToolUiKit.text($r('app.string.subnet_copied')));
          })
      }
      .width('100%')

      // 注意事项（例如「你填的其实是网络地址」）排在最前，避免用户抄完才看到
      if (this.noticeText.length > 0) {
        Text(this.noticeText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }

      ForEach(this.resultRows(), (row: ResultRow) => {
        Row() {
          Text(row.label)
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .width(88)
          Text(row.value)
            .fontSize(scaled(14))
            .fontColor(row.highlight ? colorOf(NGFColorToken.WARNING) : colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (row: ResultRow) => ToolUiKit.text(row.label))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 反向规划：按主机数反推前缀长度 */
  @Builder
  private buildReversePlanSection() {
    Column({ space: 8 }) {
      Text($r('app.string.subnet_label_plan'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Row({ space: 12 }) {
        TextInput({ text: this.wantedHosts, placeholder: $r('app.string.subnet_placeholder_plan') })
          .layoutWeight(1)
          .height(44)
          .fontSize(scaled(15))
          .type(InputType.Number)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((value: string) => {
            this.wantedHosts = value;
          })
      }
      .width('100%')

      if (this.reversePlanText().length > 0) {
        Text(this.reversePlanText())
          .fontSize(scaled(14))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
          .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 组装结果行；未算出结果时返回空数组 */
  private resultRows(): Array<ResultRow> {
    const rows: Array<ResultRow> = [];
    const info: SubnetInfo | null = this.info;
    if (info === null) {
      return rows;
    }
    rows.push(new ResultRow($r('app.string.subnet_field_cidr'), info.cidr, false));
    rows.push(new ResultRow($r('app.string.subnet_field_mask'), info.mask, false));
    rows.push(new ResultRow($r('app.string.subnet_field_wildcard'), info.wildcardMask, false));
    rows.push(new ResultRow($r('app.string.subnet_field_network'), info.network, false));
    rows.push(new ResultRow($r('app.string.subnet_field_broadcast'), info.broadcast, false));
    rows.push(new ResultRow($r('app.string.subnet_field_usable'), info.firstUsable.length > 0
      ? info.firstUsable + ' ~ ' + info.lastUsable
      : ToolUiKit.text($r('app.string.subnet_no_usable')), false));
    rows.push(new ResultRow($r('app.string.subnet_field_total'), String(info.totalAddresses), false));
    rows.push(new ResultRow($r('app.string.subnet_field_hosts'), String(info.usableHosts), false));
    if (this.kinds.length > 0) {
      rows.push(new ResultRow($r('app.string.subnet_field_kinds'),
        addressKindText(this.kinds, this.locale), false));
    }
    return rows;
  }

  /** 反向规划的结果文案 */
  private reversePlanText(): string {
    // 判断与措辞都在 Messages 层（判断用纯逻辑的 prefixForHosts，措辞用资源键）
    return reversePlanText(this.wantedHosts);
  }

  /** 重新计算；输入不合法时清空结果并给出原因 */
  private recalculate(): void {
    const text: string = this.input.trim();
    if (text.length === 0) {
      // 空输入不报错（用户正在输入），只是还没有结果
      this.errorText = '';
      this.info = null;
      this.kinds = [];
      this.report = '';
      this.noticeText = '';
      return;
    }

    const parsed: SubnetParseResult = parseSubnetInput(text);
    if (!parsed.ok) {
      this.errorText = subnetParseFailureText(parsed.failure, parsed.args);
      this.info = null;
      this.kinds = [];
      this.report = '';
      this.noticeText = '';
      return;
    }

    this.errorText = '';
    const info: SubnetInfo = computeSubnet(parsed.addressValue, parsed.prefix);
    this.info = info;
    this.kinds = describeAddressKind(parsed.addressValue);
    this.report = formatSubnetReport(info, this.kinds, this.locale);
    // 提示二选一，避免同义重复：
    // /31 与 /32 的「注意事项」已经涵盖了前缀常识，此时不再叠加前缀说明；
    // 其余前缀（/0、/30、<=8、/24）没有注意事项，就只显示前缀说明。
    const notice: string = addressNoticeText(info);
    this.noticeText = notice.length > 0
      ? notice
      : prefixRemarkText(prefixRemark(info.prefix));
  }

  /** 清空输入与结果 */
  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.input = '';
    this.errorText = '';
    this.info = null;
    this.kinds = [];
    this.report = '';
    this.noticeText = '';
    this.wantedHosts = '';
    toolStateStore.clearDraft(TOOL_ID);
  }

  /** 防抖写草稿 */
  private scheduleDraftSave(text: string): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      toolStateStore.writeDraft(TOOL_ID, text);
    }, DRAFT_DEBOUNCE_MS);
  }

  /** 立即落盘 */
  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }
}