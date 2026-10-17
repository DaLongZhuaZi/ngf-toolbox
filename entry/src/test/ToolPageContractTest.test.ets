import { describe, expect, it } from '@ohos/hypium';
import { NGFToolCategory, NGFLocalizedText, NGFToolMeta } from '../main/ets/core/ToolModel';
import { ToolContext } from '../main/ets/core/ToolPageContract';

/**
 * 工具页面上下文的测试。
 *
 * ## 这里真正要钉住的是**语言回退**
 *
 * \`ToolContext.fromMeta\` 是「元数据（纯数据层）→ 页面上下文（UI 层）」的唯一桥梁。
 * 它会按当前 locale 从双语元数据里取值。取值规则本身在 \`NGFLocalizedText.forLocale\`，
 * 但**回退方向**是这条链路最容易悄悄改坏的地方：
 *
 * - 英文环境缺英文 → 回退中文（而不是显示空白）
 * - 中文环境缺中文 → 回退英文
 * - 日语等第三语言 → 显示中文（本 App 的第一语言），不做「非中文即英文」的推断
 *
 * 这些分支在真机上要改系统语言才能碰到，而且改坏之后的表现是「界面某个字段空了」，
 * 不报错、不影响其它功能——正是最该用单测钉死的一类。
 */
export default function toolPageContractTest() {
  describe('ToolPageContractTest', () => {
    const zhName = new NGFLocalizedText('时间戳', 'Timestamp');
    const zhLimit = new NGFLocalizedText('不做时区换算', 'No timezone conversion');

    const buildMeta = (name: NGFLocalizedText, limitation: NGFLocalizedText, net: boolean): NGFToolMeta => {
      return new NGFToolMeta('timestamp', name, NGFToolCategory.COMPUTE,
        new NGFLocalizedText('说明', 'Description'),
        limitation, [], 'symbol_timer', 20, net);
    };

    it('中文环境取中文', 0, () => {
      const ctx: ToolContext = ToolContext.fromMeta(buildMeta(zhName, zhLimit, false), 'zh-CN');
      expect(ctx.toolName).assertEqual('时间戳');
      expect(ctx.limitation).assertEqual('不做时区换算');
    });

    it('英文环境取英文', 0, () => {
      const ctx: ToolContext = ToolContext.fromMeta(buildMeta(zhName, zhLimit, false), 'en-US');
      expect(ctx.toolName).assertEqual('Timestamp');
      expect(ctx.limitation).assertEqual('No timezone conversion');
    });

    it('英文环境缺英文时回退中文而不是留空', 0, () => {
      const onlyZh = new NGFLocalizedText('只有中文', '');
      const ctx: ToolContext = ToolContext.fromMeta(buildMeta(onlyZh, onlyZh, false), 'en-US');
      expect(ctx.toolName).assertEqual('只有中文');
      expect(ctx.limitation).assertEqual('只有中文');
    });

    it('中文环境缺中文时回退英文', 0, () => {
      const onlyEn = new NGFLocalizedText('', 'English only');
      const ctx: ToolContext = ToolContext.fromMeta(buildMeta(onlyEn, onlyEn, false), 'zh-CN');
      expect(ctx.toolName).assertEqual('English only');
    });

    it('第三语言显示中文而不是英文', 0, () => {
      // 刻意不做「非中文即英文」的推断：本 App 的第一语言是中文
      const ctx: ToolContext = ToolContext.fromMeta(buildMeta(zhName, zhLimit, false), 'ja-JP');
      expect(ctx.toolName).assertEqual('时间戳');
    });

    it('toolId 原样带出', 0, () => {
      const ctx: ToolContext = ToolContext.fromMeta(buildMeta(zhName, zhLimit, false), 'zh-CN');
      expect(ctx.toolId).assertEqual('timestamp');
    });

    it('usesNetwork 原样带出（页内明示联网的依据）', 0, () => {
      // 隐私红线：只有端口测试为 true，页面据此显示联网提示
      const yes: ToolContext = ToolContext.fromMeta(buildMeta(zhName, zhLimit, true), 'zh-CN');
      const no: ToolContext = ToolContext.fromMeta(buildMeta(zhName, zhLimit, false), 'zh-CN');
      expect(yes.usesNetwork).assertTrue();
      expect(no.usesNetwork).assertFalse();
    });

    it('大小写与分隔符不同的 locale 都算英文', 0, () => {
      const meta = buildMeta(zhName, zhLimit, false);
      expect(ToolContext.fromMeta(meta, 'en').toolName).assertEqual('Timestamp');
      expect(ToolContext.fromMeta(meta, 'EN-us').toolName).assertEqual('Timestamp');
      expect(ToolContext.fromMeta(meta, 'en_US').toolName).assertEqual('Timestamp');
    });

    it('空 locale 不按英文处理', 0, () => {
      // 读不到语言时宁可按中文走，也不要因为空串被判成英文
      const ctx: ToolContext = ToolContext.fromMeta(buildMeta(zhName, zhLimit, false), '');
      expect(ctx.toolName).assertEqual('时间戳');
    });
  });
}
