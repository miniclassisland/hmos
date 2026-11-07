import {
  AccountInfo,
  QuotaItem,
  MemberItem,
  InvitationItem,
  PairingRequestItem,
  PreRegItem,
  AdminAccountItem,
  getQuotaLabel
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosIconTextButton } from './HmosIcons';
import { SecurityAndAdminView } from './SecurityAndAdminView';

@Component
export struct AdmissionAndGovernanceView {
  @Prop accountId: string = '';
  @Prop subMode: string = 'pairing';
  // 'pairing' | 'prereg' | 'account' | 'access' | 'invitations' | 'security' | 'admin_users' | 'admin_pending' | 'admin_accounts' | 'admin_settings'
  @Prop breakpoint: string = 'sm';
  @Prop themeMode: string = 'light';
  public onTakeoverTenant: (acc: AdminAccountItem) => void = () => {};
  public onRefreshAccounts: () => void = () => {};

  // Admission state
  @State accountInfo: AccountInfo | null = null;
  @State pairingModeVal: string = 'open';
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

  @State statusMsg: string = '';
  @State isError: boolean = false;
  private lastAccount: string = '';
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

    if (this.subMode === 'pairing' && this.accountId.length > 0) {
      const mRes = await api.getPairingStatus(this.accountId);
      if (mRes.ok && mRes.data) {
        this.pairingModeVal = mRes.data;
      } else {
        const infoRes = await api.getAccountInfo(this.accountId);
        if (infoRes.ok && infoRes.data) {
          this.accountInfo = infoRes.data;
          this.pairingModeVal = infoRes.data.registration_mode || 'open';
        }
      }
      const pRes = await api.listPairingRequests(this.accountId, this.pairingFilter);
      if (pRes.ok && pRes.data) {
        this.pairingList = pRes.data;
      }
    } else if (this.subMode === 'prereg' && this.accountId.length > 0) {
      const r = await api.listPreRegItems(this.accountId);
      if (r.ok && r.data) {
        this.preRegList = r.data;
      }
    } else if (this.subMode === 'account' && this.accountId.length > 0) {
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
    } else if (this.subMode === 'access' && this.accountId.length > 0) {
      const mRes = await api.listMembers(this.accountId);
      if (mRes.ok && mRes.data) {
        this.members = mRes.data;
      }
    } else if (this.subMode === 'invitations' && this.accountId.length > 0) {
      const iRes = await api.listInvitations(this.accountId);
      if (iRes.ok && iRes.data) {
        this.invitations = iRes.data;
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
    if (this.subMode === 'security') { return '管理个人资料、登录安全证书、扫码登录与两步验证'; }
    if (this.subMode === 'admin_users') { return '管理全平台注册用户、角色权限与两步验证状态'; }
    if (this.subMode === 'admin_pending') { return '审核待批准的新用户注册申请'; }
    if (this.subMode === 'admin_accounts') { return '管理全平台集控账户、资源配额并支持一键进入接管'; }
    return '配置全平台开放注册、审核策略与系统公告参数';
  }

  @Builder
  buildPairingView() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text('终端接入安全策略')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Text('决定新 ClassIsland 客户端首次连接本账户注册服务时的准入规则。无论选择何种模式，只要设备已在「预注册客户端」白名单中匹配（班级标识或物理 MAC），均可直接放行并自动绑定预设档案。')
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
              .fontColor(this.pairingModeVal === pair[0] ? '#FFFFFF' : this.theme().textPrimary)
              .backgroundColor(this.pairingModeVal === pair[0] ? this.theme().accentColor : this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(async () => {
                const r = await ApiService.get().setPairingMode(this.accountId, pair[0]);
                if (r.ok) {
                  this.pairingModeVal = pair[0];
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
              Text(`终端标识: ${req.client_uid || '-'} | MAC: ${req.mac || '-'} | IP: ${req.ip || '-'}`)
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
          TextInput({ placeholder: '设备备注', text: this.newPreLabel })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.newPreLabel = v; })
          TextInput({ placeholder: '班级标识', text: this.newPreClassId })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.newPreClassId = v; })
          TextInput({ placeholder: 'MAC 地址（可选）', text: this.newPreMac })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.newPreMac = v; })
          HmosIconTextButton(
            $r('sys.symbol.plus'),
            '添加',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            async () => {
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
            },
            34,
            12
          )
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

            HmosIconTextButton(
              $r('sys.symbol.folder'),
              '下载引导配置',
              this.theme().accentColor,
              this.theme().bgAccentSubtle,
              Color.Transparent,
              async () => {
                const r = await ApiService.get().getPreRegPresetJson(this.accountId, item.id);
                if (r.ok && r.data) {
                  this.exportedPresetText = r.data;
                }
              },
              28,
              11
            )

            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              Color.Transparent,
              async () => {
                await ApiService.get().deletePreRegItem(this.accountId, item.id);
                await this.reloadData();
              },
              28,
              14
            )
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
          Text('子域名标识').fontSize(13).fontColor(this.theme().textSecondary).width(120)
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
            Text('账户编号').fontSize(13).fontColor(this.theme().textSecondary).width(120)
            Text(`${this.accountInfo.id}`).fontSize(13).fontColor(this.theme().textPrimary)
          }.width('100%')

          Row({ space: 8 }) {
            Text('接口密钥').fontSize(13).fontColor(this.theme().textSecondary).width(120)
            Text(this.accountInfo.api_key)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor(this.theme().textPrimary)
              .layoutWeight(1)
            HmosIconTextButton(
              $r('sys.symbol.arrow_clockwise'),
              '重置密钥',
              this.theme().textPrimary,
              this.theme().bgSubtle,
              this.theme().borderColor,
              async () => {
                const r = await ApiService.get().regenerateApiKey(this.accountId);
                if (r.ok) {
                  this.notify('接口密钥已重新生成', false);
                  await this.reloadData();
                }
              },
              28,
              11
            )
          }.width('100%')
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })

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
            Text(getQuotaLabel(q.quota_key || q.quota_type || '')).fontSize(13).fontColor(this.theme().textPrimary).layoutWeight(1)
            Text(`${q.current_value} / ${q.max_value ?? q.limit_value ?? 0}`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().accentColor)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (q: QuotaItem) => `${q.id}_${q.quota_key}`)
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
              HmosIconButton(
                $r('sys.symbol.trash'),
                this.theme().dangerColor,
                Color.Transparent,
                Color.Transparent,
                async () => {
                  await ApiService.get().removeMember(this.accountId, m.user_id);
                  await this.reloadData();
                },
                26,
                13
              )
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
          HmosIconTextButton(
            $r('sys.symbol.plus'),
            '创建邀请码',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            async () => {
              const r = await ApiService.get().createInvitation(this.accountId, this.newInvRole, Number(this.newInvMaxUses) || 10);
              if (r.ok) {
                this.notify('邀请码已创建', false);
                await this.reloadData();
              }
            },
            32,
            12
          )
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
            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              Color.Transparent,
              async () => {
                await ApiService.get().revokeInvitation(this.accountId, inv.id);
                await this.reloadData();
              },
              26,
              13
            )
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

  build() {
    Column({ space: 16 }) {
      if (this.lastAccount !== this.accountId || this.lastMode !== this.subMode) {
        Row().height(0).onAppear(() => {
          this.reloadData();
        })
      }

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

        HmosIconTextButton(
          $r('sys.symbol.arrow_clockwise'),
          '刷新',
          this.theme().textPrimary,
          this.theme().bgCard,
          this.theme().borderColor,
          () => {
            this.reloadData();
          },
          34,
          13
        )
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
      } else {
        SecurityAndAdminView({
          subMode: this.subMode,
          breakpoint: this.breakpoint,
          themeMode: this.themeMode,
          onTakeoverTenant: (acc: AdminAccountItem) => {
            this.onTakeoverTenant(acc);
          },
          onRefreshAccounts: () => {
            this.onRefreshAccounts();
          }
        })
      }
    }
    .width('100%')
  }
}
