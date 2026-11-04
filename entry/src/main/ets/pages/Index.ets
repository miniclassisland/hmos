import {
  UserInfo,
  AccountSummary,
  ClientRecord,
  PairingRequestItem,
  AuditLogItem,
  AdminAccountItem,
  GlobalStats
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
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

  // Theme Mode ('system' | 'light' | 'dark') matching Web ThemeModeToggle
  @State themeMode: string = 'light';

  // Endpoint & Auth State (matching web/app/login/page.tsx)
  @State managementEndpoint: string = 'https://api.miniclassisland.com';
  @State adminEndpoint: string = 'https://admin.miniclassisland.com/api';
  @State showEndpointConfig: boolean = false;
  @State isLoggedIn: boolean = false;
  @State loginStep: string = 'email'; // 'email' | 'login' | 'register' | 'totp' | 'oobe'
  @State useAdminAuthEndpoint: boolean = false;

  @State emailInput: string = '';
  @State loginUsername: string = '';
  @State loginPassword: string = '';
  @State regDisplayName: string = '';
  @State totpSession: string = '';
  @State totpCode: string = '';
  @State totpUseRecovery: boolean = false;
  @State authError: string = '';
  @State authInfoMsg: string = '';
  @State isSubmitting: boolean = false;

  // OOBE Wizard State
  @State oobePasscode: string = '';
  @State oobeVerified: boolean = false;
  @State oobePgUrl: string = 'postgres://postgres:postgres@localhost:5432/miniclassisland?sslmode=disable';
  @State oobeRedisUrl: string = 'redis://localhost:6379/0';
  @State oobeDomain: string = 'api.miniclassisland.com';
  @State oobeAdminUser: string = 'admin';
  @State oobeAdminEmail: string = 'admin@example.com';
  @State oobeAdminPassword: string = '';

  // Session & Multi-Tenant Context (matching web/app/page.tsx AccountListPage)
  @State currentUser: UserInfo | null = null;
  @State accounts: AccountSummary[] = [];
  @State currentAccountId: number = 0;
  @State currentAccountName: string = '';
  @State currentAccountSlug: string = '';
  @State showCreateAccountDialog: boolean = false;
  @State showJoinInviteDialog: boolean = false;
  @State newTenantName: string = '';
  @State newTenantSlug: string = '';
  @State inviteCodeInput: string = '';

  // AppShell Mode & Menus (matching web/components/TopBar.tsx & UserMenu.tsx & Sidebar.tsx)
  @State isSuperAdminMode: boolean = false;
  @State isSuperAdminTakeover: boolean = false;
  @State showUserMenuPopover: boolean = false;
  @State showMobileDrawer: boolean = false;
  @State currentSection: string = 'dashboard';

  // Dashboard Metrics (matching web/app/dashboard/page.tsx)
  @State dashOnlineClients: number = 0;
  @State dashTotalClients: number = 0;
  @State dashPendingPairings: number = 0;
  @State dashTotalResources: number = 0;
  @State dashRecentAudits: number = 0;
  @State dashPresetJson: string = '';
  @State adminGlobalStats: GlobalStats | null = null;

  // Exact 6 navigation sections from web/components/Sidebar.tsx
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

  // Exact SuperAdmin navigation from admin/components/AdminShell.tsx
  private superAdminNavItems: NavMenuItem[] = [
    { key: 'admin_dashboard', label: '全局仪表盘' },
    { key: 'admin_users', label: '全局用户管理' },
    { key: 'admin_pending', label: '注册审核' },
    { key: 'admin_accounts', label: '全局账户与配额' },
    { key: 'admin_settings', label: '系统参数设置' }
  ];

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private async handleEmailCheck(): Promise<void> {
    const trimmed = this.emailInput.trim();
    if (trimmed.length === 0) {
      return;
    }
    this.authError = '';
    this.authInfoMsg = '';
    this.isSubmitting = true;
    ApiService.get().setEndpoints(this.managementEndpoint, this.adminEndpoint);
    const res = await ApiService.get().checkMailAvailability(trimmed);
    this.isSubmitting = false;

    if (res.isOobe) {
      this.loginStep = 'oobe';
      return;
    }
    if (!res.ok) {
      // Fallback to direct login if endpoint check is unavailable or username was entered
      this.loginUsername = trimmed;
      this.loginStep = 'login';
      return;
    }
    if (res.data === true) {
      // Email is available -> go to register step
      this.loginStep = 'register';
    } else {
      // Email already exists -> go to login step
      this.loginUsername = trimmed;
      this.loginStep = 'login';
    }
  }

  private async handleLogin(): Promise<void> {
    this.authError = '';
    this.authInfoMsg = '';
    this.isSubmitting = true;
    ApiService.get().setEndpoints(this.managementEndpoint, this.adminEndpoint);
    const identifier = this.loginUsername.trim().length > 0 ? this.loginUsername.trim() : this.emailInput.trim();
    const res = await ApiService.get().login(identifier, this.loginPassword, this.useAdminAuthEndpoint);
    this.isSubmitting = false;

    if (res.isOobe) {
      this.loginStep = 'oobe';
      return;
    }
    if (!res.ok || !res.data) {
      this.authError = res.error || '登录失败';
      return;
    }
    if (res.data.totp_required) {
      this.totpSession = res.data.totp_session;
      this.loginStep = 'totp';
      return;
    }
    await this.onAuthSuccess(res.data.token, res.data.user);
  }

  private async handleRegister(): Promise<void> {
    if (this.loginPassword.length < 12) {
      this.authError = '密码长度至少为 12 个字符';
      return;
    }
    this.authError = '';
    this.isSubmitting = true;
    ApiService.get().setEndpoints(this.managementEndpoint, this.adminEndpoint);
    const email = this.emailInput.trim();
    const autoUsername = email.indexOf('@') > 0 ? email.split('@')[0] : email;
    const r = await ApiService.get().registerUser(
      autoUsername,
      email,
      this.loginPassword,
      this.regDisplayName.trim()
    );
    this.isSubmitting = false;
    if (r.ok) {
      this.loginUsername = email;
      this.loginStep = 'login';
      this.authInfoMsg = '注册成功，请登录或等待超级管理员审核通过';
    } else {
      this.authError = r.error || '注册失败';
    }
  }

  private async handleTotpVerify(): Promise<void> {
    this.authError = '';
    this.isSubmitting = true;
    const api = ApiService.get();
    const res = this.totpUseRecovery
      ? await api.recoverTotp(this.totpSession, this.totpCode, this.useAdminAuthEndpoint)
      : await api.verifyTotp(this.totpSession, this.totpCode, this.useAdminAuthEndpoint);
    this.isSubmitting = false;

    if (!res.ok || !res.data) {
      this.authError = res.error || '验证失败';
      return;
    }
    await this.onAuthSuccess(res.data.token, res.data.user);
  }

  private async onAuthSuccess(token: string, user: UserInfo): Promise<void> {
    ApiService.get().setToken(token);
    this.currentUser = user;
    this.isLoggedIn = true;
    this.currentAccountId = 0; // Show Account Selection Page (/) first, matching web/app/page.tsx
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

  // ==================== ThemeModeToggle (matches web/components/ThemeModeToggle.tsx) ====================
  @Builder
  buildThemeModeToggle(onBlueBg: boolean) {
    Row({ space: 2 }) {
      ForEach([
        ['system', '自动'],
        ['light', '浅色'],
        ['dark', '深色']
      ], (item: string[]) => {
        Text(item[1])
          .fontSize(12)
          .fontWeight(this.themeMode === item[0] ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(
            this.themeMode === item[0]
              ? (onBlueBg ? '#FFFFFF' : this.theme().accentColor)
              : (onBlueBg ? '#E0E0E0' : this.theme().textSecondary)
          )
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(4)
          .backgroundColor(
            this.themeMode === item[0]
              ? (onBlueBg ? '#33FFFFFF' : this.theme().bgAccentSubtle)
              : Color.Transparent
          )
          .onClick(() => {
            this.themeMode = item[0];
          })
      }, (item: string[]) => item[0])
    }
    .padding(2)
    .borderRadius(6)
    .backgroundColor(onBlueBg ? '#22000000' : this.theme().bgSubtle)
    .border({ width: 1, color: onBlueBg ? '#44FFFFFF' : this.theme().borderColor })
  }

  // ==================== Footer Disclaimer (matches web/app/login/page.tsx & page.tsx) ====================
  @Builder
  buildWebFooterDisclaimer() {
    Column({ space: 4 }) {
      Divider().color(this.theme().borderColor).margin({ bottom: 12 })
      Text('本项目与 ClassIsland 官方无关，ClassIsland 是由 ClassIsland 社区开发和维护的开源软件')
        .fontSize(11)
        .fontColor(this.theme().textSecondary)
        .textAlign(TextAlign.Center)
      Text('本项目由 MINIOpenSource 开发和维护，并开源在 GitHub')
        .fontSize(11)
        .fontColor(this.theme().textSecondary)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .margin({ top: 20 })
  }

  // ==================== 1. Web Login Screen (/login) ====================
  @Builder
  buildLoginScreen() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          // Centered Login Card (width: 420, borderRadius: 12, padding: 32)
          Column({ space: 14 }) {
            // Logo & Title Header
            Column({ space: 8 }) {
              Image($r('app.media.app_icon'))
                .width(64)
                .height(64)
                .borderRadius(12)
                .margin({ bottom: 4 })
              Text('欢迎来到 MINI ClassIsland')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().textPrimary)
                .textAlign(TextAlign.Center)
              Text(
                this.loginStep === 'email' ? '输入您的邮箱以继续' :
                this.loginStep === 'login' ? '欢迎回来，请登录' :
                this.loginStep === 'register' ? '创建一个新账户' :
                this.loginStep === 'totp' ? '安全验证' : '系统初始化配置 (OOBE)'
              )
                .fontSize(14)
                .fontColor(this.theme().textSecondary)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ bottom: 8 })

            // Optional collapsible Server Endpoint configuration
            if (this.showEndpointConfig) {
              Column({ space: 8 }) {
                Text('服务器接口配置')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textPrimary)
                Column({ space: 4 }) {
                  Text('集控 API 地址 (Management)').fontSize(11).fontColor(this.theme().textSecondary)
                  TextInput({ text: this.managementEndpoint })
                    .height(34)
                    .fontSize(12)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.managementEndpoint = v; })
                }.alignItems(HorizontalAlign.Start)

                Column({ space: 4 }) {
                  Text('超管 API 地址 (Admin)').fontSize(11).fontColor(this.theme().textSecondary)
                  TextInput({ text: this.adminEndpoint })
                    .height(34)
                    .fontSize(12)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.adminEndpoint = v; })
                }.alignItems(HorizontalAlign.Start)

                Row({ space: 8 }) {
                  Button('初始化向导 (OOBE)')
                    .height(28)
                    .fontSize(11)
                    .fontColor(this.theme().textSecondary)
                    .backgroundColor(this.theme().bgSubtle)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onClick(() => {
                      this.loginStep = this.loginStep === 'oobe' ? 'email' : 'oobe';
                      this.showEndpointConfig = false;
                    })
                  Blank()
                  Button('完成')
                    .height(28)
                    .fontSize(11)
                    .fontColor('#FFFFFF')
                    .backgroundColor(this.theme().accentColor)
                    .borderRadius(4)
                    .onClick(() => {
                      ApiService.get().setEndpoints(this.managementEndpoint, this.adminEndpoint);
                      this.showEndpointConfig = false;
                    })
                }.width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.theme().bgSubtle)
              .borderRadius(6)
              .border({ width: 1, color: this.theme().borderColor })
            }

            // MessageBar for Error / Info
            if (this.authError.length > 0) {
              Row() {
                Text(this.authError)
                  .fontSize(13)
                  .fontColor(this.theme().badgeDangerFg)
              }
              .width('100%')
              .padding(10)
              .backgroundColor(this.theme().badgeDangerBg)
              .borderRadius(4)
            }
            if (this.authInfoMsg.length > 0) {
              Row() {
                Text(this.authInfoMsg)
                  .fontSize(13)
                  .fontColor(this.theme().badgeSuccessFg)
              }
              .width('100%')
              .padding(10)
              .backgroundColor(this.theme().badgeSuccessBg)
              .borderRadius(4)
            }

            // Step 1: Email check (matches web/app/login/page.tsx step === "email")
            if (this.loginStep === 'email') {
              Column({ space: 14 }) {
                Column({ space: 6 }) {
                  Text('邮箱地址').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
                  TextInput({ placeholder: 'you@example.com', text: this.emailInput })
                    .height(38)
                    .fontSize(14)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.emailInput = v; })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Button(this.isSubmitting ? '请稍候...' : '继续')
                  .width('100%')
                  .height(38)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.theme().accentColor)
                  .borderRadius(4)
                  .onClick(() => {
                    this.handleEmailCheck();
                  })

                Text('使用用户名与密码直接登录')
                  .fontSize(12)
                  .fontColor(this.theme().accentColor)
                  .padding(4)
                  .onClick(() => {
                    this.loginStep = 'login';
                  })
              }
              .width('100%')
            } else if (this.loginStep === 'login') {
              // Step 2: Login (matches web/app/login/page.tsx step === "login")
              Column({ space: 14 }) {
                Column({ space: 6 }) {
                  Text('邮箱或用户名').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
                  TextInput({ placeholder: '输入邮箱或用户名', text: this.loginUsername || this.emailInput })
                    .height(38)
                    .fontSize(14)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => {
                      this.loginUsername = v;
                      this.emailInput = v;
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Column({ space: 6 }) {
                  Text('密码').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
                  TextInput({ placeholder: '输入密码', text: this.loginPassword })
                    .type(InputType.Password)
                    .height(38)
                    .fontSize(14)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.loginPassword = v; })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Button(this.isSubmitting ? '登录中...' : '登录')
                  .width('100%')
                  .height(38)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.theme().accentColor)
                  .borderRadius(4)
                  .onClick(() => {
                    this.handleLogin();
                  })

                Button('使用其他邮箱')
                  .width('100%')
                  .height(34)
                  .fontSize(13)
                  .fontColor(this.theme().textSecondary)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    this.loginStep = 'email';
                    this.loginPassword = '';
                    this.authError = '';
                  })
              }
              .width('100%')
            } else if (this.loginStep === 'register') {
              // Step 3: Register (matches web/app/login/page.tsx step === "register")
              Column({ space: 14 }) {
                Column({ space: 6 }) {
                  Text('邮箱').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
                  TextInput({ text: this.emailInput })
                    .enabled(false)
                    .height(38)
                    .fontSize(14)
                    .fontColor(this.theme().textSecondary)
                    .backgroundColor(this.theme().bgSubtle)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Column({ space: 6 }) {
                  Text('显示名称（可选）').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
                  TextInput({ placeholder: '您的昵称', text: this.regDisplayName })
                    .height(38)
                    .fontSize(14)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.regDisplayName = v; })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Column({ space: 6 }) {
                  Text('密码（至少 12 个字符）').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
                  TextInput({ placeholder: '设置安全密码', text: this.loginPassword })
                    .type(InputType.Password)
                    .height(38)
                    .fontSize(14)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.loginPassword = v; })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Text('密码长度至少为 12 个字符，用户名将自动生成')
                  .fontSize(12)
                  .fontColor(this.theme().textSecondary)
                  .width('100%')

                Button(this.isSubmitting ? '提交中...' : '完成注册')
                  .width('100%')
                  .height(38)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.theme().accentColor)
                  .borderRadius(4)
                  .onClick(() => {
                    this.handleRegister();
                  })

                Button('使用其他邮箱')
                  .width('100%')
                  .height(34)
                  .fontSize(13)
                  .fontColor(this.theme().textSecondary)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    this.loginStep = 'email';
                    this.loginPassword = '';
                    this.authError = '';
                  })
              }
              .width('100%')
            } else if (this.loginStep === 'totp') {
              // Step 4: 2FA Verification (matches web/app/login/page.tsx step === "2fa")
              Column({ space: 14 }) {
                Column({ space: 6 }) {
                  Text(this.totpUseRecovery ? '恢复码' : '两步验证码')
                    .fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
                  TextInput({
                    placeholder: this.totpUseRecovery ? '输入恢复码' : '输入 6 位验证码',
                    text: this.totpCode
                  })
                    .height(38)
                    .fontSize(14)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.totpCode = v; })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Button(this.totpUseRecovery ? '恢复' : '验证')
                  .width('100%')
                  .height(38)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.theme().accentColor)
                  .borderRadius(4)
                  .onClick(() => {
                    this.handleTotpVerify();
                  })

                Row({ space: 8 }) {
                  Button(this.totpUseRecovery ? '使用验证码' : '使用恢复码')
                    .height(32)
                    .fontSize(12)
                    .fontColor(this.theme().textSecondary)
                    .backgroundColor(Color.Transparent)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.totpUseRecovery = !this.totpUseRecovery;
                      this.totpCode = '';
                    })
                  Button('返回')
                    .height(32)
                    .fontSize(12)
                    .fontColor(this.theme().textSecondary)
                    .backgroundColor(Color.Transparent)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.loginStep = 'login';
                      this.totpCode = '';
                    })
                }.width('100%')
              }
              .width('100%')
            } else if (this.loginStep === 'oobe') {
              // OOBE First-Run Setup Wizard
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  TextInput({ placeholder: '服务端 OOBE Passcode', text: this.oobePasscode })
                    .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
                    .onChange((v: string) => { this.oobePasscode = v; })
                  Button('验证口令')
                    .height(36).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
                    .onClick(async () => {
                      ApiService.get().setEndpoints(this.managementEndpoint, this.adminEndpoint);
                      const r = await ApiService.get().verifyOobe(this.oobePasscode);
                      if (r.ok) {
                        this.oobeVerified = true;
                        this.authInfoMsg = 'OOBE 口令验证通过';
                      } else {
                        this.authError = r.error || 'OOBE 口令验证失败';
                      }
                    })
                }.width('100%')

                TextInput({ placeholder: 'PostgreSQL 连接串', text: this.oobePgUrl })
                  .height(36).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onChange((v: string) => { this.oobePgUrl = v; })
                TextInput({ placeholder: 'Redis 连接串', text: this.oobeRedisUrl })
                  .height(36).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onChange((v: string) => { this.oobeRedisUrl = v; })
                TextInput({ placeholder: '系统主域名', text: this.oobeDomain })
                  .height(36).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onChange((v: string) => { this.oobeDomain = v; })
                TextInput({ placeholder: '超级管理员用户名', text: this.oobeAdminUser })
                  .height(36).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onChange((v: string) => { this.oobeAdminUser = v; })
                TextInput({ placeholder: '超级管理员邮箱', text: this.oobeAdminEmail })
                  .height(36).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onChange((v: string) => { this.oobeAdminEmail = v; })
                TextInput({ placeholder: '超级管理员初始密码', text: this.oobeAdminPassword })
                  .type(InputType.Password)
                  .height(36).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onChange((v: string) => { this.oobeAdminPassword = v; })

                Row({ space: 8 }) {
                  Button('返回')
                    .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
                    .onClick(() => { this.loginStep = 'email'; })
                  Button('完成初始化')
                    .height(36).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor)
                    .borderRadius(4).layoutWeight(2)
                    .onClick(async () => {
                      ApiService.get().setEndpoints(this.managementEndpoint, this.adminEndpoint);
                      const payload: Record<string, Object> = {
                        'passcode': this.oobePasscode,
                        'postgres_url': this.oobePgUrl,
                        'redis_url': this.oobeRedisUrl,
                        'domain': this.oobeDomain,
                        'admin_username': this.oobeAdminUser,
                        'admin_email': this.oobeAdminEmail,
                        'admin_password': this.oobeAdminPassword
                      };
                      const r = await ApiService.get().configureOobe(payload);
                      if (r.ok) {
                        this.loginStep = 'login';
                        this.authInfoMsg = '系统初始化成功，请登录';
                      } else {
                        this.authError = r.error || '初始化失败';
                      }
                    })
                }.width('100%')
              }
              .width('100%')
            }

            this.buildWebFooterDisclaimer()
          }
          .width(this.breakpoint === 'sm' ? '92%' : 420)
          .padding(this.breakpoint === 'sm' ? 24 : 36)
          .backgroundColor(this.theme().bgCard)
          .borderRadius(12)
          .shadow({ radius: 24, color: '#26000000', offsetX: 0, offsetY: 8 })
          .margin({ top: 56, bottom: 36 })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')

      // Floating Top-Right Theme Switcher & Server Config Gear (Safe-Area & PC Caption Bar aware)
      Row({ space: 8 }) {
        Button('服务器设置')
          .height(28)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor('#26000000')
          .border({ width: 1, color: '#44FFFFFF', radius: 6 })
          .onClick(() => {
            this.showEndpointConfig = !this.showEndpointConfig;
          })
        this.buildThemeModeToggle(true)
      }
      .margin({
        top: this.safeTopVp + 14,
        right: Math.max(this.safeRightVp, this.captionRightReserveVp) + 16
      })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.safeBottomVp })
    .backgroundColor(this.theme().loginBg)
  }

  // ==================== 2. Web Account Selection Screen (/ — AccountListPage) ====================
  @Builder
  buildAccountSelectionScreen() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          Column({ space: 14 }) {
            // Header
            Column({ space: 6 }) {
              Image($r('app.media.app_icon'))
                .width(48)
                .height(48)
                .borderRadius(10)
                .margin({ bottom: 4 })
              Text('选择 MINI ClassIsland 账户')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().textPrimary)
              Text('选择一个账户以进入集控管理面板')
                .fontSize(13)
                .fontColor(this.theme().textSecondary)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ bottom: 8 })

            if (this.accounts.length === 0) {
              Column({ space: 6 }) {
                Text('您还没有加入任何 MINI ClassIsland 账户')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme().textSecondary)
                Text('请创建一个新账户或使用邀请码加入已有账户')
                  .fontSize(12)
                  .fontColor(this.theme().textTertiary)
              }
              .width('100%')
              .padding(24)
              .alignItems(HorizontalAlign.Center)
            } else {
              Column({ space: 10 }) {
                ForEach(this.accounts, (acc: AccountSummary) => {
                  Row({ space: 14 }) {
                    // Left 44x44 blue icon box
                    Column() {
                      Text(acc.name && acc.name.length > 0 ? acc.name.substring(0, 1).toUpperCase() : 'M')
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.theme().accentColor)
                    }
                    .width(44)
                    .height(44)
                    .borderRadius(10)
                    .backgroundColor(this.theme().bgAccentSubtle)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Center)

                    // Center info
                    Column({ space: 4 }) {
                      Text(acc.name)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.theme().textPrimary)
                        .maxLines(1)
                      Row({ space: 6 }) {
                        if (acc.slug && acc.slug.length > 0) {
                          Text(acc.slug)
                            .fontSize(11)
                            .fontColor(this.theme().textSecondary)
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .backgroundColor(this.theme().bgSubtle)
                            .borderRadius(4)
                        }
                        Text(acc.is_active !== false ? '活跃' : '停用')
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(acc.is_active !== false ? this.theme().badgeSuccessFg : this.theme().badgeDangerFg)
                          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                          .backgroundColor(acc.is_active !== false ? this.theme().badgeSuccessBg : this.theme().badgeDangerBg)
                          .borderRadius(99)
                      }
                      Text(`ID: ${acc.id}`)
                        .fontSize(11)
                        .fontColor(this.theme().textTertiary)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Text('→')
                      .fontSize(18)
                      .fontColor(this.theme().textSecondary)
                  }
                  .width('100%')
                  .padding({ left: 18, right: 18, top: 14, bottom: 14 })
                  .backgroundColor(this.theme().bgCard)
                  .borderRadius(10)
                  .border({ width: 1, color: this.theme().borderColor })
                  .onClick(() => {
                    this.selectAccountAndEnter(acc);
                  })
                }, (acc: AccountSummary) => `${acc.id}`)
              }
              .width('100%')
            }

            // Create Account Inline Dialog Card
            if (this.showCreateAccountDialog) {
              Column({ space: 10 }) {
                Text('创建新账户')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textPrimary)
                Column({ space: 4 }) {
                  Text('账户名称').fontSize(12).fontColor(this.theme().textPrimary)
                  TextInput({ placeholder: '例如：北京市第一中学', text: this.newTenantName })
                    .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.newTenantName = v; })
                }.alignItems(HorizontalAlign.Start).width('100%')

                Column({ space: 4 }) {
                  Text('子域名标识 (Slug，可选)').fontSize(12).fontColor(this.theme().textPrimary)
                  TextInput({ placeholder: '例如：beijing-no1-high', text: this.newTenantSlug })
                    .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.newTenantSlug = v; })
                }.alignItems(HorizontalAlign.Start).width('100%')

                Row({ space: 8 }) {
                  Button('取消')
                    .height(34).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgCard)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
                    .onClick(() => { this.showCreateAccountDialog = false; })
                  Button('创建')
                    .height(34).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor)
                    .borderRadius(4).layoutWeight(1)
                    .onClick(async () => {
                      if (!this.newTenantName.trim()) { return; }
                      const r = await ApiService.get().createTenantAccount(this.newTenantName.trim(), this.newTenantSlug.trim());
                      if (r.ok && r.data) {
                        this.newTenantName = '';
                        this.newTenantSlug = '';
                        this.showCreateAccountDialog = false;
                        await this.refreshAccountsList();
                        const createdSummary: AccountSummary = {
                          id: r.data.id,
                          name: r.data.name,
                          slug: r.data.slug,
                          api_key: r.data.api_key,
                          is_active: r.data.is_active,
                          role: 'owner'
                        };
                        this.selectAccountAndEnter(createdSummary);
                      }
                    })
                }.width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(this.theme().bgSubtle)
              .borderRadius(8)
              .border({ width: 1, color: this.theme().borderColor })
            }

            // Join By Invite Inline Dialog Card
            if (this.showJoinInviteDialog) {
              Column({ space: 10 }) {
                Text('使用邀请码加入')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textPrimary)
                TextInput({ placeholder: '输入邀请码', text: this.inviteCodeInput })
                  .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onChange((v: string) => { this.inviteCodeInput = v; })
                Row({ space: 8 }) {
                  Button('取消')
                    .height(34).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgCard)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
                    .onClick(() => { this.showJoinInviteDialog = false; })
                  Button('加入账户')
                    .height(34).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor)
                    .borderRadius(4).layoutWeight(1)
                    .onClick(async () => {
                      if (!this.inviteCodeInput.trim()) { return; }
                      const r = await ApiService.get().acceptInvitation(this.inviteCodeInput.trim());
                      if (r.ok) {
                        this.inviteCodeInput = '';
                        this.showJoinInviteDialog = false;
                        await this.refreshAccountsList();
                      }
                    })
                }.width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(this.theme().bgSubtle)
              .borderRadius(8)
              .border({ width: 1, color: this.theme().borderColor })
            }

            // Action Buttons Row (matches web/app/page.tsx)
            Row({ space: 8 }) {
              Button('+ 创建新账户')
                .height(36)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor(this.theme().accentColor)
                .borderRadius(4)
                .layoutWeight(1)
                .onClick(() => {
                  this.showCreateAccountDialog = !this.showCreateAccountDialog;
                  this.showJoinInviteDialog = false;
                })
              Button('使用邀请码加入')
                .height(36)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgCard)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .layoutWeight(1)
                .onClick(() => {
                  this.showJoinInviteDialog = !this.showJoinInviteDialog;
                  this.showCreateAccountDialog = false;
                })
            }
            .width('100%')
            .margin({ top: 6 })

            if (this.currentUser && this.currentUser.role === 'superadmin') {
              Button('进入超级管理平台')
                .width('100%')
                .height(36)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme().accentColor)
                .backgroundColor(this.theme().bgAccentSubtle)
                .borderRadius(4)
                .onClick(() => {
                  this.isSuperAdminMode = true;
                  this.currentAccountId = -1;
                  this.currentSection = 'admin_dashboard';
                  this.refreshDashboardMetrics();
                })
            }

            Button('退出登录')
              .height(32)
              .fontSize(13)
              .fontColor(this.theme().textSecondary)
              .backgroundColor(Color.Transparent)
              .onClick(async () => {
                await ApiService.get().logout();
                this.isLoggedIn = false;
                this.currentAccountId = 0;
              })

            this.buildWebFooterDisclaimer()
          }
          .width(this.breakpoint === 'sm' ? '92%' : 460)
          .padding(this.breakpoint === 'sm' ? 24 : 36)
          .backgroundColor(this.theme().bgCard)
          .borderRadius(12)
          .shadow({ radius: 24, color: '#26000000', offsetX: 0, offsetY: 8 })
          .margin({ top: 56, bottom: 36 })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')

      Row() {
        this.buildThemeModeToggle(true)
      }
      .margin({
        top: this.safeTopVp + 14,
        right: Math.max(this.safeRightVp, this.captionRightReserveVp) + 16
      })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.safeBottomVp })
    .backgroundColor(this.theme().loginBg)
  }

  // ==================== 3. Web TopBar (Integrated with HMOS PC / Free Multi-Window TitleBar & Safe-Area) & UserMenu Popover ====================
  @Builder
  buildTopBar() {
    Column() {
      Row({ space: 12 }) {
        if (this.breakpoint === 'sm') {
          Button('☰')
            .width(34)
            .height(32)
            .fontSize(16)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgSubtle)
            .border({ width: 1, color: this.theme().borderColor, radius: 6 })
            .onClick(() => {
              this.showMobileDrawer = !this.showMobileDrawer;
              this.showUserMenuPopover = false;
            })
        }

        Text(this.isSuperAdminMode ? 'MINI ClassIsland 超级管理平台' : 'MINI ClassIsland 管理面板')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)
          .maxLines(1)

        this.buildThemeModeToggle(false)

        // UserMenu Trigger Pill (matches web/components/UserMenu.tsx)
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

          Text('▾')
            .fontSize(10)
            .fontColor(this.theme().textSecondary)
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
      // User Header
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

  // ==================== 4. Web Sidebar (matches web/components/Sidebar.tsx & admin/components/AdminShell.tsx) ====================
  @Builder
  buildSidebar() {
    Column() {
      // Sidebar Header aligned with 48vp Integrated TitleBar + Top Safe-Area
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

      // Sidebar Nav Items
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

  // ==================== 5. Web Dashboard Content (matches web/app/dashboard/page.tsx) ====================
  @Builder
  buildStatCard(value: string, label: string, valueColor: string, targetSec: string) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
      Text(label)
        .fontSize(13)
        .fontColor(this.theme().textSecondary)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .backgroundColor(this.theme().bgCard)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().borderColor })
    .layoutWeight(1)
    .onClick(() => {
      this.currentSection = targetSec;
    })
  }

  @Builder
  buildDashboardContent() {
    Column({ space: 16 }) {
      if (this.isSuperAdminTakeover) {
        Row({ space: 8 }) {
          Text(`当前正在以超级管理员身份接管集控账户：${this.currentAccountName} (#${this.currentAccountId})`)
            .fontSize(13)
            .fontColor(this.theme().badgeWarningFg)
            .layoutWeight(1)
          Button('返回超管平台')
            .height(28)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(() => {
              this.isSuperAdminTakeover = false;
              this.isSuperAdminMode = true;
              this.currentSection = 'admin_accounts';
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.theme().badgeWarningBg)
        .borderRadius(6)
      }

      // Page Header (.page-header)
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('仪表盘')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text(`当前账户：${this.currentAccountName || '-'} — 实时集控运行状态总览`)
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('下载通用配置 (仅接口地址)')
          .height(34)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(async () => {
            const r = await ApiService.get().getManagementPresetJson(this.currentAccountId);
            if (r.ok && r.data) {
              this.dashPresetJson = r.data;
            }
          })
      }
      .width('100%')

      // 4 Stat Cards (.grid-4)
      if (this.breakpoint === 'lg') {
        Row({ space: 16 }) {
          this.buildStatCard(`${this.dashOnlineClients} / ${this.dashTotalClients}`, '在线客户端 / 注册设备总数', this.theme().successColor, 'clients')
          this.buildStatCard(`${this.dashPendingPairings}`, '待审批配对码请求', this.theme().warningColor, 'pairing')
          this.buildStatCard(`${this.dashTotalResources}`, '已创建配置档案资源总数', this.theme().accentColor, 'res_Subjects')
          this.buildStatCard(`${this.dashRecentAudits}`, '近期客户端审计记录', this.theme().textPrimary, 'audit')
        }
        .width('100%')
      } else {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            this.buildStatCard(`${this.dashOnlineClients} / ${this.dashTotalClients}`, '在线客户端 / 注册总数', this.theme().successColor, 'clients')
            this.buildStatCard(`${this.dashPendingPairings}`, '待审批配对码请求', this.theme().warningColor, 'pairing')
          }.width('100%')
          Row({ space: 12 }) {
            this.buildStatCard(`${this.dashTotalResources}`, '已创建档案资源总数', this.theme().accentColor, 'res_Subjects')
            this.buildStatCard(`${this.dashRecentAudits}`, '近期客户端审计记录', this.theme().textPrimary, 'audit')
          }.width('100%')
        }
      }

      if (this.dashPresetJson.length > 0) {
        Column({ space: 8 }) {
          Row() {
            Text(`ManagementPreset-${this.currentAccountSlug || 'account'}-generic.json`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
              .layoutWeight(1)
            Button('关闭')
              .height(26)
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
              .backgroundColor(this.theme().bgSubtle)
              .borderRadius(4)
              .onClick(() => { this.dashPresetJson = ''; })
          }.width('100%')

          TextArea({ text: this.dashPresetJson })
            .height(120)
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgSubtle)
            .border({ width: 1, color: this.theme().borderColor, radius: 6 })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.theme().bgCard)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      }

      // Exact Workflow Guide Card from web/app/dashboard/page.tsx
      Column({ space: 10 }) {
        Text('MINI ClassIsland 集控工作流指引')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)

        Text('1. 接入客户端：点击右上角「下载通用配置」并将生成的 ManagementPreset.json 放入 ClassIsland 程序目录；或在「接入管理 -> 预注册客户端」中为指定班级生成带标识的专属引导配置，结合「配对码管理」完成设备准入。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)

        Text('2. 编写 7 大资源档案：在左侧「档案管理」下依次配置科目 (Subjects)、时间表 (TimeLayout)、课表 (ClassPlan)、策略 (Policy)、默认设置 (DefaultSettings)、组件 (Components) 与凭据 (Credentials)。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)

        Text('3. 按设备精准分配与控制：在「客户端 -> 客户端管理」中可为不同班级绑定专属课表与策略，或实时推送通知横幅、强制同步与重启指令。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  // ==================== 6. SuperAdmin Dashboard Content (matches admin/app/page.tsx) ====================
  @Builder
  buildSuperAdminDashboard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('全局平台总览')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text('MINI ClassIsland 超级管理平台实时运行指标与全局统计')
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('刷新数据')
          .height(34)
          .fontSize(13)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgCard)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onClick(() => {
            this.refreshDashboardMetrics();
          })
      }
      .width('100%')

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          this.buildStatCard(`${this.adminGlobalStats?.total_users ?? 0}`, '全局注册用户数', this.theme().accentColor, 'admin_users')
          this.buildStatCard(`${this.adminGlobalStats?.pending_users ?? 0}`, '待审核注册申请', this.theme().warningColor, 'admin_pending')
        }.width('100%')
        Row({ space: 12 }) {
          this.buildStatCard(`${this.adminGlobalStats?.total_accounts ?? 0}`, '集控账户 (Tenants) 总数', this.theme().accentColor, 'admin_accounts')
          this.buildStatCard(`${this.adminGlobalStats?.online_clients ?? 0} / ${this.adminGlobalStats?.total_clients ?? 0}`, '全局在线客户端 / 注册总数', this.theme().successColor, 'admin_accounts')
        }.width('100%')
      }

      Column({ space: 8 }) {
        Text('超级管理员工作台说明')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Text('您当前处于 MINI ClassIsland 超级管理平台。您可以在左侧导航中管理全局用户、审批新用户注册申请、配置各集控账户的商业化/资源配额，或一键接管任意集控账户。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  @Builder
  buildMainActiveView() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.isSuperAdminMode && this.currentSection === 'admin_dashboard') {
          this.buildSuperAdminDashboard()
        } else if (this.currentSection === 'dashboard') {
          this.buildDashboardContent()
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
        this.buildLoginScreen()
      } else if (!this.isSuperAdminMode && this.currentAccountId <= 0) {
        this.buildAccountSelectionScreen()
      } else {
        // Web AppShell Layout: Sidebar + (TopBar + Main Content Area)
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
