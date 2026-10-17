/**
 * 二维码生成工具页。
 *
 * ## 绘制用谁的能力
 *
 * 二维码的**编码与绘制**交给 ArkUI 内置的 {@link QRCode} 组件完成——
 * 这是框架能力，不需要自己实现 Reed-Solomon 纠错与矩阵排布。
 * 本工具真正的价值在于「二维码里放什么」：Wi-Fi 的转义、vCard 的 CRLF、
 * 网址的协议补全、电话的号码清理，全部在 {@link QrPayload}（纯逻辑、有单测）。
 *
 * ## 关于「导出图片」
 *
 * 产品定义稿原本把「导出图片」列在二维码工具里。实现时确认：
 * 存图需要组件截图（componentSnapshot）+ 文件写入 + 相册写入，
 * 是一条依赖多项平台能力、且**本机无法验证**的链路。
 * 因此这里只做「生成 + 复制内容 + 系统分享文本」，
 * 并在工具边界里明说做不到导出图片——把边界讲清楚，比给一个半可用的导出按钮诚实。
 *
 * ## 颜色：刻意不给调色
 *
 * 二维码的可靠性依赖对比度。让用户把码点改成浅灰、背景改成深色，
 * 很容易做出「看着挺酷但扫不出来」的二维码。这里固定黑码白底，
 * 把可靠性放在可玩性前面。
 *
 * @module tools/qrcode/QrCodePage
 */

import { NGFControlStyleTokens } from 'ngf_framework';
import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import {
  NGFColorToken, ngfSystemShareFacade } from 'ngf_framework';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  buildPayload,
  lengthNotice,
  QrContentKind,
  QrField,
  QrInput,
  QrKindInfo,
  QrPayloadResult,
  qrKinds,
  QR_COMFORTABLE_LENGTH,
  QrWifiSecurity,
  shorteningHint
} from './QrPayload';
import { currentLocale, FALLBACK_LOCALE } from '../../ui/LocaleSource';
import {
  lengthNoticeText,
  qrFailureText,
  qrKindLabelText,
  qrResultKindText,
  shorteningHintText
} from './QrMessages';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'qrcode';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 500;

/** 二维码预览边长（vp）：太小会扫不出，太大在小屏上放不下 */
const QR_SIZE: number = 220;

/** Wi-Fi 加密方式的选项 */
class SecurityOption {
  readonly value: string;
  /** 选项名（WPA 这类是通用写法，只有两种需要翻译） */
  readonly label: ResourceStr;

  constructor(value: string, label: ResourceStr) {
    this.value = value;
    this.label = label;
  }
}

const SECURITY_OPTIONS: Array<SecurityOption> = [
  new SecurityOption(QrWifiSecurity.WPA, 'WPA/WPA2/WPA3'),
  new SecurityOption(QrWifiSecurity.WEP, $r('app.string.qr_security_wep')),
  new SecurityOption(QrWifiSecurity.NONE, $r('app.string.qr_security_none'))
];

/** 草稿里保存的形态：类型 + 各字段值 */
class QrDraft {
  kind: string = QrContentKind.TEXT;
  fields: Map<string, string> = new Map<string, string>();
}

@Builder
export function buildQrCodePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildQrCodeContent })
}

@Builder
function buildQrCodeContent() {
  QrCodeToolBody()
}

@Component
struct QrCodeToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private kind: QrContentKind = QrContentKind.TEXT;
  /** 各字段的值。用 Map 而不是一堆 @State 字符串：字段随类型变化，动态表格更好维护 */
  @State private fieldValues: Map<string, string> = new Map<string, string>();
  /** 当前语言：类型名是双语数据，按它取 */
  @State private locale: string = FALLBACK_LOCALE;
  @State private errorText: string = '';
  @State private payload: string = '';
  /** 长度提示与缩短建议各自一句（可能为空） */
  @State private noticeText: string = '';
  @State private hintText: string = '';
  /** 让 QRCode 组件重绘：内容不变时不需要重建 */
  @State private qrValue: string = '';

  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.payload = restored;

  }


  aboutToAppear(): void {
    this.locale = currentLocale();
    this.locale = currentLocale();
    this.loadDraft();
    this.rebuild();
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildKindSection()
      this.buildFieldSection()
      if (this.errorText.length > 0) {
        this.buildError()
      }
      this.buildPreviewSection()
      this.buildPayloadSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 类型选择 */
  @Builder
  private buildKindSection() {
    Column({ space: 8 }) {
      Text($r('app.string.qr_label_kind'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(qrKinds(), (info: QrKindInfo) => {
          Text(qrKindLabelText(info, this.locale))
            .fontSize(scaled(12))
            .fontColor(this.kind === info.kind
              ? colorOf(NGFColorToken.PRIMARY)
              : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .accessibilityText(ToolUiKit.text(qrKindLabelText(info, this.locale)))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.kind === info.kind
              ? colorOf(NGFColorToken.PRIMARY_CONTAINER)
              : colorOf(NGFColorToken.SURFACE))
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.kind = info.kind;
              this.scheduleDraftSave();
              this.rebuild();
            })
        }, (info: QrKindInfo) => info.kind)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 字段表单：按当前类型动态渲染 */
  @Builder
  private buildFieldSection() {
    Column({ space: 10 }) {
      ForEach(this.fieldsOfCurrentKind(), (field: string) => {
        this.buildField(field)
      }, (field: string) => field)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 单个字段（含特殊控件：加密方式用选择项，密码用密码框） */
  @Builder
  private buildField(field: string) {
    Column({ space: 6 }) {
      Text(fieldLabel(field))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      if (field === QrField.SECURITY) {
        // 加密方式：用选择项而不是自由输入（自由输入会拼出无效的 T: 值）
        Row({ space: 8 }) {
          ForEach(SECURITY_OPTIONS, (option: SecurityOption) => {
            Text(option.label)
              .fontSize(scaled(12))
              .fontColor(this.value(field) === option.value
                ? colorOf(NGFColorToken.PRIMARY)
                : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
                .accessibilityText(ToolUiKit.text(option.label))
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(this.value(field) === option.value
                ? colorOf(NGFColorToken.PRIMARY_CONTAINER)
                : colorOf(NGFColorToken.SURFACE))
              .borderRadius(12)
              .onClick(() => {
                this.setValue(field, option.value);
              })
          }, (option: SecurityOption) => option.value)
        }
        .width('100%')
      } else if (isMultilineField(field)) {
        TextArea({ text: this.value(field), placeholder: fieldPlaceholder(field) })
          .width('100%')
          .height(80)
          .fontSize(scaled(14))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((next: string) => {
            this.setValue(field, next);
          })
      } else {
        TextInput({ text: this.value(field), placeholder: fieldPlaceholder(field) })
          .width('100%')
          .height(44)
          .fontSize(scaled(14))
          .type(field === QrField.PASSWORD ? InputType.Password : InputType.Normal)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((next: string) => {
            this.setValue(field, next);
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

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

  /** 预览区 */
  @Builder
  private buildPreviewSection() {
    Column({ space: 10 }) {
      if (this.qrValue.length > 0) {
        Column({ space: 8 }) {
          QRCode(this.qrValue)
            .width(QR_SIZE)
            .height(QR_SIZE)
            // 固定黑码白底：对比度是二维码能不能扫出来的决定性因素，
            // 把它交给用户调色只会换来一堆「扫不出来」。
            .color(Color.Black)
            .backgroundColor(Color.White)
          Text(ToolUiKit.stringOf($r('app.string.qr_label_scan_as'),
            [qrResultKindText(this.kind)]))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)

        if (this.noticeText.length > 0) {
          Text(this.noticeText)
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.WARNING))
            .width('100%')
        }
        if (this.hintText.length > 0) {
          Text(this.hintText)
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .width('100%')
        }
      } else {
        Text($r('app.string.qr_empty'))
          .fontSize(scaled(14))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(24)
          .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
          .borderRadius(12)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 内容与操作 */
  @Builder
  private buildPayloadSection() {
    if (this.payload.length > 0) {
      Column({ space: 10 }) {
        Row() {
          Text($r('app.string.qr_label_payload'))
            .fontSize(scaled(15))
            .fontWeight(FontWeight.Medium)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          Blank()
          Text(ToolUiKit.stringOf($r('app.string.qr_chars'), [String(this.payload.length)]))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        }
        .width('100%')

        Text(this.payload)
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .width('100%')
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)

        Row({ space: 12 }) {
          Button($r('app.string.qr_action_copy'))
            .layoutWeight(1)
            .height(NGFControlStyleTokens.DENSE_BUTTON_HEIGHT)
            .fontSize(scaled(14))
            .onClick(() => {
              ToolUiKit.copyText(this.payload, ToolUiKit.text($r('app.string.qr_copied')));
            })
          Button($r('app.string.qr_action_share'))
            .layoutWeight(1)
            .height(NGFControlStyleTokens.DENSE_BUTTON_HEIGHT)
            .fontSize(scaled(14))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .onClick(() => {
              // 分享的是**内容文本**，不是二维码图片：存图需要组件截图，
              // 属于本工具明确不做的范围（见工具边界）。
              ngfSystemShareFacade.shareText(this.payload);
            })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
      .borderRadius(12)
    }
  }

  /** 当前类型需要的字段 */
  private fieldsOfCurrentKind(): Array<string> {
    const list: Array<QrKindInfo> = qrKinds();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].kind === this.kind) {
        return list[i].fields;
      }
    }
    return [];
  }

  /** 读字段值；未设置返回空串 */
  private value(field: string): string {
    const stored: string | undefined = this.fieldValues.get(field);
    return stored === undefined ? '' : stored;
  }

  /** 写字段值并重算 */
  private setValue(field: string, next: string): void {
    const updated: Map<string, string> = new Map<string, string>();
    this.fieldValues.forEach((v: string, k: string) => {
      updated.set(k, v);
    });
    updated.set(field, next);
    this.fieldValues = updated;
    this.scheduleDraftSave();
    this.rebuild();
  }

  /** 重新构造二维码内容 */
  private rebuild(): void {
    const input: QrInput = new QrInput();
    const fields: Array<string> = this.fieldsOfCurrentKind();
    for (let i: number = 0; i < fields.length; i++) {
      input.set(fields[i], this.value(fields[i]));
    }
    // 加密方式没选过时给个默认值，否则用户一进 Wi-Fi 类型就会看到「必须填密码」的报错
    if (this.kind === QrContentKind.WIFI && this.value(QrField.SECURITY).length === 0) {
      input.set(QrField.SECURITY, QrWifiSecurity.WPA);
    }

    const result: QrPayloadResult = buildPayload(this.kind, input);
    if (!result.ok) {
      // 内容还没填全时不报错、也不显示二维码：用户正在打字，
      // 一进页面就满屏红字是最烦人的体验。
      const anyFilled: boolean = this.hasAnyFieldValue();
      this.errorText = anyFilled ? qrFailureText(result.failure) : '';
      this.payload = '';
      this.noticeText = '';
      this.qrValue = '';
      this.noticeText = '';
      this.hintText = '';
      return;
    }
    this.errorText = '';
    this.payload = result.payload;
    this.qrValue = result.payload;
    this.noticeText = lengthNoticeText(lengthNotice(result.payload));
    this.hintText = shorteningHintText(shorteningHint(this.kind, result.payload));
  }

  /** 当前类型下是否已有任何一个字段被填过 */
  private hasAnyFieldValue(): boolean {
    const fields: Array<string> = this.fieldsOfCurrentKind();
    for (let i: number = 0; i < fields.length; i++) {
      if (this.value(fields[i]).trim().length > 0) {
        return true;
      }
    }
    return false;
  }

  /** 读草稿（类型 + 字段） */
  private loadDraft(): void {
    const raw: string = toolStateStore.readDraft(TOOL_ID);
    if (raw.length === 0) {
      return;
    }
    try {
      // 草稿是 JSON：类型 + 字段表。用 JSON 而不是拼接字符串，
      // 是因为字段值里可能含任何字符（含换行），拼接方案无法可靠反解。
      const parsed: QrDraft = JSON.parse(raw) as QrDraft;
      if (parsed.kind !== undefined && parsed.kind.length > 0) {
        this.kind = parsed.kind as QrContentKind;
      }
      const restored: Map<string, string> = new Map<string, string>();
      if (parsed.fields !== undefined) {
        // JSON.parse 出来的对象不能直接用 obj[key] 遍历（ArkTS 禁止动态属性访问），
        // 走 JSON.stringify 再读原文更稳妥——这里改用显式字段清单来恢复。
        const source: string = JSON.stringify(parsed.fields);
        const list: Array<QrKindInfo> = qrKinds();
        for (let i: number = 0; i < list.length; i++) {
          for (let k: number = 0; k < list[i].fields.length; k++) {
            const field: string = list[i].fields[k];
            const value: string = readJsonField(source, field);
            if (value.length > 0) {
              restored.set(field, value);
            }
          }
        }
      }
      this.fieldValues = restored;
    } catch (error) {
      // 草稿损坏就当没有草稿：一份可选功能的坏数据不该让工具打不开。
      toolStateStore.clearDraft(TOOL_ID);
    }
  }

  /** 写草稿 */
  private saveDraft(): void {
    const fields: Map<string, string> = new Map<string, string>();
    this.fieldValues.forEach((v: string, k: string) => {
      fields.set(k, v);
    });
    const draft: QrDraft = new QrDraft();
    draft.kind = this.kind;
    draft.fields = fields;
    toolStateStore.writeDraft(TOOL_ID, JSON.stringify(draft));
  }

  private scheduleDraftSave(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      this.saveDraft();
    }, DRAFT_DEBOUNCE_MS);
  }

  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.saveDraft();
  }
}

/**
 * 字段标签。
 *
 * 返回 ResourceStr 而不是 string：标签走资源键。
 * 兜底返回字段标识本身（而不是空串）——万一将来加了字段忘了补标签，
 * 页面上会显示 'ssid' 这样的内部名，比一片空白更容易发现。
 */
function fieldLabel(field: string): ResourceStr {
  if (field === QrField.TEXT) {
    return $r('app.string.qr_field_text');
  }
  if (field === QrField.URL) {
    return $r('app.string.qr_field_url');
  }
  if (field === QrField.SSID) {
    return $r('app.string.qr_field_ssid');
  }
  if (field === QrField.PASSWORD) {
    return $r('app.string.qr_field_password');
  }
  if (field === QrField.SECURITY) {
    return $r('app.string.qr_field_security');
  }
  if (field === QrField.NAME) {
    return $r('app.string.qr_field_name');
  }
  if (field === QrField.ORG) {
    return $r('app.string.qr_field_org');
  }
  if (field === QrField.TITLE) {
    return $r('app.string.qr_field_title');
  }
  if (field === QrField.TEL) {
    return $r('app.string.qr_field_tel');
  }
  if (field === QrField.EMAIL) {
    return $r('app.string.qr_field_email');
  }
  if (field === QrField.ADDRESS) {
    return $r('app.string.qr_field_address');
  }
  if (field === QrField.PHONE) {
    return $r('app.string.qr_field_phone');
  }
  if (field === QrField.BODY) {
    return $r('app.string.qr_field_body');
  }
  if (field === QrField.SUBJECT) {
    return $r('app.string.qr_field_subject');
  }
  return field;
}
/** 字段的输入提示 */
function fieldPlaceholder(field: string): ResourceStr {
  if (field === QrField.TEXT) {
    return $r('app.string.qr_ph_text');
  }
  if (field === QrField.URL) {
    return $r('app.string.qr_ph_url');
  }
  if (field === QrField.SSID) {
    return $r('app.string.qr_ph_ssid');
  }
  if (field === QrField.PASSWORD) {
    return $r('app.string.qr_ph_password');
  }
  if (field === QrField.NAME) {
    return $r('app.string.qr_ph_name');
  }
  // 电话与名片里的电话号码共用一个提示：两者要求完全一样
  if (field === QrField.PHONE || field === QrField.TEL) {
    return $r('app.string.qr_ph_tel');
  }
  if (field === QrField.EMAIL) {
    // 邮箱是国际通用写法，两种语言下都一样，不做翻译
    return 'name@example.com';
  }
  if (field === QrField.SUBJECT) {
    return $r('app.string.qr_ph_subject');
  }
  if (field === QrField.BODY) {
    return $r('app.string.qr_ph_body');
  }
  if (field === QrField.ORG) {
    return $r('app.string.qr_ph_org');
  }
  if (field === QrField.TITLE) {
    return $r('app.string.qr_ph_title');
  }
  if (field === QrField.ADDRESS) {
    return $r('app.string.qr_ph_address');
  }
  return '';
}
/** 是否为多行字段 */
function isMultilineField(field: string): boolean {
  return field === QrField.TEXT || field === QrField.BODY;
}

/**
 * 从草稿 JSON 文本里读一个字段。
 *
 * 为什么不直接对 JSON.parse 的结果做 obj[field]：ArkTS 禁止动态属性访问。
 * 这里的取值走「转成 JSON 文本 + 精确查找键」，逻辑简单且不依赖动态索引。
 * 草稿是**我们自己的**格式，因此不需要一个通用 JSON 解析器。
 */
function readJsonField(jsonText: string, field: string): string {
  const key: string = '"' + field + '":';
  const at: number = jsonText.indexOf(key);
  if (at < 0) {
    return '';
  }
  let index: number = at + key.length;
  while (index < jsonText.length && jsonText.charAt(index) === ' ') {
    index++;
  }
  if (index >= jsonText.length || jsonText.charAt(index) !== '"') {
    return '';
  }
  index++;
  let value: string = '';
  while (index < jsonText.length) {
    const ch: string = jsonText.charAt(index);
    if (ch === '\\') {
      const next: string = index + 1 < jsonText.length ? jsonText.charAt(index + 1) : '';
      if (next === 'n') {
        value += '\n';
      } else if (next === 't') {
        value += '\t';
      } else if (next === 'r') {
        value += '\r';
      } else {
        value += next;
      }
      index += 2;
      continue;
    }
    if (ch === '"') {
      break;
    }
    value += ch;
    index++;
  }
  return value;
}