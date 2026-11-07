import {
  UserInfo,
  AccountSummary,
  StoredLoginCert,
  formatTimestamp
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosIconTextButton, HmosSymbolIcon } from './HmosIcons';
import { scanBarcode, scanCore } from '@kit.ScanKit';

@Component
export struct AuthAndAccountView {
  @Prop mode: string = 'login'; // 'login' | 'accounts'
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
  public onEnterSuperAdmin: () => void = () => {};
  public onRefreshAccounts: () => void = () => {};
  public onLogout: () => void = () => {};

  @State managementEndpoint: string = 'https://api.miniclassisland.com';
  @State adminEndpoint: string = 'https://admin.miniclassisland.com/api';
  @State showEndpointConfig: boolean = false;
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

  // Login Security Certificate & Reverse QR Web Login State
  @State certExchangeInput: string = '';
  @State qrLoginCodeInput: string = '';
  @State storedCert: StoredLoginCert | null = null;

  // OOBE Wizard State
  @State oobePasscode: string = '';
  @State oobeVerified: boolean = false;
  @State oobePgUrl: string = 'postgres://postgres:postgres@localhost:5432/miniclassisland?sslmode=disable';
  @State oobeRedisUrl: string = 'redis://localhost:6379/0';
  @State oobeDomain: string = 'api.miniclassisland.com';
  @State oobeAdminUser: string = 'admin';
  @State oobeAdminEmail: string = 'admin@example.com';
  @State oobeAdminPassword: string = '';

  // Account Selection Dialogs
  @State showCreateAccountDialog: boolean = false;
  @State showJoinInviteDialog: boolean = false;
  @State newTenantName: string = '';
  @State newTenantSlug: string = '';
  @State inviteCodeInput: string = '';

  aboutToAppear(): void {
    this.managementEndpoint = ApiService.get().managementUrl;
    this.adminEndpoint = ApiService.get().adminUrl;
    this.storedCert = ApiService.get().storedCertificate;
  }

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
      this.loginUsername = trimmed;
      this.loginStep = 'login';
      return;
    }
    if (res.data === true) {
      this.loginStep = 'register';
    } else {
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
    this.onAuthCompleted(res.data.token, res.data.user);
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
    this.onAuthCompleted(res.data.token, res.data.user);
  }

  private async handleRedeemAndLogin(): Promise<void> {
    const raw = this.certExchangeInput.trim();
    if (!raw) {
      this.authError = '请输入或粘贴安全证书兑换码 / DeepLink 链接';
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
  buildCertificateAndQrSection(showQrAuthorize: boolean) {
    Column({ space: 10 }) {
      Divider().color(this.theme().borderColor).margin({ top: 4, bottom: 4 })

      // Stored Login Security Certificate Box
      Column({ space: 8 }) {
        Row({ space: 6 }) {
          HmosSymbolIcon($r('sys.symbol.checkmark_shield'), 15, this.theme().accentColor)
          Text('登录安全证书')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .layoutWeight(1)
        }
        .width('100%')

        if (this.storedCert !== null) {
          Column({ space: 4 }) {
            Text(`已存证书 ID: ${this.storedCert.cert_id} · 代数: ${this.storedCert.generation}/${this.storedCert.max_generation}`)
              .fontSize(11)
              .fontColor(this.theme().badgeSuccessFg)
            Text(`到期时间: ${formatTimestamp(this.storedCert.expires_at)}`)
              .fontSize(11)
              .fontColor(this.theme().textSecondary)
            Row({ space: 6 }) {
              HmosIconTextButton(
                $r('sys.symbol.checkmark_shield'),
                '用安全证书直接登录',
                '#FFFFFF',
                this.theme().accentColor,
                Color.Transparent,
                () => {
                  this.handleUseStoredCertificateSession();
                },
                32,
                12
              )
              HmosIconTextButton(
                $r('sys.symbol.arrow_clockwise'),
                '轮换代际',
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
                32,
                11
              )
              HmosIconButton(
                $r('sys.symbol.trash'),
                this.theme().dangerColor,
                this.theme().bgCard,
                this.theme().borderColor,
                () => {
                  ApiService.get().storedCertificate = null;
                  AppStorage.setOrCreate<string>('storedCertificateJson', '');
                  this.storedCert = null;
                },
                32,
                14
              )
            }
            .width('100%')
          }
          .width('100%')
          .padding(10)
          .backgroundColor(this.theme().badgeSuccessBg)
          .borderRadius(6)
        }

        Row({ space: 6 }) {
          TextInput({
            placeholder: '粘贴安全证书兑换链接或兑换码',
            text: this.certExchangeInput
          })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.certExchangeInput = v; })

          HmosIconTextButton(
            $r('sys.symbol.qrcode'),
            '扫码或兑换',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            () => {
              if (this.certExchangeInput.trim().length > 0) {
                this.handleRedeemAndLogin();
              } else {
                this.startNativeQrScan();
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
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      // Reverse QR Code Web Login Box
      if (showQrAuthorize || this.storedCert !== null) {
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            HmosSymbolIcon($r('sys.symbol.qrcode'), 15, this.theme().accentColor)
            Text('扫码授权登录网页端')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
              .layoutWeight(1)
          }
          .width('100%')

          Row({ space: 6 }) {
            TextInput({
              placeholder: '粘贴网页登录二维码链接或直接点击右侧扫码',
              text: this.qrLoginCodeInput
            })
              .height(34)
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => { this.qrLoginCodeInput = v; })

            HmosIconTextButton(
              $r('sys.symbol.qrcode'),
              '扫码授权网页登录',
              '#FFFFFF',
              this.theme().accentColor,
              Color.Transparent,
              () => {
                if (this.qrLoginCodeInput.trim().length > 0) {
                  this.handleAuthorizeQrWebLogin();
                } else {
                  this.startNativeQrScan();
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
        .backgroundColor(this.theme().bgSubtle)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      }
    }
    .width('100%')
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

  @Builder
  buildAccountSelectionScreen() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          Column({ space: 14 }) {
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

            if (this.authError.length > 0) {
              Row() {
                Text(this.authError).fontSize(13).fontColor(this.theme().badgeDangerFg)
              }
              .width('100%').padding(10).backgroundColor(this.theme().badgeDangerBg).borderRadius(4)
            }
            if (this.authInfoMsg.length > 0) {
              Row() {
                Text(this.authInfoMsg).fontSize(13).fontColor(this.theme().badgeSuccessFg)
              }
              .width('100%').padding(10).backgroundColor(this.theme().badgeSuccessBg).borderRadius(4)
            }

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

                    HmosSymbolIcon($r('sys.symbol.arrow_right'), 16, this.theme().textSecondary)
                  }
                  .width('100%')
                  .padding({ left: 18, right: 18, top: 14, bottom: 14 })
                  .backgroundColor(this.theme().bgCard)
                  .borderRadius(10)
                  .border({ width: 1, color: this.theme().borderColor })
                  .onClick(() => {
                    this.onSelectAccount(acc);
                  })
                }, (acc: AccountSummary) => `${acc.id}`)
              }
              .width('100%')
            }

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
                  Text('子域名标识（可选）').fontSize(12).fontColor(this.theme().textPrimary)
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
                        this.onRefreshAccounts();
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

            Row({ space: 8 }) {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 4 }) {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(14)
                    .fontColor(['#FFFFFF'])
                  Text('创建新账户')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                }
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
              }
              .height(36)
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
                  this.onEnterSuperAdmin();
                })
            }

            // Certificate & Reverse QR Web Login card also available when logged in
            this.buildCertificateAndQrSection(true)

            Button('退出登录')
              .height(32)
              .fontSize(13)
              .fontColor(this.theme().textSecondary)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.onLogout();
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

  build() {
    Column() {
      if (this.mode === 'accounts') {
        this.buildAccountSelectionScreen()
      } else {
        this.buildLoginScreen()
      }
    }
    .width('100%')
    .height('100%')
  }
}
