import {
  ResourceItem,
  ResourceVersionItem,
  SubjectEntry,
  TimeLayoutGroup,
  TimeLayoutPoint,
  generateUuid,
  extractIsoTimePart,
  formatTimestamp
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosIconTextButton, HmosSymbolIcon } from './HmosIcons';
import { ProfileScheduleEditors } from './ProfileScheduleEditors';
import { ProfileSettingsAndComponentsEditors } from './ProfileSettingsAndComponentsEditors';

@Component
export struct ProfileEditorView {
  @Prop accountId: string = '';
  @Prop resourceType: string = 'Subjects';
  @Prop breakpoint: string = 'sm';
  @Prop themeMode: string = 'light';

  @State resources: ResourceItem[] = [];
  @State selectedName: string = '';
  @State editorTab: string = 'visual'; // 'visual' | 'json'
  @State rawJsonText: string = '{}';
  @State statusMessage: string = '';
  @State isError: boolean = false;
  @State isLoading: boolean = false;
  @State showCreateModal: boolean = false;
  @State newFileName: string = '';

  // Version History Drawer State
  @State showHistoryPanel: boolean = false;
  @State versionHistoryList: ResourceVersionItem[] = [];

  // Auxiliary resources for cross-referencing (Subjects & TimeLayouts)
  @State refSubjectFiles: ResourceItem[] = [];
  @State refTimeLayoutFiles: ResourceItem[] = [];
  @State selectedRefSubjectFile: string = '';
  @State selectedRefTimeLayoutFile: string = '';
  @State refSubjectsMap: SubjectEntry[] = [];
  @State refTimeLayoutsMap: TimeLayoutGroup[] = [];

  private lastLoadedType: string = '';
  private lastLoadedAccount: string = '';

  aboutToAppear(): void {
    this.reloadIfNeeded();
  }

  private notifyStatus(msg: string, err: boolean): void {
    this.statusMessage = msg;
    this.isError = err;
  }

  public async reloadIfNeeded(): Promise<void> {
    if (!this.accountId || this.accountId.length === 0) {
      return;
    }
    this.lastLoadedType = this.resourceType;
    this.lastLoadedAccount = this.accountId;
    this.isLoading = true;
    const res = await ApiService.get().listResources(this.accountId, this.resourceType);
    this.isLoading = false;
    if (res.ok && res.data) {
      this.resources = res.data;
      if (this.resources.length > 0) {
        await this.selectResource(this.resources[0]);
      } else {
        this.selectedName = '';
        this.rawJsonText = this.getDefaultJsonForType(this.resourceType);
      }
    } else {
      this.notifyStatus(res.error || '加载资源列表失败', true);
    }

    if (this.resourceType === 'TimeLayout' || this.resourceType === 'ClassPlan') {
      const subRes = await ApiService.get().listResources(this.accountId, 'Subjects');
      if (subRes.ok && subRes.data) {
        this.refSubjectFiles = subRes.data;
        if (this.refSubjectFiles.length > 0) {
          await this.loadRefSubjectContent(this.refSubjectFiles[0]);
        }
      }
    }
    if (this.resourceType === 'ClassPlan') {
      const tlRes = await ApiService.get().listResources(this.accountId, 'TimeLayout');
      if (tlRes.ok && tlRes.data) {
        this.refTimeLayoutFiles = tlRes.data;
        if (this.refTimeLayoutFiles.length > 0) {
          await this.loadRefTimeLayoutContent(this.refTimeLayoutFiles[0]);
        }
      }
    }
  }

  private async loadRefSubjectContent(item: ResourceItem): Promise<void> {
    this.selectedRefSubjectFile = item.resource_name;
    let content = item.content || '';
    if (!content || content.trim().length === 0) {
      const r = await ApiService.get().readResourceRaw(this.accountId, 'Subjects', item.resource_name);
      if (r.ok && r.data) {
        content = r.data;
      }
    }
    this.parseRefSubjects(content);
  }

  private async loadRefTimeLayoutContent(item: ResourceItem): Promise<void> {
    this.selectedRefTimeLayoutFile = item.resource_name;
    let content = item.content || '';
    if (!content || content.trim().length === 0) {
      const r = await ApiService.get().readResourceRaw(this.accountId, 'TimeLayout', item.resource_name);
      if (r.ok && r.data) {
        content = r.data;
      }
    }
    this.parseRefTimeLayouts(content);
  }

  private parseRefSubjects(content: string): void {
    try {
      const obj = JSON.parse(content || '{}') as Record<string, Object>;
      const subs = (obj['Subjects'] || {}) as Record<string, Record<string, Object>>;
      const list: SubjectEntry[] = [];
      const keys = Object.keys(subs);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        const item = subs[k] || {};
        list.push({
          key: k,
          Name: String(item['Name'] || '未命名科目'),
          Initial: String(item['Initial'] || ''),
          TeacherName: String(item['TeacherName'] || ''),
          IsOutDoor: Boolean(item['IsOutDoor'])
        });
      }
      this.refSubjectsMap = list;
    } catch (_e) {
      this.refSubjectsMap = [];
    }
  }

  private parseRefTimeLayouts(content: string): void {
    try {
      const obj = JSON.parse(content || '{}') as Record<string, Object>;
      const tls = (obj['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
      const list: TimeLayoutGroup[] = [];
      const keys = Object.keys(tls);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        const g = tls[k] || {};
        const ptsRaw = (g['Layouts'] || []) as Record<string, Object>[];
        const pts: TimeLayoutPoint[] = [];
        for (let j = 0; j < ptsRaw.length; j++) {
          const p = ptsRaw[j];
          pts.push({
            StartSecond: extractIsoTimePart(String(p['StartSecond'] || '08:00:00')),
            EndSecond: extractIsoTimePart(String(p['EndSecond'] || '08:45:00')),
            TimeType: Number(p['TimeType'] || 0),
            DefaultClassId: String(p['DefaultClassId'] || ''),
            IsHideDefault: Boolean(p['IsHideDefault']),
            BreakName: String(p['BreakName'] || '')
          });
        }
        list.push({
          key: k,
          Name: String(g['Name'] || k),
          Layouts: pts
        });
      }
      this.refTimeLayoutsMap = list;
    } catch (_e) {
      this.refTimeLayoutsMap = [];
    }
  }

  private getDefaultJsonForType(t: string): string {
    if (t === 'Subjects') {
      const id1 = generateUuid();
      return `{\n  "Name": "默认科目表",\n  "Subjects": {\n    "${id1}": {\n      "Name": "语文",\n      "Initial": "语",\n      "TeacherName": "",\n      "IsOutDoor": false\n    }\n  }\n}`;
    }
    if (t === 'TimeLayout') {
      const id1 = generateUuid();
      return `{\n  "Name": "标准时间表",\n  "TimeLayouts": {\n    "${id1}": {\n      "Name": "常规作息",\n      "Layouts": [\n        { "StartSecond": "08:00:00", "EndSecond": "08:45:00", "TimeType": 0, "DefaultClassId": "", "IsHideDefault": false, "BreakName": "" },\n        { "StartSecond": "08:45:00", "EndSecond": "08:55:00", "TimeType": 1, "DefaultClassId": "", "IsHideDefault": false, "BreakName": "课间休息" }\n      ]\n    }\n  }\n}`;
    }
    if (t === 'ClassPlan') {
      const id1 = generateUuid();
      return `{\n  "Name": "标准课表",\n  "ClassPlanGroups": {},\n  "ClassPlans": {\n    "${id1}": {\n      "Name": "周一课表",\n      "TimeLayoutId": "",\n      "IsEnabled": true,\n      "IsOverlay": false,\n      "TimeRule": { "WeekDay": 1, "WeekCountDiv": 0, "WeekCountDivTotal": 2 },\n      "Classes": [{ "SubjectId": "" }]\n    }\n  }\n}`;
    }
    if (t === 'Policy') {
      return `{\n  "DisableProfileClassPlanEditing": false,\n  "DisableProfileTimeLayoutEditing": false,\n  "DisableProfileSubjectsEditing": false,\n  "DisableProfileEditing": false,\n  "DisableSettingsEditing": false,\n  "DisableSplashCustomize": false,\n  "DisableDebugMenu": false,\n  "AllowExitManagement": true,\n  "DisableEasterEggs": false,\n  "DisableSentry": false,\n  "DisablePluginInstalling": false,\n  "DisableAutomation": false\n}`;
    }
    if (t === 'DefaultSettings') {
      return `{\n  "WindowDockingLocation": 1,\n  "WindowLayer": 1,\n  "WindowDockingOffsetX": 0,\n  "WindowDockingOffsetY": 0,\n  "Scale": 1.0,\n  "IsNotificationEnabled": true,\n  "IsNotificationEffectEnabled": true,\n  "IsNotificationSoundEnabled": true,\n  "IsSpeechEnabled": true,\n  "SpeechVolume": 1.0,\n  "Theme": 0,\n  "PrimaryColor": "#0078D4",\n  "TimeOffsetSeconds": 0\n}`;
    }
    if (t === 'Components') {
      return `{\n  "Lines": [\n    {\n      "IsMainLine": true,\n      "IsEnabled": true,\n      "IslandSeparationMode": 0,\n      "Children": [\n        {\n          "Id": "7c645d35-8151-48ba-b4ac-15017460d994",\n          "NameCache": "课程表",\n          "HorizontalAlignment": 1\n        }\n      ]\n    }\n  ]\n}`;
    }
    if (t === 'Credentials') {
      return `{\n  "UserCredential": "",\n  "AdminCredential": "",\n  "EditProfileAuthorizeLevel": 0,\n  "EditPolicyAuthorizeLevel": 2,\n  "ExitManagementAuthorizeLevel": 2,\n  "EditSettingsAuthorizeLevel": 1,\n  "SwitchProfileAuthorizeLevel": 1,\n  "TempOverlayClassPlanAuthorizeLevel": 1,\n  "ChangeTimeOffsetAuthorizeLevel": 1,\n  "ExitApplicationAuthorizeLevel": 2,\n  "RestartApplicationAuthorizeLevel": 1\n}`;
    }
    return '{}';
  }

  private async selectResource(item: ResourceItem): Promise<void> {
    this.selectedName = item.resource_name;
    this.showHistoryPanel = false;
    let body = item.content || '';
    if (!body || body.trim().length === 0) {
      const r = await ApiService.get().readResourceRaw(this.accountId, this.resourceType, item.resource_name);
      if (r.ok && r.data && r.data.trim().length > 0) {
        body = r.data;
      }
    }
    this.rawJsonText = body && body.trim().length > 0 ? body : this.getDefaultJsonForType(this.resourceType);
    this.notifyStatus(`已加载资源: ${item.resource_name} (v${item.version})`, false);
  }

  private async loadHistoryVersions(): Promise<void> {
    if (!this.selectedName) { return; }
    const r = await ApiService.get().listResourceHistory(this.accountId, this.resourceType, this.selectedName);
    if (r.ok && r.data) {
      this.versionHistoryList = r.data;
    } else {
      this.versionHistoryList = [];
    }
  }

  private async restoreHistoryVersion(ver: number): Promise<void> {
    if (!this.selectedName) { return; }
    const r = await ApiService.get().readResourceHistoryVersion(this.accountId, this.resourceType, this.selectedName, ver);
    if (r.ok && r.data) {
      const contentObj = r.data.content;
      const contentStr = typeof contentObj === 'string' ? contentObj : JSON.stringify(contentObj, null, 2);
      this.rawJsonText = contentStr;
      this.showHistoryPanel = false;
      this.notifyStatus(`已加载历史版本 v${ver} 至编辑器，点击「保存」即可正式写入`, false);
    } else {
      this.notifyStatus(r.error || '读取历史版本失败', true);
    }
  }

  private async saveCurrentResource(): Promise<void> {
    if (!this.selectedName) {
      this.notifyStatus('请先选择或新建一个资源文件', true);
      return;
    }
    const res = await ApiService.get().writeResource(
      this.accountId,
      this.resourceType,
      this.selectedName,
      this.rawJsonText
    );
    if (res.ok) {
      this.notifyStatus(`已保存 ${this.selectedName}`, false);
      await this.reloadIfNeeded();
    } else {
      this.notifyStatus(res.error || '保存失败', true);
    }
  }

  private async createNewResource(): Promise<void> {
    const name = this.newFileName.trim();
    if (!name) {
      this.notifyStatus('请输入资源文件名', true);
      return;
    }
    const defaultContent = this.getDefaultJsonForType(this.resourceType);
    const res = await ApiService.get().createResource(this.accountId, this.resourceType, name, defaultContent);
    if (res.ok) {
      this.newFileName = '';
      this.showCreateModal = false;
      this.notifyStatus(`已创建资源 ${name}`, false);
      await this.reloadIfNeeded();
    } else {
      this.notifyStatus(res.error || '创建失败', true);
    }
  }

  private async deleteCurrentResource(): Promise<void> {
    if (!this.selectedName) {
      return;
    }
    const res = await ApiService.get().deleteResource(this.accountId, this.resourceType, this.selectedName);
    if (res.ok) {
      this.notifyStatus(`已删除 ${this.selectedName}`, false);
      await this.reloadIfNeeded();
    } else {
      this.notifyStatus(res.error || '删除失败', true);
    }
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private getPageTitle(): string {
    if (this.resourceType === 'Subjects') { return '科目管理'; }
    if (this.resourceType === 'TimeLayout') { return '时间表管理'; }
    if (this.resourceType === 'ClassPlan') { return '课表管理'; }
    if (this.resourceType === 'Policy') { return '策略管理'; }
    if (this.resourceType === 'DefaultSettings') { return '默认设置'; }
    if (this.resourceType === 'Components') { return '组件设置'; }
    return '凭据管理';
  }

  private getPageSubtitle(): string {
    if (this.resourceType === 'Subjects') { return '管理 ClassIsland 科目档案'; }
    if (this.resourceType === 'TimeLayout') { return '管理 ClassIsland 作息时间表与自动化行动档案'; }
    if (this.resourceType === 'ClassPlan') { return '管理 ClassIsland 课表、课表群组与多周轮换规则档案'; }
    if (this.resourceType === 'Policy') { return '管理 ClassIsland 集控安全策略档案'; }
    if (this.resourceType === 'DefaultSettings') { return '管理 ClassIsland 默认界面、停靠位置与提醒参数'; }
    if (this.resourceType === 'Components') { return '管理 ClassIsland 顶栏组件行、容器嵌套与对齐配置'; }
    return '管理 ClassIsland 客户端操作授权等级与密码哈希';
  }

  @Builder
  buildFileSidebar() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        HmosSymbolIcon($r('sys.symbol.folder'), 15, this.theme().accentColor)
        Text('资源文件')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
      }
      .margin({ bottom: 4 })

      if (this.showCreateModal) {
        Row({ space: 6 }) {
          TextInput({ placeholder: '如 default 或 senior-1', text: this.newFileName })
            .height(34)
            .fontSize(13)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => {
              this.newFileName = v;
            })
          Button('创建')
            .height(34)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(() => {
              this.createNewResource();
            })
        }
        .width('100%')
        .margin({ bottom: 6 })
      }

      if (this.resources.length === 0) {
        Text('暂无文件')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .padding(8)
      } else {
        Column({ space: 2 }) {
          ForEach(this.resources, (item: ResourceItem) => {
            Row({ space: 6 }) {
              Text(item.resource_name)
                .fontSize(13)
                .fontColor(this.selectedName === item.resource_name ? this.theme().accentColor : this.theme().textPrimary)
                .fontWeight(this.selectedName === item.resource_name ? FontWeight.Bold : FontWeight.Normal)
                .layoutWeight(1)
                .maxLines(1)
              Text(`v${item.version}`)
                .fontSize(11)
                .fontColor(this.theme().textSecondary)
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(6)
            .backgroundColor(this.selectedName === item.resource_name ? this.theme().bgAccentSubtle : Color.Transparent)
            .onClick(() => {
              this.selectResource(item);
            })
          }, (item: ResourceItem) => `${item.id}_${item.version}`)
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
  }

  @Builder
  buildEditorPane() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text(this.selectedName ? `编辑档案: ${this.selectedName}` : '请从左侧选择一个资源文件')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)

        if (this.selectedName.length > 0) {
          HmosIconTextButton(
            $r('sys.symbol.clock'),
            '历史版本',
            this.theme().textPrimary,
            this.theme().bgSubtle,
            this.theme().borderColor,
            async () => {
              this.showHistoryPanel = !this.showHistoryPanel;
              if (this.showHistoryPanel) {
                await this.loadHistoryVersions();
              }
            },
            32,
            12
          )
        }

        Button(this.editorTab === 'json' ? '可视化编辑' : 'JSON 源码')
          .height(32)
          .fontSize(12)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgSubtle)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onClick(() => {
            this.editorTab = this.editorTab === 'json' ? 'visual' : 'json';
          })

        if (this.selectedName.length > 0) {
          HmosIconButton(
            $r('sys.symbol.trash'),
            this.theme().dangerColor,
            this.theme().bgCard,
            this.theme().borderColor,
            () => {
              this.deleteCurrentResource();
            },
            32,
            14
          )
        }

        Button('保存')
          .height(32)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(() => {
            this.saveCurrentResource();
          })
      }
      .width('100%')

      if (this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .fontSize(13)
          .fontColor(this.isError ? this.theme().badgeDangerFg : this.theme().badgeSuccessFg)
          .padding(10)
          .width('100%')
          .backgroundColor(this.isError ? this.theme().badgeDangerBg : this.theme().badgeSuccessBg)
          .borderRadius(4)
      }

      if (this.showHistoryPanel) {
        Column({ space: 8 }) {
          Row() {
            Text(`文件历史版本记录 (${this.selectedName})`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
              .layoutWeight(1)
            Button('关闭')
              .height(24).fontSize(11).fontColor(this.theme().textSecondary).backgroundColor(Color.Transparent)
              .onClick(() => { this.showHistoryPanel = false; })
          }.width('100%')

          if (this.versionHistoryList.length === 0) {
            Text('暂无历史版本快照')
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
              .padding(8)
          } else {
            ForEach(this.versionHistoryList, (verItem: ResourceVersionItem) => {
              Row({ space: 8 }) {
                Text(`v${verItem.version}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().accentColor)
                Text(formatTimestamp(verItem.created_at))
                  .fontSize(12)
                  .fontColor(this.theme().textSecondary)
                  .layoutWeight(1)
                Button('还原此版本至编辑器')
                  .height(26)
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.theme().accentColor)
                  .borderRadius(4)
                  .onClick(() => {
                    this.restoreHistoryVersion(verItem.version);
                  })
              }
              .width('100%')
              .padding({ top: 6, bottom: 6 })
              .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
            }, (verItem: ResourceVersionItem) => `ver_${verItem.version}`)
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.theme().bgSubtle)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      }

      if (this.editorTab === 'json') {
        TextArea({ text: this.rawJsonText })
          .height(400)
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgSubtle)
          .border({ width: 1, color: this.theme().borderColor, radius: 6 })
          .onChange((v: string) => {
            this.rawJsonText = v;
          })
      } else {
        if (this.resourceType === 'Subjects' || this.resourceType === 'TimeLayout' || this.resourceType === 'ClassPlan') {
          ProfileScheduleEditors({
            resourceType: this.resourceType,
            rawJsonText: this.rawJsonText,
            refSubjectsMap: this.refSubjectsMap,
            refTimeLayoutsMap: this.refTimeLayoutsMap,
            themeMode: this.themeMode,
            onJsonMutated: (nextJson: string) => {
              this.rawJsonText = nextJson;
            }
          })
        } else {
          ProfileSettingsAndComponentsEditors({
            accountId: this.accountId,
            resourceType: this.resourceType,
            rawJsonText: this.rawJsonText,
            themeMode: this.themeMode,
            onJsonMutated: (nextJson: string) => {
              this.rawJsonText = nextJson;
            },
            onStatusFeedback: (msg: string, err: boolean) => {
              this.notifyStatus(msg, err);
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
      if (this.lastLoadedType !== this.resourceType || this.lastLoadedAccount !== this.accountId) {
        Row()
          .height(0)
          .onAppear(() => {
            this.reloadIfNeeded();
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
          $r('sys.symbol.plus'),
          '新建文件',
          '#FFFFFF',
          this.theme().accentColor,
          Color.Transparent,
          () => {
            this.showCreateModal = !this.showCreateModal;
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
            this.reloadIfNeeded();
          },
          34,
          13
        )
      }
      .width('100%')

      if (this.breakpoint !== 'sm') {
        Row({ space: 20 }) {
          Column() {
            this.buildFileSidebar()
          }
          .width(240)

          Column() {
            this.buildEditorPane()
          }
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      } else {
        this.buildFileSidebar()
        this.buildEditorPane()
      }
    }
    .width('100%')
  }
}
