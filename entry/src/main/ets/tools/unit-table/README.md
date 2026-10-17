# unit-table（存储单位速查）

KiB/MiB/GiB（1024 进制 IEC）与 kB/MB/GB（1000 进制 SI）双体系对照——
「500GB 硬盘显示 465GB」的根源。输入字节数输出两套体系的数值。

- 演示的 NGF 层：utils
- 纯逻辑：UnitTableLogic.ets（UnitTableTest.test.ets 4 条，换算锚点）
- 页面：UnitTablePage.ets
- 与 unit-convert 配对：那做任意换算，这是体系对照速查。
