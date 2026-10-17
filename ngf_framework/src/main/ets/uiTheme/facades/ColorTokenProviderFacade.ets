import { logger } from '../../utils/Logger';
import { IColorTokenProvider, NGFColorToken, NGFColorValue } from '../contracts/IColorTokenProvider';
import { ngfThemeManagerFacade } from './ThemeManagerFacade';

const TAG: string = 'NGFColorTokenProviderFacade';

class ColorTokenProviderFacade implements IColorTokenProvider {
  private static instance: ColorTokenProviderFacade | null = null;
  private readonly colors: Map<string, NGFColorValue> = new Map<string, NGFColorValue>();

  static getInstance(): ColorTokenProviderFacade {
    if (!ColorTokenProviderFacade.instance) {
      ColorTokenProviderFacade.instance = new ColorTokenProviderFacade();
    }
    return ColorTokenProviderFacade.instance;
  }

  resolveColor(token: NGFColorToken): string {
    const value = this.colors.get(token);
    if (value === undefined) {
      logger.debug(TAG, '颜色 Token 未注册: ' + token);
      return '#000000';
    }
    const isDark = ngfThemeManagerFacade.isDarkMode();
    return isDark ? value.dark : value.light;
  }

  resolveColorValue(token: NGFColorToken): NGFColorValue {
    const value = this.colors.get(token);
    if (value !== undefined) {
      return value;
    }
    return new NGFColorValue(token, '#000000', '#000000');
  }

  registerColor(value: NGFColorValue): void {
    this.colors.set(value.token, value);
    logger.debug(TAG, '注册颜色 Token: ' + value.token);
  }

  registerDefaults(): void {
    this.registerColor(new NGFColorValue(NGFColorToken.PRIMARY, '#6750A4', '#D0BCFF'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_PRIMARY, '#FFFFFF', '#381E72'));
    this.registerColor(new NGFColorValue(NGFColorToken.PRIMARY_CONTAINER, '#EADDFF', '#4F378B'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_PRIMARY_CONTAINER, '#21005D', '#EADDFF'));
    this.registerColor(new NGFColorValue(NGFColorToken.SECONDARY, '#625B71', '#CCC2DC'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_SECONDARY, '#FFFFFF', '#332D41'));
    this.registerColor(new NGFColorValue(NGFColorToken.SECONDARY_CONTAINER, '#E8DEF8', '#4A4458'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_SECONDARY_CONTAINER, '#1D192B', '#E8DEF8'));
    this.registerColor(new NGFColorValue(NGFColorToken.TERTIARY, '#7D5260', '#EFB8C8'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_TERTIARY, '#FFFFFF', '#492532'));
    this.registerColor(new NGFColorValue(NGFColorToken.SURFACE, '#FEF7FF', '#141218'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_SURFACE, '#1D1B20', '#E6E0E9'));
    this.registerColor(new NGFColorValue(NGFColorToken.SURFACE_VARIANT, '#E7E0EC', '#49454F'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_SURFACE_VARIANT, '#49454F', '#CAC4D0'));
    this.registerColor(new NGFColorValue(NGFColorToken.BACKGROUND, '#FEF7FF', '#141218'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_BACKGROUND, '#1D1B20', '#E6E0E9'));
    this.registerColor(new NGFColorValue(NGFColorToken.ERROR_COLOR, '#B3261E', '#F2B8B5'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_ERROR, '#FFFFFF', '#601410'));
    this.registerColor(new NGFColorValue(NGFColorToken.OUTLINE, '#79747E', '#938F99'));
    this.registerColor(new NGFColorValue(NGFColorToken.OUTLINE_VARIANT, '#CAC4D0', '#49454F'));
    // 本仓先行补充的 5 个语义 Token（见 IColorTokenProvider.ets 的说明）
    this.registerColor(new NGFColorValue(NGFColorToken.ERROR_CONTAINER, '#F9DEDC', '#8C1D18'));
    this.registerColor(new NGFColorValue(NGFColorToken.ON_ERROR_CONTAINER, '#410E0B', '#F9DEDC'));
    this.registerColor(new NGFColorValue(NGFColorToken.WARNING, '#7A5900', '#F0B457'));
    this.registerColor(new NGFColorValue(NGFColorToken.WARNING_CONTAINER, '#FFF3E0', '#2B2417'));
    this.registerColor(new NGFColorValue(NGFColorToken.SUCCESS, '#1D8147', '#5FD08A'));
    logger.info(TAG, '注册默认颜色 Token: ' + this.colors.size + ' 个');
  }
}

export const ngfColorTokenProviderFacade: ColorTokenProviderFacade = ColorTokenProviderFacade.getInstance();
