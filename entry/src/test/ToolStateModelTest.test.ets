import { describe, expect, it } from '@ohos/hypium';
import {
  parseToolUseState,
  RECENT_TOOL_LIMIT,
  serializeToolUseState,
  ToolUseState
} from '../main/ets/core/ToolStateModel';

/**
 * 收藏 / 最近使用状态模型的单测。
 *
 * 这些逻辑决定了「App 是否记得住用户的习惯」，而它的失败方式很隐蔽：
 * 不报错，只是列表悄悄变长、或者同一个工具重复出现。
 * 因此每条规则都单独写一个用例，用例名说明它防的是什么。
 */
export default function toolStateModelTest() {
  describe('toolStateModelTest', () => {
    it('收藏按添加顺序追加，重复收藏不会出现两条', 0, () => {
      let state: ToolUseState = ToolUseState.empty();
      state = state.withFavorite('regex-tester');
      state = state.withFavorite('json-toolkit');
      // 再收藏一次已收藏的：状态不变（返回自身，引用相等）
      const again: ToolUseState = state.withFavorite('regex-tester');
      expect(again === state).assertTrue();
      expect(state.favorites.length).assertEqual(2);
      expect(state.favorites[0]).assertEqual('regex-tester');
      expect(state.favorites[1]).assertEqual('json-toolkit');
    });

    it('收藏 id 前后空白会被去掉，避免出现「看起来一样的两条」', 0, () => {
      let state: ToolUseState = ToolUseState.empty();
      state = state.withFavorite('  regex-tester  ');
      expect(state.favorites[0]).assertEqual('regex-tester');
      expect(state.isFavorite('regex-tester')).assertTrue();
    });

    it('空 id 不会被收藏', 0, () => {
      let state: ToolUseState = ToolUseState.empty();
      const next: ToolUseState = state.withFavorite('   ');
      expect(next.favorites.length).assertEqual(0);
      expect(next === state).assertTrue();
    });

    it('取消收藏时不动最近使用（两者语义不同）', 0, () => {
      // 回归保护：曾经把「取消收藏」实现成同时从最近使用里删掉，
      // 结果用户「刚用完想再点一次却找不到了」。
      let state: ToolUseState = ToolUseState.empty();
      state = state.withFavorite('regex-tester');
      state = state.withRecentUse('regex-tester');
      const afterUnfav: ToolUseState = state.withoutFavorite('regex-tester');
      expect(afterUnfav.isFavorite('regex-tester')).assertFalse();
      expect(afterUnfav.recents.indexOf('regex-tester') >= 0).assertTrue();
    });

    it('取消一个没收藏的 id 不改变状态', 0, () => {
      const state: ToolUseState = ToolUseState.empty();
      expect(state.withoutFavorite('nope') === state).assertTrue();
    });

    it('toggledFavorite 是收藏开关', 0, () => {
      let state: ToolUseState = ToolUseState.empty();
      state = state.toggledFavorite('digest');
      expect(state.isFavorite('digest')).assertTrue();
      state = state.toggledFavorite('digest');
      expect(state.isFavorite('digest')).assertFalse();
    });

    it('重复使用同一工具是「移动」而不是「重复插入」', 0, () => {
      // 回归保护：重复插入会让「最近使用」很快被同一个工具占满。
      let state: ToolUseState = ToolUseState.empty();
      state = state.withRecentUse('a');
      state = state.withRecentUse('b');
      state = state.withRecentUse('a');
      expect(state.recents.length).assertEqual(2);
      expect(state.recents[0]).assertEqual('a');
      expect(state.recents[1]).assertEqual('b');
    });

    it('最近使用超出上限时砍掉最旧的一头', 0, () => {
      let state: ToolUseState = ToolUseState.empty();
      // 多推入两个，验证上限被遵守且保留的是最近的
      for (let i: number = 0; i < RECENT_TOOL_LIMIT + 2; i++) {
        state = state.withRecentUse('tool-' + i.toString());
      }
      expect(state.recents.length).assertEqual(RECENT_TOOL_LIMIT);
      // 最新的在最前
      expect(state.recents[0]).assertEqual('tool-' + (RECENT_TOOL_LIMIT + 1).toString());
      // 最旧的两个被淘汰
      expect(state.recents.indexOf('tool-0')).assertEqual(-1);
      expect(state.recents.indexOf('tool-1')).assertEqual(-1);
    });

    it('最近使用记录空 id 时状态不变', 0, () => {
      const state: ToolUseState = ToolUseState.empty();
      expect(state.withRecentUse('  ') === state).assertTrue();
    });

    it('不可变性：变更返回新实例，原实例不被改动', 0, () => {
      // 首页的 UI 状态直接引用这份对象；若原地改会让引用不变、
      // 状态观察器侦测不到，表现为「点了收藏图标不变」。
      const original: ToolUseState = ToolUseState.empty();
      const changed: ToolUseState = original.withFavorite('x');
      expect(original.favorites.length).assertEqual(0);
      expect(changed.favorites.length).assertEqual(1);
      expect(changed === original).assertFalse();
    });

    it('序列化再反序列化后状态一致（草稿要能跨进程存活）', 0, () => {
      let state: ToolUseState = ToolUseState.empty();
      state = state.withFavorite('a');
      state = state.withRecentUse('b');
      const restored: ToolUseState = parseToolUseState(serializeToolUseState(state));
      expect(restored.favorites.length).assertEqual(1);
      expect(restored.favorites[0]).assertEqual('a');
      expect(restored.recents[0]).assertEqual('b');
    });

    it('反序列化容忍损坏数据：退化为空状态而不抛异常', 0, () => {
      // 这份数据在设备上，可能被旧版本写过或被手工改坏。
      // 因为一份可选功能的数据而让首页打不开是错误的取舍。
      const fromGarbage: ToolUseState = parseToolUseState('这不是 JSON');
      expect(fromGarbage.favorites.length).assertEqual(0);
      expect(fromGarbage.recents.length).assertEqual(0);
      const fromEmpty: ToolUseState = parseToolUseState('');
      expect(fromEmpty.favorites.length).assertEqual(0);
    });

    it('反序列化会清掉重复项、空项，并把最近使用裁到上限', 0, () => {
      const dirty: string = '{"favorites":["a","a","","b"],"recents":["x","x","y"]}';
      const cleaned: ToolUseState = parseToolUseState(dirty);
      expect(cleaned.favorites.length).assertEqual(2);
      expect(cleaned.favorites[0]).assertEqual('a');
      expect(cleaned.favorites[1]).assertEqual('b');
      expect(cleaned.recents.length).assertEqual(2);
    });

    it('反序列化容忍缺少字段的对象', 0, () => {
      const partial: ToolUseState = parseToolUseState('{}');
      expect(partial.favorites.length).assertEqual(0);
      expect(partial.recents.length).assertEqual(0);
    });
  });
}
