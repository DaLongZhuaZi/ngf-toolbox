/**

 * 接线一致性检查：**元数据清单 ↔ 页面注册表 ↔ 目录结构 ↔ 单测**。
 *
 * ## 它防的是什么
 *
 * 工具箱的「加一件工具」要同时改四处：
 * 1. `tools/<toolId>/` 目录；
 * 2. `tools/ToolsCatalog.ets` 的元数据登记；
 * 3. `ui/ToolPageRegistry.ets` 的页面登记；
 * 4. `entry/src/test/<Name>Test.test.ets` 单测。
 *
 * 漏改任何一处都**不会报错**，而是静默降级：
 * - 漏 2 → 首页根本没有这件工具；
 * - 漏 3 → 首页有入口，但点进去是「建设中」（明明已经实现了）；
 * - 漏 4 → 测试文件在仓库里，但真机上从不执行。
 *
 * 这类「静默不一致」正是最该被自动化抓住的。本脚本做静态根因比对，
 * 不需要编译、不需要设备。
 *
 * ## 元数据那一侧是「问代码」而不是「抠源码」
 *
 * 工具清单**直接 import `builtinTools()` 拿**（那是启动时真正用的那份清单），
 * 页面注册表与目录结构仍是静态扫描（页面注册表 import 了 ArkUI，加载不了）。
 * 这个分工是踩坑之后定的：早先元数据也靠正则找 `registry.register(X.y())`，
 * 结果一次「把 16 行 register 收敛成遍历数组」的重构就让 32 个目录全被判成未登记。
 * 判据不能建立在「容易被重构改掉的写法」之上。
 *
 * 用法（**必须带类型剥离加载器**，否则导入不了 .ets）：
 *   node --import ./tools/verify/register.mjs tools/verify/check-wiring.mjs
 */

import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..');
const ETS = join(REPO_ROOT, 'entry', 'src', 'main', 'ets');
const TEST_DIR = join(REPO_ROOT, 'entry', 'src', 'test');


const problems = [];

// ── 1. 目录结构：每件工具一个目录 ──
const toolDirRoot = join(ETS, 'tools');
const toolDirs = readdirSync(toolDirRoot)
  .filter((name) => {
    try {
      return readdirSync(join(toolDirRoot, name)).length > 0;
    } catch (error) {
      return false;
    }
  });

// ── 2. 元数据清单里登记的 id ──
//
// 这里**直接问代码**，而不是从源码里正则抠。
//
// 起因是一次真实回归：把 registerAllTools 里 16 行 `registry.register(ImplementedTools.x())`
// 收敛成「遍历 builtinTools() 数组」之后，基于「找 register(...) 调用」的旧抠法
// 一条也匹配不到，于是 32 个目录全被判成「未登记」——**检查器自己误报**。
// 教训是：用「重构容易改动的形状」当判据，检查器就会跟着重构一起坏。
// 而 builtinTools() 是启动时真正使用的那份清单，问它不会失真。
//
// 代价是必须带类型剥离加载器运行（见文件尾的用法提示）。
let implementedIds = [];
let plannedIds = [];
try {
  const catalog = await import('../../entry/src/main/ets/tools/ToolsCatalog.ets');
  implementedIds = catalog.builtinTools().map((meta) => meta.id);
  // 「规划中」的工具会以 registerPlaceholder 登记，清单里目前没有；
  // 由注册表侧的 isPlaceholder 决定，这里留空即可（首页显示「建设中」由它兜底）。
} catch (error) {
  console.error('无法加载工具清单（需要用类型剥离加载器运行本脚本）：');
  console.error('  node --import ./tools/verify/register.mjs tools/verify/check-wiring.mjs');
  console.error('底层错误：' + (error && error.message ? error.message : String(error)));
  process.exit(2);
}
const catalogSource = readFileSync(join(toolDirRoot, 'ToolsCatalog.ets'), 'utf8');

// ── 3. 页面注册表里登记的 id ──
const registrySource = readFileSync(join(ETS, 'ui', 'ToolPageRegistry.ets'), 'utf8');
// 先把块注释去掉再匹配：文件头部的文档注释里有
// `pages.set('<toolId>', buildXxxPage)` 这样的**示例**，不去掉会被当成真实登记
// （第一版就是这么误报出一条"ghost"的）。
// 块注释与**行注释**都要剥掉。只剥块注释时，被 `//` 注释掉的一行
// `// pages.set('x', ...)` 仍会被匹配成「已登记」——而「临时注释掉一行登记」
// 恰好是这个检查器最该抓住的场景（首页会变成「建设中」，却报 0 问题）。
const registryCode = registrySource.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
const pageIds = new Set();
{
  const pattern = /pages\.set\('([^']+)'/g;
  let match;
  while ((match = pattern.exec(registryCode)) !== null) {
    pageIds.add(match[1]);
  }
}

// ── 4. 交叉核对 ──
for (const id of implementedIds) {
  if (!pageIds.has(id)) {
    problems.push('元数据标记「已实现」但页面注册表没有登记：' + id
      + ' → 首页有入口，点进去却是「建设中」');
  }
  if (toolDirs.indexOf(id) < 0) {
    problems.push('元数据登记了 ' + id + '，但没有对应的 tools/' + id + '/ 目录');
  }
}
for (const id of pageIds) {
  if (implementedIds.indexOf(id) < 0) {
    problems.push('页面注册表登记了 ' + id + '，但元数据里没有标记为已实现');
  }
}
for (const id of plannedIds) {
  if (pageIds.has(id)) {
    problems.push('元数据标记为「规划中」但页面已经登记：' + id + ' → 首页会显示「建设中」却其实能用');
  }
}
for (const dir of toolDirs) {
  if (implementedIds.indexOf(dir) < 0 && plannedIds.indexOf(dir) < 0) {
    problems.push('存在 tools/' + dir + '/ 目录，但元数据清单里没有登记');
  }
}

// ── 5. 每件已实现工具都要有页面文件与单测文件 ──
function kebabToPascal(id) {
  let out = '';
  let upperNext = true;
  for (let i = 0; i < id.length; i += 1) {
    const ch = id.charAt(i);
    if (ch === '-') {
      upperNext = true;
      continue;
    }
    out += upperNext ? ch.toUpperCase() : ch;
    upperNext = false;
  }
  return out;
}

const testFiles = readdirSync(TEST_DIR);
for (const id of implementedIds) {
  const dir = join(toolDirRoot, id);
  if (!existsSync(dir)) {
    continue;
  }
  const files = readdirSync(dir);
  const pageFiles = files.filter((name) => name.endsWith('Page.ets'));
  if (pageFiles.length === 0) {
    problems.push('已实现工具缺少页面文件：tools/' + id + '/ *Page.ets');
  }
  // 单测文件不一定与 id 同名（ToolLogic ↔ XxxLogic），所以退一步：
  // 检查该工具的页面/逻辑是否被某个测试文件 import。
  const testSource = testFiles
    .filter((name) => name.endsWith('.test.ets'))
    .map((name) => readFileSync(join(TEST_DIR, name), 'utf8'))
    .join('\n');
  if (testSource.indexOf('/tools/' + id + '/') < 0) {
    problems.push('已实现工具没有任何单测 import 它的纯逻辑：tools/' + id
      + '/ → 违反 PR-005（纯逻辑单测覆盖是合入门禁）');
  }
}

// ── 5.5 页面构建器名与导入路径必须能对上真实导出 ──
// check-wiring 原先只看 id，导致 `pages.set('digest', buildDigestPageTypo)`
// 或 import 路径写错都能全过——而这只有 CI 编译能抓。
// 这里做双向比对：注册表 import 进来的名字，必须真的由目标页面文件导出。
{
  const pageDirRoot = join(ETS, 'tools');
  // 收集「import { buildXxx } from '<path>'」这一对
  const importPattern = /import\s*\{\s*([A-Za-z_$][\w$]*)\s*\}\s*from\s*'([^']+)'/g;
  const importedBuilders = new Map();
  let importMatch;
  while ((importMatch = importPattern.exec(registryCode)) !== null) {
    importedBuilders.set(importMatch[1], importMatch[2]);
  }
  // 收集 pages.set 用到的构建器名
  //
  // ⚠️ 这里的 `(?:wrapBuilder\(\s*)?` 是必需的，别删。
  // 注册表现在写的是 `pages.set('id', wrapBuilder(buildXPage))`；
  // 而本检查最初是按 `pages.set('id', buildXPage)`（裸标识符）写的正则，
  // 引入 wrapBuilder 之后**它再也匹配不上任何一行**——usedBuilders 恒为空集，
  // 整个 §5.5 变成死代码，却一直显示「0 问题」。
  // 实测：把某个构建器改成不存在的 buildGhostPage，检查照样报 0 问题。
  const usedBuilders = new Set();
  const setPattern = /pages\.set\('[^']+'\s*,\s*(?:wrapBuilder\(\s*)?([A-Za-z_$][\w$]*)/g;
  let setMatch;
  while ((setMatch = setPattern.exec(registryCode)) !== null) {
    usedBuilders.add(setMatch[1]);
  }
  for (const builderName of usedBuilders) {
    const importPath = importedBuilders.get(builderName);
    if (importPath === undefined) {
      problems.push('页面注册表使用了 ' + builderName + '()，但没有 import 它');
      continue;
    }
    if (importPath.indexOf('../tools/') !== 0) {
      problems.push(builderName + ' 的 import 路径不像工具页面：' + importPath);
      continue;
    }
    // 解析到真实文件
    const idFromPath = importPath.replace('../tools/', '').split('/')[0];
    let resolved = '';
    const dirPath = join(pageDirRoot, idFromPath);
    for (const candidate of readdirSync(dirPath)) {
      if (candidate.endsWith('.ets') && importPath.endsWith('/' + candidate.replace(/\.ets$/, ''))) {
        resolved = join(dirPath, candidate);
      }
    }
    if (resolved.length === 0) {
      problems.push(builderName + ' 的 import 路径解析不到真实文件：' + importPath);
      continue;
    }
    const pageSource = readFileSync(resolved, 'utf8');
    const exportPattern = new RegExp('export\\s+function\\s+' + builderName + '\\s*\\(');
    if (!exportPattern.test(pageSource)) {
      problems.push(resolved.replace(REPO_ROOT + '\\', '') + ' 没有导出 ' + builderName
        + '（注册表引用的构建器名与页面实际导出的名字不一致）');
      continue;
    }
    // 查的是**这个导出函数自己**带不带 @Builder，而不是「文件里出现过 @Builder」。
    //
    // 原来的写法是 pageSource.indexOf('@Builder') < 0 —— 工具页里必然还有别的
    // @Builder 方法（buildInputSection 之类），所以那个条件**永远为假**，
    // 这条检查从未生效过。实测：删掉导出函数的 @Builder，检查照样报 0 问题。
    const decoratedPattern = new RegExp('@Builder\\s+export\\s+function\\s+' + builderName + '\\s*\\(');
    if (!decoratedPattern.test(pageSource)) {
      problems.push(builderName + ' 没有 @Builder 装饰器：' + importPath
        + ' → 它不会被当成 UI 构建器展开，注册表里 wrapBuilder 包出来的东西渲染不出内容');
    }
  }
}

// ── 5.8 路由表与 @Entry 页面必须双向一致 ──
// 这道检查是补一个真实的空档：about 页新建时，如果忘了往 main_pages.json 里加一条，
// 它在真机上会直接打开失败（而且是运行期才报），三道原有检查全都看不到。
// 反向同理：main_pages.json 里写了一个不存在的页面，构建/运行期才炸。
{
  const pagesProfile = join(REPO_ROOT, 'entry', 'src', 'main', 'resources', 'base', 'profile', 'main_pages.json');
  if (existsSync(pagesProfile)) {
    const profileText = readFileSync(pagesProfile, 'utf8');
    const declared = new Set();
    const declaredPattern = /"([^"]+\/[^"]+)"/g;
    let declaredMatch;
    while ((declaredMatch = declaredPattern.exec(profileText)) !== null) {
      declared.add(declaredMatch[1]);
    }

    // 扫描全部 @Entry 页面
    const entryPages = new Set();
    const scanEntry = (dir) => {
      for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const full = join(dir, entry.name);
        if (entry.isDirectory()) {
          scanEntry(full);
          continue;
        }
        if (!entry.name.endsWith('.ets')) {
          continue;
        }
        const source = readFileSync(full, 'utf8');
        if (!/@Entry\b/.test(source)) {
          continue;
        }
        // 由文件位置推出路由名：.../ets/pages/xxx.ets -> pages/xxx
        //
        // 必须先把反斜杠统一成正斜杠再切分。第一版直接找 'ets/' 或 'ets\\'，
        // 在 Windows 上会命中路径里的 "…\\ets\\pages\\Index.ets" 中
        // 「ets」紧邻的那一段，切出 "Index.ets" 而不是 "pages/Index.ets"，
        // 于是所有页面都被报成「声明了不存在的页面」。
        // 就地归一：用 charCode 判断，避免正则转义在多层引用里失真
        let rel = '';
        for (let index = 0; index < full.length; index += 1) {
          rel += full.charCodeAt(index) === 92 ? '/' : full.charAt(index);
        }
        const etsMarker = '/ets/';
        const at = rel.indexOf(etsMarker);
        if (at >= 0) {
          const afterEts = rel.substring(at + etsMarker.length).replace(/\.ets$/, '');
          if (afterEts.indexOf('pages/') === 0) {
            entryPages.add(afterEts);
          }
        }
      }
    };
    scanEntry(join(ETS, 'pages'));

    entryPages.forEach((page) => {
      if (!declared.has(page)) {
        problems.push('@Entry 页面没有登记进 main_pages.json：' + page
          + ' → 真机上打开它会失败（运行期才报，编译不报）');
      }
    });
    declared.forEach((page) => {
      if (!entryPages.has(page)) {
        problems.push('main_pages.json 声明了不存在的页面：' + page);
      }
    });
  }
}

// ── 5.9 core/ 的纯逻辑模块必须被测试覆盖（直接或间接）──
//
// 为什么单独补这一节：上面的 §5 只检查 tools/<id>/ 目录，
// **core/ 里的纯逻辑漏在检查之外**。实测 `core/ToolRoutes.ets`
// （导航参数的编解码）一直没有测试，是人工翻查才发现的——
// 而它的旧注释里还写着「抽成纯函数是为了能单测」。
//
// 用**可达性**而不是「文件名出现在测试里」：纯逻辑之间会互相引用
// （`DigestAlgorithms` 用 `HashCore` 的算法），测试覆盖了上游就等于覆盖了下游。
// 只按文件名匹配会把这类间接覆盖误报成「没有测试」。

/**
 * 允许没有测试的纯逻辑模块，每条必须能说出理由。
 *
 * 加进来之前先问：它真的测不了吗？还是只是懒得写？
 */
const TEST_EXEMPT = new Map([
  ['core/ToolNavigator.ets',
    '它做的事是调框架门面发起跳转，import 了 ngfNavigationShellFacade；'
    + '在 Node 里跑不了（门面要读 AppStorage 里的导航栈）。契约与编解码已抽到 '
    + 'core/ToolRoutes.ets 并有覆盖。'],
]);

function isPureLogicModule(rel) {
  if (!rel.endsWith('.ets')) return false;
  if (/(Page|Messages)\.ets$/.test(rel)) return false;   // UI 层：装饰器 + $r()，Node 跑不了
  if (TEST_EXEMPT.has(rel)) return false;
  return rel.startsWith('core/') || /^tools\/[^/]+\//.test(rel);
}

/** 抽出某个 .ets 里的相对 import 目标（解析成相对 entry/src/main/ets 的路径） */
function importsOf(absPath, relDir) {
  const src = readFileSync(absPath, 'utf8');
  const out = [];
  const re = /from\s+'(\.\.?\/[^']+)'/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const target = m[1];
    // 只关心本项目内的 .ets；跨到 ngf_framework 或 kit 的忽略
    if (target.indexOf('ngf_framework') >= 0) continue;
    const resolved = join(relDir, target).replace(/\\/g, '/');
    out.push(resolved.endsWith('.ets') ? resolved : resolved + '.ets');
  }
  return out;
}

// 建图：节点是相对 ETS 的路径，边是 import
const graph = new Map();
function addEdges(rel) {
  const abs = join(ETS, rel);
  if (!existsSync(abs)) return;
  const relDir = rel.slice(0, rel.lastIndexOf('/'));
  graph.set(rel, importsOf(abs, relDir));
}

const allEts = [];
(function walkEts(dir, prefix) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      walkEts(join(dir, e.name), prefix + e.name + '/');
    } else if (e.name.endsWith('.ets')) {
      allEts.push(prefix + e.name);
    }
  }
})(ETS, '');

for (const rel of allEts) addEdges(rel);
for (const name of readdirSync(TEST_DIR)) {
  if (!name.endsWith('.test.ets') || name === 'List.test.ets') continue;
  const abs = join(TEST_DIR, name);
  const src = readFileSync(abs, 'utf8');
  const re = /from\s+'\.\.\/main\/ets\/([^']+)'/g;
  const seeds = [];
  let m;
  while ((m = re.exec(src)) !== null) {
    seeds.push(m[1].endsWith('.ets') ? m[1] : m[1] + '.ets');
  }
  graph.set('__test__/' + name, seeds);
}

// 从测试出发做可达性
const reached = new Set();
const queue = [...graph.keys()].filter((k) => k.startsWith('__test__/'));
while (queue.length > 0) {
  const cur = queue.pop();
  for (const next of (graph.get(cur) || [])) {
    // 归一化：去掉 ./ 与 ../ 造成的偏差，统一成相对 ETS 的路径
    const parts = next.split('/');
    const stack = [];
    for (const seg of parts) {
      if (seg === '.' || seg === '') continue;
      else if (seg === '..') stack.pop();
      else stack.push(seg);
    }
    const norm = stack.join('/');
    if (reached.has(norm)) continue;
    reached.add(norm);
    if (graph.has(norm)) queue.push(norm);
  }
}

const untested = allEts.filter((rel) => isPureLogicModule(rel) && !reached.has(rel));
for (const rel of untested) {
  problems.push('纯逻辑模块没有任何（直接或间接的）单测覆盖：' + rel
    + ' → 本仓纪律是「纯逻辑必须有单测」（AGENTS.md §3）。'
    + '确实测不了的，加进本脚本的 TEST_EXEMPT 并写明理由。');
}

// ── 6. hypium 总入口是否覆盖了全部测试文件 ──
const listEntry = readFileSync(join(TEST_DIR, 'List.test.ets'), 'utf8');
for (const name of testFiles.filter((n) => n.endsWith('.test.ets') && n !== 'List.test.ets')) {
  const moduleName = name.replace(/\.test\.ets$/, '.test');
  if (listEntry.indexOf("'./" + moduleName + "'") < 0) {
    problems.push('测试文件没有登记进 hypium 总入口：' + name
      + ' → 真机上从不执行（跑 node tools/verify/gen-test-entry.mjs 重新生成）');
  }
}

console.log('已实现工具 ' + implementedIds.length + ' 件，规划中 ' + plannedIds.length + ' 件，'
  + '页面登记 ' + pageIds.size + ' 件，工具目录 ' + toolDirs.length + ' 个，测试文件 ' + testFiles.length + ' 个');
console.log('');
// ── 5.10 每个工具模块必须有 README ──
//
// docs/产品定义.md §五「样板仓要求」：**仓库结构即教学**——
// 每个工具一个独立模块，模块 README 一段话说明它用了哪层 NGF、入口在哪。
// 实测这条一度是 0/16：16 个模块一个 README 都没有，而门禁完全看不见。
//
// 这条检查零误报：工具目录里有 README 是硬要求，不存在「合理缺失」。
{
  const toolsRoot = join(ETS, 'tools');
  for (const entry of readdirSync(toolsRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) {
      continue;
    }
    const readme = join(toolsRoot, entry.name, 'README.md');
    if (!existsSync(readme)) {
      problems.push('工具模块 ' + entry.name + '/ 没有 README.md —— '
        + 'docs/产品定义.md §五 要求「每个工具一个独立模块，模块 README 一段话说明它用了哪层 NGF、入口在哪」。'
        + '本仓是官方样板，仓库结构本身就是教学材料。');
    }
  }
}


// ── 5.11 纯逻辑文件不得把「类型别名」与「运行时值」写进同一条 import（PR-010） ──
//
// PR-010 的理由：ArkTS 剥离类型时可能**丢掉整条 import 语句**，
// 连带丢掉同一条里的枚举值或常量 —— 表现是运行时 undefined，**编译不报错**。
//
// 本仓此前**没有任何门禁守这条**（实测：全部 14 条 active 规则里，
// 只有 PR-005/PR-013/PR-014 在脚本里被按号引用，PR-010 一次都没出现过）。
//
// 判据是精确的：解析 import 的目标模块，看它把每个名字导出成 type/interface（类型）
// 还是 enum/class/const/function/let（值）。一条语句里两者都有就是违反。
{
  const kindOf = new Map();
  const collect = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        collect(full);
      } else if (entry.name.endsWith('.ets')) {
        const text = readFileSync(full, 'utf8');
        for (const m of text.matchAll(/export\s+type\s+(\w+)/g)) {
          kindOf.set(full + '|' + m[1], 'type');
        }
        for (const m of text.matchAll(/export\s+interface\s+(\w+)/g)) {
          kindOf.set(full + '|' + m[1], 'type');
        }
        for (const m of text.matchAll(/export\s+(?:enum|class|const|function|let)\s+(\w+)/g)) {
          kindOf.set(full + '|' + m[1], 'value');
        }
      }
    }
  };
  collect(ETS);

  const pureFiles = [];
  const collectPure = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        collectPure(full);
      } else if (entry.name.endsWith('.ets')
        && !entry.name.endsWith('Page.ets') && !entry.name.endsWith('Messages.ets')) {
        pureFiles.push(full);
      }
    }
  };
  collectPure(join(ETS, 'core'));
  collectPure(join(ETS, 'tools'));

  for (const file of pureFiles) {
    const src = readFileSync(file, 'utf8').split(/\r?\n/);
    for (let i = 0; i < src.length; i++) {
      const m = src[i].match(/^import\s*\{([^}]*)\}\s*from\s*'([^']+)'/);
      if (m === null || m[2].charAt(0) !== '.') {
        continue;
      }
      const depDir = dirname(file);
      const rawDep = join(depDir, m[2]);
      const depFile = rawDep.endsWith('.ets') ? rawDep : rawDep + '.ets';
      const typeNames = [];
      const valueNames = [];
      for (const raw of m[1].split(',')) {
        const name = raw.trim();
        if (name.length === 0) {
          continue;
        }
        const kind = kindOf.get(depFile + '|' + name);
        if (kind === 'type') {
          typeNames.push(name);
        } else if (kind === 'value') {
          valueNames.push(name);
        }
      }
      if (typeNames.length > 0 && valueNames.length > 0) {
        const rel = relative(REPO_ROOT, file).split('\\').join('/');
        problems.push(rel + ':' + (i + 1) + ' 把类型与运行时值写进了同一条 import'
          + '（类型：' + typeNames.join(', ') + '；值：' + valueNames.join(', ') + '）—— '
          + '违反 PR-010。ArkTS 剥离类型时可能丢掉整条语句，连带丢掉那些值，'
          + '表现为运行时 undefined 且编译不报错。请把类型别名单独拆成一条 import。');
      }
    }
  }
}


if (problems.length === 0) {
  console.log('接线一致性检查：0 问题');
} else {
  for (const problem of problems) {
    console.log('[问题] ' + problem);
  }
  console.log('');
  console.log('接线一致性检查：' + problems.length + ' 个问题');
}
process.exitCode = problems.length === 0 ? 0 : 1;