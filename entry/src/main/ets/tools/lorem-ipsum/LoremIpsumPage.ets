/**
 * 占位文本生成工具页。
 *
 * ## 布局：四个配置项（两行网格）+ 生成按钮 + 段落结果
 *
 * 数字配置用 TextInput（number 输入类型）；语言用两个胶囊单选；
 * 结果按段落分块渲染（每段一个卡片），顶部提供「复制全部」。
 *
 * @module tools/lorem-ipsum/LoremIpsumPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { generateLorem, LoremLanguage, LoremResult } from './LoremIpsum';
import { loremFailureText } from './LoremIpsumMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'lorem-ipsum';

@Builder
export function buildLoremIpsumPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildLoremContent })
}

@Builder
function buildLoremContent() {
  LoremToolBody()
}

@Component
struct LoremToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private paragraphs: string = '3';
  @State private sentences: string = '4';
  @State private seed: string = '42';
  @State private lang: LoremLanguage = LoremLanguage.LATIN;
  @State private result: LoremResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;

  private onHistoryPick(): void {
    // 本工具的输入是结构化配置，历史回填不适用；保留钩子与其它工具一致
  }

  private run(): void {
    const p: number = parseInt(this.paragraphs, 10);
    const s: number = parseInt(this.sentences, 10);
    const sd: number = parseInt(this.seed, 10);
    if (isNaN(p) || isNaN(s) || isNaN(sd)) {
      this.errorText = ToolUiKit.text($r('app.string.li_err_range'));
      this.result = null;
      return;
    }
    const r: LoremResult = generateLorem(p, s, sd, this.lang);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = loremFailureText(r.failure);
      this.result = null;
    }
  }

  private allText(): string {
    return this.result === null ? '' : this.result.paragraphs.join(String.fromCharCode(10) + String.fromCharCode(10));
  }

  build() {
    Column({ space: 16 }) {
      this.buildConfigSection()
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
        this.buildResultSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }

  @Builder
  private buildConfigSection() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text($r('app.string.li_label_paragraphs'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          TextInput({ text: this.paragraphs })
            .width('100%')
            .height(40)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .type(InputType.Number)
            .onChange((v: string) => {
              this.paragraphs = v;
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text($r('app.string.li_label_sentences'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          TextInput({ text: this.sentences })
            .width('100%')
            .height(40)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .type(InputType.Number)
            .onChange((v: string) => {
              this.sentences = v;
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 4 }) {
        Text($r('app.string.li_label_seed'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextInput({ text: this.seed })
          .width('100%')
          .height(40)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.seed = v;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text($r('app.string.li_label_lang'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Row({ space: 8 }) {
          Text($r('app.string.li_lang_latin'))
            .fontSize(scaled(12))
            .fontColor(this.lang === LoremLanguage.LATIN ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
            .backgroundColor(this.lang === LoremLanguage.LATIN ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .onClick(() => {
              this.lang = LoremLanguage.LATIN;
            })
            .accessibilityText(ToolUiKit.text($r('app.string.li_lang_latin')))
          Text($r('app.string.li_lang_chinese'))
            .fontSize(scaled(12))
            .fontColor(this.lang === LoremLanguage.CHINESE ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
            .backgroundColor(this.lang === LoremLanguage.CHINESE ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .onClick(() => {
              this.lang = LoremLanguage.CHINESE;
            })
            .accessibilityText(ToolUiKit.text($r('app.string.li_lang_chinese')))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        Button($r('app.string.li_action_generate'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
          })
        Button($r('app.string.li_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.result = null;
            this.errorText = '';
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildResultSection() {
    Column({ space: 10 }) {
      Row() {
        Text(this.result === null ? '' :
          ToolUiKit.stringOf($r('app.string.li_result_words'), [String(this.result.words)]))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text(this.copied ? $r('app.string.li_copied') : $r('app.string.li_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
          .onClick(() => {
            ToolUiKit.copyText(this.allText(), ToolUiKit.text($r('app.string.li_copied')));
            this.copied = true;
            setTimeout((): void => {
              this.copied = false;
            }, 1500);
          })
      }
      .width('100%')

      ForEach(this.result === null ? [] : this.result.paragraphs, (para: string, idx: number) => {
        Text(para)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .accessibilityText(ToolUiKit.text($r('app.string.li_result_words')).replace('%s', String(this.result === null ? 0 : this.result.words)) + ': ' + para)
      }, (para: string, idx: number) => idx + ':' + para.substring(0, 16))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
