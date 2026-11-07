import {
  UserInfo,
  AdminUserItem,
  AdminAccountItem,
  GlobalStats,
  StoredLoginCert,
  formatTimestamp
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosIconTextButton, HmosSymbolIcon } from './HmosIcons';

@Component
export struct SecurityAndAdminView {
  @Prop subMode: string = 'security';
  // 'security' | 'admin_users' | 'admin_pending' | 'admin_accounts' | 'admin_settings'
  @Prop breakpoint: string = 'sm';
  @Prop themeMode: string = 'light';
  public onTakeoverTenant: (acc: AdminAccountItem) => void = () => {};

  // Personal Security
  @State userProfile: UserInfo | null = null;
  @State secDisplayName: string = '';
  @State secEmail: string = '';
  @State secUsername: string = '';
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State totpSecret: string = '';
  @State totpUri: string = '';
  @State totpConfirmCode: string = '';
  @State totpRecoveryCodes: string[] = [];
  @State disableTotpPassword: string = '';
  @State disableTotpCode: string = '';

  // Login Security Certificate & Reverse QR Web Login
  @State certIssuePassword: string = '';
  @State certIssueTotpCode: string = '';
  @State certIssueDeviceName: string = 'HarmonyOS 客户端';
  @State issuedCertDeepLink: string = '';
  @State activeCertList: Record<string, Object>[] = [];
  @State localRedeemCodeInput: string = '';
  @State localStoredCert: StoredLoginCert | null = null;
  @State qrLoginCodeInput: string = '';

  // SuperAdmin Governance
  @State globalStats: GlobalStats | null = null;
  @State adminUsers: AdminUserItem[] = [];
  @State userSearch: string = '';
  @State newAdminUsername: string = '';
  @State newAdminEmail: string = '';
  @State newAdminPassword: string = '';
  @State newAdminRole: string = 'user';
  @State pendingUsers: AdminUserItem[] = [];
  @State adminAccounts: AdminAccountItem[] = [];
  @State accountSearch: string = '';
  @State newGlobalAccName: string = '';
  @State newGlobalAccSlug: string = '';
  @State newGlobalAccOwnerId: string = '1';
  @State selectedQuotaAccountId: number = 0;
  @State qMaxClients: string = '100';
  @State qMaxGrpc: string = '100';
  @State qMaxBw: string = '1024';
  @State qOta: boolean = true;
  @State qAudit: boolean = true;

  // System settings
  @State sysRegOpen: boolean = true;
  @State sysRequireApproval: boolean = false;
  @State sysMaxAccountsPerUser: string = '5';
  @State sysDefaultRole: string = 'user';
  @State sysMotd: string = '';

  @State statusMsg: string = '';
  @State isError: boolean = false;
  private lastMode: string = '';

  aboutToAppear(): void {
    this.reloadData();
  }

  private notify(msg: string, err: boolean): void {
    this.statusMsg = msg;
    this.isError = err;
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  public async reloadData(): Promise<void> {
    this.lastMode = this.subMode;
    const api = ApiService.get();
    this.localStoredCert = api.storedCertificate;

    if (this.subMode === 'security') {
      const uRes = await api.getProfile();
      if (uRes.ok && uRes.data) {
        this.userProfile = uRes.data;
        this.secDisplayName = uRes.data.display_name || '';
        this.secEmail = uRes.data.email || '';
        this.secUsername = uRes.data.username || '';
      }
      const cRes = await api.listSecurityCertificates();
      if (cRes.ok && cRes.data) {
        this.activeCertList = cRes.data;
      }
    } else if (this.subMode === 'admin_users') {
      const r = await api.listGlobalUsers(this.userSearch);
      if (r.ok && r.data) {
        this.adminUsers = r.data;
      }
    } else if (this.subMode === 'admin_pending') {
      const r = await api.listPendingUsers();
      if (r.ok && r.data) {
        this.pendingUsers = r.data;
      }
    } else if (this.subMode === 'admin_accounts') {
      const sRes = await api.getGlobalStats();
      if (sRes.ok && sRes.data) {
        this.globalStats = sRes.data;
      }
      const r = await api.listGlobalAccounts(this.accountSearch);
      if (r.ok && r.data) {
        this.adminAccounts = r.data;
      }
    } else if (this.subMode === 'admin_settings') {
      const r = await api.getSystemSettings();
      if (r.ok && r.data) {
        const s = r.data;
        this.sysRegOpen = s['registration_open'] !== 'false';
        this.sysRequireApproval = s['require_approval'] === 'true';
        this.sysMaxAccountsPerUser = s['max_accounts_per_user'] || '5';
        this.sysDefaultRole = s['default_role'] || 'user';
        this.sysMotd = s['motd'] || '';
      }
    }
  }

  @Builder
  buildSecurityView() {
    Column({ space: 16 }) {
      // 1. 个人资料卡片
      Column({ space: 12 }) {
        Text('个人资料')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text('显示名称').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({ placeholder: '显示名称', text: this.secDisplayName })
              .height(34)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onChange((v: string) => { this.secDisplayName = v; })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('邮箱').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({ placeholder: '邮箱', text: this.secEmail })
              .height(34)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onChange((v: string) => { this.secEmail = v; })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')

        Button('保存个人资料')
          .height(34)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(async () => {
            const r = await ApiService.get().updateProfile(this.secDisplayName, this.secEmail, this.secUsername);
            this.notify(r.ok ? '个人资料已更新' : (r.error || '更新失败'), !r.ok);
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      // 2. 登录安全证书签发、兑换与轮换卡片 (7-day cert, 5-min exchange code, 1-hour session token, <=12 gen)
      Column({ space: 12 }) {
        Row({ space: 6 }) {
          HmosSymbolIcon($r('sys.symbol.checkmark_shield'), 16, this.theme().accentColor)
          Text('登录安全证书（有效期 7 天 · 兑换码 5 分钟 · 最多轮换 12 代）')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .layoutWeight(1)
        }
        .width('100%')

        Text('验证登录密码与两步验证码后签发一张有效期 7 天的登录安全证书，并生成 5 分钟单次兑换码与深链接。客户端使用安全证书可随时申请不超过 1 小时的管理会话令牌，剩余有效期低于 24 小时时可自动轮换下一代（最多 12 代）。')
          .fontSize(12)
          .fontColor(this.theme().textSecondary)
          .lineHeight(18)

        Row({ space: 8 }) {
          TextInput({ placeholder: '当前账户密码', text: this.certIssuePassword })
            .type(InputType.Password)
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.certIssuePassword = v; })

          if (this.userProfile?.totp_enabled) {
            TextInput({ placeholder: '2FA 验证码 / 恢复码', text: this.certIssueTotpCode })
              .height(34)
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => { this.certIssueTotpCode = v; })
          }

          TextInput({ placeholder: '终端备注名称', text: this.certIssueDeviceName })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.certIssueDeviceName = v; })

          HmosIconTextButton(
            $r('sys.symbol.plus'),
            '签发安全证书',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            async () => {
              if (!this.certIssuePassword) {
                this.notify('请输入账户密码以验证身份', true);
                return;
              }
              const r = await ApiService.get().issueSecurityCertificate(
                this.certIssuePassword,
                this.certIssueTotpCode,
                '',
                this.certIssueDeviceName
              );
              if (r.ok && r.data) {
                const code = String(r.data['exchange_code'] || '');
                const deepLink = String(r.data['deeplink'] || `miniclassisland://exchange-certificate/${code}`);
                this.issuedCertDeepLink = deepLink;
                this.certIssuePassword = '';
                this.certIssueTotpCode = '';
                this.notify('登录安全证书已签发，请在 5 分钟内使用兑换链接', false);
                await this.reloadData();
              } else {
                this.notify(r.error || '签发登录安全证书失败', true);
              }
            },
            34,
            12
          )
        }
        .width('100%')

        if (this.issuedCertDeepLink.length > 0) {
          Column({ space: 6 }) {
            Text('新签发安全证书 5 分钟单次兑换 DeepLink:')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().accentColor)
            TextInput({ text: this.issuedCertDeepLink })
              .height(34)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgCard)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          }
          .width('100%')
          .padding(10)
          .backgroundColor(this.theme().bgSubtle)
          .borderRadius(6)
        }

        // Local certificate redeem & status on this device
        Column({ space: 8 }) {
          Text('本机存储的登录安全证书')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          if (this.localStoredCert !== null) {
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(`证书 ID: ${this.localStoredCert.cert_id} · 代际: ${this.localStoredCert.generation}/${this.localStoredCert.max_generation}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme().badgeSuccessFg)
                Text(`过期时间: ${formatTimestamp(this.localStoredCert.expires_at)}`)
                  .fontSize(11)
                  .fontColor(this.theme().textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              HmosIconTextButton(
                $r('sys.symbol.checkmark_shield'),
                '续期 1 小时令牌',
                '#FFFFFF',
                this.theme().accentColor,
                Color.Transparent,
                async () => {
                  const r = await ApiService.get().requestSessionFromCertificate(3600);
                  this.notify(r.ok ? '已通过安全证书续期 1 小时管理令牌' : (r.error || '续期失败'), !r.ok);
                },
                28,
                11
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
                    this.localStoredCert = r.data;
                    this.notify(`证书已轮换至第 ${r.data.generation} 代`, false);
                  } else {
                    this.notify(r.error || '剩余有效期低于 24 小时方可轮换', true);
                  }
                },
                28,
                11
              )
            }
            .width('100%')
            .padding(10)
            .backgroundColor(this.theme().badgeSuccessBg)
            .borderRadius(6)
          }

          Row({ space: 8 }) {
            TextInput({
              placeholder: '输入兑换码或 miniclassisland://exchange-certificate/{Code} 下载证书到本机',
              text: this.localRedeemCodeInput
            })
              .height(34)
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => { this.localRedeemCodeInput = v; })
            HmosIconTextButton(
              $r('sys.symbol.qrcode'),
              '兑换并保存至本机',
              '#FFFFFF',
              this.theme().accentColor,
              Color.Transparent,
              async () => {
                if (!this.localRedeemCodeInput.trim()) { return; }
                const r = await ApiService.get().redeemCertificate(this.localRedeemCodeInput.trim());
                if (r.ok && r.data) {
                  this.localStoredCert = r.data;
                  this.localRedeemCodeInput = '';
                  this.notify('登录安全证书已下载并保存至本机', false);
                  await this.reloadData();
                } else {
                  this.notify(r.error || '兑换失败', true);
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
        .borderRadius(6)

        // Active server certificates list
        if (this.activeCertList.length > 0) {
          Column({ space: 6 }) {
            Text('当前账户已签发的活跃安全证书列表')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
            ForEach(this.activeCertList, (cert: Record<string, Object>) => {
              Row({ space: 8 }) {
                Column({ space: 2 }) {
                  Text(`${String(cert['device_name'] || '客户端')}`)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme().textPrimary)
                  Text(`代际: ${Number(cert['generation'] || 0)}/${Number(cert['max_generation'] || 12)} · 到期: ${formatTimestamp(Number(cert['expires_at'] || 0))}`)
                    .fontSize(11)
                    .fontColor(this.theme().textSecondary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                HmosIconTextButton(
                  $r('sys.symbol.trash'),
                  '吊销',
                  this.theme().dangerColor,
                  Color.Transparent,
                  this.theme().borderColor,
                  async () => {
                    const cid = String(cert['cert_id'] || '');
                    await ApiService.get().revokeSecurityCertificate(cid);
                    this.notify(`已吊销安全证书 ${cid}`, false);
                    await this.reloadData();
                  },
                  28,
                  11
                )
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
            }, (cert: Record<string, Object>) => String(cert['cert_id'] || Math.random()))
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      // 3. 反向扫码授权登录网页端卡片 (miniclassisland://qr-login/{Code})
      Column({ space: 12 }) {
        Row({ space: 6 }) {
          HmosSymbolIcon($r('sys.symbol.qrcode'), 16, this.theme().accentColor)
          Text('扫码登录网页端')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .layoutWeight(1)
        }
        .width('100%')

        Text('在网页端登录页切换到「扫码登录」，使用本客户端扫描二维码或粘贴 miniclassisland://qr-login/{Code} 链接，即可通过当前登录会话或本机安全证书一键授权网页端登录。')
          .fontSize(12)
          .fontColor(this.theme().textSecondary)

        Row({ space: 8 }) {
          TextInput({
            placeholder: '粘贴 miniclassisland://qr-login/{Code} 或网页登录码',
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
            $r('sys.symbol.checkmark_shield'),
            '授权网页登录',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            async () => {
              if (!this.qrLoginCodeInput.trim()) { return; }
              const r = await ApiService.get().authorizeWebQrLogin(this.qrLoginCodeInput.trim());
              if (r.ok) {
                this.qrLoginCodeInput = '';
                this.notify('已成功授权网页端登录', false);
              } else {
                this.notify(r.error || '网页端登录授权失败', true);
              }
            },
            34,
            12
          )
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      // 4. 修改密码卡片
      Column({ space: 12 }) {
        Text('修改登录密码')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text('当前密码').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({ placeholder: '输入当前密码', text: this.oldPassword })
              .type(InputType.Password)
              .height(34)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onChange((v: string) => { this.oldPassword = v; })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('新密码（至少 12 位）').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({ placeholder: '输入新密码', text: this.newPassword })
              .type(InputType.Password)
              .height(34)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onChange((v: string) => { this.newPassword = v; })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')

        Button('修改密码')
          .height(34)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(async () => {
            const r = await ApiService.get().changePassword(this.oldPassword, this.newPassword);
            this.notify(r.ok ? '密码修改成功' : (r.error || '密码修改失败'), !r.ok);
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      // 5. 两步验证卡片
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('两步验证')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text(this.userProfile?.totp_enabled ? '已启用' : '未启用')
            .fontSize(11)
            .fontColor(this.userProfile?.totp_enabled ? this.theme().badgeSuccessFg : this.theme().badgeWarningFg)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.userProfile?.totp_enabled ? this.theme().badgeSuccessBg : this.theme().badgeWarningBg)
            .borderRadius(99)
        }

        if (!this.userProfile?.totp_enabled) {
          Button('启用两步验证')
            .height(34)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(async () => {
              const r = await ApiService.get().enableTotp();
              if (r.ok && r.data) {
                this.totpSecret = String(r.data['secret'] || '');
                this.totpUri = String(r.data['qr_uri'] || r.data['uri'] || '');
              }
            })

          if (this.totpSecret.length > 0) {
            Text(`密钥: ${this.totpSecret}`).fontSize(12).fontFamily('monospace').fontColor(this.theme().accentColor)
            Text(`绑定链接: ${this.totpUri}`).fontSize(11).fontColor(this.theme().textSecondary)
            Row({ space: 8 }) {
              TextInput({ placeholder: '输入验证器 6 位动态码确认绑定', text: this.totpConfirmCode })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .layoutWeight(1)
                .onChange((v: string) => { this.totpConfirmCode = v; })
              Button('验证并启用')
                .height(34)
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor(this.theme().accentColor)
                .borderRadius(4)
                .onClick(async () => {
                  const r = await ApiService.get().confirmTotp(this.totpConfirmCode);
                  if (r.ok && r.data) {
                    const codes = (r.data['recovery_codes'] || []) as string[];
                    this.totpRecoveryCodes = codes;
                    this.notify('两步验证已激活，请保存好恢复码', false);
                    await this.reloadData();
                  }
                })
            }
          }
          if (this.totpRecoveryCodes.length > 0) {
            Text(`恢复码: ${this.totpRecoveryCodes.join(' , ')}`)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor(this.theme().successColor)
          }
        } else {
          Row({ space: 8 }) {
            TextInput({ placeholder: '登录密码', text: this.disableTotpPassword })
              .type(InputType.Password)
              .height(34)
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => { this.disableTotpPassword = v; })
            TextInput({ placeholder: '6位动态码', text: this.disableTotpCode })
              .height(34)
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => { this.disableTotpCode = v; })
            Button('停用两步验证')
              .height(34)
              .fontSize(12)
              .fontColor('#FFFFFF')
              .backgroundColor(this.theme().dangerColor)
              .borderRadius(4)
              .onClick(async () => {
                const r = await ApiService.get().disableTotp(this.disableTotpPassword, this.disableTotpCode);
                if (r.ok) {
                  this.notify('已停用两步验证', false);
                  await this.reloadData();
                }
              })
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  @Builder
  buildSuperAdminView() {
    Column({ space: 14 }) {
      if (this.subMode === 'admin_users') {
        Row({ space: 6 }) {
          TextInput({ placeholder: '新建用户名', text: this.newAdminUsername })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.newAdminUsername = v; })
          TextInput({ placeholder: '邮箱', text: this.newAdminEmail })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.newAdminEmail = v; })
          TextInput({ placeholder: '初始密码', text: this.newAdminPassword })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.newAdminPassword = v; })
          Button(this.newAdminRole === 'superadmin' ? '超管' : '普通')
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => {
              this.newAdminRole = this.newAdminRole === 'superadmin' ? 'user' : 'superadmin';
            })
          HmosIconTextButton(
            $r('sys.symbol.plus'),
            '创建用户',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            async () => {
              const payload: Record<string, Object> = {
                'username': this.newAdminUsername,
                'email': this.newAdminEmail,
                'password': this.newAdminPassword,
                'display_name': this.newAdminUsername,
                'role': this.newAdminRole,
                'can_create_account': true
              };
              const r = await ApiService.get().createGlobalUser(payload);
              if (r.ok) {
                this.notify('已创建全局用户', false);
                await this.reloadData();
              }
            },
            34,
            12
          )
        }

        ForEach(this.adminUsers, (u: AdminUserItem) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(`${u.display_name || u.username} (@${u.username}) [${u.role}]`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
              Text(`${u.email} · 状态:${u.is_active ? '正常' : '封禁'} · 建户权限:${u.can_create_account ? '允许' : '禁止'} · 两步验证:${u.totp_enabled ? '已启用' : '未启用'}`)
                .fontSize(11).fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button(u.can_create_account ? '禁建户' : '允建户')
              .height(26).fontSize(11).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(async () => {
                const body: Record<string, Object> = { 'can_create_account': !u.can_create_account };
                await ApiService.get().updateGlobalUser(u.id, body);
                await this.reloadData();
              })
            if (u.totp_enabled) {
              Button('重置两步验证')
                .height(26).fontSize(11).fontColor(this.theme().badgeWarningFg).backgroundColor(this.theme().badgeWarningBg).borderRadius(4)
                .onClick(async () => {
                  await ApiService.get().disableGlobalUserTotp(u.id);
                  await this.reloadData();
                })
            }
            Button(u.is_active ? '禁用' : '启用')
              .height(26).fontSize(11).fontColor(u.is_active ? this.theme().dangerColor : this.theme().successColor)
              .backgroundColor(this.theme().bgSubtle).borderRadius(4)
              .onClick(async () => {
                const body: Record<string, Object> = { 'is_active': !u.is_active };
                await ApiService.get().updateGlobalUser(u.id, body);
                await this.reloadData();
              })
            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              Color.Transparent,
              async () => {
                await ApiService.get().deleteGlobalUser(u.id);
                await this.reloadData();
              },
              26,
              13
            )
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (u: AdminUserItem) => `${u.id}`)
      } else if (this.subMode === 'admin_pending') {
        if (this.pendingUsers.length === 0) {
          Text('当前没有待审批的用户申请').fontSize(13).fontColor(this.theme().textSecondary).padding(16)
        }
        ForEach(this.pendingUsers, (u: AdminUserItem) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(`${u.username} (${u.email})`).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
              Text(`申请时间: ${formatTimestamp(u.created_at)}`).fontSize(12).fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('批准注册')
              .height(30).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
              .onClick(async () => {
                await ApiService.get().approvePendingUser(u.id);
                await this.reloadData();
              })
            Button('拒绝')
              .height(30).fontSize(12).fontColor(this.theme().dangerColor).backgroundColor(Color.Transparent)
              .onClick(async () => {
                await ApiService.get().rejectPendingUser(u.id);
                await this.reloadData();
              })
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (u: AdminUserItem) => `${u.id}`)
      } else if (this.subMode === 'admin_accounts') {
        Row({ space: 8 }) {
          TextInput({ placeholder: '新集控账户名称', text: this.newGlobalAccName })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.newGlobalAccName = v; })
          TextInput({ placeholder: '唯一子域名标识', text: this.newGlobalAccSlug })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.newGlobalAccSlug = v; })
          HmosIconTextButton(
            $r('sys.symbol.plus'),
            '创建账户',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            async () => {
              const payload: Record<string, Object> = {
                'name': this.newGlobalAccName,
                'slug': this.newGlobalAccSlug,
                'owner_id': Number(this.newGlobalAccOwnerId) || 1
              };
              const r = await ApiService.get().createGlobalAccount(payload);
              if (r.ok) {
                this.notify('已创建全局集控账户', false);
                await this.reloadData();
              }
            },
            34,
            12
          )
        }

        if (this.selectedQuotaAccountId > 0) {
          Column({ space: 8 }) {
            Text(`配置账户 #${this.selectedQuotaAccountId} 配额上限`)
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme().accentColor)
            Row({ space: 6 }) {
              Text('最大终端:').fontSize(12).fontColor(this.theme().textPrimary)
              TextInput({ text: this.qMaxClients }).height(32).width(70).fontSize(12)
                .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => { this.qMaxClients = v; })
              Text('最大连接:').fontSize(12).fontColor(this.theme().textPrimary)
              TextInput({ text: this.qMaxGrpc }).height(32).width(70).fontSize(12)
                .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => { this.qMaxGrpc = v; })
              Text('带宽上限:').fontSize(12).fontColor(this.theme().textPrimary)
              TextInput({ text: this.qMaxBw }).height(32).width(80).fontSize(12)
                .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => { this.qMaxBw = v; })
              Button('保存配额')
                .height(32).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
                .onClick(async () => {
                  const qMap: Record<string, number> = {
                    'max_clients': Number(this.qMaxClients) || 100,
                    'max_grpc_connections': Number(this.qMaxGrpc) || 100,
                    'max_bandwidth_mb': Number(this.qMaxBw) || 1024,
                    'feature.ota': this.qOta ? 1 : 0,
                    'feature.audit': this.qAudit ? 1 : 0
                  };
                  const r = await ApiService.get().updateGlobalAccountQuotas(this.selectedQuotaAccountId, qMap);
                  if (r.ok) {
                    this.notify('配额已保存', false);
                    this.selectedQuotaAccountId = 0;
                  }
                })
            }
          }
          .padding(12)
          .backgroundColor(this.theme().bgSubtle)
          .borderRadius(8)
        }

        ForEach(this.adminAccounts, (acc: AdminAccountItem) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(`${acc.name} (${acc.slug})`)
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
              Text(`ID: #${acc.id} · 准入: ${acc.registration_mode} · 状态: ${acc.is_active ? '活跃' : '停用'}`)
                .fontSize(12).fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button('进入集控管理')
              .height(28).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
              .onClick(() => {
                this.onTakeoverTenant(acc);
              })
            Button('配额')
              .height(28).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(() => {
                this.selectedQuotaAccountId = acc.id;
              })
            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              Color.Transparent,
              async () => {
                await ApiService.get().deleteGlobalAccount(acc.id);
                await this.reloadData();
              },
              28,
              14
            )
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (acc: AdminAccountItem) => `${acc.id}`)
      } else if (this.subMode === 'admin_settings') {
        Row() {
          Text('开放新用户注册').fontSize(13).fontColor(this.theme().textPrimary).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.sysRegOpen })
            .onChange((v: boolean) => { this.sysRegOpen = v; })
        }.width('100%').padding({ top: 8, bottom: 8 }).border({ width: { bottom: 1 }, color: this.theme().borderSubtle })

        Row() {
          Text('新用户注册需超管审批').fontSize(13).fontColor(this.theme().textPrimary).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.sysRequireApproval })
            .onChange((v: boolean) => { this.sysRequireApproval = v; })
        }.width('100%').padding({ top: 8, bottom: 8 }).border({ width: { bottom: 1 }, color: this.theme().borderSubtle })

        Row({ space: 8 }) {
          Text('每用户最大可建账户数:').fontSize(13).fontColor(this.theme().textPrimary)
          TextInput({ text: this.sysMaxAccountsPerUser })
            .height(34).width(80).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => { this.sysMaxAccountsPerUser = v; })
        }.width('100%')

        Row({ space: 8 }) {
          Text('系统公告:').fontSize(13).fontColor(this.theme().textPrimary)
          TextInput({ text: this.sysMotd })
            .height(34).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.sysMotd = v; })
        }.width('100%')

        Button('保存系统设置')
          .height(36)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .width('100%')
          .onClick(async () => {
            const settingsMap: Record<string, string> = {
              'registration_open': this.sysRegOpen ? 'true' : 'false',
              'require_approval': this.sysRequireApproval ? 'true' : 'false',
              'max_accounts_per_user': this.sysMaxAccountsPerUser,
              'default_role': this.sysDefaultRole,
              'motd': this.sysMotd
            };
            const r = await ApiService.get().updateSystemSettings(settingsMap);
            this.notify(r.ok ? '全局系统设置已保存' : (r.error || '保存失败'), !r.ok);
          })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.theme().bgCard)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().borderColor })
  }

  build() {
    Column({ space: 16 }) {
      if (this.lastMode !== this.subMode) {
        Row().height(0).onAppear(() => {
          this.reloadData();
        })
      }

      if (this.statusMsg.length > 0) {
        Text(this.statusMsg)
          .fontSize(13)
          .fontColor(this.isError ? this.theme().badgeDangerFg : this.theme().badgeSuccessFg)
          .padding(10)
          .width('100%')
          .backgroundColor(this.isError ? this.theme().badgeDangerBg : this.theme().badgeSuccessBg)
          .borderRadius(4)
      }

      if (this.subMode === 'security') {
        this.buildSecurityView()
      } else {
        this.buildSuperAdminView()
      }
    }
    .width('100%')
  }
}
