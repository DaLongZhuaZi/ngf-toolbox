/**
 * NGF 开发者工具箱 - 首页占位页 (脚手架)。
 *
 * 本页只是工程脚手架的占位: 正式首页 (搜索 + 收藏 + 工具网格) 在功能开发阶段
 * 按 docs/产品定义.md 与 .agent-rules/project-rules.md 实现, 工具通过注册表接入,
 * 不要在本页堆砌工具实现。
 */
@Entry
@Component
struct Index {
  private plannedTools: string[] = [
    '正则测试', 'JSON 工具', '时间戳', '编解码套件',
    '摘要计算', '二维码生成', '代码查看', '端口测试',
    'JWT 解码', 'Cron 解析', '子网计算', '进制转换',
    '颜色转换', 'UUID 与随机密码', '文本 Diff', '日期计算'
  ];

  build() {
    Column({ space: 12 }) {
      Text('NGF 开发者工具箱')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 48 })
      Text('NGF 框架官方样板 · 建设中')
        .fontSize(14)
        .fontColor(Color.Gray)
      Text('首发规划工具 (' + this.plannedTools.length.toString() + ' 件):')
        .fontSize(14)
        .margin({ top: 24 })
      List({ space: 6 }) {
        ForEach(this.plannedTools, (toolName: string) => {
          ListItem() {
            Text(toolName).fontSize(15)
          }
        }, (toolName: string) => toolName)
      }
      .layoutWeight(1)
      .width('86%')
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
