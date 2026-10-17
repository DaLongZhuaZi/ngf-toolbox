/**
 * 设备端测试总入口（ohosTest 模块）。
 *
 * ## 为什么只是一行转发
 *
 * 638 个真实单测住在 `entry/src/test/`，因为它们要能被 `tools/verify/run.mjs`
 * 在**本机 Node 上**直接跑（CI 不跑单测，本机不跑就等于没人验）。
 *
 * DevEco 的默认布局是把测试放在 ohosTest 里，两者只能选一个位置。
 * 这里不去复制一份测试清单——**直接转发**，
 * 于是「设备上跑的」和「本机跑的」永远是同一批用例，不可能漂移。
 *
 * 用法（真机）：
 *   hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap
 *   hdc install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
 *   hdc shell aa test -b com.dlzz.ngftoolbox -m entry_test -s unittest OpenHarmonyTestRunner
 */
import appTests from '../../../test/List.test';

export default function testsuite(): void {
  appTests();
}
