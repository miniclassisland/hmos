import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private density: number = 1.5;

  private handleWantDeepLink(want: Want): void {
    const uri = (want.uri || '').trim();
    if (!uri) {
      return;
    }
    const lower = uri.toLowerCase();
    if (lower.startsWith('miniclassisland://exchange-certificate')) {
      AppStorage.setOrCreate<string>('pendingCertUri', '');
      AppStorage.setOrCreate<string>('pendingCertUri', uri);
    } else if (lower.startsWith('miniclassisland://qr-login')) {
      AppStorage.setOrCreate<string>('pendingQrLoginUri', '');
      AppStorage.setOrCreate<string>('pendingQrLoginUri', uri);
    } else if (lower.startsWith('miniclassisland://')) {
      AppStorage.setOrCreate<string>('pendingCertUri', '');
      AppStorage.setOrCreate<string>('pendingCertUri', uri);
    }
  }

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.handleWantDeepLink(want);
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.handleWantDeepLink(want);
  }

  private refreshDensity(): void {
    try {
      const disp = display.getDefaultDisplaySync();
      if (disp.densityPixels > 0) {
        this.density = disp.densityPixels;
      }
    } catch (_e) {
      this.density = 1.5;
    }
  }

  private pxToVp(px: number): number {
    if (px <= 0) {
      return 0;
    }
    return Math.round(px / (this.density > 0 ? this.density : 1.5));
  }

  private updateBreakpoint(widthPx: number, heightPx: number): void {
    this.refreshDensity();
    const widthVp = this.pxToVp(widthPx);
    const heightVp = this.pxToVp(heightPx);
    AppStorage.setOrCreate<number>('windowWidthVp', widthVp);
    AppStorage.setOrCreate<number>('windowHeightVp', heightVp);

    let bp = 'sm';
    if (widthVp >= 840) {
      bp = 'lg';
    } else if (widthVp >= 600) {
      bp = 'md';
    }
    AppStorage.setOrCreate<string>('breakpoint', bp);
    AppStorage.setOrCreate<boolean>('isFreeMultiWindow', widthVp >= 600);
  }

  private updateSafeAreaAndDecor(win: window.Window): void {
    this.refreshDensity();

    // 1. Detect deviceType ('phone' | 'tablet' | '2in1' | 'pc')
    let devType = 'phone';
    try {
      devType = (deviceInfo.deviceType || 'phone').toLowerCase();
    } catch (_e) {
      devType = 'phone';
    }
    const isPcOr2in1 = (devType === '2in1' || devType === 'pc');
    AppStorage.setOrCreate<string>('deviceType', devType);
    AppStorage.setOrCreate<boolean>('isPcMode', isPcOr2in1);

    // 2. Read System Avoid Areas (StatusBar, Cutout, Navigation Indicator)
    let topSafeVp = 0;
    let bottomSafeVp = 0;
    let leftSafeVp = 0;
    let rightSafeVp = 0;

    try {
      const sysArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      topSafeVp = Math.max(topSafeVp, this.pxToVp(sysArea.topRect.height));
      bottomSafeVp = Math.max(bottomSafeVp, this.pxToVp(sysArea.bottomRect.height));
    } catch (_e) {}

    try {
      const cutoutArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      topSafeVp = Math.max(topSafeVp, this.pxToVp(cutoutArea.topRect.height));
      leftSafeVp = Math.max(leftSafeVp, this.pxToVp(cutoutArea.leftRect.width));
      rightSafeVp = Math.max(rightSafeVp, this.pxToVp(cutoutArea.rightRect.width));
    } catch (_e) {}

    try {
      const navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      bottomSafeVp = Math.max(bottomSafeVp, this.pxToVp(navArea.bottomRect.height));
    } catch (_e) {}

    // 3. Configure HMOS PC / 2in1 & Tablet Free Multi-Window Integrated TitleBar
    let decorHeightVp = 0;
    let captionRightReserveVp = 0;
    try {
      // Hide default system title bar so TopBar integrates seamlessly with window controls
      win.setWindowDecorVisible(false);
      win.setWindowDecorHeight(48);
      decorHeightVp = 48;
      // On 2in1 / PC or floating window with native min/max/close buttons on the top-right
      if (isPcOr2in1) {
        captionRightReserveVp = 138;
      }
    } catch (_e) {
      decorHeightVp = 0;
    }

    try {
      const currentDecorH = win.getWindowDecorHeight();
      if (currentDecorH > 0) {
        decorHeightVp = currentDecorH;
        // On tablet free-multi-window or 2in1 when window decor is active, reserve right caption buttons width
        if (captionRightReserveVp === 0) {
          captionRightReserveVp = 132;
        }
      }
    } catch (_e) {}

    AppStorage.setOrCreate<number>('safeTopVp', topSafeVp);
    AppStorage.setOrCreate<number>('safeBottomVp', bottomSafeVp);
    AppStorage.setOrCreate<number>('safeLeftVp', leftSafeVp);
    AppStorage.setOrCreate<number>('safeRightVp', rightSafeVp);
    AppStorage.setOrCreate<number>('decorHeightVp', decorHeightVp);
    AppStorage.setOrCreate<number>('captionRightReserveVp', captionRightReserveVp);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      this.mainWindow = mainWindow;

      // Enable edge-to-edge full screen layout for immersive safe-area & PC titlebar integration
      try {
        mainWindow.setWindowLayoutFullScreen(true);
      } catch (_e) {}

      // Set transparent status/navigation bars so app theme controls colors
      try {
        mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: '#242424',
          navigationBarContentColor: '#242424'
        });
      } catch (_e) {}

      const props = mainWindow.getWindowProperties();
      this.updateBreakpoint(props.windowRect.width, props.windowRect.height);
      this.updateSafeAreaAndDecor(mainWindow);

      mainWindow.on('windowSizeChange', (size: window.Size) => {
        this.updateBreakpoint(size.width, size.height);
        this.updateSafeAreaAndDecor(mainWindow);
      });

      mainWindow.on('avoidAreaChange', (_data) => {
        this.updateSafeAreaAndDecor(mainWindow);
      });

      mainWindow.on('windowStatusChange', (statusType: window.WindowStatusType) => {
        // 1: FULL_SCREEN, 2: MAXIMIZE, 3: MINIMIZE, 4: FLOATING, 5: SPLIT_SCREEN
        const st = Number(statusType);
        AppStorage.setOrCreate<number>('windowStatusType', st);
        // When entering floating / split-screen on Tablet or 2in1, reserve right space for window control buttons
        const isFloatingOrPc = (st === 4 || st === 2 || (AppStorage.get<boolean>('isPcMode') ?? false));
        AppStorage.setOrCreate<number>('captionRightReserveVp', isFloatingOrPc ? 138 : 0);
        this.updateSafeAreaAndDecor(mainWindow);
      });
    } catch (_err) {
      AppStorage.setOrCreate<string>('breakpoint', 'sm');
    }

    windowStage.loadContent('pages/Index', (_err) => {
    });
  }
}
