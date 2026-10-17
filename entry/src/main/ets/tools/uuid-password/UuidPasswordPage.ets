/**
 * UUID 与随机密码工具页。
 *
 * ## 随机源为什么写在这里
 *
 * 系统安全随机来自 `@ohos.security.cryptoFramework`（设备能力）。纯逻辑层一旦 import 它，
 * `entry/src/test` 的本地单测就跑不起来，所以：
 * - 纯逻辑定义 {@link NGFRandomByteSource} 这个可继承基类，只依赖"能给我随机字节"这件事；
 * - **页面**（本文件，唯一允许碰设备能力的地方之一）提供真实现。
 *
 * 这样既守住了分层，又保证了**全工程没有任何一处使用 Math.random 生成 UUID/密码**。
 *
 * @module tools/uuid-password/UuidPasswordPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  evaluatePasswordStrength,
  generatePassword,
  generateUuidBatch,
  NGFPasswordOptions,
  NGFPasswordResult,
  NGFPasswordStrength,
  NGFRandomByteSource,
  NGFUuidBatchResult,
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  UUID_MAX_COUNT
} from './UuidPasswordLogic';
import {
  FIELD_DIGITS,
  FIELD_LOWERCASE,
  FIELD_SYMBOLS,
  FIELD_UPPERCASE,
  passwordAdviceList,
  passwordFailureText,
  strengthLineText,
  uuidFailureText
} from './UuidPasswordMessages';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'uuid-password';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 400;

/**
 * 系统安全随机源（页面层实现）。
 *
 * `generateRandomSync` 由 cryptoFramework 提供，底层是系统的密码学安全随机数发生器；
 * 失败时直接抛给调用方，由纯逻辑转成用户可见的错误提示——**不会**降级成不安全随机。
 */
class CryptoFrameworkRandomSource extends NGFRandomByteSource {
  nextBytes(count: number): Uint8Array {
    try {
      const random: cryptoFramework.Random = cryptoFramework.createRandom();
      const blob: cryptoFramework.DataBlob = random.generateRandomSync(count);
      return blob.data;
    } catch (error) {
      // 显式接住再抛，而不是让它裸抛（ArkTS 要求「Function may throw exceptions」必须处理）。
      //
      // 关键约束：安全随机源拿不到时**绝不能**降级成 Math.random —— 那会让生成的
      // 密码/密钥变成可预测的。所以这里不是「吞掉异常」，而是换成一个带错误码的异常，
      // 由上层（纯逻辑）转成 PasswordFailure 码，最终文案来自资源表。
      //
      // 消息刻意用 ASCII：它**不渲染给用户**，只是往上传递的载体。
      // 写成中文会让 check-i18n 把它算成「未翻译的用户可见文案」——
      // 而它既不该标 i18n-dev-error（用户确实会看到由它转出来的提示，
      // 标了就等于谎称「用户看不到」），也不该进资源表（它从不显示）。
      const businessError = error as BusinessError;
      throw new Error('secure random unavailable: code=' + String(businessError.code));
    }
  }
}

@Builder
export function buildUuidPasswordPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildUuidPasswordContent })
}

@Builder
function buildUuidPasswordContent() {
  UuidPasswordToolBody()
}

@Component
struct UuidPasswordToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  /** 唯一一份随机源：两个分区共用，避免各自创建 */
  private readonly source: NGFRandomByteSource = new CryptoFrameworkRandomSource();

  @State private uuidCountText: string = '5';
  @State private uuidUppercase: boolean = false;
  @State private uuidHyphens: boolean = true;
  @State private uuidResult: string[] = [];
  @State private uuidError: string = '';

  @State private passwordLengthText: string = '16';
  @State private useLowercase: boolean = true;
  @State private useUppercase: boolean = true;
  @State private useDigits: boolean = true;
  @State private useSymbols: boolean = true;
  @State private excludeConfusable: boolean = true;
  @State private passwordText: string = '';
  @State private passwordError: string = '';
  /** 强度评估结果（结构化：档位与建议都是码，文案在渲染时取） */
  @State private strength: NGFPasswordStrength | null = null;

  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.uuidCountText = restored;

  }


  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.applyDraft(saved);
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildUuidSection()
      this.buildPasswordSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** UUID 分区 */
  @Builder
  private buildUuidSection() {
    Column({ space: 8 }) {
      Text('UUID v4')
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Text(ToolUiKit.stringOf($r('app.string.uuidpwd_uuid_hint'), [String(UUID_MAX_COUNT)]))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      TextInput({ text: this.uuidCountText,
          placeholder: ToolUiKit.stringOf($r('app.string.uuidpwd_uuid_placeholder'),
            [String(UUID_MAX_COUNT)]) })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.uuidCountText = value;
          this.scheduleDraftSave();
        })

      Row({ space: 12 }) {
        Row({ space: 6 }) {
          Text($r('app.string.uuidpwd_uuid_uppercase')).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE))
          Toggle({ type: ToggleType.Switch, isOn: this.uuidUppercase })
            .accessibilityText(ToolUiKit.text($r('app.string.uuidpwd_uuid_uppercase')))
            .selectedColor(colorOf(NGFColorToken.PRIMARY))
            .onChange((isOn: boolean) => {
              this.uuidUppercase = isOn;
              this.saveDraft();
            })
        }
        .layoutWeight(1)

        Row({ space: 6 }) {
          Text($r('app.string.uuidpwd_uuid_hyphens')).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE))
          Toggle({ type: ToggleType.Switch, isOn: this.uuidHyphens })
            .accessibilityText(ToolUiKit.text($r('app.string.uuidpwd_uuid_hyphens')))
            .selectedColor(colorOf(NGFColorToken.PRIMARY))
            .onChange((isOn: boolean) => {
              this.uuidHyphens = isOn;
              this.saveDraft();
            })
        }
        .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.uuidpwd_uuid_generate'))
          .layoutWeight(1)
          .onClick(() => {
            this.generateUuids();
            this.flushDraft();
          })

        Button($r('app.string.uuidpwd_uuid_copy_all'))
          .layoutWeight(1)
          .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            ToolUiKit.copyText(this.uuidResult.join('\n'),
        ToolUiKit.stringOf($r('app.string.uuidpwd_uuid_copied_all'),
          [String(this.uuidResult.length)]));
          })

        Button($r('app.string.shell_action_clear'))
          .width(72)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')

      if (this.uuidError.length > 0) {
        Text(this.uuidError)
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      }

      ForEach(this.uuidResult, (item: string) => {
        Row() {
          Text(item)
            .fontSize(scaled(13))
            .layoutWeight(1)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          Text($r('app.string.shell_action_copy'))
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .onClick(() => {
              ToolUiKit.copyText(item, ToolUiKit.text($r('app.string.uuidpwd_uuid_copied')));
            })
        }
        .width('100%')
        .padding(10)
        .borderRadius(10)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
      }, (item: string, index: number) => item + '#' + String(index))
    }
    .width('100%')

    .alignItems(HorizontalAlign.Start)
  }

  // ── 给 @Builder 用的取值方法 ──────────────────────────────
  // @Builder 体里只允许 UI 组件语法，不能写 `const` / `if (x) { return; }` 这类语句。
  // 所以凡是「先取值、再判断」的地方，都把取值挪成普通方法，Builder 里只留表达式。

  /** 是否有可展示的强度结果 */
  private hasStrength(): boolean {
    return this.passwordText.length > 0 && this.strength !== null;
  }

  /** 强度一句话 */
  private strengthLine(): string {
    const strength: NGFPasswordStrength | null = this.strength;
    if (strength === null) {
      return '';
    }
    return strengthLineText(strength, PASSWORD_MIN_LENGTH);
  }

  /** 强度是否达标（决定用成功色还是警告色） */
  private strengthGood(): boolean {
    const strength: NGFPasswordStrength | null = this.strength;
    return strength !== null && strength.score >= 3;
  }

  /** 改进建议列表 */
  private strengthAdvice(): Array<string> {
    const strength: NGFPasswordStrength | null = this.strength;
    if (strength === null) {
      return [];
    }
    return passwordAdviceList(strength, PASSWORD_MIN_LENGTH);
  }

  /** 密码分区 */
  @Builder
  private buildPasswordSection() {
    Column({ space: 8 }) {
      Text($r('app.string.uuidpwd_pwd_title'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Text(ToolUiKit.stringOf($r('app.string.uuidpwd_pwd_hint'),
          [String(PASSWORD_MIN_LENGTH), String(PASSWORD_MAX_LENGTH)]))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      TextInput({ text: this.passwordLengthText, placeholder: $r('app.string.uuidpwd_pwd_length_placeholder') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.passwordLengthText = value;
          this.scheduleDraftSave();
        })

      Row({ space: 12 }) {
        this.buildSwitchRow($r('app.string.uuidpwd_pwd_lowercase'), FIELD_LOWERCASE, this.useLowercase)
        this.buildSwitchRow($r('app.string.uuidpwd_pwd_uppercase'), FIELD_UPPERCASE, this.useUppercase)
      }
      .width('100%')

      Row({ space: 12 }) {
        this.buildSwitchRow($r('app.string.uuidpwd_pwd_digits'), FIELD_DIGITS, this.useDigits)
        this.buildSwitchRow($r('app.string.uuidpwd_pwd_symbols'), FIELD_SYMBOLS, this.useSymbols)
      }
      .width('100%')

      Row() {
        Text($r('app.string.uuidpwd_pwd_exclude')).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.excludeConfusable })
          .accessibilityText(ToolUiKit.text($r('app.string.uuidpwd_pwd_exclude')))
          .selectedColor(colorOf(NGFColorToken.PRIMARY))
          .onChange((isOn: boolean) => {
            this.excludeConfusable = isOn;
            this.saveDraft();
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.uuidpwd_pwd_generate'))
          .layoutWeight(1)
          .onClick(() => {
            this.generatePasswordText();
            this.flushDraft();
          })

        Button($r('app.string.shell_action_copy'))
          .layoutWeight(1)
          .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            ToolUiKit.copyText(this.passwordText, ToolUiKit.text($r('app.string.uuidpwd_pwd_copied')));
          })
      }
      .width('100%')

      if (this.passwordError.length > 0) {
        Text(this.passwordError)
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      }

      // 存结构化结果、渲染时才取文案：这样切换语言后重新渲染就是新语言，
      // 不需要重新生成一次密码。
      // 注意：取值不能写成 `const`——`@Builder` 体只允许 UI 组件语法，
      // 中间夹普通语句会得到「Only UI component syntax can be written here」。
      if (this.hasStrength()) {
        Column({ space: 6 }) {
          Text(this.passwordText)
            .fontSize(scaled(16))
            .lineHeight(24)
            .width('100%')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))

          Text(this.strengthLine())
            .fontSize(scaled(13))
            .fontColor(this.strengthGood() ? colorOf(NGFColorToken.SUCCESS) : colorOf(NGFColorToken.WARNING))

          ForEach(this.strengthAdvice(), (item: string) => {
            Text('· ' + item)
              .fontSize(scaled(12))
              .lineHeight(18)
              .width('100%')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }, (item: string) => item)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 一个字符类别开关（标签 + 开关） */
  @Builder
  private buildSwitchRow(label: ResourceStr, field: string, isOn: boolean) {
    Row({ space: 6 }) {
      Text(label).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE))
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .accessibilityText(ToolUiKit.text(label))
        .selectedColor(colorOf(NGFColorToken.PRIMARY))
        .onChange((value: boolean) => {
          this.toggleClass(field, value);
        })
    }
    .layoutWeight(1)
  }

/**
   * 开关与状态字段的映射。
   *
   * @Builder 的参数是**按值传**的，所以回写只能靠一个标识去找字段。
   * 这个标识必须是与显示无关的稳定值（FIELD_* 常量）——原先用的是**显示标签本身**，
   * 于是「小写 abc」这句话一旦被翻译，开关就再也找不到对应的字段了。
   * 这是做双语时暴露出来的一个隐患：看起来只是文案的地方，实际还兼着逻辑键。
   */
  private toggleClass(field: string, value: boolean): void {
    if (field === FIELD_LOWERCASE) {
      this.useLowercase = value;
    } else if (field === FIELD_UPPERCASE) {
      this.useUppercase = value;
    } else if (field === FIELD_DIGITS) {
      this.useDigits = value;
    } else if (field === FIELD_SYMBOLS) {
      this.useSymbols = value;
    }
    this.saveDraft();
  }

  /** 生成 UUID 列表 */
  private generateUuids(): void {
    const count: number = parseInt(this.uuidCountText, 10);
    if (isNaN(count)) {
      this.uuidError = ToolUiKit.text($r('app.string.uuidpwd_uuid_count_not_digit'));
      this.uuidResult = [];
      return;
    }
    const result: NGFUuidBatchResult = generateUuidBatch(this.source, count,
      this.uuidUppercase, this.uuidHyphens);
    if (!result.ok) {
      this.uuidError = uuidFailureText(result.failure, result.args);
      this.uuidResult = [];
      return;
    }
    this.uuidError = '';
    this.uuidResult = result.uuids;
  }

  /** 生成密码并立即评估强度 */
  private generatePasswordText(): void {
    const length: number = parseInt(this.passwordLengthText, 10);
    if (isNaN(length)) {
      this.passwordError = ToolUiKit.text($r('app.string.uuidpwd_pwd_length_not_digit'));
      this.passwordText = '';
      return;
    }
    const options: NGFPasswordOptions = new NGFPasswordOptions(length, this.useLowercase,
      this.useUppercase, this.useDigits, this.useSymbols, this.excludeConfusable);
    const result: NGFPasswordResult = generatePassword(this.source, options);
    if (!result.ok) {
      this.passwordError = passwordFailureText(result.failure, result.args);
      this.passwordText = '';
      this.strength = null;
      return;
    }
    this.passwordError = '';
    this.passwordText = result.password;
    const strength: NGFPasswordStrength = evaluatePasswordStrength(result.password);
    this.strength = strength;
  }

  /** 清空两个分区的结果（输入选项保留，便于连续生成） */
  private clearAll(): void {
    this.uuidResult = [];
    this.uuidError = '';
    this.passwordText = '';
    this.passwordError = '';
    this.strength = null;
    toolStateStore.clearDraft(TOOL_ID);
  }

  /** 草稿：行分隔（选项个数固定，格式只被本页面的两个方法读写） */
  private serializeDraft(): string {
    return this.uuidCountText + '\n' + (this.uuidUppercase ? '1' : '0') + '\n'
      + (this.uuidHyphens ? '1' : '0') + '\n' + this.passwordLengthText + '\n'
      + (this.useLowercase ? '1' : '0') + '\n' + (this.useUppercase ? '1' : '0') + '\n'
      + (this.useDigits ? '1' : '0') + '\n' + (this.useSymbols ? '1' : '0') + '\n'
      + (this.excludeConfusable ? '1' : '0');
  }

  private applyDraft(raw: string): void {
    const parts: string[] = raw.split('\n');
    if (parts.length < 9) {
      return;
    }
    if (parts[0].length > 0) {
      this.uuidCountText = parts[0];
    }
    this.uuidUppercase = parts[1] === '1';
    this.uuidHyphens = parts[2] === '1';
    if (parts[3].length > 0) {
      this.passwordLengthText = parts[3];
    }
    this.useLowercase = parts[4] === '1';
    this.useUppercase = parts[5] === '1';
    this.useDigits = parts[6] === '1';
    this.useSymbols = parts[7] === '1';
    this.excludeConfusable = parts[8] === '1';
  }

  private saveDraft(): void {
    toolStateStore.writeDraft(TOOL_ID, this.serializeDraft());
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