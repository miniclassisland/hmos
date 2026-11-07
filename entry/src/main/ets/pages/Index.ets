import {
  UserInfo,
  AccountSummary,
  AdminAccountItem,
  GlobalStats
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosSymbolIcon } from '../components/HmosIcons';
import { AuthAndAccountView } from '../components/AuthAndAccountView';
import { DashboardView } from '../components/DashboardView';
import { ProfileEditorView } from '../components/ProfileEditorView';
import { ClientsAndOpsView } from '../components/ClientsAndOpsView';
import { AdmissionAndGovernanceView } from '../components/AdmissionAndGovernanceView';

interface NavMenuItem {
  key: string;
  label: string;
}

interface NavMenuSection {
  title: string;
  items: NavMenuItem[];
}

@Entry
@Component
struct Index {
  // Adaptive, Safe-Area & PC Integrated TitleBar properties synced from EntryAbility
  @StorageProp('breakpoint') breakpoint: string = 'sm';
  @StorageProp('windowWidthVp') windowWidthVp: number = 360;
  @StorageProp('windowHeightVp') windowHeightVp: number = 780;
  @StorageProp('windowStatusType') windowStatusType: number = 0;
  @StorageProp('safeTopVp') safeTopVp: number = 0;
  @StorageProp('safeBottomVp') safeBottomVp: number = 0;
  @StorageProp('safeLeftVp') safeLeftVp: number = 0;
  @StorageProp('safeRightVp') safeRightVp: number = 0;
  @StorageProp('isPcMode') isPcMode: boolean = false;
  @StorageProp('decorHeightVp') decorHeightVp: number = 48;
  @StorageProp('captionRightReserveVp') captionRightReserveVp: number = 0;

  // DeepLink state synced from EntryAbility
  @StorageLink('pendingCertUri') @Watch('onPendingCertUriChanged') pendingCertUri: string = '';
  @StorageLink('pendingQrLoginUri') @Watch('onPendingQrLoginUriChanged') pendingQrLoginUri: string = '';

  @State themeMode: string = 'light';
  @State isLoggedIn: boolean = false;
  @State currentUser: UserInfo | null = null;
  @State accounts: AccountSummary[] = [];
  @State currentAccountId: number = 0;
  @State currentAccountName: string = '';
  @State currentAccountSlug: string = '';

  @State isSuperAdminMode: boolean = false;
  @State isSuperAdminTakeover: boolean = false;
  @State showUserMenuPopover: boolean = false;
  @State showMobileDrawer: boolean = false;
  @State currentSection: string = 'dashboard';

  // Dashboard Metrics
  @State dashOnlineClients: number = 0;
  @State dashTotalClients: number = 0;
  @State dashPendingPairings: number = 0;
  @State dashTotalResources: number = 0;
  @State dashRecentAudits: number = 0;
  @State adminGlobalStats: GlobalStats | null = null;

  @State deepLinkBannerMsg: string = '';

  private tenantNavSections: NavMenuSection[] = [
    {
      title: '概览',
      items: [
        { key: 'dashboard', label: '仪表盘' }
      ]
    },
    {
      title: '档案管理',
      items: [
        { key: 'res_Subjects', label: '科目管理' },
        { key: 'res_TimeLayout', label: '时间表管理' },
        { key: 'res_ClassPlan', label: '课表管理' },
        { key: 'res_Policy', label: '策略管理' },
        { key: 'res_DefaultSettings', label: '默认设置' },
        { key: 'res_Components', label: '组件设置' },
        { key: 'res_Credentials', label: '凭据管理' }
      ]
    },
    {
      title: '客户端',
      items: [
        { key: 'clients', label: '客户端管理' },
        { key: 'notifications', label: '通知推送' },
        { key: 'audit', label: '审计日志' }
      ]
    },
    {
      title: '接入管理',
      items: [
        { key: 'pairing', label: '配对码管理' },
        { key: 'prereg', label: '预注册客户端' }
      ]
    },
    {
      title: '账户',
      items: [
        { key: 'account', label: '账户概览' },
        { key: 'access', label: '访问控制' },
        { key: 'invitations', label: '邀请管理' }
      ]
    },
    {
      title: '安全',
      items: [
        { key: 'security', label: '安全设置' }
      ]
    }
  ];

  private superAdminNavItems: NavMenuItem[] = [
    { key: 'admin_dashboard', label: '全局仪表盘' },
    { key: 'admin_users', label: '全局用户管理' },
    { key: 'admin_pending', label: '注册审核' },
    { key: 'admin_accounts', label: '全局账户与配额' },
    { key: 'admin_settings', label: '系统参数设置' }
  ];

  aboutToAppear(): void {
    if (this.pendingCertUri && this.pendingCertUri.trim().length > 0) {
      this.onPendingCertUriChanged();
    }
    if (this.pendingQrLoginUri && this.pendingQrLoginUri.trim().length > 0) {
      this.onPendingQrLoginUriChanged();
    }
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private async onPendingCertUriChanged(): Promise<void> {
    const uri = (this.pendingCertUri || '').trim();
    if (!uri) {
      return;
    }
    this.pendingCertUri = '';
    const api = ApiService.get();
    const r = await api.redeemCertificate(uri);
    if (!r.ok || !r.data) {
      this.deepLinkBannerMsg = r.error || '通过深链接兑换登录安全证书失败';
      return;
    }
    if (api.token.length === 0) {
      await api.requestSessionFromCertificate(3600);
    }
    if (api.token.length > 0) {
      const pRes = await api.getProfile();
      if (pRes.ok && pRes.data) {
        await this.onAuthSuccess(api.token, pRes.data);
        this.deepLinkBannerMsg = `已下载安全证书并自动登录`;
      }
    }
  }

  private async onPendingQrLoginUriChanged(): Promise<void> {
    const uri = (this.pendingQrLoginUri || '').trim();
    if (!uri) {
      return;
    }
    this.pendingQrLoginUri = '';
    const r = await ApiService.get().authorizeWebQrLogin(uri);
    if (r.ok) {
      this.deepLinkBannerMsg = '已通过扫码 DeepLink 成功授权网页端登录';
    } else {
      this.deepLinkBannerMsg = r.error || '网页端扫码登录授权失败';
    }
  }

  private async onAuthSuccess(token: string, user: UserInfo): Promise<void> {
    ApiService.get().setToken(token);
    this.currentUser = user;
    this.isLoggedIn = true;
    this.currentAccountId = 0;
    await this.refreshAccountsList();
  }

  private async refreshAccountsList(): Promise<void> {
    const accRes = await ApiService.get().listMyAccounts();
    if (accRes.ok && accRes.data) {
      this.accounts = accRes.data;
    }
  }

  private selectAccountAndEnter(acc: AccountSummary): void {
    this.currentAccountId = acc.id;
    this.currentAccountName = acc.name;
    this.currentAccountSlug = acc.slug;
    this.isSuperAdminMode = false;
    this.isSuperAdminTakeover = false;
    this.currentSection = 'dashboard';
    this.refreshDashboardMetrics();
  }

  private async refreshDashboardMetrics(): Promise<void> {
    const api = ApiService.get();
    if (this.isSuperAdminMode) {
      const gRes = await api.getGlobalStats();
      if (gRes.ok && gRes.data) {
        this.adminGlobalStats = gRes.data;
      }
      return;
    }
    if (this.currentAccountId <= 0) {
      return;
    }
    const cRes = await api.listClients(this.currentAccountId);
    if (cRes.ok && cRes.data) {
      this.dashTotalClients = cRes.data.length;
      let online = 0;
      for (let i = 0; i < cRes.data.length; i++) {
        if (cRes.data[i].status === 'online') {
          online++;
        }
      }
      this.dashOnlineClients = online;
    }
    const pRes = await api.listPairingRequests(this.currentAccountId, 'pending');
    if (pRes.ok && pRes.data) {
      this.dashPendingPairings = pRes.data.length;
    }
    const aRes = await api.listAuditLogs(this.currentAccountId, '', 'all');
    if (aRes.ok && aRes.data) {
      this.dashRecentAudits = aRes.data.length;
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
  }

  @Builder
  buildThemeModeToggle() {
    Row({ space: 2 }) {
      ForEach([
        ['system', '自动'],
        ['light', '浅色'],
        ['dark', '深色']
      ], (item: string[]) => {
        Text(item[1])
          .fontSize(12)
          .fontWeight(this.themeMode === item[0] ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.themeMode === item[0] ? this.theme().accentColor : this.theme().textSecondary)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(4)
          .backgroundColor(this.themeMode === item[0] ? this.theme().bgAccentSubtle : Color.Transparent)
          .onClick(() => {
            this.themeMode = item[0];
          })
      }, (item: string[]) => item[0])
    }
    .padding(2)
    .borderRadius(6)
    .backgroundColor(this.theme().bgSubtle)
    .border({ width: 1, color: this.theme().borderColor })
  }

  @Builder
  buildTopBar() {
    Column() {
      Row({ space: 12 }) {
        if (this.breakpoint === 'sm') {
          HmosIconButton(
            $r('sys.symbol.line_3_horizontal'),
            this.theme().textPrimary,
            this.theme().bgSubtle,
            this.theme().borderColor,
            () => {
              this.showMobileDrawer = !this.showMobileDrawer;
              this.showUserMenuPopover = false;
            },
            34,
            16
          )
        }

        Text(this.isSuperAdminMode ? 'MINI ClassIsland 超级管理平台' : 'MINI ClassIsland 管理面板')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)
          .maxLines(1)

        this.buildThemeModeToggle()

        Row({ space: 8 }) {
          Column() {
            Text(
              (this.currentAccountName || this.currentUser?.display_name || this.currentUser?.username || 'U')
                .substring(0, 1)
                .toUpperCase()
            )
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(26)
          .height(26)
          .borderRadius(13)
          .backgroundColor(this.theme().accentColor)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          if (this.breakpoint !== 'sm') {
            Text(this.isSuperAdminMode ? (this.currentUser?.username || '超级管理员') : (this.currentAccountName || '账户'))
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .constraintSize({ maxWidth: 140 })
              .maxLines(1)
          }

          HmosSymbolIcon($r('sys.symbol.chevron_down'), 12, this.theme().textSecondary)
        }
        .padding({ left: 8, right: 10, top: 4, bottom: 4 })
        .backgroundColor(this.theme().bgCard)
        .borderRadius(6)
        .border({ width: 1, color: this.theme().borderColor })
        .onClick(() => {
          this.showUserMenuPopover = !this.showUserMenuPopover;
        })
      }
      .width('100%')
      .height(48 + (this.breakpoint === 'sm' ? this.safeTopVp : 0))
      .padding({
        left: 16 + (this.breakpoint === 'sm' ? this.safeLeftVp : 0),
        right: 16 + Math.max(this.safeRightVp, this.captionRightReserveVp),
        top: this.breakpoint === 'sm' ? this.safeTopVp : 0
      })
      .backgroundColor(this.theme().bgCard)

      Divider().color(this.theme().borderColor)
    }
    .width('100%')
  }

  @Builder
  buildUserMenuDropdown() {
    Column({ space: 4 }) {
      Row({ space: 10 }) {
        Column() {
          Text(
            (this.currentAccountName || this.currentUser?.display_name || this.currentUser?.username || 'U')
              .substring(0, 1)
              .toUpperCase()
          )
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.theme().accentColor)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 2 }) {
          Text(this.currentUser?.display_name || this.currentUser?.username || '当前用户')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text(this.currentUser?.role === 'superadmin' ? '超级管理员' : '普通用户')
            .fontSize(12)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(8)

      if (!this.isSuperAdminMode && this.currentAccountId > 0) {
        Divider().color(this.theme().borderColor).margin({ top: 4, bottom: 4 })
        Column({ space: 2 }) {
          Text('当前账户').fontSize(11).fontColor(this.theme().textSecondary)
          Text(`${this.currentAccountName}${this.currentAccountSlug ? ` (${this.currentAccountSlug})` : ''}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }

      Divider().color(this.theme().borderColor).margin({ top: 4, bottom: 4 })

      Button('切换账户')
        .width('100%')
        .height(34)
        .fontSize(13)
        .fontColor(this.theme().textPrimary)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showUserMenuPopover = false;
          this.isSuperAdminMode = false;
          this.currentAccountId = 0;
          this.refreshAccountsList();
        })

      if (this.currentUser?.role === 'superadmin') {
        Button(this.isSuperAdminMode ? '返回集控管理面板' : '超级管理面板')
          .width('100%')
          .height(34)
          .fontSize(13)
          .fontColor(this.theme().accentColor)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showUserMenuPopover = false;
            if (this.isSuperAdminMode) {
              this.isSuperAdminMode = false;
              if (this.accounts.length > 0) {
                this.selectAccountAndEnter(this.accounts[0]);
              } else {
                this.currentAccountId = 0;
              }
            } else {
              this.isSuperAdminMode = true;
              this.currentAccountId = -1;
              this.currentSection = 'admin_dashboard';
              this.refreshDashboardMetrics();
            }
          })
      }

      if (!this.isSuperAdminMode) {
        Button('安全设置')
          .width('100%')
          .height(34)
          .fontSize(13)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showUserMenuPopover = false;
            this.currentSection = 'security';
          })
      }

      Divider().color(this.theme().borderColor).margin({ top: 4, bottom: 4 })

      Button('登出')
        .width('100%')
        .height(34)
        .fontSize(13)
        .fontColor(this.theme().dangerColor)
        .backgroundColor(Color.Transparent)
        .onClick(async () => {
          this.showUserMenuPopover = false;
          await ApiService.get().logout();
          this.isLoggedIn = false;
          this.currentAccountId = 0;
        })
    }
    .width(240)
    .padding(8)
    .backgroundColor(this.theme().bgCard)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().borderColor })
    .shadow({ radius: 16, color: '#24000000', offsetX: 0, offsetY: 4 })
  }

  @Builder
  buildSidebar() {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.app_icon'))
          .width(26)
          .height(26)
          .borderRadius(6)
        Text(this.isSuperAdminMode ? 'MINI ClassIsland 超管平台' : 'MINI ClassIsland 管理面板')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)
          .maxLines(1)
      }
      .width('100%')
      .height(48 + (this.breakpoint !== 'sm' ? this.safeTopVp : 0))
      .padding({
        left: 18 + this.safeLeftVp,
        right: 18,
        top: this.breakpoint !== 'sm' ? this.safeTopVp : 0
      })
      .border({ width: { bottom: 1 }, color: this.theme().borderColor })

      Scroll() {
        Column({ space: 14 }) {
          if (this.isSuperAdminMode) {
            Column({ space: 2 }) {
              ForEach(this.superAdminNavItems, (item: NavMenuItem) => {
                Row() {
                  Text(item.label)
                    .fontSize(13)
                    .fontWeight(this.currentSection === item.key ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.currentSection === item.key ? this.theme().accentColor : this.theme().textPrimary)
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 9, bottom: 9 })
                .borderRadius(6)
                .backgroundColor(this.currentSection === item.key ? this.theme().bgAccentSubtle : Color.Transparent)
                .onClick(() => {
                  this.currentSection = item.key;
                  this.showMobileDrawer = false;
                })
              }, (item: NavMenuItem) => item.key)
            }
            .width('100%')
          } else {
            ForEach(this.tenantNavSections, (sec: NavMenuSection) => {
              Column({ space: 2 }) {
                Text(sec.title)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textSecondary)
                  .padding({ left: 12, bottom: 4 })
                  .width('100%')

                ForEach(sec.items, (item: NavMenuItem) => {
                  Row() {
                    Text(item.label)
                      .fontSize(13)
                      .fontWeight(this.currentSection === item.key ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.currentSection === item.key ? this.theme().accentColor : this.theme().textPrimary)
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .borderRadius(6)
                  .backgroundColor(this.currentSection === item.key ? this.theme().bgAccentSubtle : Color.Transparent)
                  .onClick(() => {
                    this.currentSection = item.key;
                    this.showMobileDrawer = false;
                  })
                }, (item: NavMenuItem) => item.key)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }, (sec: NavMenuSection) => sec.title)
          }
        }
        .width('100%')
        .padding({
          left: 10 + this.safeLeftVp,
          right: 10,
          top: 12,
          bottom: 16 + this.safeBottomVp
        })
      }
      .layoutWeight(1)

      if (this.isSuperAdminMode) {
        Column() {
          Divider().color(this.theme().borderColor)
          Row({ space: 8 }) {
            Button('返回集控主面板')
              .width('100%')
              .height(34)
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
              .backgroundColor(this.theme().bgCard)
              .border({ width: 1, color: this.theme().borderColor, radius: 6 })
              .onClick(() => {
                this.isSuperAdminMode = false;
                if (this.accounts.length > 0) {
                  this.selectAccountAndEnter(this.accounts[0]);
                } else {
                  this.currentAccountId = 0;
                }
              })
          }
          .padding({ left: 12 + this.safeLeftVp, right: 12, top: 12, bottom: 12 + this.safeBottomVp })
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgSidebar)
    .border({ width: { right: 1 }, color: this.theme().borderColor })
  }

  @Builder
  buildMainActiveView() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.deepLinkBannerMsg.length > 0) {
          Row({ space: 8 }) {
            Text(this.deepLinkBannerMsg)
              .fontSize(12)
              .fontColor(this.theme().badgeInfoFg)
              .layoutWeight(1)
            HmosIconButton(
              $r('sys.symbol.xmark'),
              this.theme().badgeInfoFg,
              Color.Transparent,
              Color.Transparent,
              () => {
                this.deepLinkBannerMsg = '';
              },
              24,
              12
            )
          }
          .width('100%')
          .padding(10)
          .backgroundColor(this.theme().badgeInfoBg)
          .borderRadius(6)
        }

        if ((this.isSuperAdminMode && this.currentSection === 'admin_dashboard') || this.currentSection === 'dashboard') {
          DashboardView({
            isSuperAdminMode: this.isSuperAdminMode && this.currentSection === 'admin_dashboard',
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
              this.refreshDashboardMetrics();
            }
          })
        } else if (this.currentSection.indexOf('res_') === 0) {
          ProfileEditorView({
            accountId: this.currentAccountId,
            resourceType: this.currentSection.substring(4),
            breakpoint: this.breakpoint,
            themeMode: this.themeMode
          })
        } else if (this.currentSection === 'clients' || this.currentSection === 'notifications' || this.currentSection === 'audit') {
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
              this.currentAccountId = acc.id;
              this.currentAccountName = acc.name;
              this.currentAccountSlug = acc.slug;
              this.isSuperAdminMode = false;
              this.isSuperAdminTakeover = true;
              this.currentSection = 'dashboard';
              this.refreshDashboardMetrics();
            }
          })
        }
      }
      .width('100%')
      .padding({
        left: (this.breakpoint === 'sm' ? 16 : 24) + (this.breakpoint === 'sm' ? this.safeLeftVp : 0),
        right: (this.breakpoint === 'sm' ? 16 : 24) + this.safeRightVp,
        top: this.breakpoint === 'sm' ? 16 : 24,
        bottom: (this.breakpoint === 'sm' ? 16 : 24) + this.safeBottomVp
      })
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(this.theme().bgPrimary)
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
          },
          onAuthCompleted: (token: string, user: UserInfo) => {
            this.onAuthSuccess(token, user);
          },
          onSelectAccount: (acc: AccountSummary) => {
            this.selectAccountAndEnter(acc);
          },
          onEnterSuperAdmin: () => {
            this.isSuperAdminMode = true;
            this.currentAccountId = -1;
            this.currentSection = 'admin_dashboard';
            this.refreshDashboardMetrics();
          },
          onRefreshAccounts: () => {
            this.refreshAccountsList();
          },
          onLogout: async () => {
            await ApiService.get().logout();
            this.isLoggedIn = false;
            this.currentAccountId = 0;
          }
        })
      } else if (!this.isSuperAdminMode && this.currentAccountId <= 0) {
        AuthAndAccountView({
          mode: 'accounts',
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
          },
          onAuthCompleted: (token: string, user: UserInfo) => {
            this.onAuthSuccess(token, user);
          },
          onSelectAccount: (acc: AccountSummary) => {
            this.selectAccountAndEnter(acc);
          },
          onEnterSuperAdmin: () => {
            this.isSuperAdminMode = true;
            this.currentAccountId = -1;
            this.currentSection = 'admin_dashboard';
            this.refreshDashboardMetrics();
          },
          onRefreshAccounts: () => {
            this.refreshAccountsList();
          },
          onLogout: async () => {
            await ApiService.get().logout();
            this.isLoggedIn = false;
            this.currentAccountId = 0;
          }
        })
      } else {
        Stack({ alignContent: Alignment.TopEnd }) {
          if (this.breakpoint === 'sm') {
            Column() {
              this.buildTopBar()
              if (this.showMobileDrawer) {
                Column() {
                  this.buildSidebar()
                }
                .width('100%')
                .layoutWeight(1)
              } else {
                this.buildMainActiveView()
              }
            }
            .width('100%')
            .height('100%')
          } else {
            Row() {
              Column() {
                this.buildSidebar()
              }
              .width(250 + this.safeLeftVp)
              .height('100%')

              Column() {
                if (this.safeTopVp > 0) {
                  Row()
                    .width('100%')
                    .height(this.safeTopVp)
                    .backgroundColor(this.theme().bgCard)
                }
                this.buildTopBar()
                this.buildMainActiveView()
              }
              .layoutWeight(1)
              .height('100%')
            }
            .width('100%')
            .height('100%')
          }

          if (this.showUserMenuPopover) {
            Column() {
              this.buildUserMenuDropdown()
            }
            .margin({
              top: 52 + this.safeTopVp,
              right: 16 + Math.max(this.safeRightVp, this.captionRightReserveVp)
            })
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgPrimary)
  }
}
