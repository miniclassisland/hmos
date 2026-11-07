import {
  UserInfo,
  AccountSummary,
  StoredLoginCert,
  TicketItem,
  TicketMessageItem,
  getAccountRoleLabel,
  getSystemRoleLabel,
  getTicketStatusLabel,
  getTicketPriorityLabel,
  getTicketCategoryLabel,
  formatTimestamp
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosIconTextButton, HmosSymbolIcon } from './HmosIcons';
import { scanBarcode, scanCore } from '@kit.ScanKit';

@Component
export struct AuthAndAccountView {
  @Prop mode: string = 'login'; // 'login' | 'user_home' | 'tickets'
  @Prop breakpoint: string = 'sm';
  @Prop themeMode: string = 'light';
  @Prop safeTopVp: number = 0;
  @Prop safeBottomVp: number = 0;
  @Prop safeRightVp: number = 0;
  @Prop captionRightReserveVp: number = 0;
  @Prop currentUser: UserInfo | null = null;
  @Prop accounts: AccountSummary[] = [];

  public onThemeChange: (nextMode: string) => void = () => {};
  public onAuthCompleted: (token: string, user: UserInfo) => void = () => {};
  public onSelectAccount: (acc: AccountSummary) => void = () => {};
  public onNavigateAccountSection: (acc: AccountSummary, sec: string) => void = () => {};
  public onNavigateSection: (sec: string) => void = () => {};
  public onEnterSuperAdmin: () => void = () => {};
  public onRefreshAccounts: () => void = () => {};
  public onLogout: () => void = () => {};

  @State managementEndpoint: string = 'https://api.miniclassisland.com';
  @State adminEndpoint: string = 'https://admin.miniclassisland.com/api';
  @State showEndpointConfig: boolean = false;

  @State authError: string = '';
  @State authInfoMsg: string = '';
  @State isSubmitting: boolean = false;

  // Login Security Certificate & Reverse QR Web Login State
  @State certExchangeInput: string = '';
  @State qrLoginCodeInput: string = '';
  @State storedCert: StoredLoginCert | null = null;

  // User Center Home State (matching web/app/page.tsx)
  @State showCreateAccountDialog: boolean = false;
  @State newTenantName: string = '';
  @State newTenantSlug: string = '';
  @State accountSearchQuery: string = '';

  // Support Tickets State (matching web/app/tickets/page.tsx)
  @State tickets: TicketItem[] = [];
  @State ticketStatusFilter: string = 'all';
  @State showCreateTicketForm: boolean = false;
  @State newTicketSubject: string = '';
  @State newTicketCategory: string = 'general';
  @State newTicketPriority: string = 'normal';
  @State newTicketContent: string = '';
  @State activeTicketDetail: TicketItem | null = null;
  @State ticketReplyText: string = '';

  private lastLoadedMode: string = '';

  aboutToAppear(): void {
    this.managementEndpoint = ApiService.get().managementUrl;
    this.adminEndpoint = ApiService.get().adminUrl;
    this.storedCert = ApiService.get().storedCertificate;
    this.reloadForMode();
  }

  private reloadForMode(): void {
    this.lastLoadedMode = this.mode;
    if (this.mode === 'tickets') {
      this.loadMyTickets();
    }
  }

  private async loadMyTickets(): Promise<void> {
    const r = await ApiService.get().listMyTickets(this.ticketStatusFilter);
    if (r.ok && r.data) {
      this.tickets = r.data;
    }
  }

  private async openTicketDetail(t: TicketItem): Promise<void> {
    const r = await ApiService.get().getTicketDetail(t.id);
    if (r.ok && r.data) {
      this.activeTicketDetail = r.data;
    } else {
      this.activeTicketDetail = t;
    }
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private getFilteredAccounts(): AccountSummary[] {
    const q = this.accountSearchQuery.trim().toLowerCase();
    if (!q) {
      return this.accounts;
    }
    const out: AccountSummary[] = [];
    for (let i = 0; i < this.accounts.length; i++) {
      const a = this.accounts[i];
      const hay = `${a.name} ${a.slug}`.toLowerCase();
      if (hay.indexOf(q) >= 0) {
        out.push(a);
      }
    }
    return out;
  }

  private async handleRedeemAndLogin(): Promise<void> {
    const raw = this.certExchangeInput.trim();
    if (!raw) {
      this.authError = '请输入或粘贴安全证书兑换码';
      return;
    }
    this.authError = '';
    this.authInfoMsg = '';
    this.isSubmitting = true;
    ApiService.get().setEndpoints(this.managementEndpoint, this.adminEndpoint);
    const r = await ApiService.get().redeemCertificate(raw);
    if (!r.ok || !r.data) {
      this.isSubmitting = false;
      this.authError = r.error || '兑换登录安全证书失败';
      return;
    }
    this.storedCert = r.data;
    this.certExchangeInput = '';
    if (ApiService.get().token.length > 0) {
      const pRes = await ApiService.get().getProfile();
      this.isSubmitting = false;
      if (pRes.ok && pRes.data) {
        this.onAuthCompleted(ApiService.get().token, pRes.data);
        return;
      }
    }
    await this.handleUseStoredCertificateSession();
  }

  private async handleUseStoredCertificateSession(): Promise<void> {
    this.authError = '';
    this.authInfoMsg = '';
    this.isSubmitting = true;
    const api = ApiService.get();
    const sRes = await api.requestSessionFromCertificate(3600);
    if (!sRes.ok || !sRes.data) {
      this.isSubmitting = false;
      this.authError = sRes.error || '使用安全证书申请临时令牌失败';
      return;
    }
    const nowSec = Math.floor(Date.now() / 1000);
    if (this.storedCert && (this.storedCert.expires_at - nowSec) < 86400 && this.storedCert.generation < this.storedCert.max_generation) {
      const rotRes = await api.rotateCertificateIfEligible();
      if (rotRes.ok && rotRes.data) {
        this.storedCert = rotRes.data;
      }
    }
    const pRes = await api.getProfile();
    this.isSubmitting = false;
    if (pRes.ok && pRes.data) {
      this.onAuthCompleted(api.token, pRes.data);
    } else {
      this.authInfoMsg = '已使用登录安全证书获取 1 小时管理会话令牌';
    }
  }

  private async handleAuthorizeQrWebLogin(): Promise<void> {
    const raw = this.qrLoginCodeInput.trim();
    if (!raw) {
      this.authError = '请输入或扫描网页端登录二维码链接';
      return;
    }
    this.authError = '';
    this.authInfoMsg = '';
    const r = await ApiService.get().authorizeWebQrLogin(raw);
    if (r.ok) {
      this.qrLoginCodeInput = '';
      this.authInfoMsg = '已成功授权网页端扫码登录';
    } else {
      this.authError = r.error || '网页端扫码登录授权失败';
    }
  }

  private async startNativeQrScan(): Promise<void> {
    this.authError = '';
    this.authInfoMsg = '';
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: false,
        enableAlbum: true
      };
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(getContext(this), options);
      const scanned = (result.originalValue || '').trim();
      if (!scanned) {
        return;
      }
      if (scanned.toLowerCase().startsWith('miniclassisland://qr-login')) {
        this.qrLoginCodeInput = scanned;
        await this.handleAuthorizeQrWebLogin();
      } else {
        this.certExchangeInput = scanned;
        await this.handleRedeemAndLogin();
      }
    } catch (_err) {
      this.authError = '未能启动系统扫码器，请检查设备相机状态或从相册识别二维码';
    }
  }

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
            this.onThemeChange(item[0]);
          })
      }, (item: string[]) => item[0])
    }
    .padding(2)
    .borderRadius(6)
    .backgroundColor(onBlueBg ? '#22000000' : this.theme().bgSubtle)
    .border({ width: 1, color: onBlueBg ? '#44FFFFFF' : this.theme().borderColor })
  }

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

  @Builder
  buildLoginScreen() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          Column({ space: 14 }) {
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
              Text('请使用扫码器扫描登录安全证书二维码完成移动端登录')
                .fontSize(14)
                .fontColor(this.theme().textSecondary)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ bottom: 8 })

            if (this.showEndpointConfig) {
              Column({ space: 8 }) {
                Text('服务器接口配置')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textPrimary)
                Column({ space: 4 }) {
                  Text('集控服务地址').fontSize(11).fontColor(this.theme().textSecondary)
                  TextInput({ text: this.managementEndpoint })
                    .height(34)
                    .fontSize(12)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.managementEndpoint = v; })
                }.alignItems(HorizontalAlign.Start)

                Column({ space: 4 }) {
                  Text('超管服务地址').fontSize(11).fontColor(this.theme().textSecondary)
                  TextInput({ text: this.adminEndpoint })
                    .height(34)
                    .fontSize(12)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .onChange((v: string) => { this.adminEndpoint = v; })
                }.alignItems(HorizontalAlign.Start)

                Row({ space: 8 }) {
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

            if (this.authError.length > 0) {
              Row() {
                Text(this.authError).fontSize(13).fontColor(this.theme().badgeDangerFg)
              }
              .width('100%')
              .padding(10)
              .backgroundColor(this.theme().badgeDangerBg)
              .borderRadius(4)
            }
            if (this.authInfoMsg.length > 0) {
              Row() {
                Text(this.authInfoMsg).fontSize(13).fontColor(this.theme().badgeSuccessFg)
              }
              .width('100%')
              .padding(10)
              .backgroundColor(this.theme().badgeSuccessBg)
              .borderRadius(4)
            }

            if (this.storedCert !== null) {
              Column({ space: 6 }) {
                Text(`已存登录安全证书 · 第 ${this.storedCert.generation}/${this.storedCert.max_generation} 代`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme().badgeSuccessFg)
                Text(`到期时间: ${formatTimestamp(this.storedCert.expires_at)}`)
                  .fontSize(11)
                  .fontColor(this.theme().textSecondary)
                Row({ space: 6 }) {
                  HmosIconTextButton(
                    $r('sys.symbol.checkmark_shield'),
                    '使用本机安全证书一键登录',
                    '#FFFFFF',
                    this.theme().accentColor,
                    Color.Transparent,
                    () => {
                      this.handleUseStoredCertificateSession();
                    },
                    34,
                    12
                  )
                  HmosIconTextButton(
                    $r('sys.symbol.arrow_clockwise'),
                    '轮换下一代',
                    this.theme().textPrimary,
                    this.theme().bgCard,
                    this.theme().borderColor,
                    async () => {
                      const r = await ApiService.get().rotateCertificateIfEligible();
                      if (r.ok && r.data) {
                        this.storedCert = r.data;
                        this.authInfoMsg = `安全证书已成功轮换至第 ${r.data.generation} 代`;
                      } else {
                        this.authError = r.error || '仅当有效期低于 24 小时且未超 12 代时可轮换';
                      }
                    },
                    34,
                    12
                  )
                }
                .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.theme().badgeSuccessBg)
              .borderRadius(8)
            }

            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.qrcode'))
                  .fontSize(18)
                  .fontColor(['#FFFFFF'])
                Text(this.isSubmitting ? '正在验证登录...' : '扫码登录')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .height(44)
            .backgroundColor(this.theme().accentColor)
            .borderRadius(6)
            .onClick(() => {
              this.startNativeQrScan();
            })

            Text('请先在网页端「个人资料与安全设置」签发移动端登录安全证书，然后点击上方「扫码登录」扫描二维码即可直接完成登录；已绑定安全证书时也可直接扫描网页端登录二维码确认授权。')
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
              .textAlign(TextAlign.Center)
              .lineHeight(18)

            this.buildWebFooterDisclaimer()
          }
          .width(this.breakpoint === 'sm' ? '92%' : 440)
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

      Row({ space: 8 }) {
        HmosIconTextButton(
          $r('sys.symbol.gearshape'),
          '服务器设置',
          '#FFFFFF',
          '#26000000',
          '#44FFFFFF',
          () => {
            this.showEndpointConfig = !this.showEndpointConfig;
          },
          28,
          12
        )
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

  // ==================== USER CENTER HOME (1:1 with web/app/page.tsx) ====================
  @Builder
  buildUserCenterHomeView() {
    Column({ space: 18 }) {
      // Header Row
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(`欢迎回来，${this.currentUser?.display_name || this.currentUser?.username || '用户'}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text('在此选择要管理的集控账户中心，或前往个人安全中心')
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.currentUser?.can_create_account !== false) {
          HmosIconTextButton(
            $r('sys.symbol.plus'),
            '创建新账户',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            () => {
              this.showCreateAccountDialog = !this.showCreateAccountDialog;
            },
            36,
            13
          )
        }
      }
      .width('100%')

      if (this.authError.length > 0) {
        Row() {
          Text(this.authError).fontSize(13).fontColor(this.theme().badgeDangerFg)
        }
        .width('100%').padding(10).backgroundColor(this.theme().badgeDangerBg).borderRadius(6)
      }
      if (this.authInfoMsg.length > 0) {
        Row() {
          Text(this.authInfoMsg).fontSize(13).fontColor(this.theme().badgeSuccessFg)
        }
        .width('100%').padding(10).backgroundColor(this.theme().badgeSuccessBg).borderRadius(6)
      }

      if (this.showCreateAccountDialog) {
        Column({ space: 12 }) {
          Text('创建新的 MINI ClassIsland 集控账户中心')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text('账户名称（例如：XX中学集控中心）').fontSize(12).fontColor(this.theme().textSecondary)
              TextInput({ placeholder: '输入组织或学校名称', text: this.newTenantName })
                .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => { this.newTenantName = v; })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Column({ space: 4 }) {
              Text('账户唯一标识（可选，留空自动生成）').fontSize(12).fontColor(this.theme().textSecondary)
              TextInput({ placeholder: '如 no1-high-school', text: this.newTenantSlug })
                .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => { this.newTenantSlug = v; })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')

          Row({ space: 8 }) {
            Button('立即创建')
              .height(34).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
              .onClick(async () => {
                if (!this.newTenantName.trim()) { return; }
                const r = await ApiService.get().createTenantAccount(this.newTenantName.trim(), this.newTenantSlug.trim());
                if (r.ok && r.data) {
                  this.newTenantName = '';
                  this.newTenantSlug = '';
                  this.showCreateAccountDialog = false;
                  this.onRefreshAccounts();
                  const createdSummary: AccountSummary = {
                    id: r.data.id,
                    name: r.data.name,
                    slug: r.data.slug,
                    api_key: r.data.api_key,
                    is_active: r.data.is_active,
                    role: 'owner'
                  };
                  this.onSelectAccount(createdSummary);
                } else {
                  this.authError = r.error || '创建账户失败';
                }
              })
            Button('取消')
              .height(34).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(() => { this.showCreateAccountDialog = false; })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(this.theme().bgCard)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().accentColor })
      }

      // 3 Summary Stat Cards (matching web/app/page.tsx)
      if (this.breakpoint !== 'sm') {
        Row({ space: 14 }) {
          Column({ space: 6 }) {
            Text(`${this.accounts.length}`)
              .fontSize(26).fontWeight(FontWeight.Bold).fontColor(this.theme().accentColor)
            Text('可访问账户中心')
              .fontSize(13).fontColor(this.theme().textSecondary)
          }
          .alignItems(HorizontalAlign.Start).padding(18).backgroundColor(this.theme().bgCard)
          .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)

          Column({ space: 6 }) {
            Text(this.currentUser?.username || '-')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
            Text(`当前登录账号 · ${getSystemRoleLabel(this.currentUser?.role_code || this.currentUser?.role || 'user')}`)
              .fontSize(12).fontColor(this.theme().textSecondary)
          }
          .alignItems(HorizontalAlign.Start).padding(18).backgroundColor(this.theme().bgCard)
          .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)

          Column({ space: 6 }) {
            Text(this.currentUser?.totp_enabled ? '已启用' : '未启用')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.currentUser?.totp_enabled ? this.theme().badgeSuccessFg : this.theme().badgeWarningFg)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor(this.currentUser?.totp_enabled ? this.theme().badgeSuccessBg : this.theme().badgeWarningBg)
              .borderRadius(99)
            Text('两步验证 · 点击前往安全设置 →')
              .fontSize(12).fontColor(this.theme().accentColor)
          }
          .alignItems(HorizontalAlign.Start).padding(18).backgroundColor(this.theme().bgCard)
          .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)
          .onClick(() => {
            this.onNavigateSection('security');
          })
        }
        .width('100%')
      } else {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text(`${this.accounts.length}`)
                .fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.theme().accentColor)
              Text('可访问账户中心')
                .fontSize(12).fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start).padding(14).backgroundColor(this.theme().bgCard)
            .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)

            Column({ space: 4 }) {
              Text(this.currentUser?.totp_enabled ? '已启用' : '未启用')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentUser?.totp_enabled ? this.theme().badgeSuccessFg : this.theme().badgeWarningFg)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(this.currentUser?.totp_enabled ? this.theme().badgeSuccessBg : this.theme().badgeWarningBg)
                .borderRadius(99)
              Text('两步验证 · 前往安全设置 →')
                .fontSize(11).fontColor(this.theme().accentColor)
            }
            .alignItems(HorizontalAlign.Start).padding(14).backgroundColor(this.theme().bgCard)
            .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)
            .onClick(() => {
              this.onNavigateSection('security');
            })
          }.width('100%')

          Column({ space: 4 }) {
            Text(this.currentUser?.username || '-')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
            Text(`当前登录账号 · ${getSystemRoleLabel(this.currentUser?.role_code || this.currentUser?.role || 'user')}`)
              .fontSize(12).fontColor(this.theme().textSecondary)
          }
          .width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(this.theme().bgCard)
          .borderRadius(8).border({ width: 1, color: this.theme().borderColor })
        }
        .width('100%')
      }

      // Accounts Directory Card (matching web/app/page.tsx)
      Column({ space: 14 }) {
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            HmosSymbolIcon($r('sys.symbol.person_2'), 16, this.theme().accentColor)
            Text(`您的集控账户中心 (${this.getFilteredAccounts().length})`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
          }
          .layoutWeight(1)

          TextInput({ placeholder: '搜索账户名称或标识...', text: this.accountSearchQuery })
            .height(32)
            .width(this.breakpoint === 'sm' ? 150 : 220)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => { this.accountSearchQuery = v; })
        }
        .width('100%')

        if (this.getFilteredAccounts().length === 0) {
          Column({ space: 8 }) {
            Text(this.accounts.length === 0 ? '您尚未加入任何集控账户中心' : '没有匹配的账户中心')
              .fontSize(14)
              .fontColor(this.theme().textSecondary)
            if (this.accounts.length === 0 && this.currentUser?.can_create_account !== false) {
              Button('立即创建第一个账户中心')
                .height(34).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
                .onClick(() => { this.showCreateAccountDialog = true; })
            }
          }
          .width('100%')
          .padding(32)
          .alignItems(HorizontalAlign.Center)
        } else {
          Column({ space: 10 }) {
            ForEach(this.getFilteredAccounts(), (acc: AccountSummary) => {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Column({ space: 2 }) {
                    Text(acc.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.theme().textPrimary)
                    Text(`标识: ${acc.slug}`)
                      .fontSize(11)
                      .fontFamily('monospace')
                      .fontColor(this.theme().textSecondary)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(getAccountRoleLabel(acc.role || 'owner'))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme().badgeInfoFg)
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(this.theme().badgeInfoBg)
                    .borderRadius(99)
                }
                .width('100%')

                Row({ space: 8 }) {
                  HmosIconTextButton(
                    $r('sys.symbol.gearshape'),
                    '基础信息',
                    this.theme().textPrimary,
                    this.theme().bgCard,
                    this.theme().borderColor,
                    () => {
                      this.onNavigateAccountSection(acc, 'account');
                    },
                    32,
                    12
                  )

                  Button({ type: ButtonType.Normal }) {
                    Row({ space: 4 }) {
                      Text('进入账户中心')
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#FFFFFF')
                      SymbolGlyph($r('sys.symbol.arrow_right'))
                        .fontSize(13)
                        .fontColor(['#FFFFFF'])
                    }
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                  }
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(this.theme().accentColor)
                  .borderRadius(4)
                  .onClick(() => {
                    this.onSelectAccount(acc);
                  })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.theme().bgSubtle)
              .borderRadius(8)
              .border({ width: 1, color: this.theme().borderColor })
            }, (acc: AccountSummary) => acc.id)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      this.buildWebFooterDisclaimer()
    }
    .width('100%')
  }

  // ==================== MY TICKETS VIEW (1:1 with web/app/tickets/page.tsx) ====================
  @Builder
  buildTicketsView() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text('我的工单')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text('向平台管理员提交技术支持、配额申请或问题反馈')
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        HmosIconTextButton(
          $r('sys.symbol.plus'),
          '提交新工单',
          '#FFFFFF',
          this.theme().accentColor,
          Color.Transparent,
          () => {
            this.showCreateTicketForm = !this.showCreateTicketForm;
          },
          34,
          13
        )
        HmosIconTextButton(
          $r('sys.symbol.arrow_clockwise'),
          '刷新',
          this.theme().textPrimary,
          this.theme().bgCard,
          this.theme().borderColor,
          () => {
            this.loadMyTickets();
          },
          34,
          13
        )
      }
      .width('100%')

      if (this.showCreateTicketForm) {
        Column({ space: 10 }) {
          Text('新建支持工单')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          TextInput({ placeholder: '工单标题（简要描述问题或需求）', text: this.newTicketSubject })
            .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => { this.newTicketSubject = v; })

          Row({ space: 8 }) {
            Text('分类:').fontSize(12).fontColor(this.theme().textSecondary)
            ForEach(['general', 'bug', 'quota', 'account'], (cat: string) => {
              Button(getTicketCategoryLabel(cat))
                .height(26).fontSize(11)
                .fontColor(this.newTicketCategory === cat ? '#FFFFFF' : this.theme().textPrimary)
                .backgroundColor(this.newTicketCategory === cat ? this.theme().accentColor : this.theme().bgSubtle)
                .borderRadius(4)
                .onClick(() => { this.newTicketCategory = cat; })
            }, (cat: string) => cat)
          }.width('100%')

          Row({ space: 8 }) {
            Text('优先级:').fontSize(12).fontColor(this.theme().textSecondary)
            ForEach(['low', 'normal', 'high', 'urgent'], (pri: string) => {
              Button(getTicketPriorityLabel(pri))
                .height(26).fontSize(11)
                .fontColor(this.newTicketPriority === pri ? '#FFFFFF' : this.theme().textPrimary)
                .backgroundColor(this.newTicketPriority === pri ? this.theme().accentColor : this.theme().bgSubtle)
                .borderRadius(4)
                .onClick(() => { this.newTicketPriority = pri; })
            }, (pri: string) => pri)
          }.width('100%')

          TextArea({ placeholder: '详细描述您遇到的问题或需要申请的配额...', text: this.newTicketContent })
            .height(90).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => { this.newTicketContent = v; })

          Row({ space: 8 }) {
            Button('提交工单')
              .height(34).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
              .onClick(async () => {
                if (!this.newTicketSubject.trim() || !this.newTicketContent.trim()) { return; }
                const r = await ApiService.get().createTicket(
                  this.newTicketSubject.trim(),
                  this.newTicketCategory,
                  this.newTicketPriority,
                  this.newTicketContent.trim()
                );
                if (r.ok) {
                  this.newTicketSubject = '';
                  this.newTicketContent = '';
                  this.showCreateTicketForm = false;
                  await this.loadMyTickets();
                }
              })
            Button('取消')
              .height(34).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(() => { this.showCreateTicketForm = false; })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(this.theme().bgCard)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().accentColor })
      }

      Row({ space: 6 }) {
        ForEach(['all', 'open', 'in_progress', 'resolved', 'closed'], (st: string) => {
          Button(st === 'all' ? '全部状态' : getTicketStatusLabel(st))
            .height(28).fontSize(12)
            .fontColor(this.ticketStatusFilter === st ? '#FFFFFF' : this.theme().textPrimary)
            .backgroundColor(this.ticketStatusFilter === st ? this.theme().accentColor : this.theme().bgSubtle)
            .borderRadius(4)
            .onClick(() => {
              this.ticketStatusFilter = st;
              this.loadMyTickets();
            })
        }, (st: string) => st)
      }.width('100%')

      if (this.activeTicketDetail !== null) {
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            Text(`[${this.activeTicketDetail.ticket_no}] ${this.activeTicketDetail.subject}`)
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary).layoutWeight(1)
            if (this.activeTicketDetail.status !== 'closed') {
              Button('关闭工单')
                .height(28).fontSize(12).fontColor(this.theme().dangerColor).backgroundColor(this.theme().bgSubtle)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onClick(async () => {
                  if (!this.activeTicketDetail) { return; }
                  await ApiService.get().closeTicket(this.activeTicketDetail.id);
                  await this.openTicketDetail(this.activeTicketDetail);
                  await this.loadMyTickets();
                })
            }
            Button('返回列表')
              .height(28).fontSize(12).fontColor(this.theme().textSecondary).backgroundColor(this.theme().bgSubtle).borderRadius(4)
              .onClick(() => { this.activeTicketDetail = null; })
          }.width('100%')

          ForEach(this.activeTicketDetail.messages || [], (m: TicketMessageItem) => {
            Column({ space: 4 }) {
              Row() {
                Text(`${m.sender_name || '用户'}${m.is_staff_reply ? ' · 平台客服' : ''}`)
                  .fontSize(12).fontWeight(FontWeight.Bold)
                  .fontColor(m.is_staff_reply ? this.theme().accentColor : this.theme().textPrimary)
                  .layoutWeight(1)
                Text(m.created_at || '')
                  .fontSize(11).fontColor(this.theme().textSecondary)
              }.width('100%')
              Text(m.content)
                .fontSize(13).fontColor(this.theme().textPrimary)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor(m.is_staff_reply ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
            .borderRadius(6)
          }, (m: TicketMessageItem) => m.id)

          if (this.activeTicketDetail.status !== 'closed') {
            Row({ space: 8 }) {
              TextInput({ placeholder: '输入回复内容...', text: this.ticketReplyText })
                .height(36).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
                .onChange((v: string) => { this.ticketReplyText = v; })
              Button('发送回复')
                .height(36).fontSize(13).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
                .onClick(async () => {
                  if (!this.activeTicketDetail || !this.ticketReplyText.trim()) { return; }
                  const r = await ApiService.get().replyTicket(this.activeTicketDetail.id, this.ticketReplyText.trim());
                  if (r.ok) {
                    this.ticketReplyText = '';
                    await this.openTicketDetail(this.activeTicketDetail);
                  }
                })
            }.width('100%')
          }
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.theme().bgCard)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().accentColor })
      }

      Column({ space: 8 }) {
        if (this.tickets.length === 0) {
          Text('暂无工单记录')
            .fontSize(13).fontColor(this.theme().textSecondary).padding(24)
        } else {
          ForEach(this.tickets, (t: TicketItem) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text(t.ticket_no)
                    .fontSize(11).fontFamily('monospace').fontColor(this.theme().textSecondary)
                  Text(t.subject)
                    .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
                }
                Text(`分类: ${getTicketCategoryLabel(t.category)} · 优先级: ${getTicketPriorityLabel(t.priority)} · 更新于: ${t.updated_at || t.created_at}`)
                  .fontSize(12).fontColor(this.theme().textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(getTicketStatusLabel(t.status))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(t.status === 'resolved' ? this.theme().badgeSuccessFg : this.theme().badgeInfoFg)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(t.status === 'resolved' ? this.theme().badgeSuccessBg : this.theme().badgeInfoBg)
                .borderRadius(99)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.theme().bgSubtle)
            .borderRadius(6)
            .onClick(() => {
              this.openTicketDetail(t);
            })
          }, (t: TicketItem) => t.id)
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.lastLoadedMode !== this.mode) {
        Row().height(0).onAppear(() => {
          this.reloadForMode();
        })
      }

      if (this.mode === 'user_home' || this.mode === 'accounts') {
        this.buildUserCenterHomeView()
      } else if (this.mode === 'tickets') {
        this.buildTicketsView()
      } else {
        this.buildLoginScreen()
      }
    }
    .width('100%')
  }
}
