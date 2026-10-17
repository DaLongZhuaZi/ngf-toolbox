/**
 * 本地纯逻辑验证器。
 *
 * ## 它做什么
 *
 * 扫描 entry/src/test 下的单测文件，用本地 hypium 替身把它们**真的跑一遍**，
 * 然后报告每个用例的通过/失败。跑的是工程里那份**同一份**测试代码，
 * 不是另写一套。
 *
 * ## 为什么需要它（而不是等 CI）
 *
 * 本机没有 hvigor/DevEco 工具链，构建走 CI。若完全依赖 CI，
 * 一次「算法写错」要等到推送后才发现。而纯逻辑部分（时间戳换算、
 * 进制转换、cron 解析……）恰恰是最容易错、又最不需要设备的部分。
 * 这个脚本把这一层的反馈周期从「几分钟 + 一次推送」压到「一秒」。
 *
 * ## 边界
 *
 * - 只覆盖不依赖 ArkUI / 设备能力的纯逻辑；
 * - **不能**替代真机回归与 CI 构建（装饰器、资源、权限都不在这里验证）。
 *
 * 用法：node --import ./tools/verify/register.mjs tools/verify/run.mjs
 */

import { readdirSync, existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..');
const TEST_DIR = join(REPO_ROOT, 'entry', 'src', 'test');
const CORE_DIR = join(REPO_ROOT, 'entry', 'src', 'main', 'ets', 'core');
const TOOLS_DIR = join(REPO_ROOT, 'entry', 'src', 'main', 'ets', 'tools');

/** 只跑这些测试文件（避免把 scaffolding 与 ohosTest 类的东西混进来） */
function listTestFiles() {
  const files = readdirSync(TEST_DIR)
    .filter((name) => name.endsWith('.test.ets'))
    // List.test.ets 是 hypium 的总入口（把所有套件再调一遍）。若把它也当成
    // 一个套件跑，每个用例都会被统计两次，报告数字会翻倍——这正是最初的表现。
    .filter((name) => name !== 'List.test.ets');
  files.sort();
  return files;
}

/**
 * 允许 import ArkUI 的文件（不参与本地纯逻辑加载检查）。
 *
 * 这些文件承担的是「调用框架/系统 API」的职责，不是纯逻辑，
 * 本来就只能由 hvigor 编译。列在这里是为了让检查结果保持
 * 「0 失败 = 纯逻辑层真的干净」，而不是被这些预期内的失败淹没。
 */
const ARKUI_DEPENDENT_FILES = new Set([
  'core/ToolNavigator.ets'
]);

/**
 * 工具目录里的 **UI 层**文件命名约定。
 *
 * - \`XxxPage.ets\`：页面组件（装饰器 + ArkUI 属性，本来就只有 hvigor 能编译）
 * - \`XxxMessages.ets\`：失败码 → 文案的映射（用 \`$r()\`，因此同属 UI 层）
 *
 * 做双语时新增了第二类：纯逻辑只返回错误码，翻译必须发生在能 import ArkUI 的地方。
 * 这个约定让「哪些文件算纯逻辑」有明确答案，而不是靠人工记忆。
 */
const UI_LAYER_FILE_PATTERN = /(Page|Messages)\.ets$/;

/**
 * ArkUI / 设备能力的痕迹。
 *
 * \`$r(\` 是最关键的一条：它只在函数体里出现，**模块加载不会报错**，
 * 所以「能加载」根本证明不了「不依赖 ArkUI」——早先 --logic 只做加载冒烟，
 * 一个大量调用 \`$r()\` 的文件照样被算成纯逻辑，检查结果是假的绿灯。
 * 现在改成静态断言：纯逻辑文件里出现这些痕迹就判失败。
 */
/**
 * **致命**痕迹：出现即说明这个文件离不开 ArkUI，本地根本跑不了它。
 *
 * 这两类是最危险的，因为它们**不影响模块加载**——\`$r()\` 与装饰器都在函数体/定义处，
 * import 一个这样的模块不会报错，于是「能加载」会给出假的绿灯。
 */
const ARKUI_FATAL_MARKERS = [
  { pattern: /\$r\s*\(/, label: '\$r()（ArkUI 资源引用）' },
  { pattern: /@(Component|Entry|Builder|State|Prop|Link|Watch|Provide|Consume)\b/, label: 'ArkUI 装饰器' }
];

/**
 * **提示性**痕迹：依赖系统能力或框架门面，但本机验证器**有替身**（见 register.mjs 的
 * ngf-stub / 模块映射），因此它们的单测是真的能跑、能给出有意义结论的。
 *
 * 例如 \`core/ToolStateStore.ets\`：它是持久化适配层，本来就要用框架的 Preferences 门面，
 * 而替身让它在本机可测——这没有「假绿灯」的问题，所以只报告、不判失败。
 */
const FRAMEWORK_DEPENDENT_MARKERS = [
  { pattern: /from\s+['"]@kit\./, label: "@kit.* 系统能力" },
  { pattern: /from\s+['"]@ohos\./, label: "@ohos.* 系统能力" },
  { pattern: /from\s+['"]ngf_framework['"]/, label: 'ngf_framework 框架门面' }
];

/** 纯逻辑模块（供 --logic 模式做「可加载性 + 洁净度」检查） */
function listPureLogicModules() {
  const result = [];
  if (existsSync(CORE_DIR)) {
    for (const name of readdirSync(CORE_DIR)) {
      if (name.endsWith('.ets') && !UI_LAYER_FILE_PATTERN.test(name)) {
        result.push(join(CORE_DIR, name));
      }
    }
  }
  if (existsSync(TOOLS_DIR)) {
    const walk = (dir) => {
      for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const full = join(dir, entry.name);
        if (entry.isDirectory()) {
          walk(full);
        } else if (entry.name.endsWith('.ets') && !UI_LAYER_FILE_PATTERN.test(entry.name)) {
          result.push(full);
        }
      }
    };
    walk(TOOLS_DIR);
  }
  return result;
}

/**
 * 检查一个「纯逻辑」文件是否真的干净。
 *
 * @returns 违规说明数组（空数组 = 干净）
 */
function stripComments(source) {
  // 先剥注释：文档注释里会举例写 \`$r('app.string.x')\`，
  // 那是说明而不是用法（check-resources 也踩过同一个坑）。
  return source
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/\/\/[^\n]*/g, ' ');
}

/** 致命违规：出现即不是纯逻辑，且会被误算成本机可验证 */
function findPurityViolations(filePath) {
  const stripped = stripComments(readFileSync(filePath, 'utf8'));
  const violations = [];
  for (const marker of ARKUI_FATAL_MARKERS) {
    if (marker.pattern.test(stripped)) {
      violations.push(marker.label);
    }
  }
  return violations;
}

/** 提示性依赖：如实报出来，让「本机可验证」这句话有据可查 */
function findFrameworkDependencies(filePath) {
  const stripped = stripComments(readFileSync(filePath, 'utf8'));
  const found = [];
  for (const marker of FRAMEWORK_DEPENDENT_MARKERS) {
    if (marker.pattern.test(stripped)) {
      found.push(marker.label);
    }
  }
  return found;
}

async function runTests() {
  const { hypiumCases } = await import('./hypium-shim.mjs');
  const files = listTestFiles();
  let passed = 0;
  const failures = [];
  const suites = [];

  for (const file of files) {
    const before = hypiumCases.length;
    const url = pathToFileURL(join(TEST_DIR, file)).href;
    try {
      const module = await import(url);
      const register = module.default;
      if (typeof register !== 'function') {
        failures.push({ file, name: '(模块)', error: '没有 default export 函数（hypium 要求导出 testsuite）' });
        continue;
      }
      register();
    } catch (error) {
      failures.push({ file, name: '(加载)', error: error && error.message ? error.message : String(error) });
      continue;
    }

    const added = hypiumCases.slice(before);
    let suitePassed = 0;
    for (const item of added) {
      try {
        item.body();
        passed += 1;
        suitePassed += 1;
      } catch (error) {
        failures.push({ file, name: item.name, error: error && error.message ? error.message : String(error) });
      }
    }
    suites.push({ file, total: added.length, passed: suitePassed });
  }

  return { passed, failures, suites, files };
}

/**
 * 是否为「预期需要 ArkUI」的文件。
 *
 * 用「后缀匹配」而不是精确相等：不同平台上路径分隔符与是否带前导分隔符
 * 都不一致，精确匹配会静默失效（检查结果里冒出一个预期内的失败，
 * 久而久之就没人看了——这正是这类检查最常见的死法）。
 */
function isArkUiDependent(relative) {
  const normalized = normalizeSlashes(relative);
  for (const entry of ARKUI_DEPENDENT_FILES) {
    if (normalized.endsWith(entry)) {
      return true;
    }
  }
  return false;
}

/** 把路径里的反斜杠统一成正斜杠（用 charCode 判断，避免正则转义在多层引用里失真） */
function normalizeSlashes(value) {
  let result = '';
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    // 92 = '\'，47 = '/'
    result += code === 92 ? '/' : value.charAt(index);
  }
  return result.replace(/^\/+/, '');
}

async function checkLoadable() {
  const modules = listPureLogicModules();
  const results = [];
  for (const modulePath of modules) {
    const relative = modulePath.replace(REPO_ROOT + '\\', '').replace(REPO_ROOT + '/', '');
    if (isArkUiDependent(relative)) {
      continue;
    }
    // 先断言洁净度，再试加载。
    // 顺序很重要：只做加载冒烟的话，一个大量调用 $r() 的文件**照样能加载成功**
    // （$r 只在函数体里出现），于是检查结果是一盏假的绿灯。
    const violations = findPurityViolations(modulePath);
    if (violations.length > 0) {
      results.push({
        relative,
        ok: false,
        error: '不是纯逻辑（应改名为 *Page.ets / *Messages.ets 或移出本目录）：'
          + violations.join('、')
      });
      continue;
    }
    try {
      await import(pathToFileURL(modulePath).href);
      results.push({
        relative,
        ok: true,
        error: '',
        frameworkDeps: findFrameworkDependencies(modulePath)
      });
    } catch (error) {
      results.push({ relative, ok: false, error: error && error.message ? error.message : String(error) });
    }
  }
  return results;
}

const mode = process.argv.includes('--logic') ? 'logic' : 'tests';

if (mode === 'logic') {
  const results = await checkLoadable();
  const ok = results.filter((r) => r.ok);
  const bad = results.filter((r) => !r.ok);
  console.log('纯逻辑模块加载检查：' + ok.length + ' 个可加载，' + bad.length + ' 个失败');
  for (const item of bad) {
    console.log('  [失败] ' + item.relative);
    console.log('         ' + item.error);
  }
  // 如实报出「虽然干净、但依赖被替身的框架/系统能力」的模块数：
  // 「本机可验证」这句话应该能对着这行数字被核对，而不是一句笼统的承诺。
  const withDeps = ok.filter((r) => r.frameworkDeps && r.frameworkDeps.length > 0);
  if (withDeps.length > 0) {
    console.log('');
    console.log('其中 ' + withDeps.length + ' 个模块依赖框架/系统能力，本机由替身承接'
      + '（因此它们的单测结论仍然有效）：');
    for (const item of withDeps) {
      console.log('  · ' + item.relative + ' —— ' + item.frameworkDeps.join('、'));
    }
  }
  process.exitCode = bad.length === 0 ? 0 : 1;
} else {
  const { passed, failures, suites } = await runTests();
  console.log('=== 本地纯逻辑测试 ===');
  for (const suite of suites) {
    const mark = suite.passed === suite.total ? 'OK  ' : 'FAIL';
    console.log('  [' + mark + '] ' + suite.file + '  ' + suite.passed + '/' + suite.total);
  }
  console.log('');
  console.log('通过 ' + passed + ' 个用例，失败 ' + failures.length + ' 个');
  if (failures.length > 0) {
    console.log('');
    for (const failure of failures) {
      console.log('  ✗ ' + failure.file + ' :: ' + failure.name);
      console.log('      ' + failure.error);
    }
  }
  process.exitCode = failures.length === 0 ? 0 : 1;
}
