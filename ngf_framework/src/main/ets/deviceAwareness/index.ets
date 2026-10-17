export {
  IHoldingAwarenessManager,
  NGFHoldingAwarenessConfidence,
  NGFHoldingAwarenessListener,
  NGFHoldingAwarenessSide,
  NGFHoldingAwarenessSnapshot,
  NGFHoldingAwarenessSource,
  NGFHoldingUiAnchor
} from './contracts/IHoldingAwarenessManager';

export {
  IDeviceAdaptationManager,
  NGFBreakpoint,
  NGFDeviceChangeListener,
  NGFDeviceInfo,
  NGFDeviceType,
  NGFFoldStatus,
  NGFScreenOrientation,
  NGFRuntimeStatus,
  NGFAppThreadInfo
} from './contracts/IDeviceAdaptationManager';

export {
  IVisualEffectsManager,
  NGFSystemMaterialPolicy,
  NGFVisualEffectsCapability,
  NGFVisualEffectsMaterialMode,
  NGFVisualEffectsSettings,
  NGFVisualEffectsState,
  NGFVisualEffectsStateListener
} from './contracts/IVisualEffectsManager';

export { IAdaptiveLayout, NGFBreakpointLayoutConfig } from './contracts/IAdaptiveLayout';
export {
  IDeviceCapabilityDetector,
  NGFCapabilityType,
  NGFCapabilityResult
} from './contracts/IDeviceCapabilityDetector';

// ⚠️ 本行是**本仓先行修改**，需回来源仓（airwavefootprints）同步。
// 原因：AccessibilityFacade 文件一直存在，但漏了这条导出，导致
// `import { ngfAccessibilityFacade } from 'ngf_framework'` 拿不到——
// 而无障碍是官方样板应用必须演示的能力。详见 ngf_framework/VENDORED.md。
export { ngfAccessibilityFacade, NGFAccessibilityState } from './facades/AccessibilityFacade';
export { ngfHoldingAwarenessFacade } from './facades/HoldingAwarenessFacade';
export { ngfDeviceAdaptationFacade } from './facades/DeviceAdaptationFacade';
export { ngfVisualEffectsFacade } from './facades/VisualEffectsFacade';
export { ngfAdaptiveLayoutFacade } from './facades/AdaptiveLayoutFacade';
export { DeviceCapabilityDetectorFacade, ngfDeviceCapabilityDetectorFacade } from './facades/DeviceCapabilityDetectorFacade';
export { ngfDeviceAwarenessIntegrationFacade } from './facades/NGFDeviceAwarenessIntegrationFacade';
