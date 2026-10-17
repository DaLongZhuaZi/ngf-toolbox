import { hdsMaterial, HdsTabs, HdsTabsController, HdsTabsFloatingStyle, SystemMaterialParams } from '@kit.UIDesignKit';

class NGFHdsTabsSystemMaterialParams implements SystemMaterialParams {
  materialType?: hdsMaterial.MaterialType;
  materialLevel?: hdsMaterial.MaterialLevel;

  constructor(materialLevel: hdsMaterial.MaterialLevel) {
    this.materialType = hdsMaterial.MaterialType.IMMERSIVE;
    this.materialLevel = materialLevel;
  }
}

class NGFHdsTabsFloatingStyle implements HdsTabsFloatingStyle {
  adaptToHandedness?: boolean;
  systemMaterialEffect?: SystemMaterialParams;
  thermoCtrl?: boolean;
  barOpacity?: number;

  constructor(materialLevel: hdsMaterial.MaterialLevel) {
    this.adaptToHandedness = true;
    this.systemMaterialEffect = new NGFHdsTabsSystemMaterialParams(materialLevel);
    this.thermoCtrl = true;
    this.barOpacity = 0.92;
  }
}

export class NGFHdsTabItem {
  readonly title: string;

  constructor(title: string) {
    this.title = title;
  }
}

@Component
  // ⚠️ 以下三项**不能**是 private —— 它们是父组件必须能传入的配置。
  // 声明成 private 时 ArkTS 会告警「Property 'X' is private and can not be
  // initialized through the component constructor」，而后果是**静默的**：
  // items 保持空数组 → 页签一个都不渲染；onChangeCallback 保持空实现 →
  // 点了页签没反应。编译不报错，只有真编译日志里三行 WARN。
  // （本仓先行修正，需回来源仓同步，见 ngf_framework/VENDORED.md）
export struct NGFHdsImmersiveTabs {
  private controller: HdsTabsController = new HdsTabsController();
  items: Array<NGFHdsTabItem> = [];
  @Prop selectedIndex: number = 0;
  @StorageProp('ngf_visual_effects_effective_material_level')
  private effectiveMaterialLevel: number = hdsMaterial.MaterialLevel.ADAPTIVE;
  onChangeCallback: (index: number) => void = (): void => {};
  @Builder defaultBuilder(index: number) {}
  @BuilderParam contentBuilder: (index: number) => void = this.defaultBuilder;

  build(): void {
    HdsTabs({ controller: this.controller }) {
      ForEach(this.items, (item: NGFHdsTabItem, index: number): void => {
        TabContent() {
          this.contentBuilder(index);
        }
        .tabBar(this.buildTabBarItem(item, this.selectedIndex === index))
      }, (item: NGFHdsTabItem, index: number): string => index + '_' + item.title)
    }
    .barPosition(BarPosition.End)
    .barMode(BarMode.Fixed)
    .barOverlap(true)
    .barFloatingStyle(new NGFHdsTabsFloatingStyle(this.resolveMaterialLevel()))
    .onChange((index: number): void => {
      this.onChangeCallback(index);
    })
  }

  private resolveMaterialLevel(): hdsMaterial.MaterialLevel {
    switch (this.effectiveMaterialLevel) {
      case hdsMaterial.MaterialLevel.EXQUISITE:
        return hdsMaterial.MaterialLevel.EXQUISITE;
      case hdsMaterial.MaterialLevel.GENTLE:
        return hdsMaterial.MaterialLevel.GENTLE;
      case hdsMaterial.MaterialLevel.SMOOTH:
        return hdsMaterial.MaterialLevel.SMOOTH;
      default:
        return hdsMaterial.MaterialLevel.ADAPTIVE;
    }
  }

  @Builder
  private buildTabBarItem(item: NGFHdsTabItem, isSelected: boolean): void {
    Column({ space: 4 }) {
      Text(item.title)
        .fontSize(11)
        .fontColor(isSelected ? $r('app.color.button_primary') : $r('app.color.text_secondary'))
        .fontWeight(isSelected ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }
}
