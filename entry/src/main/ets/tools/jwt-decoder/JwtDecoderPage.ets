/**
 * JWT 解码工具页。
 *
 * 页面只负责「拿输入 → 调纯逻辑 → 摆结果」，解码规则全部在 {@link ./JwtDecoder}。
 * 页面上唯一需要自己判断的是**过期状态怎么显示**：没有 exp 声明时既不能显示"有效"
 * 也不能显示"已过期"，必须明说"没有过期时间"——这类"没声明"与"声明为假"的混淆
 * 是安全类工具最容易误导人的地方。
 *
 * @module tools/jwt-decoder/JwtDecoderPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { decodeJwt, NGFJwtClaim, NGFJwtDecodeResult } from './JwtDecoder';
import {
  claimLabelText,
  claimRelativeText,
  claimTimeText,
  jwtFailureText
} from './JwtMessages';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'jwt-decoder';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 400;

@Builder
export function buildJwtDecoderPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildJwtDecoderContent })
}

@Builder
function buildJwtDecoderContent() {
  JwtDecoderToolBody()
}

@Component
struct JwtDecoderToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private token: string = '';
  @State private result: NGFJwtDecodeResult | null = null;
  /** 过期状态行的颜色档位：0=无过期时间 1=有效 2=已过期 3=解析失败 */
  @State private statusLevel: number = 0;
  @State private statusText: string = '';
  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.token = restored;

  }


  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.token = saved;
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()

      if (this.statusText.length > 0) {
        this.buildStatusSection()
      }

      if (this.result !== null && this.result.ok) {
        this.buildSegmentSection()
        this.buildClaimSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 输入区 */
  @Builder
  private buildInputSection() {
    Column({ space: 8 }) {
      Text($r('app.string.jwt_label_paste'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextArea({ text: this.token, placeholder: $r('app.string.jwt_placeholder') })
        .width('100%')
        .height(120)
        .fontSize(scaled(14))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .padding(12)
        .onChange((value: string) => {
          this.token = value;
          this.scheduleDraftSave(value);
        })

      Row({ space: 12 }) {
        Button($r('app.string.jwt_action_decode'))
          .layoutWeight(1)
          .onClick(() => {
            this.decode();
          })

        Button($r('app.string.shell_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 状态区：过期状态或错误原因 */
  @Builder
  private buildStatusSection() {
    Text(this.statusText)
      .fontSize(scaled(13))
      .lineHeight(20)
      .width('100%')
      .padding(12)
      .borderRadius(12)
      .backgroundColor(this.statusLevel === 2 || this.statusLevel === 3
        ? colorOf(NGFColorToken.ERROR_CONTAINER)
        : (this.statusLevel === 1 ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : colorOf(NGFColorToken.SURFACE)))
      .fontColor(this.statusLevel === 2 || this.statusLevel === 3
        ? colorOf(NGFColorToken.ERROR_COLOR)
        : (this.statusLevel === 1 ? colorOf(NGFColorToken.SUCCESS) : colorOf(NGFColorToken.ON_SURFACE_VARIANT)))
  }

  /** 三段原文：Header / Payload / Signature */
  @Builder
  private buildSegmentSection() {
    Column({ space: 8 }) {
      this.buildSegmentCard('Header', this.result === null ? '' : this.result.headerJson,
        this.result === null ? '' : this.result.headerRaw)
      this.buildSegmentCard('Payload', this.result === null ? '' : this.result.payloadJson,
        this.result === null ? '' : this.result.payloadRaw)
      this.buildSegmentCard($r('app.string.jwt_label_signature'), this.result === null ? '' : this.result.signature,
        this.result === null ? '' : this.result.signature)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 单段展示卡片：标题 + 复制 + 正文 */
  @Builder
  private buildSegmentCard(title: ResourceStr, body: string, copyValue: string) {
    Column({ space: 6 }) {
      Row() {
        Text(title)
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Blank()
        Text($r('app.string.shell_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
          .onClick(() => {
            ToolUiKit.copyText(copyValue,
        ToolUiKit.stringOf($r('app.string.jwt_copied'), [ToolUiKit.stringOf(title, [])]));
          })
      }
      .width('100%')

      Text(body)
        .fontSize(scaled(13))
        .lineHeight(20)
        .width('100%')
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 时间类声明表 */
  @Builder
  private buildClaimSection() {
    if (this.result !== null && this.result.claims.length > 0) {
      Column({ space: 6 }) {
        Text($r('app.string.jwt_label_time_claims'))
          .fontSize(scaled(15))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))

        ForEach(this.result.claims, (claim: NGFJwtClaim) => {
          Row({ space: 8 }) {
            Text(claimLabelText(claim.key))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .width(128)

            Column({ space: 2 }) {
              Text(claimTimeText(claim))
                .fontSize(scaled(13))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              Text(claim.rawValue + '  ·  ' + claimRelativeText(claim.relative))
                .fontSize(scaled(12))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (claim: NGFJwtClaim) => claim.key)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  /** 解码并刷新状态行 */
  private decode(): void {
    const decoded: NGFJwtDecodeResult = decodeJwt(this.token, Date.now());
    this.result = decoded;
    this.flushDraft();
    if (!decoded.ok) {
      this.statusLevel = 3;
      this.statusText = jwtFailureText(decoded.failure);
      return;
    }
    if (!decoded.hasExpiration) {
      this.statusLevel = 0;
      this.statusText = ToolUiKit.text($r('app.string.jwt_status_no_exp'));
      return;
    }
    if (decoded.expired) {
      this.statusLevel = 2;
      this.statusText = ToolUiKit.stringOf($r('app.string.jwt_status_expired'),
      [claimTimeText(decoded.claims[0]), claimRelativeText(decoded.claims[0].relative)]);
      return;
    }
    this.statusLevel = 1;
    this.statusText = ToolUiKit.stringOf($r('app.string.jwt_status_valid'),
      [claimTimeText(decoded.claims[0]), claimRelativeText(decoded.claims[0].relative)]);
  }

  /** 清空输入、结果与草稿 */
  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.token = '';
    this.result = null;
    this.statusText = '';
    this.statusLevel = 0;
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
    toolStateStore.writeDraft(TOOL_ID, this.token);
  }
}