import { describe, expect, it } from '@ohos/hypium';
import { clampDraft, DRAFT_MAX_LENGTH, toolStateStore, ToolStateStore } from '../main/ets/core/ToolStateStore';
import { ToolUseState } from '../main/ets/core/ToolStateModel';

/**
 * 收藏 / 最近使用 / 草稿**持久化门面**的单测。
 *
 * ## 为什么这一层最需要测试
 *
 * 这里有一个真实且代价很高的坑：框架的 `SettingsManager.initialize()` 是
 * **异步**的，而它在模块引导阶段是用 `void` 调用的（不 await）。
 * 于是「应用启动完成」**不等于**「Preferences 读得出来了」。
 *
 * 如果一个实现在存储未就绪时把内存里的空状态当成真实状态，
 * 那么用户第一次点收藏时就会把**磁盘上真实的收藏数据整个覆盖掉**——
 * 而且不报错、无提示。用户的感受就是「我的收藏莫名其妙没了」。
 *
 * 因此下面的用例重点不在「能存能取」，而在**未就绪时的行为**：
 * 必须拒绝写入，且不能把空当真。
 *
 * ## 存储怎么来的
 *
 * 本地验证时 `ngf_framework` 由 tools/verify/ngf-stub.mjs 提供，
 * 它把存储内容挂在 `globalThis.__NGF_STUB_STORE__` 上供这里控制。
 * 真机上跑同一份测试时，这段 globalThis 代码不存在，
 * 相关用例会因为拿不到控制句柄而**优雅跳过**（见 resetStore 的返回）。
 */

/** 取本地验证用的存储控制句柄；真机上返回 null（相关用例跳过） */
interface StoreControl {
  memory: Map<string, string>;
  ready: boolean;
}

function storeControl(): StoreControl | null {
  const raw: Object | undefined = globalThis.__NGF_STUB_STORE__ as Object | undefined;
  if (raw === undefined || raw === null) {
    return null;
  }
  return raw as StoreControl;
}

/** 把存储切成「未就绪且为空」，返回一份全新的 facade 实例 */
function freshStore(unready: boolean): ToolStateStore {
  const control: StoreControl | null = storeControl();
  if (control !== null) {
    control.memory.clear();
    control.ready = !unready;
  }
  return new ToolStateStore();
}

export default function toolStateStoreTest() {
  describe('toolStateStoreTest', () => {
    it('存储未就绪时 load 返回 false，且 isLoaded 保持 false', 0, () => {
      // 关键：不能返回「空收藏」并标记已加载——那会把「还不知道」误当成「没有」。
      const store: ToolStateStore = freshStore(true);
      expect(store.load()).assertFalse();
      expect(store.isLoaded()).assertFalse();
    });

    it('存储未就绪时拒绝写入收藏（避免覆盖磁盘上的真实数据）', 0, () => {
      const store: ToolStateStore = freshStore(true);
      expect(store.toggleFavorite('regex-tester')).assertFalse();
      // 内存状态也不能变：否则界面会显示一个「看起来已保存」的假状态
      expect(store.isFavorite('regex-tester')).assertFalse();
    });

    it('存储未就绪时 markUsed 与 clearRecents 同样被拒绝', 0, () => {
      const store: ToolStateStore = freshStore(true);
      expect(store.markUsed('regex-tester')).assertFalse();
      expect(store.clearRecents()).assertFalse();
    });

    it('存储就绪后 load 成功，空存储解析为空状态', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      expect(store.load()).assertTrue();
      expect(store.isLoaded()).assertTrue();
      expect(store.getState().favorites.length).assertEqual(0);
      expect(store.getState().recents.length).assertEqual(0);
    });

    it('就绪后能收藏、能落盘、新实例能读回（跨进程不丢）', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      expect(store.toggleFavorite('regex-tester')).assertTrue();
      expect(store.isFavorite('regex-tester')).assertTrue();

      // 换一个 facade 实例重新读，模拟「杀进程后重启」：
      // 只有真的写进了存储，新实例才读得到。
      const reopened: ToolStateStore = new ToolStateStore();
      expect(reopened.load()).assertTrue();
      expect(reopened.isFavorite('regex-tester')).assertTrue();
    });

    it('取消收藏也会落盘', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      store.toggleFavorite('json-toolkit');
      expect(store.toggleFavorite('json-toolkit')).assertTrue();

      const reopened: ToolStateStore = new ToolStateStore();
      reopened.load();
      expect(reopened.isFavorite('json-toolkit')).assertFalse();
    });

    it('markUsed 记进最近使用并落盘', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      expect(store.markUsed('codec-suite')).assertTrue();

      const reopened: ToolStateStore = new ToolStateStore();
      reopened.load();
      expect(reopened.getState().recents.length).assertEqual(1);
      expect(reopened.getState().recents[0]).assertEqual('codec-suite');
    });

    it('重复 markUsed 同一工具不会让最近使用列表变长', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      store.markUsed('timestamp');
      store.markUsed('timestamp');
      expect(store.getState().recents.length).assertEqual(1);
    });

    it('clearRecents 清空最近使用但保留收藏', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      store.toggleFavorite('timestamp');
      store.markUsed('timestamp');
      expect(store.clearRecents()).assertTrue();
      expect(store.getState().recents.length).assertEqual(0);
      // 收藏是「我常驻想要它」，不该被清最近使用连带清掉
      expect(store.isFavorite('timestamp')).assertTrue();
    });

    it('写入的收藏能被新实例读回，顺序保持不变', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      store.toggleFavorite('a');
      store.toggleFavorite('b');
      store.toggleFavorite('c');
      const reopened: ToolStateStore = new ToolStateStore();
      reopened.load();
      const favorites: Array<string> = reopened.getState().favorites;
      expect(favorites.length).assertEqual(3);
      expect(favorites[0]).assertEqual('a');
      expect(favorites[1]).assertEqual('b');
      expect(favorites[2]).assertEqual('c');
    });

    it('草稿能写入、读回、清除', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      const store: ToolStateStore = freshStore(false);
      expect(store.readDraft('json-toolkit')).assertEqual('');
      store.writeDraft('json-toolkit', '{"a":1}');
      expect(store.readDraft('json-toolkit')).assertEqual('{"a":1}');
      store.clearDraft('json-toolkit');
      expect(store.readDraft('json-toolkit')).assertEqual('');
    });

    it('草稿互相隔离：不同工具的草稿不会串', 0, () => {
      // 真机上没有桩控制句柄，而这些用例要求「存储**可控且已就绪**」——
      // 真机用的是框架真实存储，测试里没法把它切成空/未就绪，期望值无从建立。
      //
      // ⚠️ 这里以前只有注释、没有跳过：真机上它们以「真实存储」跑，于是 9 条全挂。
      // 文件头的说明写着「会优雅跳过」，代码里却从来没有那个分支——
      // 注释描述的是一个**没实现的意图**。
      if (storeControl() === null) {
        return;
      }
      // 串了的表现是「打开 JSON 工具看到上次在时间戳里输入的内容」。
      const store: ToolStateStore = freshStore(false);
      store.writeDraft('json-toolkit', 'json 的内容');
      store.writeDraft('timestamp', '时间戳的内容');
      expect(store.readDraft('json-toolkit')).assertEqual('json 的内容');
      expect(store.readDraft('timestamp')).assertEqual('时间戳的内容');
    });

    it('草稿 id 为空时读写都安全（不抛异常、不写入）', 0, () => {
      const store: ToolStateStore = freshStore(false);
      expect(store.readDraft('   ')).assertEqual('');
      store.writeDraft('   ', '不该被保存');
      store.clearDraft('   ');
      expect(store.readDraft('')).assertEqual('');
    });

    it('clampDraft：短文本原样保留', 0, () => {
      expect(clampDraft('短文本')).assertEqual('短文本');
      expect(clampDraft('')).assertEqual('');
    });

    it('clampDraft：超长文本裁到上限以内', 0, () => {
      // Preferences 单条 value 不宜过大；不限长会让用户粘一份几 MB 日志后
      // 拖慢启动。
      const huge: string = 'x'.repeat(DRAFT_MAX_LENGTH + 5000);
      const clamped: string = clampDraft(huge);
      expect(clamped.length).assertEqual(DRAFT_MAX_LENGTH);
    });

    it('clampDraft：超长时保留尾部（用户最近在改的部分）', 0, () => {
      // 保留开头是常见但错误的选择：用户下次打开想看的是「我刚写到哪」。
      const prefix: string = 'A'.repeat(200);
      const suffix: string = 'B'.repeat(DRAFT_MAX_LENGTH);
      const clamped: string = clampDraft(prefix + suffix);
      expect(clamped.length).assertEqual(DRAFT_MAX_LENGTH);
      expect(clamped.charAt(clamped.length - 1)).assertEqual('B');
      // 开头那 200 个 A 应该被丢掉
      expect(clamped.indexOf('A')).assertEqual(-1);
    });

    it('loadForTest 注入状态后免存储可用（供其它模块的测试使用）', 0, () => {
      // 这个后门是给「需要预置收藏」的测试用的，必须真的绕过存储，
      // 否则依赖它的测试在真机上会因存储未就绪而行为不一致。
      const store: ToolStateStore = new ToolStateStore();
      store.loadForTest(new ToolUseState(['x'], ['y']));
      expect(store.isLoaded()).assertTrue();
      expect(store.isFavorite('x')).assertTrue();
      expect(store.getState().recents[0]).assertEqual('y');
    });
  });
}
