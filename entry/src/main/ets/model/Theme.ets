// Exact Fluent UI / Web Design System Theme Tokens for MINI ClassIsland
// Mirrors web/app/globals.css and admin/app/globals.css 1:1

export interface WebThemePalette {
  isDark: boolean;
  bgPrimary: string;       // --bg-primary (#f5f5f5 / #121212)
  bgSidebar: string;       // --bg-sidebar (#fafafa / #181818)
  bgCard: string;          // --bg-card (#ffffff / #1e1e1e)
  bgSubtle: string;        // --bg-subtle (#fafafa / #252525)
  bgInput: string;         // --bg-input (#ffffff / #252525)
  bgAccentSubtle: string;  // --bg-accent-subtle (#e1efff / #15293e)
  bgSuccessSubtle: string; // --bg-success-subtle (#f0f9f0 / #132a13)
  textPrimary: string;     // --text-primary (#242424 / #f0f0f0)
  textSecondary: string;   // --text-secondary (#616161 / #a6a6a6)
  textTertiary: string;    // --text-tertiary (#999999 / #6e6e6e)
  borderColor: string;     // --border-color (#e0e0e0 / #2e2e2e)
  borderSubtle: string;    // --border-subtle (#f0f0f0 / #262626)
  accentColor: string;     // --accent-color (#0078d4 / #4aa3ff)
  accentHover: string;     // --accent-hover (#106ebe / #6eb5ff)
  dangerColor: string;     // --danger-color (#d13438 / #f1707b)
  successColor: string;    // --success-color (#107c10 / #54b054)
  warningColor: string;    // --warning-color (#ffb900 / #fce100)
  loginBg: string;         // Web /login full-page background (#0078d4 / #0d1520)
  badgeSuccessBg: string;  // #dff6dd / #173b17
  badgeSuccessFg: string;  // #107c10 / #6ccb5f
  badgeDangerBg: string;   // #fde7e9 / #44161a
  badgeDangerFg: string;   // #d13438 / #f1707b
  badgeWarningBg: string;  // #fff4ce / #433519
  badgeWarningFg: string;  // #a17c00 / #fce100
  badgeInfoBg: string;     // #e1efff / #15293e
  badgeInfoFg: string;     // #0078d4 / #4aa3ff
}

export const LIGHT_WEB_PALETTE: WebThemePalette = {
  isDark: false,
  bgPrimary: '#F5F5F5',
  bgSidebar: '#FAFAFA',
  bgCard: '#FFFFFF',
  bgSubtle: '#FAFAFA',
  bgInput: '#FFFFFF',
  bgAccentSubtle: '#E1EFFF',
  bgSuccessSubtle: '#F0F9F0',
  textPrimary: '#242424',
  textSecondary: '#616161',
  textTertiary: '#999999',
  borderColor: '#E0E0E0',
  borderSubtle: '#F0F0F0',
  accentColor: '#0078D4',
  accentHover: '#106EBE',
  dangerColor: '#D13438',
  successColor: '#107C10',
  warningColor: '#FFB900',
  loginBg: '#0078D4',
  badgeSuccessBg: '#DFF6DD',
  badgeSuccessFg: '#107C10',
  badgeDangerBg: '#FDE7E9',
  badgeDangerFg: '#D13438',
  badgeWarningBg: '#FFF4CE',
  badgeWarningFg: '#A17C00',
  badgeInfoBg: '#E1EFFF',
  badgeInfoFg: '#0078D4'
};

export const DARK_WEB_PALETTE: WebThemePalette = {
  isDark: true,
  bgPrimary: '#121212',
  bgSidebar: '#181818',
  bgCard: '#1E1E1E',
  bgSubtle: '#252525',
  bgInput: '#252525',
  bgAccentSubtle: '#15293E',
  bgSuccessSubtle: '#132A13',
  textPrimary: '#F0F0F0',
  textSecondary: '#A6A6A6',
  textTertiary: '#6E6E6E',
  borderColor: '#2E2E2E',
  borderSubtle: '#262626',
  accentColor: '#4AA3FF',
  accentHover: '#6EB5FF',
  dangerColor: '#F1707B',
  successColor: '#54B054',
  warningColor: '#FCE100',
  loginBg: '#0D1520',
  badgeSuccessBg: '#173B17',
  badgeSuccessFg: '#6CCB5F',
  badgeDangerBg: '#44161A',
  badgeDangerFg: '#F1707B',
  badgeWarningBg: '#433519',
  badgeWarningFg: '#FCE100',
  badgeInfoBg: '#15293E',
  badgeInfoFg: '#4AA3FF'
};

export function getWebPalette(themeMode: string): WebThemePalette {
  if (themeMode === 'dark') {
    return DARK_WEB_PALETTE;
  }
  return LIGHT_WEB_PALETTE;
}
