<#
  真编译门禁：跑一次真正的 ArkTS 编译（hvigor assembleHap）。

  ## 为什么必须单独有这一道

  本仓其余九道门禁全部在 Node 上跑，而 tools/verify/register.mjs 做的是**类型剥离**——
  它只把类型标注删掉再执行，**从不做类型检查**，也完全不认识 ArkUI 的 DSL。
  于是下面这些错误在九道门禁全绿的情况下依然存在：

  - $r() 返回 Resource 却被传给 string 形参
  - 枚举成员名写错 / 忘了 import
  - @Builder 体里写了 const / return
  - ArkTS 专有禁令：arkts-no-structural-typing、arkts-no-untyped-obj-literals、
    arkts-no-any-unknown、arkts-identifiers-as-prop-names
  - WrappedBuilder 这类「全局类型但被误当 import」的用法

  **实测踩过**：一轮开发里九道门禁全绿，真编译 75 ERROR + 107 WARN。

  ## 用法

      pwsh -NoProfile -File tools/verify/build.ps1

  退出码 0 = 编译通过且无 ERROR。会打印 ERROR / WARN 计数。

  ## 找不到 DevEco 时

  按 DEVECO_HOME 环境变量 -> 注册表 HKLM\SOFTWARE\Huawei\DevEco Studio -> 常见安装路径
  依次探测。都找不到就**明确报错并给出设置方法**，不会静默跳过——
  静默跳过正是这道门禁要防的事。
#>

$ErrorActionPreference = 'Continue'

function Find-DevEco {
  if ($env:DEVECO_HOME -and (Test-Path "$env:DEVECO_HOME\tools\hvigor\bin\hvigorw.js")) { return $env:DEVECO_HOME }
  foreach ($k in (Get-ChildItem 'HKLM:\SOFTWARE\Huawei\DevEco Studio' -ErrorAction SilentlyContinue)) {
    $v = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).'(default)'
    if ($v -and (Test-Path "$v\tools\hvigor\bin\hvigorw.js")) { return $v }
  }
  foreach ($p in @('C:\Program Files\Huawei\DevEco Studio', 'D:\DevEco Studio',
                   'F:\DevEco Studio', 'G:\DevEco Studio 26\DevEco Studio')) {
    if (Test-Path "$p\tools\hvigor\bin\hvigorw.js") { return $p }
  }
  return $null
}

$ds = Find-DevEco
if (-not $ds) {
  Write-Output '[失败] 找不到 DevEco Studio，无法做真编译。'
  Write-Output '       请设置环境变量 DEVECO_HOME 指向 DevEco 安装目录，例如：'
  Write-Output '         $env:DEVECO_HOME = "G:\DevEco Studio 26\DevEco Studio"'
  Write-Output '       这一步不能跳过：九道 Node 门禁不查类型，只有它能发现类型与 ArkTS 语法错误。'
  exit 2
}

$env:DEVECO_SDK_HOME = "$ds\sdk"
$log = Join-Path (Get-Location) 'build.log'
$nodeExe = "$ds\tools\node\node.exe"
$hvigorJs = "$ds\tools\hvigor\bin\hvigorw.js"
& $nodeExe $hvigorJs --mode module -p product=default -p buildMode=debug assembleHap --no-daemon 2>&1 |
    Tee-Object -FilePath $log | Out-Null

$text = Get-Content $log -Raw -Encoding UTF8
$m = [regex]::Match($text, 'COMPILE RESULT:(\w+)\s*\{ERROR:(\d+)\s+WARN:(\d+)\}')
if ($m.Success) {
  $errors = [int]$m.Groups[2].Value
  $warns = [int]$m.Groups[3].Value
  Write-Output ('编译结果：' + $m.Groups[1].Value + '  ERROR=' + $errors + '  WARN=' + $warns)
  if ($errors -gt 0) {
    Write-Output ''
    Write-Output '前若干条错误：'
    Select-String -Path $log -Pattern 'Error Message:' -Encoding UTF8 |
      Select-Object -First 15 | ForEach-Object { '  ' + $_.Line.Trim() }
    Write-Output ''
    Write-Output ('完整日志：' + $log)
    exit 1
  }
} elseif ($text -match 'BUILD SUCCESSFUL') {
  Write-Output '编译结果：BUILD SUCCESSFUL（未取到 COMPILE RESULT，但构建成功）'
} else {
  Write-Output '[失败] 构建没跑起来，也没取到 COMPILE RESULT。查看 build.log 末尾。'
  exit 1
}

if ($text -match 'BUILD SUCCESSFUL') {
  Write-Output '构建成功，HAP 已产出。'

  # ── 告警归属统计 ──────────────────────────────────────────
  #
  # 为什么非报不可：**成功路径原本取不到 COMPILE RESULT 标记**（那个标记只在失败时出现），
  # 于是 WARN 数在成功时完全不可见——只有手动 grep build.log 才看得到。
  # 结果是「entry 侧到底有没有告警」这个问题长期没有答案。
  #
  # 分开报 entry / ngf_framework 是刻意的：两者责任不同。
  # entry/ 的问题归本仓修；ngf_framework/ 是 vendored 副本，按 AGENTS.md §4 回来源仓。
  # ── 先判断本次到底有没有做 ArkTS 分析 ────────────────────
  #
  # 这是个**会让门禁骗人**的分支：hvigor 增量构建在源码没变时会把
  # CompileArkTS 标成 UP-TO-DATE —— 那一趟根本不跑类型/规范分析，
  # 于是日志里一条 ArkTS 告警都没有。
  #
  # 实测：同一份代码，增量构建报「entry/ 2 条」，clean 后全量重编报「entry/ 5 条」，
  # 漏掉的 3 条正是一个真缺陷（框架组件把配置项声明成了 private，
  # 导致运行时不渲染），它因此藏了 11 轮才被发现。
  #
  # 所以这里**不能**在空转时报「告警 0 条」——那句话是假的。
  $arkTsRan = -not ($text -match 'UP-TO-DATE :\S*@CompileArkTS')
  $warnLines = @(Select-String -Path $log -Pattern 'ArkTS:WARN File:' -Encoding UTF8)
  if (-not $arkTsRan) {
    Write-Output '  ⚠ 本次 CompileArkTS 为 UP-TO-DATE（增量空转）：**没有做 ArkTS 分析**，'
    Write-Output '    因此「告警 0 条」不代表代码干净。要看真实告警，先清缓存再编：'
    Write-Output '      & $devEco\tools\node\node.exe $devEco\tools\hvigor\bin\hvigorw.js clean --no-daemon'
    Write-Output '    改动过源码时 hvigor 会自动重编，无需手动 clean；这条提示只针对「什么都没改」的空转。'
  } elseif ($warnLines.Count -gt 0) {
    $entryWarns = @($warnLines | Where-Object { $_.Line -match '/entry/' })
    $fwWarns = @($warnLines | Where-Object { $_.Line -match 'ngf_framework' })
    Write-Output ('  告警 ' + $warnLines.Count + ' 条：entry/ ' + $entryWarns.Count + ' 条，ngf_framework/ ' + $fwWarns.Count + ' 条')
    if ($entryWarns.Count -gt 0) {
      Write-Output '  ⚠ entry/ 侧告警（本仓须处理）：'
      $entryWarns | Select-Object -First 10 | ForEach-Object {
        Write-Output ('      ' + ($_.Line -replace '.*/entry/', 'entry/').Trim())
      }
    }
  } else {
    Write-Output '  告警 0 条'
  }
  $signed = @(Get-ChildItem -Recurse -Filter *-signed.hap -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch 'oh_modules|node_modules' })
  if ($signed.Count -gt 0) {
    Write-Output '  （已产出**已签名**包 —— 本机签名配置生效）'
  } else {
    Write-Output '  （只有未签名包 —— 本机未配置签名，或 product 没引用 signingConfig）'
  }
  Get-ChildItem -Recurse -Filter *.hap -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch 'oh_modules|node_modules' } |
    ForEach-Object { Write-Output ('  ' + $_.Name + '  ' + [math]::Round($_.Length / 1KB, 1) + ' KB') }
}
exit 0