import { describe, expect, it } from '@ohos/hypium';
import {
  isEnglishLocale,
  NGFLocalizedText,
  NGFToolCategory,
  NGFToolCategoryInfo,
  NGFToolLayer,
  NGFToolMeta,
  NGFToolSearchHit
} from '../main/ets/core/ToolModel';
import { groupToolsByCategory, installToolCatalog, NGFToolCategoryGroup, toolRegistry, ToolRegistry } from '../main/ets/core/ToolRegistry';

/**
 * 工具注册表的单测。
 *
 * ## 为什么这里值得写这么多用例
 *
 * 注册表是「工具可扩展架构」的承重墙：首页的搜索、收藏、分类分组
 * 全部建立在它的输出之上。它一旦错，表现是**首页看起来不对**
 * （搜不到、排序怪、规划中的工具排到最前），而那时很难想到去查注册表。
 *
 * 因此这里刻意用**合成的假工具**（而不是真实工具清单）来测：
 * 真实清单会随开发进度变化，用它写断言会让测试变成「维护负担」；
 * 而注册表的规则（去重、排序、搜索打分）是稳定不变的。
 */

/**
 * 造一件假工具，只填测试关心的字段。
 *
 * `nameEn` / `descriptionEn` 可省略（省略即为空串），此时 {@link NGFLocalizedText.forLocale}
 * 在英文环境下会回退到中文——这本身就是要被测的行为之一。
 */
function fakeTool(
  id: string,
  name: string,
  category: NGFToolCategory,
  description: string,
  order: number,
  nameEn: string = '',
  descriptionEn: string = ''
): NGFToolMeta {
  return new NGFToolMeta(
    id,
    new NGFLocalizedText(name, nameEn),
    category,
    new NGFLocalizedText(description, descriptionEn),
    new NGFLocalizedText('测试用边界说明', 'test-only boundary note'),
    [NGFToolLayer.UTILS],
    'magnifyingglass',
    order,
    false
  );
}

/** 造一个已实现工具（register）用的元数据 */
function builtTool(id: string, name: string, order: number): NGFToolMeta {
  return fakeTool(id, name, NGFToolCategory.TEXT, name + ' 的说明文字', order);
}

export default function toolRegistryTest() {
  describe('toolRegistryTest', () => {
    it('注册后能按 id 取回元数据', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      expect(registry.register(builtTool('regex-tester', '正则测试', 10))).assertTrue();
      const meta: NGFToolMeta | null = registry.getMeta('regex-tester');
      expect(meta !== null).assertTrue();
      if (meta !== null) {
        // 元数据的文案是双语对象，取语言要显式走 forLocale；
        // 这里用中文断言，因为 builtTool 只给了中文（英文空串时回退中文）
        expect(meta.name.forLocale('zh-CN')).assertEqual('正则测试');
        expect(meta.name.forLocale('en-US')).assertEqual('正则测试');
      }
      expect(registry.has('regex-tester')).assertTrue();
    });

    it('未注册的 id 取回 null 而不是抛异常', 0, () => {
      // 首页可能在收藏里存着一个已下架工具的 id，那时必须能安全返回 null。
      const registry: ToolRegistry = new ToolRegistry();
      expect(registry.getMeta('nope') === null).assertTrue();
      expect(registry.has('nope')).assertFalse();
      expect(registry.isImplemented('nope')).assertFalse();
    });

    it('重复注册同一 id 被忽略，先注册者不被顶掉', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(builtTool('a', '第一个', 1));
      const second: boolean = registry.register(builtTool('a', '第二个', 1));
      expect(second).assertFalse();
      const meta: NGFToolMeta | null = registry.getMeta('a');
      if (meta !== null) {
        expect(meta.name.forLocale('zh-CN')).assertEqual('第一个');
      }
      expect(registry.totalCount()).assertEqual(1);
    });

    it('id 为空的元数据被拒绝注册', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      expect(registry.register(builtTool('   ', '没有 id', 1))).assertFalse();
      expect(registry.totalCount()).assertEqual(0);
    });

    it('占位工具算「未实现」，register 的算「已实现」', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(builtTool('done', '做好了', 10));
      registry.registerPlaceholder(fakeTool('todo', '建设中', NGFToolCategory.FILE, '说明', 20));
      expect(registry.isImplemented('done')).assertTrue();
      expect(registry.isImplemented('todo')).assertFalse();
      expect(registry.totalCount()).assertEqual(2);
      expect(registry.implementedCount()).assertEqual(1);
    });

    it('列表把已实现的排在规划中的前面，然后按 order', 0, () => {
      // 这是刻意的产品行为：用户不该在网格第一屏看到一堆「建设中」。
      const registry: ToolRegistry = new ToolRegistry();
      registry.registerPlaceholder(fakeTool('planned', '规划', NGFToolCategory.TEXT, '说明', 1));
      registry.register(builtTool('ready-late', '已实现但 order 大', 90));
      registry.register(builtTool('ready-early', '已实现且 order 小', 5));
      const all: Array<NGFToolMeta> = registry.listAll();
      expect(all.length).assertEqual(3);
      expect(all[0].id).assertEqual('ready-early');
      expect(all[1].id).assertEqual('ready-late');
      expect(all[2].id).assertEqual('planned');
    });

    it('order 相同时按 id 升序，保证顺序稳定', 0, () => {
      // 顺序不稳定会让网格每次渲染都可能换位置，用户会觉得「工具在乱跑」。
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(builtTool('zebra', 'Z', 50));
      registry.register(builtTool('alpha', 'A', 50));
      const all: Array<NGFToolMeta> = registry.listAll();
      expect(all[0].id).assertEqual('alpha');
      expect(all[1].id).assertEqual('zebra');
    });

    it('搜索：完全同名得分最高，压过前缀命中的同名竞争者', 0, () => {
      // 三件工具都含「JSON」，但只有一件**正好叫**「JSON 工具」。
      // 这正是「取最高分而不是累加」要保证的事：描述里提到关键词最多的那件
      // 不该排在真正名字匹配的那件前面。
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('json-toolkit', 'JSON 工具', NGFToolCategory.TEXT, '格式化与压缩 JSON', 10));
      registry.register(fakeTool('jsonish', 'JSON 格式化器', NGFToolCategory.TEXT, '和 JSON 有关', 30));
      registry.register(fakeTool('other', '别的工具', NGFToolCategory.TEXT, '这里也提到 JSON 一次', 20));

      const exact: Array<NGFToolSearchHit> = registry.search('JSON 工具');
      // 只有名字完全含「JSON 工具」的那件命中；描述里只写了「JSON」的不该被算作命中，
      // 否则用户搜一件工具的**全名**时会混进一堆只是提到它的结果。
      expect(exact.length).assertEqual(1);
      expect(exact[0].meta.id).assertEqual('json-toolkit');

      const broad: Array<NGFToolSearchHit> = registry.search('JSON');
      expect(broad.length).assertEqual(3);
      // 名字以 JSON 开头（含完全同名）排在只在描述里提到 JSON 的前面
      expect(broad[0].meta.id).assertEqual('json-toolkit');
      expect(broad[2].meta.id).assertEqual('other');
    });

    it('搜索：大写到小写的大小写不敏感', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('json-toolkit', 'JSON 工具', NGFToolCategory.TEXT, '格式化 JSON', 10));
      expect(registry.search('json').length).assertEqual(1);
      expect(registry.search('JSON').length).assertEqual(1);
      expect(registry.search('JsOn').length).assertEqual(1);
    });

    it('搜索：也能命中 id（开发者会直接敲 json）', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('uuid-password', 'UUID 与随机密码', NGFToolCategory.COMPUTE, '生成标识与密码', 10));
      expect(registry.search('uuid-password').length).assertEqual(1);
    });

    it('搜索：空关键词与纯空白返回空数组', 0, () => {
      // 返回「全部」会让调用方不得不额外判空；这里明确返回空，
      // 由首页决定「空关键词显示全部工具」这个产品行为。
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(builtTool('a', 'A', 1));
      expect(registry.search('').length).assertEqual(0);
      expect(registry.search('   ').length).assertEqual(0);
    });

    it('搜索：长度不足以命中时不返回噪声结果', 0, () => {
      // 刻意不做模糊匹配：宁可搜不到，也不要搜错（见 ToolRegistry 的说明）。
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('regex-tester', '正则测试', NGFToolCategory.TEXT, '表达式测试', 10));
      expect(registry.search('zzz').length).assertEqual(0);
    });

    it('按分类取工具只返回该分类', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('t1', '文本一', NGFToolCategory.TEXT, '说明', 1));
      registry.register(fakeTool('c1', '计算一', NGFToolCategory.COMPUTE, '说明', 2));
      registry.register(fakeTool('c2', '计算二', NGFToolCategory.COMPUTE, '说明', 3));
      expect(registry.listByCategory(NGFToolCategory.TEXT).length).assertEqual(1);
      expect(registry.listByCategory(NGFToolCategory.COMPUTE).length).assertEqual(2);
      expect(registry.listByCategory(NGFToolCategory.NETWORK).length).assertEqual(0);
      expect(registry.listByCategory(NGFToolCategory.FILE).length).assertEqual(0);
    });

    it('分类分组按产品定义稿的固定顺序，空分组被丢弃', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('f1', '文件一', NGFToolCategory.FILE, '说明', 1));
      registry.register(fakeTool('t1', '文本一', NGFToolCategory.TEXT, '说明', 2));
      const groups: Array<NGFToolCategoryGroup> = groupToolsByCategory(registry, 'zh-CN');
      // 只注册了 2 个分类，所以只有 2 组；顺序必须是 文本 -> ... -> 文件
      expect(groups.length).assertEqual(2);
      expect(groups[0].category).assertEqual(NGFToolCategory.TEXT);
      expect(groups[1].category).assertEqual(NGFToolCategory.FILE);
      expect(groups[0].label.length > 0).assertTrue();
    });

    it('分类显示名覆盖全部四个分类', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('t', 'T', NGFToolCategory.TEXT, '说明', 1));
      registry.register(fakeTool('c', 'C', NGFToolCategory.COMPUTE, '说明', 2));
      registry.register(fakeTool('n', 'N', NGFToolCategory.NETWORK, '说明', 3));
      registry.register(fakeTool('f', 'F', NGFToolCategory.FILE, '说明', 4));
      const groups: Array<NGFToolCategoryGroup> = groupToolsByCategory(registry, 'zh-CN');
      expect(groups.length).assertEqual(4);
      for (let i: number = 0; i < groups.length; i++) {
        expect(groups[i].label.length > 0).assertTrue();
      }
    });

    it('启动注册幂等：重复 ensureBuiltinsRegistered 不重复登记', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.ensureBuiltinsRegistered();
      const afterFirst: number = registry.totalCount();
      registry.ensureBuiltinsRegistered();
      expect(registry.totalCount()).assertEqual(afterFirst);
    });

    it('生产单例可用：接口不抛异常（首页直接依赖它）', 0, () => {
      // 刻意**不假设清单内容**：清单随开发进度变化，把它写进断言会让这条测试
      // 每加一件工具就变红，最后被人删掉。这里只验证单例本身可用。
      const total: number = toolRegistry.totalCount();
      expect(total >= 0).assertTrue();
      expect(toolRegistry.listAll().length).assertEqual(total);
      expect(toolRegistry.search('不存在的关键词zz').length).assertEqual(0);
    });

    it('注入清单后 ensureBuiltinsRegistered 会真的登记（接线正确性）', 0, () => {
      // 回归保护：曾经把 install 与 ensure 的顺序写反，
      // 导致注册表在清单为空时就把幂等标志置位，首页永远显示「没有工具」。
      const registry: ToolRegistry = new ToolRegistry();
      installToolCatalog((target: ToolRegistry) => {
        target.register(builtTool('injected', '注入的工具', 1));
      });
      registry.ensureBuiltinsRegistered();
      expect(registry.has('injected')).assertTrue();
      // 用完恢复成空清单，避免污染同进程里其它用例
      installToolCatalog((target: ToolRegistry) => {});
    });

    // ── 双语（元数据与搜索） ────────────────────────────────

    it('NGFLocalizedText 按 locale 取值，缺哪一侧就回退另一侧', 0, () => {
      const both: NGFLocalizedText = new NGFLocalizedText('时间戳', 'Timestamp');
      expect(both.forLocale('zh-CN')).assertEqual('时间戳');
      expect(both.forLocale('en-US')).assertEqual('Timestamp');

      // 只给中文：英文环境回退中文（有内容总比空白强）
      const zhOnly: NGFLocalizedText = new NGFLocalizedText('只有中文', '');
      expect(zhOnly.forLocale('en-US')).assertEqual('只有中文');
      // 只给英文：中文环境回退英文
      const enOnly: NGFLocalizedText = new NGFLocalizedText('', 'English only');
      expect(enOnly.forLocale('zh-CN')).assertEqual('English only');
      // 都没有：空串（不抛异常，卡片显示为空而已）
      const empty: NGFLocalizedText = new NGFLocalizedText('', '');
      expect(empty.forLocale('en-US')).assertEqual('');
      expect(empty.isEmpty).assertTrue();
      expect(both.isEmpty).assertFalse();
    });

    it('isEnglishLocale 只认完整的 en 语言子标签', 0, () => {
      expect(isEnglishLocale('en')).assertTrue();
      expect(isEnglishLocale('en-US')).assertTrue();
      expect(isEnglishLocale('en_US')).assertTrue();
      expect(isEnglishLocale('EN-us')).assertTrue();
      expect(isEnglishLocale('  en-GB  ')).assertTrue();
      // 不能把「以 en 开头的任何东西」都当英文
      expect(isEnglishLocale('eng')).assertFalse();
      expect(isEnglishLocale('enx')).assertFalse();
      expect(isEnglishLocale('zh-CN')).assertFalse();
      expect(isEnglishLocale('ja-JP')).assertFalse();
      expect(isEnglishLocale('')).assertFalse();
      expect(isEnglishLocale('e')).assertFalse();
      // 不是英文的语言**不回退成英文**，而是显示中文（本 App 的第一语言）
      expect(new NGFLocalizedText('中文', 'English').forLocale('ja-JP')).assertEqual('中文');
    });

    it('搜索同时匹配中英两种名称（任一语言的用户都搜得到）', 0, () => {
      // 这是双语改造要修掉的那个功能性缺陷：
      // 元数据只有中文时，英文环境下搜 'Timestamp' 一无所获。
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('timestamp', '时间戳', NGFToolCategory.COMPUTE,
        '时间戳与日期互转', 30, 'Timestamp', 'Convert between timestamps and dates'));
      registry.register(fakeTool('json-toolkit', 'JSON 工具', NGFToolCategory.TEXT,
        'JSON 格式化', 20, 'JSON Toolkit', 'Format and validate JSON'));

      // 英文名命中
      expect(registry.search('timestamp').length).assertEqual(1);
      expect(registry.search('timestamp')[0].meta.id).assertEqual('timestamp');
      // 中文名同样命中（英文用户敲中文也该有结果）
      expect(registry.search('时间戳').length).assertEqual(1);
      // 英文描述命中
      expect(registry.search('timestamps').length).assertEqual(1);
      // 大小写不敏感对英文尤其重要
      expect(registry.search('TIMESTAMP').length).assertEqual(1);
      expect(registry.search('Json Toolkit').length).assertEqual(1);
    });

    it('英文名完全命中时得分最高，不被中文名的部分命中压过', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      // 这件工具的英文名里含 'time'，另一件叫 'Time'
      registry.register(fakeTool('a', '甲', NGFToolCategory.TEXT,
        '说明', 1, 'Time Zone Helper', 'helper'));
      registry.register(fakeTool('b', '乙', NGFToolCategory.TEXT,
        '说明', 2, 'Time', 'exact match'));
      const hits: Array<NGFToolSearchHit> = registry.search('time');
      expect(hits.length).assertEqual(2);
      // 完全同名（乙）必须排在含 'time' 的（甲）前面
      expect(hits[0].meta.id).assertEqual('b');
    });

    it('英文缺失时搜索仍按中文回退匹配，不会漏掉工具', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      // 只给中文的假工具（模拟还没补英文的情况）
      registry.register(fakeTool('untranslated', '未翻译工具', NGFToolCategory.TEXT, '说明文字', 1));
      expect(registry.search('未翻译').length).assertEqual(1);
      // 英文环境下的行为由 forLocale 的回退决定，搜索本身不依赖 locale
      expect(registry.search('untranslated').length).assertEqual(1);
    });

    it('分类名按 locale 取，中英都不为空', 0, () => {
      const registry: ToolRegistry = new ToolRegistry();
      registry.register(fakeTool('t', 'T', NGFToolCategory.TEXT, '说明', 1));
      const zh: Array<NGFToolCategoryGroup> = groupToolsByCategory(registry, 'zh-CN');
      const en: Array<NGFToolCategoryGroup> = groupToolsByCategory(registry, 'en-US');
      expect(zh.length).assertEqual(1);
      expect(en.length).assertEqual(1);
      expect(zh[0].label).assertEqual('文本与数据');
      expect(en[0].label).assertEqual('Text & Data');
    });

    it('四个分类都有中英两种写法，且互不相同', 0, () => {
      const zh: Set<string> = new Set<string>();
      const en: Set<string> = new Set<string>();
      const ordered: Array<NGFToolCategoryInfo> = NGFToolCategoryInfo.ordered();
      expect(ordered.length).assertEqual(4);
      for (let i: number = 0; i < ordered.length; i++) {
        const zhLabel: string = ordered[i].label.forLocale('zh-CN');
        const enLabel: string = ordered[i].label.forLocale('en-US');
        expect(zhLabel.length > 0).assertTrue();
        expect(enLabel.length > 0).assertTrue();
        // 忘了翻译时英文会等于中文，这里挡住
        expect(enLabel === zhLabel).assertFalse();
        zh.add(zhLabel);
        en.add(enLabel);
      }
      expect(zh.size).assertEqual(4);
      expect(en.size).assertEqual(4);
    });

    it('labelOf 按 locale 取分类名，未知分类仍回退空串', 0, () => {
      expect(NGFToolCategoryInfo.labelOf(NGFToolCategory.NETWORK, 'zh-CN')).assertEqual('网络');
      expect(NGFToolCategoryInfo.labelOf(NGFToolCategory.NETWORK, 'en-US')).assertEqual('Network');
      // 未知分类不回退成英文，而是空串（首页据此跳过该组）
      expect(NGFToolCategoryInfo.labelOf('nope' as NGFToolCategory, 'en-US')).assertEqual('');
    });

  });
}