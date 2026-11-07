import {
  UserInfo,
  AccountSummary,
  GlobalStats,
  AdminAccountItem,
  getSystemRoleLabel
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosIconTextButton, HmosSymbolIcon } from '../components/HmosIcons';
import { AuthAndAccountView } from '../components/AuthAndAccountView';
import { DashboardView } from '../components/DashboardView';
import { ProfileEditorView } from '../components/ProfileEditorView';
import { ClientsAndOpsView } from '../components/ClientsAndOpsView';
import { AdmissionAndGovernanceView } from '../components/AdmissionAndGovernanceView';
import { scanBarcode, scanCore } from '@kit.ScanKit';

@Entry
@Component
struct Index {
  @State themeMode: string = 'light'; // 'system' | 'light' | 'dark'
  @State breakpoint: string = 'sm'; // 'sm' (<600) | 'md' (600..900) | 'lg' (>=900)
  @State windowWidthVp: number = 390;

  // Window Safe Area & Freeform Caption Avoid Rect (set by EntryAbility)
  @StorageLink('safeTopVp') safeTopVp: number = 0;
  @StorageLink('safeBottomVp') safeBottomVp: number = 0;
  @StorageLink('safeLeftVp') safeLeftVp: number = 0;
  @StorageLink('safeRightVp') safeRightVp: number = 0;
  @StorageLink('captionRightReserveVp') captionRightReserveVp: number = 0;
  @StorageLink('deepLinkUri') @Watch('onDeepLinkUriChanged') deepLinkUri: string = '';

  @State isLoggedIn: boolean = false;
  @State isSuperAdminMode: boolean = false;
  @State isSuperAdminTakeover: boolean = false;
  @State currentUser: UserInfo | null = null;
  @State accounts: AccountSummary[] = [];
  @State currentAccountId: string = '';
  @State currentAccountName: string = '';
  @State currentAccountSlug: string = '';

  // Navigation & Drawer
  @State currentSection: string = 'user_home';
  @State showMobileDrawer: boolean = false;
  @State showAccountSelectorPopover: boolean = false;
  @State showUserMenuPopover: boolean = false;

  // Dashboard Metrics
  @State dashOnlineClients: number = 0;
  @State dashTotalClients: number = 0;
  @State dashPendingPairings: number = 0;
  @State dashTotalResources: number = 0;
  @State dashRecentAudits: number = 0;
  @State adminGlobalStats: GlobalStats | null = null;

  @State globalBannerMsg: string = '';
  @State globalBannerIsError: boolean = false;
  private hasAutoLaunchedScanner: boolean = false;

  aboutToAppear(): void {
    const api = ApiService.get();
    api.initPersistentAuth();

    const savedTheme = AppStorage.get<string>('themeMode') || '';
    if (savedTheme === 'light' || savedTheme === 'dark' || savedTheme === 'system') {
      this.themeMode = savedTheme;
    }

    const savedUserRaw = AppStorage.get<string>('savedUserJson') || '';
    if (savedUserRaw.trim().length > 0) {
      try {
        this.currentUser = JSON.parse(savedUserRaw) as UserInfo;
      } catch (_e) {
        this.currentUser = null;
      }
    }

    const savedAccRaw = AppStorage.get<string>('savedAccountsJson') || '';
    if (savedAccRaw.trim().length > 0) {
      try {
        this.accounts = JSON.parse(savedAccRaw) as AccountSummary[];
      } catch (_e) {
        this.accounts = [];
      }
    }

    this.currentAccountId = AppStorage.get<string>('currentAccountId') || '';
    this.currentAccountName = AppStorage.get<string>('currentAccountName') || '';
    this.currentAccountSlug = AppStorage.get<string>('currentAccountSlug') || '';

    const nowSec = Math.floor(Date.now() / 1000);
    if (api.token.length > 0) {
      this.isLoggedIn = true;
      this.currentSection = 'user_home';
      this.refreshAuthenticatedSessionInBackground();
    } else if (api.storedCertificate !== null && api.storedCertificate.expires_at > nowSec) {
      this.autoLoginFromStoredCertificate();
    }

    if (this.deepLinkUri.trim().length > 0) {
      this.onDeepLinkUriChanged();
    } else if (!this.isLoggedIn && api.storedCertificate === null && !this.hasAutoLaunchedScanner) {
      this.hasAutoLaunchedScanner = true;
      setTimeout(() => {
        if (!this.isLoggedIn && this.deepLinkUri.trim().length === 0) {
          this.triggerAutoStartupScan();
        }
      }, 300);
    }
  }

  private async refreshAuthenticatedSessionInBackground(): Promise<void> {
    const api = ApiService.get();
    const nowSec = Math.floor(Date.now() / 1000);
    if (
      api.tokenExpiresAt > 0 &&
      (api.tokenExpiresAt - nowSec) < 300 &&
      api.storedCertificate !== null &&
      api.storedCertificate.expires_at > nowSec
    ) {
      await api.requestSessionFromCertificate(3600);
      if ((api.storedCertificate.expires_at - nowSec) < 86400 && api.storedCertificate.generation < api.storedCertificate.max_generation) {
        await api.rotateCertificateIfEligible();
      }
    }

    const profRes = await api.getProfile();
    if (profRes.ok && profRes.data) {
      this.currentUser = profRes.data;
    } else if (profRes.status === 401 && api.storedCertificate !== null && api.storedCertificate.expires_at > nowSec) {
      await this.autoLoginFromStoredCertificate();
      return;
    } else if (profRes.status === 401) {
      this.handleLogout();
      return;
    }

    await this.loadMyAccounts();
    this.persistCurrentSession();
  }

  private async autoLoginFromStoredCertificate(): Promise<void> {
    const api = ApiService.get();
    const sRes = await api.requestSessionFromCertificate(3600);
    if (!sRes.ok || !sRes.data) {
      return;
    }
    const nowSec = Math.floor(Date.now() / 1000);
    if (
      api.storedCertificate !== null &&
      (api.storedCertificate.expires_at - nowSec) < 86400 &&
      api.storedCertificate.generation < api.storedCertificate.max_generation
    ) {
      await api.rotateCertificateIfEligible();
    }
    const pRes = await api.getProfile();
    if (pRes.ok && pRes.data) {
      this.currentUser = pRes.data;
    } else if (sRes.data.user && sRes.data.user.username) {
      this.currentUser = sRes.data.user;
    }
    this.isLoggedIn = true;
    this.currentSection = 'user_home';
    await this.loadMyAccounts();
    this.persistCurrentSession();
  }

  private persistCurrentSession(): void {
    ApiService.get().saveAuthSession(
      ApiService.get().token,
      this.currentUser,
      this.accounts,
      this.currentAccountId,
      this.currentAccountName,
      this.currentAccountSlug
    );
  }

  private isSuperAdminUser(): boolean {
    if (!this.currentUser) {
      return false;
    }
    const code = this.currentUser.role_code || this.currentUser.role || '';
    return code === 'superadmin';
  }

  private isUserCenterMode(): boolean {
    if (this.isSuperAdminMode) {
      return false;
    }
    if (
      this.currentSection === 'user_home' ||
      this.currentSection === 'security' ||
      this.currentSection === 'tickets'
    ) {
      return true;
    }
    return this.currentAccountId.length === 0;
  }

  private async triggerAutoStartupScan(): Promise<void> {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: false,
        enableAlbum: true
      };
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(getContext(this), options);
      const scanned = (result.originalValue || '').trim();
      if (scanned.length > 0) {
        this.deepLinkUri = scanned;
      }
    } catch (_e) {
      // User cancelled or camera not ready; remain on scan login page
    }
  }

  public async onDeepLinkUriChanged(): Promise<void> {
    const uri = (this.deepLinkUri || '').trim();
    if (!uri) {
      return;
    }
    AppStorage.setOrCreate<string>('deepLinkUri', '');
    const lower = uri.toLowerCase();
    const api = ApiService.get();

    if (lower.startsWith('miniclassisland://qr-login')) {
      const r = await api.authorizeWebQrLogin(uri);
      this.globalBannerIsError = !r.ok;
      this.globalBannerMsg = r.ok ? '已通过 DeepLink 成功确认并授权网页端扫码登录' : (r.error || '扫码登录网页端授权失败');
      return;
    }

    if (lower.startsWith('miniclassisland://exchange-certificate') || uri.length > 0) {
      const r = await api.redeemCertificate(uri);
      if (!r.ok || !r.data) {
        this.globalBannerIsError = true;
        this.globalBannerMsg = r.error || '通过二维码兑换登录安全证书失败';
        return;
      }
      if (api.token.length === 0) {
        await api.requestSessionFromCertificate(3600);
      }
      const pRes = await api.getProfile();
      if (pRes.ok && pRes.data) {
        this.currentUser = pRes.data;
        this.isLoggedIn = true;
        this.isSuperAdminMode = false;
        this.currentSection = 'user_home';
        await this.loadMyAccounts();
        this.persistCurrentSession();
        this.globalBannerIsError = false;
        this.globalBannerMsg = '已成功绑定移动端登录安全证书并进入用户中心';
      } else {
        this.globalBannerIsError = false;
        this.globalBannerMsg = '已成功兑换并保存登录安全证书至本机';
      }
    }
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private async loadMyAccounts(): Promise<void> {
    const r = await ApiService.get().listMyAccounts();
    if (r.ok && r.data) {
      this.accounts = r.data;
      if (this.currentAccountId.length === 0 && this.accounts.length > 0) {
        this.currentAccountId = this.accounts[0].id;
        this.currentAccountName = this.accounts[0].name;
        this.currentAccountSlug = this.accounts[0].slug;
      }
      this.persistCurrentSession();
    }
  }

  private async selectTenantAccount(acc: AccountSummary, targetSection: string = 'dashboard'): Promise<void> {
    this.isSuperAdminMode = false;
    this.isSuperAdminTakeover = false;
    this.currentAccountId = acc.id;
    this.currentAccountName = acc.name;
    this.currentAccountSlug = acc.slug;
    this.currentSection = targetSection;
    this.showAccountSelectorPopover = false;
    this.showMobileDrawer = false;
    this.persistCurrentSession();
    await this.loadTenantDashboardMetrics();
  }

  private async loadTenantDashboardMetrics(): Promise<void> {
    if (this.currentAccountId.length === 0) {
      return;
    }
    const api = ApiService.get();
    const cRes = await api.listClients(this.currentAccountId);
    if (cRes.ok && cRes.data) {
      this.dashTotalClients = cRes.data.length;
      let online = 0;
      for (let i = 0; i < cRes.data.length; i++) {
        if (cRes.data[i].status === 'online' || cRes.data[i].is_online) {
          online++;
        }
      }
      this.dashOnlineClients = online;
    }
    const pRes = await api.listPairingRequests(this.currentAccountId, 'pending');
    if (pRes.ok && pRes.data) {
      this.dashPendingPairings = pRes.data.length;
    }
    let totalRes = 0;
    const types = ['Subjects', 'TimeLayout', 'ClassPlan', 'Policy', 'DefaultSettings', 'Components', 'Credentials'];
    for (let i = 0; i < types.length; i++) {
      const r = await api.listResources(this.currentAccountId, types[i]);
      if (r.ok && r.data) {
        totalRes += r.data.length;
      }
    }
    this.dashTotalResources = totalRes;
    const aRes = await api.listAuditLogs(this.currentAccountId, '', 'all');
    if (aRes.ok && aRes.data) {
      this.dashRecentAudits = aRes.data.length;
    }
  }

  private async loadSuperAdminMetrics(): Promise<void> {
    const r = await ApiService.get().getGlobalStats();
    if (r.ok && r.data) {
      this.adminGlobalStats = r.data;
    }
  }

  private handleLogout(): void {
    ApiService.get().clearAuthSession();
    this.isLoggedIn = false;
    this.isSuperAdminMode = false;
    this.isSuperAdminTakeover = false;
    this.currentUser = null;
    this.accounts = [];
    this.currentAccountId = '';
    this.currentAccountName = '';
    this.currentAccountSlug = '';
    this.currentSection = 'user_home';
    this.showUserMenuPopover = false;
    this.showMobileDrawer = false;
  }

  private getHeaderCenterTitle(): string {
    if (this.isSuperAdminMode) {
      return 'MINI ClassIsland 超级管理平台';
    }
    if (this.isUserCenterMode()) {
      return 'MINI ClassIsland 用户中心';
    }
    return `账户中心 · ${this.currentAccountName || '集控管理平台'}`;
  }

  // ==================== TOPBAR (1:1 with web/components/TopBar.tsx) ====================
  @Builder
  buildTopBar() {
    Row({ space: 10 }) {
      if (this.breakpoint !== 'lg') {
        HmosIconButton(
          $r('sys.symbol.line_3_horizontal'),
          this.theme().textPrimary,
          Color.Transparent,
          this.theme().borderColor,
          () => {
            this.showMobileDrawer = !this.showMobileDrawer;
          },
          34,
          17
        )
      }

      Text(this.getHeaderCenterTitle())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textSecondary)
        .maxLines(1)
        .layoutWeight(1)

      // 3-Button Theme Toggle Group: 自动 / 浅色 / 深色
      Row({ space: 2 }) {
        ForEach([
          ['system', '自动'],
          ['light', '浅色'],
          ['dark', '深色']
        ], (pair: string[]) => {
          Text(pair[1])
            .fontSize(11)
            .fontWeight(this.themeMode === pair[0] ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.themeMode === pair[0] ? this.theme().accentColor : this.theme().textSecondary)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .borderRadius(4)
            .backgroundColor(this.themeMode === pair[0] ? this.theme().bgAccentSubtle : Color.Transparent)
            .onClick(() => {
              this.themeMode = pair[0];
              AppStorage.setOrCreate<string>('themeMode', pair[0]);
            })
        }, (pair: string[]) => pair[0])
      }
      .padding(2)
      .borderRadius(6)
      .backgroundColor(this.theme().bgSubtle)
      .border({ width: 1, color: this.theme().borderColor })

      // User Dropdown Trigger
      Row({ space: 6 }) {
        Column() {
          HmosSymbolIcon($r('sys.symbol.person'), 13, '#FFFFFF')
        }
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(this.theme().accentColor)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        if (this.breakpoint !== 'sm') {
          Text(this.currentUser?.display_name || this.currentUser?.username || '用户')
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .maxLines(1)
            .constraintSize({ maxWidth: 110 })
        }

        HmosSymbolIcon($r('sys.symbol.chevron_down'), 11, this.theme().textSecondary)
      }
      .padding({ left: 6, right: 8, top: 4, bottom: 4 })
      .borderRadius(6)
      .backgroundColor(this.theme().bgSubtle)
      .border({ width: 1, color: this.theme().borderColor })
      .onClick(() => {
        this.showUserMenuPopover = !this.showUserMenuPopover;
      })
    }
    .width('100%')
    .height(52 + this.safeTopVp)
    .padding({
      left: Math.max(16, this.safeLeftVp),
      right: Math.max(16, Math.max(this.safeRightVp, this.captionRightReserveVp + 8)),
      top: this.safeTopVp
    })
    .backgroundColor(this.theme().bgCard)
    .border({ width: { bottom: 1 }, color: this.theme().borderColor })
  }

  // ==================== SIDEBAR (1:1 with web/components/Sidebar.tsx) ====================
  @Builder
  buildSidebarItem(iconRes: Resource, label: string, secKey: string) {
    Row({ space: 10 }) {
      if (this.currentSection === secKey) {
        Column()
          .width(3)
          .height(16)
          .borderRadius(2)
          .backgroundColor(this.theme().accentColor)
      } else {
        Column().width(3).height(16)
      }

      HmosSymbolIcon(
        iconRes,
        16,
        this.currentSection === secKey ? this.theme().accentColor : this.theme().textSecondary
      )

      Text(label)
        .fontSize(13)
        .fontWeight(this.currentSection === secKey ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentSection === secKey ? this.theme().accentColor : this.theme().textPrimary)
        .layoutWeight(1)
        .maxLines(1)
    }
    .width('100%')
    .padding({ left: 10, right: 12, top: 8, bottom: 8 })
    .borderRadius(6)
    .backgroundColor(this.currentSection === secKey ? this.theme().bgAccentSubtle : Color.Transparent)
    .onClick(() => {
      this.currentSection = secKey;
      this.showMobileDrawer = false;
      if (secKey === 'dashboard') {
        if (this.isSuperAdminMode) {
          this.loadSuperAdminMetrics();
        } else {
          this.loadTenantDashboardMetrics();
        }
      }
    })
  }

  @Builder
  buildSidebarGroupLabel(title: string) {
    Text(title)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme().textTertiary)
      .padding({ left: 12, top: 10, bottom: 4 })
  }

  @Builder
  buildSidebar() {
    Column() {
      // Brand Header
      Row({ space: 10 }) {
        Image($r('app.media.app_icon'))
          .width(30)
          .height(30)
          .borderRadius(6)
        Column({ space: 2 }) {
          Text('MINI ClassIsland')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text(
            this.isSuperAdminMode
              ? '超级管理平台'
              : (this.isUserCenterMode() ? '用户中心' : '账户集控中心')
          )
            .fontSize(11)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .border({ width: { bottom: 1 }, color: this.theme().borderColor })
      .onClick(() => {
        this.isSuperAdminMode = false;
        this.currentSection = 'user_home';
        this.showMobileDrawer = false;
      })

      Scroll() {
        Column({ space: 2 }) {
          if (this.isSuperAdminMode) {
            // SuperAdmin Mode Sidebar
            Column({ space: 4 }) {
              Button('← 返回用户中心')
                .width('100%')
                .height(30)
                .fontSize(12)
                .fontColor(this.theme().accentColor)
                .backgroundColor(this.theme().bgAccentSubtle)
                .borderRadius(6)
                .onClick(() => {
                  this.isSuperAdminMode = false;
                  this.currentSection = 'user_home';
                  this.showMobileDrawer = false;
                })
            }
            .width('100%')
            .padding({ left: 8, right: 8, bottom: 6 })

            this.buildSidebarGroupLabel('平台总览')
            this.buildSidebarItem($r('sys.symbol.square_grid_2x2'), '全局仪表盘', 'dashboard')

            this.buildSidebarGroupLabel('全局治理')
            this.buildSidebarItem($r('sys.symbol.person_2'), '全局用户管理', 'admin_users')
            this.buildSidebarItem($r('sys.symbol.person_badge_plus'), '注册审核', 'admin_pending')
            this.buildSidebarItem($r('sys.symbol.folder'), '全局账户与配额', 'admin_accounts')
            this.buildSidebarItem($r('sys.symbol.gearshape'), '系统参数设置', 'admin_settings')

            this.buildSidebarGroupLabel('个人安全')
            this.buildSidebarItem($r('sys.symbol.lock'), '个人资料与安全', 'security')
            this.buildSidebarItem($r('sys.symbol.doc_text'), '我的工单', 'tickets')
          } else if (this.isUserCenterMode()) {
            // USER CENTER MODE SIDEBAR (1:1 matching USER_CENTER_SECTIONS in web/components/Sidebar.tsx)
            this.buildSidebarGroupLabel('用户中心')
            this.buildSidebarItem($r('sys.symbol.house'), '账户主页', 'user_home')
            this.buildSidebarItem($r('sys.symbol.lock'), '个人资料与安全', 'security')
            this.buildSidebarItem($r('sys.symbol.doc_text'), '我的工单', 'tickets')
            if (this.isSuperAdminUser()) {
              this.buildSidebarItem($r('sys.symbol.checkmark_shield'), '超级管理面板', 'admin_entry')
            }

            Divider().color(this.theme().borderColor).margin({ top: 10, bottom: 6 })

            this.buildSidebarGroupLabel(`选择跳转账户中心 (${this.accounts.length})`)
            if (this.accounts.length === 0) {
              Text('暂无可管理的账户中心')
                .fontSize(12)
                .fontColor(this.theme().textSecondary)
                .padding({ left: 12, top: 6, bottom: 6 })
            } else {
              ForEach(this.accounts, (acc: AccountSummary) => {
                Row({ space: 8 }) {
                  HmosSymbolIcon($r('sys.symbol.folder'), 15, this.theme().accentColor)
                  Column({ space: 1 }) {
                    Text(acc.name)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme().textPrimary)
                      .maxLines(1)
                    Text(acc.slug)
                      .fontSize(11)
                      .fontColor(this.theme().textSecondary)
                      .maxLines(1)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  HmosSymbolIcon($r('sys.symbol.arrow_right'), 12, this.theme().textSecondary)
                }
                .width('100%')
                .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .borderRadius(6)
                .onClick(() => {
                  this.selectTenantAccount(acc, 'dashboard');
                })
              }, (acc: AccountSummary) => acc.id)
            }
          } else {
            // ACCOUNT CENTER MODE SIDEBAR (1:1 matching ACCOUNT_CENTER_SECTIONS in web/components/Sidebar.tsx)
            Column({ space: 8 }) {
              Row({ space: 6 }) {
                HmosSymbolIcon($r('sys.symbol.arrow_left'), 13, this.theme().accentColor)
                Text('返回用户中心')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme().accentColor)
              }
              .width('100%')
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .borderRadius(6)
              .backgroundColor(this.theme().bgAccentSubtle)
              .onClick(() => {
                this.currentSection = 'user_home';
                this.showMobileDrawer = false;
              })

              // Current Account Switcher Box
              Row({ space: 8 }) {
                Column({ space: 2 }) {
                  Text('当前账户中心')
                    .fontSize(10)
                    .fontColor(this.theme().textSecondary)
                  Text(this.currentAccountName || '选择账户')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme().textPrimary)
                    .maxLines(1)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                HmosSymbolIcon($r('sys.symbol.chevron_down'), 12, this.theme().textSecondary)
              }
              .width('100%')
              .padding(10)
              .backgroundColor(this.theme().bgCard)
              .borderRadius(6)
              .border({ width: 1, color: this.theme().borderColor })
              .onClick(() => {
                this.showAccountSelectorPopover = !this.showAccountSelectorPopover;
              })

              if (this.showAccountSelectorPopover) {
                Column({ space: 4 }) {
                  ForEach(this.accounts, (acc: AccountSummary) => {
                    Row() {
                      Text(acc.name)
                        .fontSize(12)
                        .fontWeight(acc.id === this.currentAccountId ? FontWeight.Bold : FontWeight.Normal)
                        .fontColor(acc.id === this.currentAccountId ? this.theme().accentColor : this.theme().textPrimary)
                        .layoutWeight(1)
                        .maxLines(1)
                    }
                    .width('100%')
                    .padding(8)
                    .borderRadius(4)
                    .backgroundColor(acc.id === this.currentAccountId ? this.theme().bgAccentSubtle : Color.Transparent)
                    .onClick(() => {
                      this.selectTenantAccount(acc, this.currentSection);
                    })
                  }, (acc: AccountSummary) => acc.id)
                }
                .width('100%')
                .padding(6)
                .backgroundColor(this.theme().bgCard)
                .borderRadius(6)
                .border({ width: 1, color: this.theme().borderColor })
              }
            }
            .width('100%')
            .padding({ left: 6, right: 6, bottom: 8 })
            .border({ width: { bottom: 1 }, color: this.theme().borderColor })

            this.buildSidebarGroupLabel('概览')
            this.buildSidebarItem($r('sys.symbol.square_grid_2x2'), '仪表盘', 'dashboard')

            this.buildSidebarGroupLabel('档案管理')
            this.buildSidebarItem($r('sys.symbol.book'), '科目管理', 'res_Subjects')
            this.buildSidebarItem($r('sys.symbol.clock'), '时间表管理', 'res_TimeLayout')
            this.buildSidebarItem($r('sys.symbol.calendar'), '课表管理', 'res_ClassPlan')
            this.buildSidebarItem($r('sys.symbol.checkmark_shield'), '策略管理', 'res_Policy')
            this.buildSidebarItem($r('sys.symbol.gearshape'), '默认设置', 'res_DefaultSettings')
            this.buildSidebarItem($r('sys.symbol.square_grid_2x2'), '组件设置', 'res_Components')
            this.buildSidebarItem($r('sys.symbol.key'), '凭据管理', 'res_Credentials')

            this.buildSidebarGroupLabel('客户端')
            this.buildSidebarItem($r('sys.symbol.display'), '客户端管理', 'clients')
            this.buildSidebarItem($r('sys.symbol.bell'), '通知推送', 'notifications')
            this.buildSidebarItem($r('sys.symbol.doc_text'), '审计日志', 'audit')

            this.buildSidebarGroupLabel('接入管理')
            this.buildSidebarItem($r('sys.symbol.qrcode'), '配对码管理', 'pairing')
            this.buildSidebarItem($r('sys.symbol.checkmark_circle'), '预注册客户端', 'prereg')

            this.buildSidebarGroupLabel('账户配置')
            this.buildSidebarItem($r('sys.symbol.gearshape'), '账户基础信息', 'account')
            this.buildSidebarItem($r('sys.symbol.person_2'), '访问控制', 'access')
            this.buildSidebarItem($r('sys.symbol.person_badge_plus'), '邀请管理', 'invitations')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding(10)
      }
      .layoutWeight(1)

      // Bottom User Card
      Row({ space: 10 }) {
        Column() {
          HmosSymbolIcon($r('sys.symbol.person'), 15, '#FFFFFF')
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(this.theme().accentColor)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 2 }) {
          Text(this.currentUser?.display_name || this.currentUser?.username || '用户')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().textPrimary)
            .maxLines(1)
          Text(this.currentUser?.email || getSystemRoleLabel(this.currentUser?.role_code || this.currentUser?.role || 'user'))
            .fontSize(11)
            .fontColor(this.theme().textSecondary)
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        HmosIconButton(
          $r('sys.symbol.arrow_right'),
          this.theme().dangerColor,
          Color.Transparent,
          this.theme().borderColor,
          () => {
            this.handleLogout();
          },
          28,
          14
        )
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 + this.safeBottomVp })
      .border({ width: { top: 1 }, color: this.theme().borderColor })
    }
    .width(248)
    .height('100%')
    .padding({ top: this.breakpoint === 'lg' ? 0 : this.safeTopVp })
    .backgroundColor(this.theme().bgSidebar)
    .border({ width: { right: 1 }, color: this.theme().borderColor })
  }

  @Builder
  buildMainActiveView() {
    Column({ space: 14 }) {
      if (this.globalBannerMsg.length > 0) {
        Row({ space: 8 }) {
          Text(this.globalBannerMsg)
            .fontSize(13)
            .fontColor(this.globalBannerIsError ? this.theme().badgeDangerFg : this.theme().badgeSuccessFg)
            .layoutWeight(1)
          Button('关闭')
            .height(24)
            .fontSize(11)
            .fontColor(this.theme().textSecondary)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.globalBannerMsg = '';
            })
        }
        .width('100%')
        .padding(10)
        .backgroundColor(this.globalBannerIsError ? this.theme().badgeDangerBg : this.theme().badgeSuccessBg)
        .borderRadius(6)
      }

      if (this.currentSection === 'admin_entry') {
        Row().height(0).onAppear(() => {
          this.isSuperAdminMode = true;
          this.currentSection = 'dashboard';
          this.loadSuperAdminMetrics();
        })
      }

      if (this.currentSection === 'user_home') {
        AuthAndAccountView({
          mode: 'user_home',
          breakpoint: this.breakpoint,
          themeMode: this.themeMode,
          currentUser: this.currentUser,
          accounts: this.accounts,
          onSelectAccount: (acc: AccountSummary) => {
            this.selectTenantAccount(acc, 'dashboard');
          },
          onNavigateAccountSection: (acc: AccountSummary, sec: string) => {
            this.selectTenantAccount(acc, sec);
          },
          onNavigateSection: (sec: string) => {
            this.currentSection = sec;
          },
          onEnterSuperAdmin: () => {
            this.isSuperAdminMode = true;
            this.currentSection = 'dashboard';
            this.loadSuperAdminMetrics();
          },
          onRefreshAccounts: () => {
            this.loadMyAccounts();
          },
          onLogout: () => {
            this.handleLogout();
          }
        })
      } else if (this.currentSection === 'tickets') {
        AuthAndAccountView({
          mode: 'tickets',
          breakpoint: this.breakpoint,
          themeMode: this.themeMode,
          currentUser: this.currentUser,
          accounts: this.accounts
        })
      } else if (this.currentSection === 'dashboard') {
        DashboardView({
          isSuperAdminMode: this.isSuperAdminMode,
          isSuperAdminTakeover: this.isSuperAdminTakeover,
          currentAccountId: this.currentAccountId,
          currentAccountName: this.currentAccountName,
          currentAccountSlug: this.currentAccountSlug,
          breakpoint: this.breakpoint,
          themeMode: this.themeMode,
          dashOnlineClients: this.dashOnlineClients,
          dashTotalClients: this.dashTotalClients,
          dashPendingPairings: this.dashPendingPairings,
          dashTotalResources: this.dashTotalResources,
          dashRecentAudits: this.dashRecentAudits,
          adminGlobalStats: this.adminGlobalStats,
          onNavigateSection: (sec: string) => {
            this.currentSection = sec;
          },
          onExitTakeover: () => {
            this.isSuperAdminTakeover = false;
            this.isSuperAdminMode = true;
            this.currentSection = 'admin_accounts';
          },
          onRefreshStats: () => {
            if (this.isSuperAdminMode) {
              this.loadSuperAdminMetrics();
            } else {
              this.loadTenantDashboardMetrics();
            }
          }
        })
      } else if (this.currentSection.indexOf('res_') === 0) {
        ProfileEditorView({
          accountId: this.currentAccountId,
          resourceType: this.currentSection.substring(4),
          breakpoint: this.breakpoint,
          themeMode: this.themeMode
        })
      } else if (
        this.currentSection === 'clients' ||
        this.currentSection === 'notifications' ||
        this.currentSection === 'audit'
      ) {
        ClientsAndOpsView({
          accountId: this.currentAccountId,
          subMode: this.currentSection,
          breakpoint: this.breakpoint,
          themeMode: this.themeMode
        })
      } else {
        AdmissionAndGovernanceView({
          accountId: this.currentAccountId,
          subMode: this.currentSection,
          breakpoint: this.breakpoint,
          themeMode: this.themeMode,
          onTakeoverTenant: (acc: AdminAccountItem) => {
            this.isSuperAdminMode = false;
            this.isSuperAdminTakeover = true;
            this.currentAccountId = acc.id;
            this.currentAccountName = acc.name;
            this.currentAccountSlug = acc.slug;
            this.currentSection = 'dashboard';
            this.loadTenantDashboardMetrics();
          },
          onRefreshAccounts: () => {
            this.loadMyAccounts();
          }
        })
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      if (!this.isLoggedIn) {
        AuthAndAccountView({
          mode: 'login',
          breakpoint: this.breakpoint,
          themeMode: this.themeMode,
          safeTopVp: this.safeTopVp,
          safeBottomVp: this.safeBottomVp,
          safeRightVp: this.safeRightVp,
          captionRightReserveVp: this.captionRightReserveVp,
          currentUser: this.currentUser,
          accounts: this.accounts,
          onThemeChange: (nextMode: string) => {
            this.themeMode = nextMode;
            AppStorage.setOrCreate<string>('themeMode', nextMode);
          },
          onAuthCompleted: async (token: string, user: UserInfo) => {
            this.currentUser = user;
            this.isLoggedIn = true;
            this.isSuperAdminMode = false;
            this.currentSection = 'user_home';
            await this.loadMyAccounts();
            this.persistCurrentSession();
          }
        })
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            this.buildTopBar()

            Row() {
              if (this.breakpoint === 'lg') {
                this.buildSidebar()
              }

              Scroll() {
                Column() {
                  this.buildMainActiveView()
                }
                .width('100%')
                .constraintSize({ maxWidth: 1320 })
                .padding({
                  left: Math.max(this.breakpoint === 'sm' ? 16 : 28, this.safeLeftVp),
                  right: Math.max(this.breakpoint === 'sm' ? 16 : 28, this.safeRightVp),
                  top: this.breakpoint === 'sm' ? 16 : 24,
                  bottom: (this.breakpoint === 'sm' ? 24 : 36) + this.safeBottomVp
                })
              }
              .layoutWeight(1)
              .height('100%')
              .align(Alignment.TopStart)
              .backgroundColor(this.theme().bgPrimary)
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')

          if (this.showUserMenuPopover) {
            Stack({ alignContent: Alignment.TopEnd }) {
              Column()
                .width('100%')
                .height('100%')
                .onClick(() => {
                  this.showUserMenuPopover = false;
                })
              Column({ space: 4 }) {
                Column({ space: 2 }) {
                  Text(this.currentUser?.display_name || this.currentUser?.username || '')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme().textPrimary)
                  Text(this.currentUser?.email || '')
                    .fontSize(11)
                    .fontColor(this.theme().textSecondary)
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(8)
                .border({ width: { bottom: 1 }, color: this.theme().borderColor })

                Row({ space: 8 }) {
                  HmosSymbolIcon($r('sys.symbol.house'), 14, this.theme().textPrimary)
                  Text('用户中心主页').fontSize(13).fontColor(this.theme().textPrimary)
                }
                .width('100%')
                .padding(8)
                .borderRadius(4)
                .onClick(() => {
                  this.showUserMenuPopover = false;
                  this.isSuperAdminMode = false;
                  this.currentSection = 'user_home';
                })

                Row({ space: 8 }) {
                  HmosSymbolIcon($r('sys.symbol.lock'), 14, this.theme().textPrimary)
                  Text('个人资料与安全').fontSize(13).fontColor(this.theme().textPrimary)
                }
                .width('100%')
                .padding(8)
                .borderRadius(4)
                .onClick(() => {
                  this.showUserMenuPopover = false;
                  this.isSuperAdminMode = false;
                  this.currentSection = 'security';
                })

                Row({ space: 8 }) {
                  HmosSymbolIcon($r('sys.symbol.doc_text'), 14, this.theme().textPrimary)
                  Text('我的工单').fontSize(13).fontColor(this.theme().textPrimary)
                }
                .width('100%')
                .padding(8)
                .borderRadius(4)
                .onClick(() => {
                  this.showUserMenuPopover = false;
                  this.isSuperAdminMode = false;
                  this.currentSection = 'tickets';
                })

                if (this.isSuperAdminUser()) {
                  Row({ space: 8 }) {
                    HmosSymbolIcon($r('sys.symbol.checkmark_shield'), 14, this.theme().accentColor)
                    Text('超级管理面板').fontSize(13).fontColor(this.theme().accentColor)
                  }
                  .width('100%')
                  .padding(8)
                  .borderRadius(4)
                  .onClick(() => {
                    this.showUserMenuPopover = false;
                    this.isSuperAdminMode = true;
                    this.currentSection = 'dashboard';
                    this.loadSuperAdminMetrics();
                  })
                }

                Divider().color(this.theme().borderColor).margin({ top: 2, bottom: 2 })

                Row({ space: 8 }) {
                  HmosSymbolIcon($r('sys.symbol.arrow_right'), 14, this.theme().dangerColor)
                  Text('退出登录').fontSize(13).fontColor(this.theme().dangerColor)
                }
                .width('100%')
                .padding(8)
                .borderRadius(4)
                .onClick(() => {
                  this.handleLogout();
                })
              }
              .width(210)
              .padding(8)
              .margin({ top: 54 + this.safeTopVp, right: 16 + this.safeRightVp })
              .backgroundColor(this.theme().bgCard)
              .borderRadius(8)
              .border({ width: 1, color: this.theme().borderColor })
              .shadow({ radius: 16, color: '#26000000', offsetX: 0, offsetY: 6 })
            }
            .width('100%')
            .height('100%')
          }

          if (this.breakpoint !== 'lg' && this.showMobileDrawer) {
            Row() {
              this.buildSidebar()
              Column()
                .layoutWeight(1)
                .height('100%')
                .backgroundColor('#66000000')
                .onClick(() => {
                  this.showMobileDrawer = false;
                })
            }
            .width('100%')
            .height('100%')
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldVal: Area, newVal: Area) => {
      const w = Number(newVal.width || 390);
      this.windowWidthVp = w;
      if (w >= 900) {
        this.breakpoint = 'lg';
      } else if (w >= 600) {
        this.breakpoint = 'md';
      } else {
        this.breakpoint = 'sm';
      }
    })
  }
}
