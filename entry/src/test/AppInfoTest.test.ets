import { describe, expect, it } from '@ohos/hypium';
import {
  allLinks,
  AppLink,
  BUNDLE_NAME,
  CONTACT_EMAIL,
  feedbackLinks,
  formatVersion,
  FRAMEWORK_REPOSITORY_URL,
  FrameworkCapability,
  frameworkCapabilities,
  isHttpUrl,
  linkRejectReason,
  privacyPoints,
  QQ_GROUP,
  repositoryQrPayload,
  REPOSITORY_URL,
  siblingProjects
} from '../main/ets/about/AppInfo';
import { NGFLocalizedText } from '../main/ets/core/ToolModel';

/**
 * 关于页信息的单测。
 *
 * ## 为什么这些「常量」也值得测
 *
 * 关于页里全是地址与文案：仓库地址、反馈链接、二维码内容。它们写错了**不会报错**，
 * 表现只有两种——用户点了没反应，或者扫出来的二维码打不开。
 * 而这一页恰恰是推广回路的关键节点（产品定义稿的「推广回路」就靠它把用户
 * 引到框架仓），地址错了整条回路就断了，却没有任何信号。
 *
 * ## 双语之后多了一层要测的东西
 *
 * 内容数据改成 {@link NGFLocalizedText} 之后，「漏翻译」变成了一个**安静**的失败：
 * 英文缺失时会回退中文，不报错、不崩溃、门禁照过。
 * 所以和工具元数据一样，这里也把「两种语言都写全了」变成断言。
 *
 * 注意页面上的**固定标签**（小标题、页脚、按钮）不在本文件范围——
 * 它们走资源键，由 \`tools/verify/check-resources.mjs\` 保证三份资源表对齐。
 */
export default function appInfoTest() {
  describe('appInfoTest', () => {
    // ── 标识符一致性 ────────────────────────────────────────

    it('包名与已定事项一致', 0, () => {
      // PR-007：产品名与包名不得自行更改。这条断言是那道规则的代码侧哨兵。
      expect(BUNDLE_NAME).assertEqual('com.dlzz.ngftoolbox');
    });

    // ── 链接合法性 ──────────────────────────────────────────

    it('全部对外链接都能通过打开前检查', 0, () => {
      // 这是本文件最有价值的一条：页面上每一条「点一下跳转」都走这个检查，
      // 任何地址写错（少斜杠、写成 github.com 而没协议）都会在这里暴露。
      const links: Array<AppLink> = allLinks();
      expect(links.length > 0).assertTrue();
      for (let i: number = 0; i < links.length; i++) {
        expect(linkRejectReason(links[i].url)).assertEqual('');
        expect(links[i].label.zh.length > 0).assertTrue();
        // 每个链接都要有说明，否则用户不知道点它会发生什么
        expect(links[i].description.zh.length > 0).assertTrue();
      }
    });

    it('仓库地址是可扫的完整 https 地址', 0, () => {
      // 二维码扫码器靠协议前缀判断「这是链接还是纯文本」。
      // 少了 https:// 时二维码依然生成，但扫出来不可点——很难发现。
      expect(isHttpUrl(REPOSITORY_URL)).assertTrue();
      expect(REPOSITORY_URL.indexOf('https://') === 0).assertTrue();
      expect(repositoryQrPayload()).assertEqual(REPOSITORY_URL);
      expect(isHttpUrl(FRAMEWORK_REPOSITORY_URL)).assertTrue();
    });

    it('Issue 链接指向本仓的问题列表', 0, () => {
      const links: Array<AppLink> = feedbackLinks();
      let issueUrl: string = '';
      for (let i: number = 0; i < links.length; i++) {
        if (links[i].label.zh.indexOf('Issue') >= 0) {
          issueUrl = links[i].url;
        }
      }
      expect(issueUrl).assertEqual(REPOSITORY_URL + '/issues');
    });

    it('邮件与 QQ 群链接格式正确', 0, () => {
      const links: Array<AppLink> = feedbackLinks();
      let mailUrl: string = '';
      let qqUrl: string = '';
      for (let i: number = 0; i < links.length; i++) {
        if (links[i].url.indexOf('mailto:') === 0) {
          mailUrl = links[i].url;
        }
        // 判据用完整的 'https://qm.qq.com'，不能只匹配 'qq.com'：
        // 邮箱地址里也含 'qq.com'，宽松匹配会让邮件链接把 QQ 群链接覆盖掉。
        if (links[i].url.indexOf('https://qm.qq.com') === 0) {
          qqUrl = links[i].url;
        }
      }
      expect(mailUrl).assertEqual('mailto:' + CONTACT_EMAIL);
      expect(mailUrl.indexOf('@') > 0).assertTrue();
      expect(qqUrl.length > 0).assertTrue();
      expect(qqUrl.indexOf(QQ_GROUP) > 0).assertTrue();
    });

    it('非 http(s) 且非 mailto/tel 的链接会被拒绝', 0, () => {
      expect(linkRejectReason('')).assertEqual('链接为空');
      expect(linkRejectReason('   ')).assertEqual('链接为空');
      expect(linkRejectReason('github.com/foo').length > 0).assertTrue();
      expect(linkRejectReason('javascript:alert(1)').length > 0).assertTrue();
      // 这三类放行
      expect(linkRejectReason('https://a.com')).assertEqual('');
      expect(linkRejectReason('http://a.com')).assertEqual('');
      expect(linkRejectReason('mailto:a@b.com')).assertEqual('');
      expect(linkRejectReason('tel:+8613800000000')).assertEqual('');
    });

    it('同框架作品至少列出一件，且地址与框架仓一致', 0, () => {
      const siblings: Array<AppLink> = siblingProjects();
      expect(siblings.length >= 1).assertTrue();
      expect(siblings[0].url).assertEqual(FRAMEWORK_REPOSITORY_URL);
      expect(siblings[0].label.forLocale('zh-CN').indexOf('电波足迹') >= 0).assertTrue();
      expect(siblings[0].label.forLocale('en-US').indexOf('AirwaveFootprints') >= 0).assertTrue();
    });

    // ── 版本展示 ────────────────────────────────────────────

    it('版本号格式化只管格式，读不到时返回空串交给页面处理', 0, () => {
      expect(formatVersion('0.1.0', 1000000)).assertEqual('v0.1.0 (1000000)');
      // 只有名字
      expect(formatVersion('1.2.3', 0)).assertEqual('v1.2.3');
      // 只有 code
      expect(formatVersion('', 42)).assertEqual('(42)');
      // 都读不到时返回空串——**不再**在这里返回中文文案：
      // 那是面向用户的一句话，应该走资源键才能跟随系统语言。
      expect(formatVersion('', 0)).assertEqual('');
      expect(formatVersion('   ', -1)).assertEqual('');
      expect(formatVersion('  ', NaN)).assertEqual('');
      // 名字两端空白会被去掉
      expect(formatVersion('  1.0.0  ', 1)).assertEqual('v1.0.0 (1)');
    });

    // ── 双语完整性（安静失败的那一类） ──────────────────────

    it('反馈与同框架作品的链接名、说明都写全了两种语言', 0, () => {
      // 缺英文会安静回退中文，不报错。所以必须断言。
      const links: Array<AppLink> = allLinks();
      for (let i: number = 0; i < links.length; i++) {
        expect(links[i].label.zh.length > 0).assertTrue();
        expect(links[i].label.en.length > 0).assertTrue();
        expect(links[i].description.zh.length > 0).assertTrue();
        expect(links[i].description.en.length > 0).assertTrue();
        // 中英完全相同通常意味着忘了翻译（邮箱这类本来就相同的除外）
        if (links[i].url.indexOf('mailto:') !== 0) {
          expect(links[i].label.en === links[i].label.zh).assertFalse();
        }
      }
    });

    // ── 框架能力清单 ────────────────────────────────────────

    it('框架能力清单无重名、每项都有两种语言的说明', 0, () => {
      const list: Array<FrameworkCapability> = frameworkCapabilities();
      expect(list.length > 0).assertTrue();
      const seen: Set<string> = new Set<string>();
      for (let i: number = 0; i < list.length; i++) {
        expect(seen.has(list[i].name)).assertFalse();
        seen.add(list[i].name);
        expect(list[i].description.zh.length > 0).assertTrue();
        expect(list[i].description.en.length > 0).assertTrue();
        expect(list[i].description.en === list[i].description.zh).assertFalse();
      }
    });

    it('层名保持英文原样（开发者要按它去翻框架源码）', 0, () => {
      const list: Array<FrameworkCapability> = frameworkCapabilities();
      for (let i: number = 0; i < list.length; i++) {
        // 层名里出现非 ASCII 就说明有人「顺手翻译」了它
        for (let k: number = 0; k < list[i].name.length; k++) {
          expect(list[i].name.charCodeAt(k) < 128).assertTrue();
        }
      }
    });

    it('清单只列本 App 真的用到的层，不罗列没用上的模块', 0, () => {
      // 关于页的作用是「告诉读者这个样板演示了什么」。
      // 把框架里没用到的模块（media/push/hardware/webBridge）列进来会误导读者。
      const list: Array<FrameworkCapability> = frameworkCapabilities();
      const names: Array<string> = [];
      for (let i: number = 0; i < list.length; i++) {
        names.push(list[i].name);
      }
      const joined: string = names.join(',');
      expect(joined.indexOf('core') >= 0).assertTrue();
      expect(joined.indexOf('data') >= 0).assertTrue();
      expect(joined.indexOf('uiTheme') >= 0).assertTrue();
      // 这些层本 App 没用上，不应出现在清单里
      expect(joined.indexOf('media') < 0).assertTrue();
      expect(joined.indexOf('push') < 0).assertTrue();
      expect(joined.indexOf('hardware') < 0).assertTrue();
      expect(joined.indexOf('webBridge') < 0).assertTrue();
    });

    // ── 隐私承诺 ────────────────────────────────────────────

    it('隐私承诺覆盖四条红线，且都是可核对的断言', 0, () => {
      const points: Array<NGFLocalizedText> = privacyPoints();
      const joined: string = points.map((p: NGFLocalizedText) => p.zh).join(' ');
      // 零遥测（PR-002）
      expect(joined.indexOf('零遥测') >= 0).assertTrue();
      // 权限只有 INTERNET（PR-003）
      expect(joined.indexOf('INTERNET') >= 0).assertTrue();
      // 数据只存本机（PR-008）
      expect(joined.indexOf('本机') >= 0).assertTrue();
      // 完全免费（PR-004）
      expect(joined.indexOf('免费') >= 0).assertTrue();
      expect(points.length >= 4).assertTrue();
    });

    it('隐私承诺的英文版同样具体，不是空话', 0, () => {
      // 英文版最容易写成 "we respect your privacy" 这种没有信息量的话。
      // 这里要求它和中文一样点名具体的机制。
      const points: Array<NGFLocalizedText> = privacyPoints();
      const en: string = points.map((p: NGFLocalizedText) => p.en).join(' ');
      expect(en.indexOf('INTERNET') >= 0).assertTrue();
      expect(en.indexOf('telemetry') >= 0).assertTrue();
      expect(en.length > 200).assertTrue();
      for (let i: number = 0; i < points.length; i++) {
        expect(points[i].en.length > 20).assertTrue();
      }
    });

    it('隐私承诺里不出现无法核对的营销话术', 0, () => {
      // 「行业领先」「极致安全」这类话在样板里是有害的：读者会以为能验证。
      const joined: string = privacyPoints().map((p: NGFLocalizedText) => p.zh).join(' ');
      expect(joined.indexOf('行业领先') < 0).assertTrue();
      expect(joined.indexOf('极致') < 0).assertTrue();
      expect(joined.indexOf('百分百') < 0).assertTrue();
    });

    it('链接清单里不含重复地址之外的意外项', 0, () => {
      // 仓库地址会同时出现在「本仓源码」与「提交 Issue」的基址里，这是预期的；
      // 但每一条都必须有可读的 label。
      const links: Array<AppLink> = allLinks();
      for (let i: number = 0; i < links.length; i++) {
        expect(links[i].label.zh.trim().length > 0).assertTrue();
        expect(links[i].url.trim().length > 0).assertTrue();
      }
      // 至少要有反馈、同框架作品、源码、框架仓四类
      expect(links.length >= 4).assertTrue();
    });

    it('forLocale 对两种语言都能取到非空内容', 0, () => {
      const links: Array<AppLink> = feedbackLinks();
      for (let i: number = 0; i < links.length; i++) {
        expect(links[i].label.forLocale('zh-CN').length > 0).assertTrue();
        expect(links[i].label.forLocale('en-US').length > 0).assertTrue();
      }
    });
  });
}
