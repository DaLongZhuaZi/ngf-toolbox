/**
 * 本地验证用的 Node 加载器钩子。
 *
 * ## 为什么需要它
 *
 * 本仓的 ArkTS 代码只能由 DevEco/hvigor 编译，而本机没有那套工具链
 * （构建走 CI，见 AGENTS.md §2）。但 core/ 与 tools/<id>/ 里的**纯逻辑**
 * 其实就是普通 TypeScript（只是多了 ArkTS 的严格约束），
 * 完全可以用 Node 22 的类型剥离能力直接跑起来。
 *
 * 这个钩子做三件事：
 * 1. 让 Node 能解析本仓那种「不带扩展名的相对 import」（ArkTS 的写法）；
 * 2. 让 Node 把 `.ets` 当作 TypeScript 剥离类型后加载；
 * 3. 把无法在 Node 里解析的裸模块（`@ohos/hypium`、`ngf_framework`）
 *    映射到本地替身，让同一份测试文件既能在真机 hypium 下跑、
 *    也能在本机跑。
 *
 * ## 边界（必须说清楚，否则会误用它）
 *
 * 它**不能**替代真机/CI 构建验证：能跑的只有不含装饰器
 * （`@Component`/`@Entry`）且不 import ArkUI 的纯逻辑文件。
 * 带装饰器的页面文件会加载失败——这是预期的，那些文件本来就只能靠 hvigor 编译。
 *
 * 它的价值：把「算法与边界」这类最容易出错、又最不需要设备的部分
 * 在本机就跑穿，而不是等 CI 或真机才发现。
 */

import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));

/** 候选扩展名，按 ArkTS 工程里的实际存在形式排列 */
const CANDIDATE_EXTENSIONS = ['.ets', '.ts', '.mts', '.js'];

/** 参与类型剥离的扩展名 */
const STRIPPED_EXTENSIONS = ['.ets', '.mts'];

/** 裸模块 → 本地替身 */
const VIRTUAL_MODULES = new Map([
  ['@ohos/hypium', join(HERE, 'hypium-shim.mjs')],
  ['ngf_framework', join(HERE, 'ngf-stub.mjs')]
]);

registerHooks({
  resolve(specifier, context, nextResolve) {
    const replacement = VIRTUAL_MODULES.get(specifier);
    if (replacement !== undefined) {
      return { url: pathToFileURL(replacement).href, shortCircuit: true };
    }

    if (specifier.startsWith('.') || specifier.startsWith('/') || specifier.startsWith('file:')) {
      const hasExtension = /\.(ets|ts|mts|js|mjs|cjs|json)$/.test(specifier);
      if (!hasExtension) {
        for (const extension of CANDIDATE_EXTENSIONS) {
          try {
            return nextResolve(specifier + extension, context);
          } catch (error) {
            // 该扩展名不存在，试下一个
          }
        }
      }
    }
    return nextResolve(specifier, context);
  },

  load(url, context, nextLoad) {
    const filePath = url.startsWith('file:') ? fileURLToPath(url) : '';
    if (filePath.length > 0) {
      for (const extension of STRIPPED_EXTENSIONS) {
        if (filePath.endsWith(extension)) {
          const source = readFileSync(filePath, 'utf8');
          // 必须用 'transform' 而不是 'strip'：本项目大量使用 enum
          // （NGFToolCategory / NGFToolLayer 等），而 strip 模式会直接报
          // "TypeScript enum is not supported in strip-only mode"。
          // transform 会把 enum 编译成等价的运行时代码，语义与 hvigor 编译结果一致。
          const transformed = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: url });
          return { format: 'module-typescript', source: transformed, shortCircuit: true };
        }
      }
    }
    return nextLoad(url, context);
  }
});
