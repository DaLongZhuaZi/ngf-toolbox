/**
 * 应用与项目的静态信息 —— 纯逻辑（只依赖 core 的 NGFLocalizedText，可直接单测）。
 *
 * ## 为什么要单独抽一个「信息模块」
 *
 * 关于页里有大量**内容**：仓库地址、同框架作品、反馈渠道、隐私承诺、框架能力说明。
 * 把它们直接写进页面组件有两个问题：
 * 1. 无法单测——地址拼错、少了斜杠、二维码内容写错，都不会报错，
 *    只会表现为「用户点了没反应」或「扫出来打不开」；
 * 2. 分散在多处——同一个仓库地址在「关于页」与「反馈入口」各写一遍，
 *    改一处漏一处。
 *
 * 因此这里把「项目是什么、地址在哪、怎么反馈」收敛成一份可测的数据，
 * 页面只负责渲染。版本号与包名属于**运行时**信息（由系统 API 读），
 * 不在这里硬编码——那是 AppScope/app.json5 的职责，见 PR-007。
 *
 * ## 文案为什么用 NGFLocalizedText 而不是 \`$r()\`
 *
 * 与工具元数据同源的理由：本模块是**纯数据层**，它要能在本机单测里被直接构造与断言。
 * 一旦 import ArkUI 的 \`$r\`，整条「关于页内容」的验证链就没了。
 * 因此内容数据把两种语言带在身上，由页面按 locale 取用；
 * 而**页面的固定标签**（小标题、页脚、按钮）走资源键，那些本来就是 UI 的事。
 *
 * @module about/AppInfo
 */

import { NGFLocalizedText } from '../core/ToolModel';

/** 简写构造器：把「中文 / English」写成一行 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

/**
 * 一个链接条目。
 *
 * \`label\` 是给人看的，\`url\` 是给系统打开的，两者分开是因为
 * 有些链接的展示名需要双语而地址必须原样。
 */
export class AppLink {
  readonly label: NGFLocalizedText;
  readonly url: string;
  /** 一句话说明这个链接是干什么的（避免用户不知道点它会发生什么） */
  readonly description: NGFLocalizedText;

  constructor(label: NGFLocalizedText, url: string, description: NGFLocalizedText) {
    this.label = label;
    this.url = url;
    this.description = description;
  }
}

/** 仓库地址（唯一来源：产品定义稿 §二 已定事项） */
export const REPOSITORY_URL: string = 'https://github.com/DaLongZhuaZi/ngf-toolbox';

/** 框架来源仓（vendored 副本的上游，见 ngf_framework/VENDORED.md） */
export const FRAMEWORK_REPOSITORY_URL: string = 'https://github.com/DaLongZhuaZi/airwavefootprints';

/** 包名（与 AppScope/app.json5 一致；PR-007 规定不得自行更改） */
export const BUNDLE_NAME: string = 'com.dlzz.ngftoolbox';

/** 官方 QQ 群（README 里已公开的信息） */
export const QQ_GROUP: string = '1067738499';

/** 联系方式：邮箱（用于关于页的「写信反馈」入口） */
export const CONTACT_EMAIL: string = 'dalongzhuazi@qq.com';

/**
 * 反馈渠道。
 *
 * 刻意**只列不需要账号、不采集数据的渠道**：GitHub Issue、QQ 群、邮件。
 * 产品定义稿里还提到「反馈中心」——那是上架前要在后端注册 app_id 的自建入口，
 * 尚未接入（见 docs/开发交接.md §二）。
 */
export function feedbackLinks(): Array<AppLink> {
  const links: Array<AppLink> = [];
  links.push(new AppLink(l10n('提交 Issue', 'Open an issue'),
    REPOSITORY_URL + '/issues',
    l10n('发现 Bug 或想提功能建议，在仓库里开一条 Issue',
      'Found a bug or have a feature request? File an issue in the repository')));
  links.push(new AppLink(l10n('加入 QQ 群', 'Join the QQ group'),
    'https://qm.qq.com/q/' + QQ_GROUP,
    l10n('群号 ' + QQ_GROUP + '，闲聊与问题都可以',
      'Group number ' + QQ_GROUP + ' — questions and chat both welcome')));
  links.push(new AppLink(l10n('写封邮件', 'Send an email'), 'mailto:' + CONTACT_EMAIL,
    l10n(CONTACT_EMAIL, CONTACT_EMAIL)));
  return links;
}

/** 同框架作品（与 App 同属一个作者谱系、同一个框架） */
export function siblingProjects(): Array<AppLink> {
  const links: Array<AppLink> = [];
  links.push(new AppLink(
    l10n('电波足迹 AirwaveFootprints', 'AirwaveFootprints'),
    FRAMEWORK_REPOSITORY_URL,
    l10n('NGF 框架的生产验证应用：野外无线电观测与信号分析',
      'The production app that validates NGF: field radio observation and signal analysis')));
  return links;
}

/** NGF 框架的一项能力（关于页的「这个框架能做什么」） */
export class FrameworkCapability {
  /** 层名。它是**技术标识**（core / uiShell / …），两种语言下都保持原样 */
  readonly name: string;
  readonly description: NGFLocalizedText;

  constructor(name: string, description: NGFLocalizedText) {
    this.name = name;
    this.description = description;
  }
}

/**
 * 关于页列出的框架能力。
 *
 * 这份清单**只列本 App 真的用到了的层**。不列出框架里本 App 没用的模块
 * （media / push / hardware / webBridge 等）——关于页的作用是
 * 「告诉读者这个样板演示了什么」，列一堆没用到的东西会误导。
 * 层名不翻译：它是框架的模块标识，开发者按它去翻框架源码。
 */
export function frameworkCapabilities(): Array<FrameworkCapability> {
  const list: Array<FrameworkCapability> = [];
  list.push(new FrameworkCapability('core',
    l10n('依赖容器、门面模式、模块引导与启动内核',
      'Dependency container, facade pattern, module bootstrap and startup kernel')));
  list.push(new FrameworkCapability('uiShell',
    l10n('页面模板、导航壳、路由与页面状态',
      'Page templates, navigation shell, routing and page state')));
  list.push(new FrameworkCapability('uiTheme',
    l10n('语义色 Token、深浅色主题、字体缩放',
      'Semantic colour tokens, light/dark themes, font scaling')));
  list.push(new FrameworkCapability('data',
    l10n('Preferences 设置存储、缓存、关系库与迁移',
      'Preferences-backed settings, caching, relational store and migrations')));
  list.push(new FrameworkCapability('i18n',
    l10n('多语言解析、相对时间格式化',
      'Locale resolution and relative-time formatting')));
  list.push(new FrameworkCapability('utils',
    l10n('日志、时间、字符串、文件与安全工具集',
      'Logging, time, string, file and security utilities')));
  list.push(new FrameworkCapability('platformOhos',
    l10n('窗口、权限、上下文桥与屏幕常亮',
      'Window, permissions, context bridge and screen keep-awake')));
  list.push(new FrameworkCapability('network',
    l10n('网络客户端门面（端口测试用其平台能力）',
      'Network client facade (Port Tester uses its platform capability)')));
  list.push(new FrameworkCapability('security',
    l10n('密钥库与用户认证门面',
      'Keystore and user-authentication facades')));
  list.push(new FrameworkCapability('contentSource / contentWorkflow',
    l10n('内容来源管线与工作流引擎（代码查看演示其分层）',
      'Content-source pipeline and workflow engine (Code Viewer demonstrates the split)')));
  return list;
}

/**
 * 关于页的「隐私承诺」条目。
 *
 * 写成**可核对的断言**而不是营销话术：每一条都能在仓库里对着代码验证。
 * 「零遥测」「只有 INTERNET 权限」这类承诺一旦经不起核对，样板的说服力就没了。
 * 因此英文版也保持同样的具体程度，不写成 "we respect your privacy" 这种空话。
 */
export function privacyPoints(): Array<NGFLocalizedText> {
  const points: Array<NGFLocalizedText> = [];
  points.push(l10n('零遥测、零统计、零账号：不收集、不上传任何数据，也没有第三方 SDK。',
    'Zero telemetry, zero analytics, zero accounts: no data is collected or uploaded, and there is no third-party SDK.'));
  points.push(l10n('只申请了一项权限：INTERNET，且仅供「端口测试」连接你自己输入的主机。',
    'Exactly one permission is requested: INTERNET, used only by Port Tester to reach the host you type yourself.'));
  points.push(l10n('其余 15 件工具全部离线运行，不发送任何网络请求。',
    'The other 15 tools run entirely offline and send no network requests at all.'));
  points.push(l10n('工具的输入历史与草稿只保存在本机，不参与任何云同步。',
    'Tool input history and drafts stay on this device and are never synced to a cloud.'));
  points.push(l10n('完全免费，没有内购、广告与付费解锁。',
    'Completely free — no in-app purchases, no ads, no paid unlocks.'));
  return points;
}

/**
 * 把 GitHub 仓库地址转成二维码内容。
 *
 * 单独成函数（而不是让页面直接塞 REPOSITORY_URL）是为了：
 * 二维码扫码器对 URL 的识别依赖协议前缀。这里显式返回完整地址，
 * 避免将来有人把常量改成 \`github.com/...\` 后二维码扫出来变成不可点的纯文本。
 */
export function repositoryQrPayload(): string {
  return REPOSITORY_URL;
}

/** 地址是否为可用的 http(s) 链接（用于在页面上做一次自检） */
export function isHttpUrl(url: string): boolean {
  const lower: string = url.trim().toLowerCase();
  return lower.indexOf('https://') === 0 || lower.indexOf('http://') === 0;
}

/**
 * 版本号的展示写法。
 *
 * 只管**格式化**，不管「读不到怎么办」：
 * 两个参数都无效时返回空串，由页面决定显示什么（页面用资源键，
 * 这样「读取失败」这句话也能跟着系统语言走）。
 * 早先这里直接返回中文文案，纯逻辑层因此藏了一句面向用户的话。
 *
 * @param versionName 来自 app.json5 的 versionName（运行时由 bundleManager 读取）
 * @param versionCode 来自 app.json5 的 versionCode
 * @returns 形如 \`v0.1.0 (1000000)\`；都无效时为空串
 */
export function formatVersion(versionName: string, versionCode: number): string {
  const name: string = versionName.trim();
  const hasCode: boolean = !isNaN(versionCode) && versionCode > 0;
  if (name.length === 0 && !hasCode) {
    return '';
  }
  if (name.length === 0) {
    return '(' + String(versionCode) + ')';
  }
  if (!hasCode) {
    return 'v' + name;
  }
  return 'v' + name + ' (' + String(versionCode) + ')';
}

/**
 * 打开外部链接前的检查。
 *
 * 返回拒绝原因（中文，仅用于日志）；空串表示可以打开。
 * 页面上所有「点一下跳转」的入口都走它，**任何一个链接写错都会在测试里暴露**，
 * 而不是等到用户点了没反应才发现。
 */
export function linkRejectReason(url: string): string {
  const trimmed: string = url.trim();
  if (trimmed.length === 0) {
    return '链接为空';
  }
  // mailto / tel 这类非 http 协议也是合法的跳转目标
  if (trimmed.indexOf('mailto:') === 0 || trimmed.indexOf('tel:') === 0) {
    return '';
  }
  if (!isHttpUrl(trimmed)) {
    return '这个链接不是 http(s) 地址，打开会失败';
  }
  return '';
}

/** 全部对外链接（用于「批量自检」与测试） */
export function allLinks(): Array<AppLink> {
  const all: Array<AppLink> = [];
  const feedback: Array<AppLink> = feedbackLinks();
  for (let i: number = 0; i < feedback.length; i++) {
    all.push(feedback[i]);
  }
  const siblings: Array<AppLink> = siblingProjects();
  for (let i: number = 0; i < siblings.length; i++) {
    all.push(siblings[i]);
  }
  all.push(new AppLink(l10n('本仓源码', 'This app\'s source'), REPOSITORY_URL,
    l10n('这个 App 自己的源码', 'The source of this app itself')));
  all.push(new AppLink(l10n('框架来源仓', 'Framework repository'), FRAMEWORK_REPOSITORY_URL,
    l10n('NGF 框架的长期维护仓', 'The long-term home of the NGF framework')));
  return all;
}
