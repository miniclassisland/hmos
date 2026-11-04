import {
  AccountInfo,
  QuotaItem,
  MemberItem,
  InvitationItem,
  PairingRequestItem,
  PreRegItem,
  UserInfo,
  AdminUserItem,
  AdminAccountItem,
  GlobalStats,
  formatTimestamp
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';

@Component
export struct AdmissionAndGovernanceView {
  @Prop accountId: number = 0;
  @Prop subMode: string = 'pairing';
  // 'pairing' | 'prereg' | 'account' | 'access' | 'invitations' | 'security' | 'admin_users' | 'admin_pending' | 'admin_accounts' | 'admin_settings'
  @Prop breakpoint: string = 'sm';
  @Prop themeMode: string = 'light';
  public onTakeoverTenant: (acc: AdminAccountItem) => void = () => {};

  // Admission state
  @State accountInfo: AccountInfo | null = null;
  @State pairingList: PairingRequestItem[] = [];
  @State pairingFilter: string = 'pending';
  @State preRegList: PreRegItem[] = [];
  @State newPreLabel: string = '';
  @State newPreClassId: string = '';
  @State newPreMac: string = '';
  @State batchCsvText: string = '';
  @State showBatchImport: boolean = false;
  @State exportedPresetText: string = '';

  // Account & Quotas & Members & Invitations
  @State editAccName: string = '';
  @State editAccSlug: string = '';
  @State quotas: QuotaItem[] = [];
  @State members: MemberItem[] = [];
  @State invitations: InvitationItem[] = [];
  @State newInvRole: string = 'member';
  @State newInvMaxUses: string = '10';
  @State joinInviteCode: string = '';

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
  private lastAccount: number = -1;
  private lastMode: string = '';

  aboutToAppear(): void {
    this.reloadData();
  }

  private notify(msg: string, err: boolean): void {
    this.statusMsg = msg;
    this.isError = err;
  }

  public async reloadData(): Promise<void> {
    this.lastAccount = this.accountId;
    this.lastMode = this.subMode;
    const api = ApiService.get();

    if (this.subMode === 'pairing' && this.accountId > 0) {
      const infoRes = await api.getAccountInfo(this.accountId);
      if (infoRes.ok && infoRes.data) {
        this.accountInfo = infoRes.data;
      }
      const pRes = await api.listPairingRequests(this.accountId, this.pairingFilter);
      if (pRes.ok && pRes.data) {
        this.pairingList = pRes.data;
      }
    } else if (this.subMode === 'prereg' && this.accountId > 0) {
      const r = await api.listPreRegItems(this.accountId);
      if (r.ok && r.data) {
        this.preRegList = r.data;
      }
    } else if (this.subMode === 'account' && this.accountId > 0) {
      const infoRes = await api.getAccountInfo(this.accountId);
      if (infoRes.ok && infoRes.data) {
        this.accountInfo = infoRes.data;
        this.editAccName = infoRes.data.name;
        this.editAccSlug = infoRes.data.slug;
      }
      const qRes = await api.getAccountQuotas(this.accountId);
      if (qRes.ok && qRes.data) {
        this.quotas = qRes.data;
      }
    } else if (this.subMode === 'access' && this.accountId > 0) {
      const mRes = await api.listMembers(this.accountId);
      if (mRes.ok && mRes.data) {
        this.members = mRes.data;
      }
    } else if (this.subMode === 'invitations' && this.accountId > 0) {
      const iRes = await api.listInvitations(this.accountId);
      if (iRes.ok && iRes.data) {
        this.invitations = iRes.data;
      }
    } else if (this.subMode === 'security') {
      const uRes = await api.getProfile();
      if (uRes.ok && uRes.data) {
        this.userProfile = uRes.data;
        this.secDisplayName = uRes.data.display_name || '';
        this.secEmail = uRes.data.email || '';
        this.secUsername = uRes.data.username || '';
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

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private getPageTitle(): string {
    if (this.subMode === 'pairing') { return '配对码与接入审批'; }
    if (this.subMode === 'prereg') { return '预注册客户端'; }
    if (this.subMode === 'account') { return '账户概览'; }
    if (this.subMode === 'access') { return '访问控制'; }
    if (this.subMode === 'invitations') { return '邀请管理'; }
    if (this.subMode === 'security') { return '安全设置'; }
    if (this.subMode === 'admin_users') { return '全局用户管理'; }
    if (this.subMode === 'admin_pending') { return '注册审核'; }
    if (this.subMode === 'admin_accounts') { return '全局账户与配额'; }
    return '系统参数设置';
  }

  private getPageSubtitle(): string {
    if (this.subMode === 'pairing') { return '配置账户终端接入安全策略，并审批新终端的配对请求'; }
    if (this.subMode === 'prereg') { return '预先登记班级终端白名单并生成免配对专属引导配置'; }
    if (this.subMode === 'account') { return '查看和管理当前 MINI ClassIsland 账户信息与引导凭证'; }
    if (this.subMode === 'access') { return '管理当前账户下的协作成员与角色权限'; }
    if (this.subMode === 'invitations') { return '生成成员邀请链接与邀请码，管理团队加入权限'; }
    if (this.subMode === 'security') { return '管理个人资料、登录密码与两步验证 (2FA TOTP)'; }
    if (this.subMode === 'admin_users') { return '管理全平台注册用户、角色权限与两步验证状态'; }
    if (this.subMode === 'admin_pending') { return '审核待批准的新用户注册申请'; }
    if (this.subMode === 'admin_accounts') { return '管理全平台集控账户、资源配额并支持一键进入接管'; }
    return '配置全平台开放注册、审核策略与系统公告参数';
  }

  @Builder
  buildPairingView() {
    Column({ space: 16 }) {
      // 终端接入安全策略卡片 (matches web/app/pairing/page.tsx)
      Column({ space: 10 }) {
        Text('终端接入安全策略')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Text('决定新 ClassIsland 客户端首次连接本账户 gRPC 注册服务时的准入规则。无论选择何种模式，只要设备已在「预注册客户端」白名单中匹配（班级标识或物理 MAC），均可直接放行并自动绑定预设档案。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach([
            ['open', '开放注册（直接放行）'],
            ['pairing', '配对码审批（需管理员批准）'],
            ['pre_reg', '仅白名单（仅允许预注册设备）']
          ], (pair: string[]) => {
            Button(pair[1])
              .height(32)
              .fontSize(12)
              .margin({ right: 8, bottom: 6 })
              .fontColor(this.accountInfo?.registration_mode === pair[0] ? '#FFFFFF' : this.theme().textPrimary)
              .backgroundColor(this.accountInfo?.registration_mode === pair[0] ? this.theme().accentColor : this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(async () => {
                if (!this.accountInfo) { return; }
                const r = await ApiService.get().updateAccountInfo(
                  this.accountId,
                  this.accountInfo.name,
                  this.accountInfo.slug,
                  pair[0]
                );
                if (r.ok) {
                  this.notify(`设备接入策略已切换为：${pair[1]}`, false);
                  await this.reloadData();
                }
              })
          }, (pair: string[]) => pair[0])
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      // 配对请求列表卡片
      Column({ space: 12 }) {
        Row({ space: 6 }) {
          Text('配对请求列表')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .layoutWeight(1)
          ForEach(['pending', 'approved', 'rejected', 'all'], (st: string) => {
            Button(st === 'pending' ? '待审批' : (st === 'approved' ? '已批准' : (st === 'rejected' ? '已拒绝' : '全部')))
              .height(26)
              .fontSize(11)
              .fontColor(this.pairingFilter === st ? '#FFFFFF' : this.theme().textPrimary)
              .backgroundColor(this.pairingFilter === st ? this.theme().accentColor : this.theme().bgSubtle)
              .borderRadius(4)
              .onClick(() => {
                this.pairingFilter = st;
                this.reloadData();
              })
          }, (st: string) => st)
        }
        .width('100%')

        if (this.pairingList.length === 0) {
          Text('暂无配对请求记录')
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
            .padding(20)
        }

        ForEach(this.pairingList, (req: PairingRequestItem) => {
          Row({ space: 12 }) {
            Text(req.pairing_code)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().badgeInfoFg)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.theme().badgeInfoBg)
              .borderRadius(99)

            Column({ space: 2 }) {
              Row({ space: 6 }) {
                Text(`班级标识: ${req.client_id || '-'}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textPrimary)
                Text(
                  req.status === 'rejected' ? '已拒绝' :
                  (req.status === 'approved' ? '已批准' : '待管理员审批')
                )
                  .fontSize(11)
                  .fontColor(
                    req.status === 'rejected' ? this.theme().badgeDangerFg :
                    (req.status === 'approved' ? this.theme().badgeSuccessFg : this.theme().badgeWarningFg)
                  )
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .backgroundColor(
                    req.status === 'rejected' ? this.theme().badgeDangerBg :
                    (req.status === 'approved' ? this.theme().badgeSuccessBg : this.theme().badgeWarningBg)
                  )
                  .borderRadius(99)
              }
              Text(`UID: ${req.client_uid || '-'} | MAC: ${req.mac || '-'} | IP: ${req.ip || '-'}`)
                .fontSize(12)
                .fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (req.status === 'pending') {
              Button('批准并配发档案')
                .height(30)
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor(this.theme().accentColor)
                .borderRadius(4)
                .onClick(async () => {
                  const emptyProf: Record<string, Object> = {};
                  const r = await ApiService.get().approvePairingRequest(this.accountId, req.id, emptyProf);
                  if (r.ok) {
                    this.notify(`配对码 ${req.pairing_code} 已批准`, false);
                    await this.reloadData();
                  }
                })
              Button('拒绝')
                .height(30)
                .fontSize(12)
                .fontColor(this.theme().dangerColor)
                .backgroundColor(Color.Transparent)
                .onClick(async () => {
                  await ApiService.get().rejectPairingRequest(this.accountId, req.id);
                  await this.reloadData();
                })
            }
          }
          .width('100%')
          .padding({ top: 10, bottom: 10, left: 8, right: 8 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (req: PairingRequestItem) => `${req.id}`)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  @Builder
  buildPreRegView() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Row() {
          Text('登记新客户端')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .layoutWeight(1)
          Button('批量 CSV 导入')
            .height(28)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgSubtle)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => { this.showBatchImport = !this.showBatchImport; })
        }
        .width('100%')

        Row({ space: 8 }) {
          TextInput({ placeholder: '设备备注 (如 高一1班一体机)', text: this.newPreLabel })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.newPreLabel = v; })
          TextInput({ placeholder: '班级标识 (ClassIdentity)', text: this.newPreClassId })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.newPreClassId = v; })
          TextInput({ placeholder: 'MAC 地址 (可选)', text: this.newPreMac })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.newPreMac = v; })
          Button('添加')
            .height(34)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(async () => {
              const payload: Record<string, Object> = {
                'label': this.newPreLabel,
                'class_identity': this.newPreClassId,
                'mac_address': this.newPreMac
              };
              const r = await ApiService.get().createPreRegItem(this.accountId, payload);
              if (r.ok) {
                this.newPreLabel = '';
                this.newPreClassId = '';
                this.newPreMac = '';
                this.notify('预注册条目已创建', false);
                await this.reloadData();
              }
            })
        }
        .width('100%')

        if (this.showBatchImport) {
          Column({ space: 8 }) {
            Text('每行格式: 备注名称,班级标识,MAC地址')
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
            TextArea({ placeholder: '高一1班,Class_101,00:11:22:33:44:55', text: this.batchCsvText })
              .height(90)
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onChange((v: string) => { this.batchCsvText = v; })
            Button('执行批量导入')
              .height(32)
              .fontSize(12)
              .fontColor('#FFFFFF')
              .backgroundColor(this.theme().accentColor)
              .borderRadius(4)
              .onClick(async () => {
                const lines = this.batchCsvText.split('\n');
                const items: Record<string, Object>[] = [];
                for (let i = 0; i < lines.length; i++) {
                  const l = lines[i].trim();
                  if (!l) { continue; }
                  const parts = l.split(',');
                  items.push({
                    'label': (parts[0] || '').trim(),
                    'class_identity': (parts[1] || '').trim(),
                    'mac_address': (parts[2] || '').trim()
                  });
                }
                if (items.length > 0) {
                  const r = await ApiService.get().batchCreatePreRegItems(this.accountId, items);
                  if (r.ok) {
                    this.showBatchImport = false;
                    this.batchCsvText = '';
                    await this.reloadData();
                  }
                }
              })
          }
          .padding(12)
          .backgroundColor(this.theme().bgSubtle)
          .borderRadius(6)
        }

        if (this.exportedPresetText.length > 0) {
          Column({ space: 4 }) {
            Row() {
              Text('专属 ManagementPreset.json').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary).layoutWeight(1)
              Button('关闭').height(22).fontSize(11).fontColor(this.theme().textSecondary).backgroundColor(Color.Transparent)
                .onClick(() => { this.exportedPresetText = ''; })
            }
            TextArea({ text: this.exportedPresetText })
              .height(100)
              .fontSize(11)
              .fontFamily('monospace')
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          }
        }

        ForEach(this.preRegList, (item: PreRegItem) => {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text(`${item.label || item.class_identity} (${item.class_identity})`)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().textPrimary)
              Text(`MAC: ${item.mac_address || '不限'} | 已绑定终端: ${item.paired_client_uid || '待接入'}`)
                .fontSize(12)
                .fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button('下载专属引导配置')
              .height(28)
              .fontSize(11)
              .fontColor(this.theme().accentColor)
              .backgroundColor(this.theme().bgAccentSubtle)
              .borderRadius(4)
              .onClick(async () => {
                const r = await ApiService.get().getPreRegPresetJson(this.accountId, item.id);
                if (r.ok && r.data) {
                  this.exportedPresetText = r.data;
                }
              })

            Button('删除')
              .height(28)
              .fontSize(11)
              .fontColor(this.theme().dangerColor)
              .backgroundColor(Color.Transparent)
              .onClick(async () => {
                await ApiService.get().deletePreRegItem(this.accountId, item.id);
                await this.reloadData();
              })
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (item: PreRegItem) => `${item.id}`)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  @Builder
  buildAccountView() {
    Column({ space: 16 }) {
      // 账户详情卡片 (matches web/app/accounts/page.tsx .detail-row)
      Column({ space: 14 }) {
        Row({ space: 8 }) {
          Text('账户名称').fontSize(13).fontColor(this.theme().textSecondary).width(120)
          TextInput({ text: this.editAccName })
            .height(34)
            .fontSize(13)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.editAccName = v; })
        }.width('100%')

        Row({ space: 8 }) {
          Text('子域名标识 (Slug)').fontSize(13).fontColor(this.theme().textSecondary).width(120)
          TextInput({ text: this.editAccSlug })
            .height(34)
            .fontSize(13)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.editAccSlug = v; })
          Button('保存修改')
            .height(34)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(async () => {
              const r = await ApiService.get().updateAccountInfo(this.accountId, this.editAccName, this.editAccSlug);
              if (r.ok) {
                this.notify('账户信息已更新', false);
                await this.reloadData();
              }
            })
        }.width('100%')

        if (this.accountInfo !== null) {
          Row({ space: 8 }) {
            Text('账户 ID').fontSize(13).fontColor(this.theme().textSecondary).width(120)
            Text(`${this.accountInfo.id}`).fontSize(13).fontColor(this.theme().textPrimary)
          }.width('100%')

          Row({ space: 8 }) {
            Text('API Key').fontSize(13).fontColor(this.theme().textSecondary).width(120)
            Text(this.accountInfo.api_key)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor(this.theme().textPrimary)
              .layoutWeight(1)
            Button('重置 API Key')
              .height(28)
              .fontSize(11)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(async () => {
                const r = await ApiService.get().regenerateApiKey(this.accountId);
                if (r.ok) {
                  this.notify('API Key 已重新生成', false);
                  await this.reloadData();
                }
              })
          }.width('100%')
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

      // 配额卡片
      Column({ space: 10 }) {
        Text('账户配额与功能')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        if (this.quotas.length === 0) {
          Text('默认配额策略生效中')
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        ForEach(this.quotas, (q: QuotaItem) => {
          Row() {
            Text(q.quota_type).fontSize(13).fontColor(this.theme().textPrimary).layoutWeight(1)
            Text(`${q.current_value} / ${q.limit_value}`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().accentColor)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (q: QuotaItem) => `${q.id}_${q.quota_type}`)
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
  buildAccessAndInvitationsView() {
    Column({ space: 12 }) {
      if (this.subMode === 'access') {
        ForEach(this.members, (m: MemberItem) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(m.display_name || m.username || '用户')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().textPrimary)
              Text(`@${m.username} · ${m.email}`)
                .fontSize(12)
                .fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            ForEach(['admin', 'member', 'viewer'], (rName: string) => {
              Button(rName === 'admin' ? '管理员' : (rName === 'member' ? '成员' : '只读'))
                .height(26)
                .fontSize(11)
                .fontColor(m.role === rName ? '#FFFFFF' : this.theme().textPrimary)
                .backgroundColor(m.role === rName ? this.theme().accentColor : this.theme().bgSubtle)
                .borderRadius(4)
                .onClick(async () => {
                  await ApiService.get().updateMemberRole(this.accountId, m.user_id, rName);
                  await this.reloadData();
                })
            }, (rName: string) => rName)

            if (m.role !== 'owner') {
              Button('移除')
                .height(26)
                .fontSize(11)
                .fontColor(this.theme().dangerColor)
                .backgroundColor(Color.Transparent)
                .onClick(async () => {
                  await ApiService.get().removeMember(this.accountId, m.user_id);
                  await this.reloadData();
                })
            }
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (m: MemberItem) => `${m.user_id}`)
      } else {
        Row({ space: 8 }) {
          Text('邀请角色:').fontSize(13).fontColor(this.theme().textPrimary)
          ForEach(['admin', 'member', 'viewer'], (rn: string) => {
            Button(rn === 'admin' ? '管理员' : (rn === 'member' ? '成员' : '只读'))
              .height(28)
              .fontSize(12)
              .fontColor(this.newInvRole === rn ? '#FFFFFF' : this.theme().textPrimary)
              .backgroundColor(this.newInvRole === rn ? this.theme().accentColor : this.theme().bgSubtle)
              .borderRadius(4)
              .onClick(() => { this.newInvRole = rn; })
          }, (rn: string) => rn)
          Blank()
          Button('+ 创建邀请码')
            .height(32)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(async () => {
              const r = await ApiService.get().createInvitation(this.accountId, this.newInvRole, Number(this.newInvMaxUses) || 10);
              if (r.ok) {
                this.notify('邀请码已创建', false);
                await this.reloadData();
              }
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          TextInput({ placeholder: '输入他人分享的邀请码以加入账户', text: this.joinInviteCode })
            .height(34)
            .fontSize(13)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.joinInviteCode = v; })
          Button('接受邀请')
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgSubtle)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(async () => {
              if (!this.joinInviteCode.trim()) { return; }
              const r = await ApiService.get().acceptInvitation(this.joinInviteCode.trim());
              this.notify(r.ok ? '成功加入集控账户' : (r.error || '邀请码无效'), !r.ok);
            })
        }

        ForEach(this.invitations, (inv: InvitationItem) => {
          Row({ space: 10 }) {
            Text(inv.code)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().badgeInfoFg)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.theme().badgeInfoBg)
              .borderRadius(6)
            Text(`角色: ${inv.role} · 已使用 ${inv.used_count} / ${inv.max_uses}`)
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
              .layoutWeight(1)
            Button('撤销')
              .height(26)
              .fontSize(11)
              .fontColor(this.theme().dangerColor)
              .backgroundColor(Color.Transparent)
              .onClick(async () => {
                await ApiService.get().revokeInvitation(this.accountId, inv.id);
                await this.reloadData();
              })
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (inv: InvitationItem) => `${inv.id}`)
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.theme().bgCard)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().borderColor })
  }

  @Builder
  buildSecurityView() {
    Column({ space: 16 }) {
      // 1. 个人资料卡片 (matches web/app/security/page.tsx)
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

      // 2. 修改密码卡片
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

      // 3. 2FA TOTP 卡片
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('两步验证 (TOTP 2FA)')
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
            Text(`密钥 (Secret): ${this.totpSecret}`).fontSize(12).fontFamily('monospace').fontColor(this.theme().accentColor)
            Text(`URI: ${this.totpUri}`).fontSize(11).fontColor(this.theme().textSecondary)
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
                  this.notify('已停用 2FA', false);
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
          Button('+ 创建用户')
            .height(34).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
            .onClick(async () => {
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
            })
        }

        ForEach(this.adminUsers, (u: AdminUserItem) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(`${u.display_name || u.username} (@${u.username}) [${u.role}]`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
              Text(`${u.email} · 状态:${u.is_active ? '正常' : '封禁'} · 建户权限:${u.can_create_account ? '允许' : '禁止'} · 2FA:${u.totp_enabled ? '已启用' : '未启用'}`)
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
              Button('重置2FA')
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
            Button('删除')
              .height(26).fontSize(11).fontColor(this.theme().dangerColor).backgroundColor(Color.Transparent)
              .onClick(async () => {
                await ApiService.get().deleteGlobalUser(u.id);
                await this.reloadData();
              })
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
          TextInput({ placeholder: '唯一标识 (slug)', text: this.newGlobalAccSlug })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.newGlobalAccSlug = v; })
          Button('+ 创建账户')
            .height(34).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
            .onClick(async () => {
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
            })
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
              Text('最大gRPC:').fontSize(12).fontColor(this.theme().textPrimary)
              TextInput({ text: this.qMaxGrpc }).height(32).width(70).fontSize(12)
                .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => { this.qMaxGrpc = v; })
              Text('带宽MB:').fontSize(12).fontColor(this.theme().textPrimary)
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
            Button('删除')
              .height(28).fontSize(12).fontColor(this.theme().dangerColor).backgroundColor(Color.Transparent)
              .onClick(async () => {
                await ApiService.get().deleteGlobalAccount(acc.id);
                await this.reloadData();
              })
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (acc: AdminAccountItem) => `${acc.id}`)
      } else if (this.subMode === 'admin_settings') {
        Row() {
          Text('开放新用户注册 (registration_open)').fontSize(13).fontColor(this.theme().textPrimary).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.sysRegOpen })
            .onChange((v: boolean) => { this.sysRegOpen = v; })
        }.width('100%').padding({ top: 8, bottom: 8 }).border({ width: { bottom: 1 }, color: this.theme().borderSubtle })

        Row() {
          Text('新用户注册需超管审批 (require_approval)').fontSize(13).fontColor(this.theme().textPrimary).layoutWeight(1)
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
          Text('系统公告 (MOTD):').fontSize(13).fontColor(this.theme().textPrimary)
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
      if (this.lastAccount !== this.accountId || this.lastMode !== this.subMode) {
        Row().height(0).onAppear(() => {
          this.reloadData();
        })
      }

      // Page Header (.page-header)
      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text(this.getPageTitle())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text(this.getPageSubtitle())
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('刷新')
          .height(34)
          .fontSize(13)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgCard)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onClick(() => {
            this.reloadData();
          })
      }
      .width('100%')

      if (this.statusMsg.length > 0) {
        Text(this.statusMsg)
          .fontSize(13)
          .fontColor(this.isError ? this.theme().badgeDangerFg : this.theme().badgeSuccessFg)
          .padding(10)
          .width('100%')
          .backgroundColor(this.isError ? this.theme().badgeDangerBg : this.theme().badgeSuccessBg)
          .borderRadius(4)
      }

      if (this.subMode === 'pairing') {
        this.buildPairingView()
      } else if (this.subMode === 'prereg') {
        this.buildPreRegView()
      } else if (this.subMode === 'account') {
        this.buildAccountView()
      } else if (this.subMode === 'access' || this.subMode === 'invitations') {
        this.buildAccessAndInvitationsView()
      } else if (this.subMode === 'security') {
        this.buildSecurityView()
      } else {
        this.buildSuperAdminView()
      }
    }
    .width('100%')
  }
}
