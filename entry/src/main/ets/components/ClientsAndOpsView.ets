import {
  ClientRecord,
  ResourceItem,
  ConfigSnapshotItem,
  formatTimestamp
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconTextButton } from './HmosIcons';
import { NotificationsAndAuditView } from './NotificationsAndAuditView';

@Component
export struct ClientsAndOpsView {
  @Prop accountId: number = 0;
  @Prop subMode: string = 'clients'; // 'clients' | 'notifications' | 'audit'
  @Prop breakpoint: string = 'sm';
  @Prop themeMode: string = 'light';

  @State clients: ClientRecord[] = [];
  @State searchQuery: string = '';
  @State statusFilter: string = 'all';
  @State selectedUids: string[] = [];
  @State activeClient: ClientRecord | null = null;
  @State clientInspectorTab: string = 'info'; // 'info' | 'profile' | 'snapshots' | 'notify'
  @State editDisplayName: string = '';
  @State editClientId: string = '';

  // Default & Per-client Profile Binding
  @State showDefaultProfilePanel: boolean = false;
  @State cpFiles: ResourceItem[] = [];
  @State tlFiles: ResourceItem[] = [];
  @State subFiles: ResourceItem[] = [];
  @State polFiles: ResourceItem[] = [];
  @State dsFiles: ResourceItem[] = [];
  @State comFiles: ResourceItem[] = [];
  @State credFiles: ResourceItem[] = [];

  @State bindCp: string = '';
  @State bindTl: string = '';
  @State bindSub: string = '';
  @State bindPol: string = '';
  @State bindDs: string = '';
  @State bindCom: string = '';
  @State bindCred: string = '';

  // Config Snapshots
  @State snapshots: ConfigSnapshotItem[] = [];
  @State selectedSnapshotJson: string = '';

  @State statusMsg: string = '';
  @State isError: boolean = false;

  private lastLoadedAccount: number = -1;
  private lastSubMode: string = '';

  aboutToAppear(): void {
    this.reloadAll();
  }

  private setFeedback(msg: string, err: boolean): void {
    this.statusMsg = msg;
    this.isError = err;
  }

  public async reloadAll(): Promise<void> {
    if (this.accountId <= 0) {
      return;
    }
    this.lastLoadedAccount = this.accountId;
    this.lastSubMode = this.subMode;
    const cRes = await ApiService.get().listClients(this.accountId);
    if (cRes.ok && cRes.data) {
      this.clients = cRes.data;
      if (this.activeClient === null && this.clients.length > 0) {
        this.selectClient(this.clients[0]);
      }
    }
    if (this.subMode === 'clients') {
      await this.loadResourceCatalog();
    }
  }

  private async loadResourceCatalog(): Promise<void> {
    const api = ApiService.get();
    const r1 = await api.listResources(this.accountId, 'ClassPlan');
    if (r1.ok && r1.data) { this.cpFiles = r1.data; }
    const r2 = await api.listResources(this.accountId, 'TimeLayout');
    if (r2.ok && r2.data) { this.tlFiles = r2.data; }
    const r3 = await api.listResources(this.accountId, 'Subjects');
    if (r3.ok && r3.data) { this.subFiles = r3.data; }
    const r4 = await api.listResources(this.accountId, 'Policy');
    if (r4.ok && r4.data) { this.polFiles = r4.data; }
    const r5 = await api.listResources(this.accountId, 'DefaultSettings');
    if (r5.ok && r5.data) { this.dsFiles = r5.data; }
    const r6 = await api.listResources(this.accountId, 'Components');
    if (r6.ok && r6.data) { this.comFiles = r6.data; }
    const r7 = await api.listResources(this.accountId, 'Credentials');
    if (r7.ok && r7.data) { this.credFiles = r7.data; }
  }

  private async selectClient(c: ClientRecord): Promise<void> {
    this.activeClient = c;
    this.editDisplayName = c.display_name || '';
    this.editClientId = c.client_id || '';
    const pRes = await ApiService.get().getClientProfile(this.accountId, c.uid);
    if (pRes.ok && pRes.data) {
      const prof = (pRes.data['profile'] || {}) as Record<string, Object>;
      this.bindCp = String(prof['cp_resource_name'] || '');
      this.bindTl = String(prof['tl_resource_name'] || '');
      this.bindSub = String(prof['sub_resource_name'] || '');
      this.bindPol = String(prof['pol_resource_name'] || '');
      this.bindDs = String(prof['ds_resource_name'] || '');
      this.bindCom = String(prof['com_resource_name'] || '');
      this.bindCred = String(prof['cred_resource_name'] || '');
    }
    const snapRes = await ApiService.get().listConfigSnapshots(this.accountId, c.uid);
    if (snapRes.ok && snapRes.data) {
      this.snapshots = snapRes.data;
    }
  }

  private getFilteredClients(): ClientRecord[] {
    const q = this.searchQuery.trim().toLowerCase();
    const out: ClientRecord[] = [];
    for (let i = 0; i < this.clients.length; i++) {
      const c = this.clients[i];
      if (this.statusFilter !== 'all' && c.status !== this.statusFilter) {
        continue;
      }
      if (q.length > 0) {
        const hay = `${c.display_name} ${c.client_id} ${c.uid} ${c.mac} ${c.last_ip}`.toLowerCase();
        if (hay.indexOf(q) < 0) {
          continue;
        }
      }
      out.push(c);
    }
    return out;
  }

  private isUidSelected(uid: string): boolean {
    return this.selectedUids.indexOf(uid) >= 0;
  }

  private toggleUidSelection(uid: string): void {
    const arr = this.selectedUids.slice();
    const idx = arr.indexOf(uid);
    if (idx >= 0) {
      arr.splice(idx, 1);
    } else {
      arr.push(uid);
    }
    this.selectedUids = arr;
  }

  private async runBatchAction(action: string): Promise<void> {
    if (this.selectedUids.length === 0) {
      this.setFeedback('请先勾选至少一台客户端设备', true);
      return;
    }
    const r = await ApiService.get().batchClientOperation(this.accountId, this.selectedUids, action);
    if (r.ok) {
      this.setFeedback(`批量操作已执行 (${this.selectedUids.length} 台)`, false);
      await this.reloadAll();
    } else {
      this.setFeedback(r.error || '批量操作失败', true);
    }
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private getOnlineCount(): number {
    let n = 0;
    for (let i = 0; i < this.clients.length; i++) {
      if (this.clients[i].status === 'online') {
        n++;
      }
    }
    return n;
  }

  private getDisabledCount(): number {
    let n = 0;
    for (let i = 0; i < this.clients.length; i++) {
      if (this.clients[i].status === 'disabled') {
        n++;
      }
    }
    return n;
  }

  @Builder
  buildResourcePickerRow(
    label: string,
    items: ResourceItem[],
    curVal: string,
    onPick: (val: string) => void
  ) {
    Column({ space: 4 }) {
      Row() {
        Text(label).fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary).layoutWeight(1)
        Text(curVal || '跟随默认').fontSize(12).fontColor(this.theme().accentColor)
      }
      .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        Button('不绑定')
          .height(24)
          .fontSize(11)
          .margin({ right: 4, bottom: 4 })
          .fontColor(curVal === '' ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(curVal === '' ? this.theme().accentColor : this.theme().bgCard)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onClick(() => { onPick(''); })
        ForEach(items, (it: ResourceItem) => {
          Button(it.resource_name)
            .height(24)
            .fontSize(11)
            .margin({ right: 4, bottom: 4 })
            .fontColor(curVal === it.resource_name ? '#FFFFFF' : this.theme().textPrimary)
            .backgroundColor(curVal === it.resource_name ? this.theme().accentColor : this.theme().bgCard)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => { onPick(it.resource_name); })
        }, (it: ResourceItem) => `${it.id}`)
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(this.theme().bgSubtle)
    .borderRadius(6)
  }

  @Builder
  buildClientListPane() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索名称、班级标识、UID、MAC 或 IP...', text: this.searchQuery })
          .height(34)
          .fontSize(13)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgInput)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .layoutWeight(1)
          .onChange((v: string) => { this.searchQuery = v; })
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach(['all', 'online', 'offline', 'disabled'], (st: string) => {
          Button(st === 'all' ? '全部状态' : (st === 'online' ? '仅在线' : (st === 'offline' ? '仅离线' : '已禁用')))
            .height(28)
            .fontSize(12)
            .fontColor(this.statusFilter === st ? '#FFFFFF' : this.theme().textPrimary)
            .backgroundColor(this.statusFilter === st ? this.theme().accentColor : this.theme().bgSubtle)
            .borderRadius(4)
            .onClick(() => { this.statusFilter = st; })
        }, (st: string) => st)
      }
      .width('100%')

      if (this.showDefaultProfilePanel) {
        Column({ space: 8 }) {
          Text('账户默认下发档案配置')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          this.buildResourcePickerRow('课表档案', this.cpFiles, this.bindCp, (v: string) => { this.bindCp = v; })
          this.buildResourcePickerRow('时间表档案', this.tlFiles, this.bindTl, (v: string) => { this.bindTl = v; })
          this.buildResourcePickerRow('科目档案', this.subFiles, this.bindSub, (v: string) => { this.bindSub = v; })
          this.buildResourcePickerRow('策略档案', this.polFiles, this.bindPol, (v: string) => { this.bindPol = v; })
          this.buildResourcePickerRow('默认设置档案', this.dsFiles, this.bindDs, (v: string) => { this.bindDs = v; })
          this.buildResourcePickerRow('组件设置档案', this.comFiles, this.bindCom, (v: string) => { this.bindCom = v; })
          this.buildResourcePickerRow('凭据档案', this.credFiles, this.bindCred, (v: string) => { this.bindCred = v; })
          Button('保存默认下发档案')
            .height(34)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .width('100%')
            .onClick(async () => {
              const payload: Record<string, Object> = {
                'cp_resource_name': this.bindCp,
                'tl_resource_name': this.bindTl,
                'sub_resource_name': this.bindSub,
                'pol_resource_name': this.bindPol,
                'ds_resource_name': this.bindDs,
                'com_resource_name': this.bindCom,
                'cred_resource_name': this.bindCred
              };
              const r = await ApiService.get().setDefaultProfile(this.accountId, payload);
              if (r.ok) {
                this.setFeedback('账户默认档案已更新', false);
                this.showDefaultProfilePanel = false;
              }
            })
        }
        .padding(14)
        .backgroundColor(this.theme().bgSubtle)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      }

      if (this.selectedUids.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          Text(`已选 ${this.selectedUids.length} 台：`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().accentColor)
            .margin({ right: 6, top: 4 })
          Button('批量同步')
            .height(26).fontSize(11).margin({ right: 4, bottom: 4 }).fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgCard).border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => { this.runBatchAction('force_sync'); })
          Button('批量重启')
            .height(26).fontSize(11).margin({ right: 4, bottom: 4 }).fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgCard).border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => { this.runBatchAction('restart'); })
          Button('批量断开')
            .height(26).fontSize(11).margin({ right: 4, bottom: 4 }).fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgCard).border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => { this.runBatchAction('disconnect'); })
          Button('批量启用')
            .height(26).fontSize(11).margin({ right: 4, bottom: 4 }).fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgCard).border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => { this.runBatchAction('enable'); })
          Button('批量禁用')
            .height(26).fontSize(11).margin({ right: 4, bottom: 4 }).fontColor(this.theme().dangerColor)
            .backgroundColor(this.theme().bgCard).border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => { this.runBatchAction('disable'); })
          Button('清空选择')
            .height(26).fontSize(11).fontColor(this.theme().textSecondary).backgroundColor(Color.Transparent)
            .onClick(() => { this.selectedUids = []; })
        }
        .padding(10)
        .backgroundColor(this.theme().bgSubtle)
        .borderRadius(6)
      }

      ForEach(this.getFilteredClients(), (client: ClientRecord) => {
        Row({ space: 10 }) {
          Checkbox()
            .select(this.isUidSelected(client.uid))
            .onChange(() => {
              this.toggleUidSelection(client.uid);
            })

          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(client.display_name || client.client_id || client.uid)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().textPrimary)
              Text(client.status === 'online' ? '在线' : (client.status === 'disabled' ? '已禁用' : '离线'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(
                  client.status === 'online' ? this.theme().badgeSuccessFg :
                  (client.status === 'disabled' ? this.theme().badgeDangerFg : this.theme().textSecondary)
                )
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .borderRadius(99)
                .backgroundColor(
                  client.status === 'online' ? this.theme().badgeSuccessBg :
                  (client.status === 'disabled' ? this.theme().badgeDangerBg : this.theme().bgSubtle)
                )
            }
            Text(`班级标识: ${client.client_id || '-'} | IP: ${client.last_ip || '-'} | MAC: ${client.mac || '-'}`)
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .onClick(() => {
            this.selectClient(client);
          })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.activeClient && this.activeClient.uid === client.uid ? this.theme().bgAccentSubtle : this.theme().bgCard)
        .borderRadius(8)
        .border({
          width: 1,
          color: this.activeClient && this.activeClient.uid === client.uid ? this.theme().accentColor : this.theme().borderColor
        })
      }, (client: ClientRecord) => client.uid)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.theme().bgCard)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().borderColor })
  }

  @Builder
  buildClientInspectorPane() {
    Column({ space: 12 }) {
      if (this.activeClient === null) {
        Text('请从左侧列表选择一台客户端设备以查看详情与远程控制')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .padding(16)
      } else {
        Row({ space: 6 }) {
          Text(`设备管理: ${this.activeClient.display_name || this.activeClient.client_id}`)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .layoutWeight(1)
          Text(this.activeClient.uid)
            .fontSize(11)
            .fontColor(this.theme().textSecondary)
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach([
            ['info', '信息与控制'],
            ['profile', '专属档案绑定'],
            ['snapshots', '配置快照'],
            ['notify', '推送通知']
          ], (pair: string[]) => {
            Button(pair[1])
              .height(30)
              .fontSize(12)
              .margin({ right: 6, bottom: 6 })
              .fontColor(this.clientInspectorTab === pair[0] ? this.theme().accentColor : this.theme().textSecondary)
              .backgroundColor(this.clientInspectorTab === pair[0] ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
              .borderRadius(6)
              .onClick(() => {
                this.clientInspectorTab = pair[0];
              })
          }, (pair: string[]) => pair[0])
        }

        if (this.clientInspectorTab === 'info') {
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Text('显示名称:').fontSize(12).fontColor(this.theme().textPrimary).width(70)
              TextInput({ text: this.editDisplayName })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .layoutWeight(1)
                .onChange((v: string) => { this.editDisplayName = v; })
            }
            Row({ space: 8 }) {
              Text('班级标识:').fontSize(12).fontColor(this.theme().textPrimary).width(70)
              TextInput({ text: this.editClientId })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .layoutWeight(1)
                .onChange((v: string) => { this.editClientId = v; })
              Button('保存信息')
                .height(34)
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor(this.theme().accentColor)
                .borderRadius(4)
                .onClick(async () => {
                  if (!this.activeClient) { return; }
                  const r = await ApiService.get().updateClient(
                    this.accountId,
                    this.activeClient.uid,
                    this.editDisplayName,
                    this.editClientId
                  );
                  if (r.ok) {
                    this.setFeedback('客户端信息已保存', false);
                    await this.reloadAll();
                  }
                })
            }

            Text(`最后在线: ${formatTimestamp(this.activeClient.last_seen_at)} | 注册时间: ${formatTimestamp(this.activeClient.registered_at)}`)
              .fontSize(11)
              .fontColor(this.theme().textSecondary)

            Divider().color(this.theme().borderColor).margin({ top: 4, bottom: 4 })

            Text('远程控制指令')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
            Flex({ wrap: FlexWrap.Wrap }) {
              Button('强制同步配置')
                .height(32).fontSize(12).margin({ right: 6, bottom: 6 })
                .fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
                .onClick(async () => {
                  if (!this.activeClient) { return; }
                  await ApiService.get().clientCommandGet(this.accountId, this.activeClient.uid, 'force-sync');
                  this.setFeedback('已下发强制同步指令', false);
                })
              Button('重启客户端')
                .height(32).fontSize(12).margin({ right: 6, bottom: 6 })
                .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onClick(async () => {
                  if (!this.activeClient) { return; }
                  await ApiService.get().clientCommandGet(this.accountId, this.activeClient.uid, 'restart');
                  this.setFeedback('已下发重启指令', false);
                })
              Button('断开连接')
                .height(32).fontSize(12).margin({ right: 6, bottom: 6 })
                .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onClick(async () => {
                  if (!this.activeClient) { return; }
                  await ApiService.get().clientActionPost(this.accountId, this.activeClient.uid, 'disconnect');
                  this.setFeedback('已断开该设备连接', false);
                  await this.reloadAll();
                })
              Button(this.activeClient.status === 'disabled' ? '启用设备' : '禁用设备')
                .height(32).fontSize(12).margin({ right: 6, bottom: 6 })
                .fontColor(this.activeClient.status === 'disabled' ? this.theme().successColor : this.theme().dangerColor)
                .backgroundColor(this.theme().bgSubtle).border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onClick(async () => {
                  if (!this.activeClient) { return; }
                  const act = this.activeClient.status === 'disabled' ? 'enable' : 'disable';
                  await ApiService.get().clientActionPost(this.accountId, this.activeClient.uid, act);
                  await this.reloadAll();
                })
              HmosIconTextButton(
                $r('sys.symbol.trash'),
                '移除设备',
                this.theme().dangerColor,
                Color.Transparent,
                Color.Transparent,
                async () => {
                  if (!this.activeClient) { return; }
                  await ApiService.get().deleteClient(this.accountId, this.activeClient.uid);
                  this.activeClient = null;
                  await this.reloadAll();
                },
                32,
                12
              )
            }
          }
        } else if (this.clientInspectorTab === 'profile') {
          Column({ space: 6 }) {
            this.buildResourcePickerRow('课表档案', this.cpFiles, this.bindCp, (v: string) => { this.bindCp = v; })
            this.buildResourcePickerRow('时间表档案', this.tlFiles, this.bindTl, (v: string) => { this.bindTl = v; })
            this.buildResourcePickerRow('科目档案', this.subFiles, this.bindSub, (v: string) => { this.bindSub = v; })
            this.buildResourcePickerRow('策略档案', this.polFiles, this.bindPol, (v: string) => { this.bindPol = v; })
            this.buildResourcePickerRow('默认设置档案', this.dsFiles, this.bindDs, (v: string) => { this.bindDs = v; })
            this.buildResourcePickerRow('组件设置档案', this.comFiles, this.bindCom, (v: string) => { this.bindCom = v; })
            this.buildResourcePickerRow('凭据档案', this.credFiles, this.bindCred, (v: string) => { this.bindCred = v; })

            Button('保存此客户端专属档案绑定')
              .height(34)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor(this.theme().accentColor)
              .borderRadius(4)
              .width('100%')
              .onClick(async () => {
                if (!this.activeClient) { return; }
                const payload: Record<string, Object> = {
                  'cp_resource_name': this.bindCp,
                  'tl_resource_name': this.bindTl,
                  'sub_resource_name': this.bindSub,
                  'pol_resource_name': this.bindPol,
                  'ds_resource_name': this.bindDs,
                  'com_resource_name': this.bindCom,
                  'cred_resource_name': this.bindCred
                };
                const r = await ApiService.get().setClientProfile(this.accountId, this.activeClient.uid, payload);
                if (r.ok) {
                  this.setFeedback('已更新该客户端档案绑定', false);
                }
              })
          }
        } else if (this.clientInspectorTab === 'snapshots') {
          Column({ space: 8 }) {
            Text('请求客户端上传当前配置快照:')
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach([
                ['1', '设置'],
                ['2', '档案'],
                ['3', '当前课表'],
                ['4', '时间表'],
                ['5', '科目'],
                ['6', '日志']
              ], (pair: string[]) => {
                Button(`抓取 ${pair[1]}`)
                  .height(28).fontSize(11).margin({ right: 6, bottom: 6 })
                  .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onClick(async () => {
                    if (!this.activeClient) { return; }
                    await ApiService.get().clientCommandGet(
                      this.accountId,
                      this.activeClient.uid,
                      `get-config?config_type=${pair[0]}`
                    );
                    this.setFeedback(`已请求上传配置类型 #${pair[0]}`, false);
                  })
              }, (pair: string[]) => pair[0])
            }

            ForEach(this.snapshots, (snap: ConfigSnapshotItem) => {
              Row() {
                Text(`类型 #${snap.config_type} | ${formatTimestamp(snap.created_at)}`)
                  .fontSize(12)
                  .fontColor(this.theme().textPrimary)
                  .layoutWeight(1)
                Button('查看内容')
                  .height(26)
                  .fontSize(11)
                  .fontColor(this.theme().accentColor)
                  .backgroundColor(this.theme().bgAccentSubtle)
                  .borderRadius(4)
                  .onClick(() => {
                    this.selectedSnapshotJson = snap.payload;
                  })
              }
              .width('100%')
              .padding(10)
              .backgroundColor(this.theme().bgSubtle)
              .borderRadius(6)
            }, (snap: ConfigSnapshotItem) => `${snap.id}`)

            if (this.selectedSnapshotJson.length > 0) {
              TextArea({ text: this.selectedSnapshotJson })
                .height(160)
                .fontSize(11)
                .fontFamily('monospace')
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgSubtle)
                .border({ width: 1, color: this.theme().borderColor, radius: 6 })
            }
          }
        } else if (this.clientInspectorTab === 'notify') {
          NotificationsAndAuditView({
            accountId: this.accountId,
            subMode: 'notifications',
            fixedClientUid: this.activeClient.uid,
            clients: this.clients,
            themeMode: this.themeMode,
            onFeedback: (msg: string, err: boolean) => {
              this.setFeedback(msg, err);
            }
          })
        }
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
      if (this.lastLoadedAccount !== this.accountId || this.lastSubMode !== this.subMode) {
        Row().height(0).onAppear(() => {
          this.reloadAll();
        })
      }

      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text(this.subMode === 'notifications' ? '通知推送' : (this.subMode === 'audit' ? '审计日志' : '客户端管理'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text(
            this.subMode === 'notifications'
              ? '向指定客户端或全部在线终端实时推送 ClassIsland 顶栏横幅与语音提醒'
              : (this.subMode === 'audit'
                ? '查看客户端关键操作与安全变更审计记录'
                : '实时监控、编辑设备信息、分配 7 大集控资源档案并执行远程控制指令')
          )
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.subMode === 'clients') {
          HmosIconTextButton(
            $r('sys.symbol.folder'),
            '默认下发档案',
            this.theme().textPrimary,
            this.theme().bgCard,
            this.theme().borderColor,
            async () => {
              this.showDefaultProfilePanel = !this.showDefaultProfilePanel;
              if (this.showDefaultProfilePanel) {
                const r = await ApiService.get().getDefaultProfile(this.accountId);
                if (r.ok && r.data) {
                  this.bindCp = r.data.cp_resource_name || '';
                  this.bindTl = r.data.tl_resource_name || '';
                  this.bindSub = r.data.sub_resource_name || '';
                  this.bindPol = r.data.pol_resource_name || '';
                  this.bindDs = r.data.ds_resource_name || '';
                  this.bindCom = r.data.com_resource_name || '';
                  this.bindCred = r.data.cred_resource_name || '';
                }
              }
            },
            34,
            13
          )
          HmosIconTextButton(
            $r('sys.symbol.arrow_clockwise'),
            '刷新状态',
            '#FFFFFF',
            this.theme().accentColor,
            Color.Transparent,
            () => {
              this.reloadAll();
            },
            34,
            13
          )
        }
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

      if (this.subMode === 'notifications' || this.subMode === 'audit') {
        NotificationsAndAuditView({
          accountId: this.accountId,
          subMode: this.subMode,
          fixedClientUid: '',
          clients: this.clients,
          themeMode: this.themeMode,
          onFeedback: (msg: string, err: boolean) => {
            this.setFeedback(msg, err);
          }
        })
      } else {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(`${this.clients.length}`).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
            Text('已注册设备总数').fontSize(12).fontColor(this.theme().textSecondary)
          }
          .alignItems(HorizontalAlign.Start).padding(16).backgroundColor(this.theme().bgCard)
          .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)

          Column({ space: 4 }) {
            Text(`${this.getOnlineCount()}`).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.theme().successColor)
            Text('当前在线设备').fontSize(12).fontColor(this.theme().textSecondary)
          }
          .alignItems(HorizontalAlign.Start).padding(16).backgroundColor(this.theme().bgCard)
          .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)

          Column({ space: 4 }) {
            Text(`${this.getDisabledCount()}`).fontSize(24).fontWeight(FontWeight.Bold)
              .fontColor(this.getDisabledCount() > 0 ? this.theme().dangerColor : this.theme().textPrimary)
            Text('已禁用设备').fontSize(12).fontColor(this.theme().textSecondary)
          }
          .alignItems(HorizontalAlign.Start).padding(16).backgroundColor(this.theme().bgCard)
          .borderRadius(8).border({ width: 1, color: this.theme().borderColor }).layoutWeight(1)
        }
        .width('100%')

        if (this.breakpoint === 'lg') {
          Row({ space: 16 }) {
            Column() {
              this.buildClientListPane()
            }
            .width('45%')
            Column() {
              this.buildClientInspectorPane()
            }
            .width('55%')
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
        } else {
          this.buildClientListPane()
          this.buildClientInspectorPane()
        }
      }
    }
    .width('100%')
  }
}
