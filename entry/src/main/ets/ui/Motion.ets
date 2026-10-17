/**
 * 统一动效常量（动效设计的单一来源）。
 *
 * ## 规范
 *
 * 时长对齐系统风格：结果出现 250ms 标准曲线；复制反馈 150ms。
 * 动效只做透明度与轻微位移（列表场景不做缩放旋转，避免眩晕）。
 *
 * @module ui/Motion
 */

/** 结果出现：时长 ms */
export const MOTION_DURATION_MS: number = 250;
/** 复制反馈：时长 ms */
export const MOTION_FEEDBACK_MS: number = 150;
/** 结果出现的纵向位移（vp） */
export const MOTION_SLIDE_VP: number = 8;