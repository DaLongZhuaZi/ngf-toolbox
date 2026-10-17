import { describe, expect, it } from '@ohos/hypium';
import { builtinTools } from '../main/ets/tools/ToolsCatalog';
import { NGFToolCategory, NGFToolCategoryInfo, NGFToolLayer, NGFToolMeta } from '../main/ets/core/ToolModel';

/**
 * 真实工具清单的单测。
 *
 * ## 为什么必须测「英文写全了」
 *
 * {@link NGFLocalizedText} 的设计是**英文缺失时安静回退中文**——
 * 这个回退本身是对的（有内容总比空白强），但它有一个危险副作用：
 * **漏写英文不会报错、不会崩、本机全部门禁也照过**，
 * 只有英文用户在界面上看到一段中文时才发现。
 *
 * 每件工具 × 3 个字段都查英文，靠人工检查必漏。
 * 所以这里把「英文写全了」变成一条会失败的断言。
 *
 * 顺带钉住清单本身的完整性：件数、id 唯一性、分类合法、order 唯一、
 * 联网工具只允许一件（PR-002/PR-003 的红线）。
 */
export default function toolsCatalogTest() {
  describe('toolsCatalogTest', () => {
    it('全部登记工具都在清单里', 0, () => {
      expect(builtinTools().length).assertEqual(81);
    });

    it('id 唯一、非空、且与目录命名规则一致（小写 kebab-case）', 0, () => {
      const seen: Set<string> = new Set<string>();
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        const id: string = metas[i].id;
        expect(id.length > 0).assertTrue();
        expect(seen.has(id)).assertFalse();
        seen.add(id);
        // kebab-case：只允许小写字母、数字与连字符，且不以连字符开头/结尾
        expect(id === id.toLowerCase()).assertTrue();
        expect(id.charAt(0) !== '-').assertTrue();
        expect(id.charAt(id.length - 1) !== '-').assertTrue();
        expect(id.indexOf('_') < 0).assertTrue();
      }
      expect(seen.size).assertEqual(81);
    });

    it('每件工具的中英文名称与说明都写全了', 0, () => {
      // 这条是本文件存在的核心理由：漏翻译会静默回退成中文。
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        const meta: NGFToolMeta = metas[i];
        expect(meta.name.zh.trim().length > 0).assertTrue();
        expect(meta.name.en.trim().length > 0).assertTrue();
        expect(meta.description.zh.trim().length > 0).assertTrue();
        expect(meta.description.en.trim().length > 0).assertTrue();
        expect(meta.limitation.zh.trim().length > 0).assertTrue();
        expect(meta.limitation.en.trim().length > 0).assertTrue();
        // 英文名不应与中文名相同（相同通常意味着忘了翻译，而不是巧合）
        expect(meta.name.en === meta.name.zh).assertFalse();
      }
    });

    it('英文字段里不含中日韩字符（那说明这一处没翻译）', 0, () => {
      // 判据是「有没有 CJK 字符」，**不是**「是不是纯 ASCII」。
      // 英文里的破折号（—）、弯引号（’）都是正常排版，不该被这条挡住——
      // 最初写成纯 ASCII 检查，结果被自己写的 em dash 误报了一次。
      // 真正要抓的失败模式只有一个：中文被原样留在英文字段里。
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        expect(hasCjk(metas[i].name.en)).assertFalse();
        expect(hasCjk(metas[i].description.en)).assertFalse();
        expect(hasCjk(metas[i].limitation.en)).assertFalse();
      }
    });

    it('中文字段里不含成段的英文字（反向漏翻译）', 0, () => {
      // 反向的失败模式：中文侧被整段替换成英文。
      // 判据用「名称」这个短字段：中文名里出现 4 个以上连续 ASCII 字母，
      // 基本就是没写中文（'JSON 工具' 这类含缩写的是正常的）。
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        // Cookie is the longest legit proper noun (6 letters); 7 means a whole English phrase
      expect(hasLongAsciiRun(metas[i].name.zh, 7)).assertFalse();
      }
    });

    it('英文边界说明不出现 markdown 星号（会被原样显示）', 0, () => {
      // limitation 是纯文本渲染；中文侧也一并检查，因为两面都曾写过 **加粗**。
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        expect(metas[i].limitation.zh.indexOf('**') < 0).assertTrue();
        expect(metas[i].limitation.en.indexOf('**') < 0).assertTrue();
      }
    });

    it('每件工具至少声明一层 NGF 能力（样板的教学价值所在）', 0, () => {
      const metas: Array<NGFToolMeta> = builtinTools();
      const knownLayers: Set<string> = new Set<string>([
        NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW, NGFToolLayer.CONTENT_SOURCE,
        NGFToolLayer.PLATFORM_OHOS, NGFToolLayer.NETWORK, NGFToolLayer.UI_THEME,
        NGFToolLayer.DATA, NGFToolLayer.SECURITY, NGFToolLayer.UI_SHELL
      ]);
      for (let i: number = 0; i < metas.length; i++) {
        expect(metas[i].layers.length > 0).assertTrue();
        for (let k: number = 0; k < metas[i].layers.length; k++) {
          // 层名写错会让关于页显示一个不存在的层
          expect(knownLayers.has(metas[i].layers[k])).assertTrue();
        }
      }
    });

    it('order 唯一，首页排序才是确定的', 0, () => {
      const seen: Set<number> = new Set<number>();
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        expect(seen.has(metas[i].order)).assertFalse();
        seen.add(metas[i].order);
      }
      expect(seen.size).assertEqual(81);
    });

    it('每件工具都有分类与图标名', 0, () => {
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        expect(metas[i].symbol.length > 0).assertTrue();
        // 分类必须是四个产品分类之一（分组按它进行，写错会让工具从首页消失）
        const label: string = NGFToolCategoryInfo.labelOf(metas[i].category, 'zh-CN');
        expect(label.length > 0).assertTrue();
      }
    });

    it('联网工具**只有一件**（PR-002/PR-003 隐私红线）', 0, () => {
      // 这是红线的代码侧哨兵：多出一件 usesNetwork=true 就意味着
      // 有工具会在用户不知情的情况下联网，而首页的联网角标也会跟着多出来。
      const metas: Array<NGFToolMeta> = builtinTools();
      const networked: Array<string> = [];
      for (let i: number = 0; i < metas.length; i++) {
        if (metas[i].usesNetwork) {
          networked.push(metas[i].id);
        }
      }
      expect(networked.length).assertEqual(1);
      expect(networked[0]).assertEqual('port-tester');
    });

    it('联网工具必须属于网络分类且声明了 network 层', 0, () => {
      const metas: Array<NGFToolMeta> = builtinTools();
      for (let i: number = 0; i < metas.length; i++) {
        if (!metas[i].usesNetwork) {
          continue;
        }
        expect(metas[i].category).assertEqual(NGFToolCategory.NETWORK);
        let hasNetworkLayer: boolean = false;
        for (let k: number = 0; k < metas[i].layers.length; k++) {
          if (metas[i].layers[k] === NGFToolLayer.NETWORK) {
            hasNetworkLayer = true;
          }
        }
        expect(hasNetworkLayer).assertTrue();
      }
    });
  });

    /**
     * **每个分类都必须至少有一件工具。**
     *
     * 首页的页签是**逐个写死**的（收藏 + 4 个分类，见 pages/Index.ets 的 buildHdsTabs）：
     * NGF 来源仓的参考实现从不使用 ForEach 生成 TabContent，而本仓在那个组件上
     * 栽过一次（页签条画出来、内容全空），所以不赌那条路径，改成写死。
     *
     * 写死的前提就是「分类数固定且都非空」——这条用例把那个**假设变成门禁**：
     * 将来某件工具改分类导致某个分类空掉时，这里会先失败，
     * 而不是让首页多出一个点不出东西的空白页签。
     */
    it('每个分类都必须至少有一件工具，且分类数固定为 4（首页页签写死的前提）', 0, () => {
      const metas: Array<NGFToolMeta> = builtinTools();
      const ordered: Array<NGFToolCategoryInfo> = NGFToolCategoryInfo.ordered();
      expect(ordered.length).assertEqual(4);
      for (let i: number = 0; i < ordered.length; i++) {
        let count: number = 0;
        for (let k: number = 0; k < metas.length; k++) {
          if (metas[k].category === ordered[i].category) {
            count += 1;
          }
        }
        expect(count > 0).assertTrue();
      }
    });

}

/**
 * 字符串里是否含中日韩字符。
 *
 * 覆盖三段：CJK 统一表意文字、CJK 标点（「」、。、，等）、全角形式。
 * 刻意**不**覆盖破折号、弯引号、± 这类普通排版符号——它们在英文里是正常的。
 */
function hasCjk(text: string): boolean {
  for (let i: number = 0; i < text.length; i++) {
    const code: number = text.charCodeAt(i);
    if ((code >= 0x4E00 && code <= 0x9FFF)
      || (code >= 0x3000 && code <= 0x303F)
      || (code >= 0xFF00 && code <= 0xFFEF)
      || (code >= 0x3400 && code <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}

/** 是否含长度达到 threshold 的连续 ASCII 字母（用于发现中文侧的整段英文） */
function hasLongAsciiRun(text: string, threshold: number): boolean {
  let run: number = 0;
  for (let i: number = 0; i < text.length; i++) {
    const code: number = text.charCodeAt(i);
    const isLetter: boolean = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    if (isLetter) {
      run += 1;
      if (run >= threshold) {
        return true;
      }
    } else {
      run = 0;
    }
  }
  return false;
}
