import {
  ResourceItem,
  SubjectEntry,
  TimeLayoutGroup,
  TimeLayoutPoint,
  ClassPlanGroup,
  ClassPlanSlot,
  ClassPlanRule,
  PolicyData,
  DefaultSettingsData,
  ComponentLineData,
  ComponentItemData,
  CredentialsData,
  BUILTIN_COMPONENTS,
  BuiltinComponentDef,
  generateUuid,
  extractIsoTimePart
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';

@Component
export struct ProfileEditorView {
  @Prop accountId: number = 0;
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

  // Auxiliary resources for cross-referencing (Subjects & TimeLayouts)
  @State refSubjectFiles: ResourceItem[] = [];
  @State refTimeLayoutFiles: ResourceItem[] = [];
  @State selectedRefSubjectFile: string = '';
  @State selectedRefTimeLayoutFile: string = '';
  @State refSubjectsMap: SubjectEntry[] = [];
  @State refTimeLayoutsMap: TimeLayoutGroup[] = [];

  // Visual Editor States:
  // 1. Subjects
  @State subjectsList: SubjectEntry[] = [];

  // 2. TimeLayout
  @State timeLayoutsList: TimeLayoutGroup[] = [];
  @State selectedLayoutIdx: number = 0;

  // 3. ClassPlan
  @State classPlansList: ClassPlanGroup[] = [];
  @State selectedPlanIdx: number = 0;

  // 4. Policy
  @State policyData: PolicyData = {
    DisableProfileClassPlanEditing: false,
    DisableProfileTimeLayoutEditing: false,
    DisableProfileSubjectsEditing: false,
    DisableProfileEditing: false,
    DisableSettingsEditing: false,
    DisableSplashCustomize: false,
    DisableDebugMenu: false,
    AllowExitManagement: true,
    DisableEasterEggs: false
  };

  // 5. DefaultSettings
  @State settingsData: DefaultSettingsData = {
    WindowDockingLocation: 1,
    WindowLayer: 1,
    WindowDockingOffsetX: 0,
    WindowDockingOffsetY: 0,
    Scale: 1.0,
    IsNotificationEnabled: true,
    IsNotificationEffectEnabled: true,
    IsNotificationSoundEnabled: true,
    IsSpeechEnabled: true,
    SpeechVolume: 1.0,
    Theme: 0,
    PrimaryColor: '#3B82F6',
    TimeOffsetSeconds: 0.0
  };
  @State presetClassIdentity: string = '';
  @State generatedPresetJson: string = '';

  // 6. Components
  @State componentLines: ComponentLineData[] = [];
  @State selectedLineIdx: number = 0;
  @State selectedCompIdx: number = -1;

  // 7. Credentials
  @State credentialsData: CredentialsData = {
    UserCredential: '',
    AdminCredential: '',
    EditProfileAuthorizeLevel: 0,
    EditPolicyAuthorizeLevel: 2,
    ExitManagementAuthorizeLevel: 2,
    EditSettingsAuthorizeLevel: 1,
    SwitchProfileAuthorizeLevel: 1,
    TempOverlayClassPlanAuthorizeLevel: 1,
    ChangeTimeOffsetAuthorizeLevel: 1,
    ExitApplicationAuthorizeLevel: 2,
    RestartApplicationAuthorizeLevel: 1
  };
  @State plainUserPassword: string = '';
  @State plainAdminPassword: string = '';

  private lastLoadedType: string = '';
  private lastLoadedAccount: number = -1;

  aboutToAppear(): void {
    this.reloadIfNeeded();
  }

  private notifyStatus(msg: string, err: boolean): void {
    this.statusMessage = msg;
    this.isError = err;
  }

  public async reloadIfNeeded(): Promise<void> {
    if (this.accountId <= 0) {
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
        this.selectResource(this.resources[0]);
      } else {
        this.selectedName = '';
        this.rawJsonText = this.getDefaultJsonForType(this.resourceType);
        this.parseJsonIntoVisual(this.rawJsonText);
      }
    } else {
      this.notifyStatus(res.error || '加载资源列表失败', true);
    }

    if (this.resourceType === 'TimeLayout' || this.resourceType === 'ClassPlan') {
      const subRes = await ApiService.get().listResources(this.accountId, 'Subjects');
      if (subRes.ok && subRes.data) {
        this.refSubjectFiles = subRes.data;
        if (this.refSubjectFiles.length > 0) {
          this.selectedRefSubjectFile = this.refSubjectFiles[0].resource_name;
          this.parseRefSubjects(this.refSubjectFiles[0].content);
        }
      }
    }
    if (this.resourceType === 'ClassPlan') {
      const tlRes = await ApiService.get().listResources(this.accountId, 'TimeLayout');
      if (tlRes.ok && tlRes.data) {
        this.refTimeLayoutFiles = tlRes.data;
        if (this.refTimeLayoutFiles.length > 0) {
          this.selectedRefTimeLayoutFile = this.refTimeLayoutFiles[0].resource_name;
          this.parseRefTimeLayouts(this.refTimeLayoutFiles[0].content);
        }
      }
    }
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
      return `{\n  "Name": "标准课表",\n  "ClassPlans": {\n    "${id1}": {\n      "Name": "周一课表",\n      "TimeLayoutId": "",\n      "IsEnabled": true,\n      "IsOverlay": false,\n      "TimeRule": { "WeekDay": 1, "WeekCountDiv": 0, "WeekCountDivTotal": 2 },\n      "Classes": [{ "SubjectId": "" }]\n    }\n  }\n}`;
    }
    if (t === 'Policy') {
      return JSON.stringify(this.policyData, null, 2);
    }
    if (t === 'DefaultSettings') {
      return JSON.stringify(this.settingsData, null, 2);
    }
    if (t === 'Components') {
      return `{\n  "Lines": [\n    {\n      "IsMainLine": true,\n      "IsEnabled": true,\n      "IslandSeparationMode": 0,\n      "Children": [\n        {\n          "Id": "1507b9a2-7884-4937-9499-4a1b54f4c855",\n          "NameCache": "课表",\n          "HorizontalAlignment": 1\n        }\n      ]\n    }\n  ]\n}`;
    }
    if (t === 'Credentials') {
      return JSON.stringify(this.credentialsData, null, 2);
    }
    return '{}';
  }

  private selectResource(item: ResourceItem): void {
    this.selectedName = item.resource_name;
    this.rawJsonText = item.content && item.content.trim().length > 0
      ? item.content
      : this.getDefaultJsonForType(this.resourceType);
    this.parseJsonIntoVisual(this.rawJsonText);
    this.notifyStatus(`已加载资源: ${item.resource_name} (v${item.version})`, false);
  }

  private parseJsonIntoVisual(jsonStr: string): void {
    try {
      const obj = JSON.parse(jsonStr || '{}') as Record<string, Object>;
      if (this.resourceType === 'Subjects') {
        const subs = (obj['Subjects'] || {}) as Record<string, Record<string, Object>>;
        const list: SubjectEntry[] = [];
        const keys = Object.keys(subs);
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i];
          const s = subs[k] || {};
          list.push({
            key: k,
            Name: String(s['Name'] || ''),
            Initial: String(s['Initial'] || ''),
            TeacherName: String(s['TeacherName'] || ''),
            IsOutDoor: Boolean(s['IsOutDoor'])
          });
        }
        this.subjectsList = list;
      } else if (this.resourceType === 'TimeLayout') {
        const tls = (obj['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
        const list: TimeLayoutGroup[] = [];
        const keys = Object.keys(tls);
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i];
          const g = tls[k] || {};
          const rawPts = (g['Layouts'] || []) as Record<string, Object>[];
          const pts: TimeLayoutPoint[] = [];
          for (let j = 0; j < rawPts.length; j++) {
            const p = rawPts[j];
            pts.push({
              StartSecond: extractIsoTimePart(String(p['StartSecond'] || p['StartTime'] || '08:00:00')),
              EndSecond: extractIsoTimePart(String(p['EndSecond'] || p['EndTime'] || '08:45:00')),
              TimeType: Number(p['TimeType'] || 0),
              DefaultClassId: String(p['DefaultClassId'] || ''),
              IsHideDefault: Boolean(p['IsHideDefault']),
              BreakName: String(p['BreakName'] || '')
            });
          }
          list.push({
            key: k,
            Name: String(g['Name'] || `时间表 ${i + 1}`),
            Layouts: pts
          });
        }
        this.timeLayoutsList = list;
        this.selectedLayoutIdx = 0;
      } else if (this.resourceType === 'ClassPlan') {
        const cps = (obj['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
        const list: ClassPlanGroup[] = [];
        const keys = Object.keys(cps);
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i];
          const g = cps[k] || {};
          const tr = (g['TimeRule'] || {}) as Record<string, Object>;
          const rawClasses = (g['Classes'] || []) as Record<string, Object>[];
          const slots: ClassPlanSlot[] = [];
          for (let j = 0; j < rawClasses.length; j++) {
            slots.push({ SubjectId: String(rawClasses[j]['SubjectId'] || '') });
          }
          const rule: ClassPlanRule = {
            WeekDay: Number(tr['WeekDay'] !== undefined ? tr['WeekDay'] : 1),
            WeekCountDiv: Number(tr['WeekCountDiv'] || 0),
            WeekCountDivTotal: Number(tr['WeekCountDivTotal'] || 2)
          };
          list.push({
            key: k,
            Name: String(g['Name'] || `课表 ${i + 1}`),
            TimeLayoutId: String(g['TimeLayoutId'] || ''),
            IsEnabled: g['IsEnabled'] !== undefined ? Boolean(g['IsEnabled']) : true,
            IsOverlay: Boolean(g['IsOverlay']),
            TimeRule: rule,
            Classes: slots
          });
        }
        this.classPlansList = list;
        this.selectedPlanIdx = 0;
      } else if (this.resourceType === 'Policy') {
        this.policyData = {
          DisableProfileClassPlanEditing: Boolean(obj['DisableProfileClassPlanEditing']),
          DisableProfileTimeLayoutEditing: Boolean(obj['DisableProfileTimeLayoutEditing']),
          DisableProfileSubjectsEditing: Boolean(obj['DisableProfileSubjectsEditing']),
          DisableProfileEditing: Boolean(obj['DisableProfileEditing']),
          DisableSettingsEditing: Boolean(obj['DisableSettingsEditing']),
          DisableSplashCustomize: Boolean(obj['DisableSplashCustomize']),
          DisableDebugMenu: Boolean(obj['DisableDebugMenu']),
          AllowExitManagement: obj['AllowExitManagement'] !== undefined ? Boolean(obj['AllowExitManagement']) : true,
          DisableEasterEggs: Boolean(obj['DisableEasterEggs'])
        };
      } else if (this.resourceType === 'DefaultSettings') {
        this.settingsData = {
          WindowDockingLocation: Number(obj['WindowDockingLocation'] !== undefined ? obj['WindowDockingLocation'] : 1),
          WindowLayer: Number(obj['WindowLayer'] !== undefined ? obj['WindowLayer'] : 1),
          WindowDockingOffsetX: Number(obj['WindowDockingOffsetX'] || 0),
          WindowDockingOffsetY: Number(obj['WindowDockingOffsetY'] || 0),
          Scale: Number(obj['Scale'] !== undefined ? obj['Scale'] : 1.0),
          IsNotificationEnabled: obj['IsNotificationEnabled'] !== undefined ? Boolean(obj['IsNotificationEnabled']) : true,
          IsNotificationEffectEnabled: obj['IsNotificationEffectEnabled'] !== undefined ? Boolean(obj['IsNotificationEffectEnabled']) : true,
          IsNotificationSoundEnabled: obj['IsNotificationSoundEnabled'] !== undefined ? Boolean(obj['IsNotificationSoundEnabled']) : true,
          IsSpeechEnabled: obj['IsSpeechEnabled'] !== undefined ? Boolean(obj['IsSpeechEnabled']) : true,
          SpeechVolume: Number(obj['SpeechVolume'] !== undefined ? obj['SpeechVolume'] : 1.0),
          Theme: Number(obj['Theme'] || 0),
          PrimaryColor: String(obj['PrimaryColor'] || '#3B82F6'),
          TimeOffsetSeconds: Number(obj['TimeOffsetSeconds'] || 0)
        };
      } else if (this.resourceType === 'Components') {
        const rawLines = (obj['Lines'] || []) as Record<string, Object>[];
        const lines: ComponentLineData[] = [];
        for (let i = 0; i < rawLines.length; i++) {
          const l = rawLines[i];
          const rawChildren = (l['Children'] || []) as Record<string, Object>[];
          const children: ComponentItemData[] = [];
          for (let j = 0; j < rawChildren.length; j++) {
            const c = rawChildren[j];
            children.push({
              Id: String(c['Id'] || '1507b9a2-7884-4937-9499-4a1b54f4c855'),
              NameCache: String(c['NameCache'] || '组件'),
              HorizontalAlignment: Number(c['HorizontalAlignment'] !== undefined ? c['HorizontalAlignment'] : 1),
              IsResourceOverridingEnabled: Boolean(c['IsResourceOverridingEnabled']),
              MainWindowSecondaryFontSize: Number(c['MainWindowSecondaryFontSize'] || 14),
              MainWindowBodyFontSize: Number(c['MainWindowBodyFontSize'] || 16),
              MainWindowEmphasizedFontSize: Number(c['MainWindowEmphasizedFontSize'] || 18),
              MainWindowLargeFontSize: Number(c['MainWindowLargeFontSize'] || 20),
              IsCustomForegroundColorEnabled: Boolean(c['IsCustomForegroundColorEnabled']),
              ForegroundColor: String(c['ForegroundColor'] || '#FFFFFF'),
              IsCustomBackgroundColorEnabled: Boolean(c['IsCustomBackgroundColorEnabled']),
              BackgroundColor: String(c['BackgroundColor'] || '#000000'),
              IsCustomBackgroundOpacityEnabled: Boolean(c['IsCustomBackgroundOpacityEnabled']),
              BackgroundOpacity: Number(c['BackgroundOpacity'] !== undefined ? c['BackgroundOpacity'] : 0.5),
              IsCustomCornerRadiusEnabled: Boolean(c['IsCustomCornerRadiusEnabled']),
              CustomCornerRadius: Number(c['CustomCornerRadius'] || 8),
              Opacity: Number(c['Opacity'] !== undefined ? c['Opacity'] : 1.0),
              IsMinWidthEnabled: Boolean(c['IsMinWidthEnabled']),
              MinWidth: Number(c['MinWidth'] || 100),
              IsMaxWidthEnabled: Boolean(c['IsMaxWidthEnabled']),
              MaxWidth: Number(c['MaxWidth'] || 500),
              IsFixedWidthEnabled: Boolean(c['IsFixedWidthEnabled']),
              FixedWidth: Number(c['FixedWidth'] || 200),
              HideOnRule: Boolean(c['HideOnRule'])
            });
          }
          lines.push({
            Children: children,
            IsMainLine: Boolean(l['IsMainLine']),
            IsEnabled: l['IsEnabled'] !== undefined ? Boolean(l['IsEnabled']) : true,
            IslandSeparationMode: Number(l['IslandSeparationMode'] || 0)
          });
        }
        this.componentLines = lines;
        this.selectedLineIdx = 0;
        this.selectedCompIdx = -1;
      } else if (this.resourceType === 'Credentials') {
        this.credentialsData = {
          UserCredential: String(obj['UserCredential'] || ''),
          AdminCredential: String(obj['AdminCredential'] || ''),
          EditProfileAuthorizeLevel: Number(obj['EditProfileAuthorizeLevel'] || 0),
          EditPolicyAuthorizeLevel: Number(obj['EditPolicyAuthorizeLevel'] || 0),
          ExitManagementAuthorizeLevel: Number(obj['ExitManagementAuthorizeLevel'] || 0),
          EditSettingsAuthorizeLevel: Number(obj['EditSettingsAuthorizeLevel'] || 0),
          SwitchProfileAuthorizeLevel: Number(obj['SwitchProfileAuthorizeLevel'] || 0),
          TempOverlayClassPlanAuthorizeLevel: Number(obj['TempOverlayClassPlanAuthorizeLevel'] || 0),
          ChangeTimeOffsetAuthorizeLevel: Number(obj['ChangeTimeOffsetAuthorizeLevel'] || 0),
          ExitApplicationAuthorizeLevel: Number(obj['ExitApplicationAuthorizeLevel'] || 0),
          RestartApplicationAuthorizeLevel: Number(obj['RestartApplicationAuthorizeLevel'] || 0)
        };
      }
    } catch (_e) {
      // Keep existing visual state if JSON is malformed while typing
    }
  }

  private syncVisualToJson(): string {
    if (this.resourceType === 'Subjects') {
      const subsObj: Record<string, Object> = {};
      for (let i = 0; i < this.subjectsList.length; i++) {
        const s = this.subjectsList[i];
        const entry: Record<string, Object> = {
          'Name': s.Name,
          'Initial': s.Initial,
          'TeacherName': s.TeacherName,
          'IsOutDoor': s.IsOutDoor
        };
        subsObj[s.key] = entry;
      }
      const root: Record<string, Object> = {
        'Name': this.selectedName || '默认科目表',
        'Subjects': subsObj
      };
      this.rawJsonText = JSON.stringify(root, null, 2);
    } else if (this.resourceType === 'TimeLayout') {
      const tlObj: Record<string, Object> = {};
      for (let i = 0; i < this.timeLayoutsList.length; i++) {
        const g = this.timeLayoutsList[i];
        const pts: Record<string, Object>[] = [];
        for (let j = 0; j < g.Layouts.length; j++) {
          const p = g.Layouts[j];
          pts.push({
            'StartSecond': p.StartSecond,
            'EndSecond': p.EndSecond,
            'TimeType': p.TimeType,
            'DefaultClassId': p.DefaultClassId,
            'IsHideDefault': p.IsHideDefault,
            'BreakName': p.BreakName
          });
        }
        const gEntry: Record<string, Object> = {
          'Name': g.Name,
          'Layouts': pts
        };
        tlObj[g.key] = gEntry;
      }
      const root: Record<string, Object> = {
        'Name': this.selectedName || '标准时间表',
        'TimeLayouts': tlObj
      };
      this.rawJsonText = JSON.stringify(root, null, 2);
    } else if (this.resourceType === 'ClassPlan') {
      const cpObj: Record<string, Object> = {};
      for (let i = 0; i < this.classPlansList.length; i++) {
        const g = this.classPlansList[i];
        const classesArr: Record<string, Object>[] = [];
        for (let j = 0; j < g.Classes.length; j++) {
          classesArr.push({ 'SubjectId': g.Classes[j].SubjectId });
        }
        const trObj: Record<string, Object> = {
          'WeekDay': g.TimeRule.WeekDay,
          'WeekCountDiv': g.TimeRule.WeekCountDiv,
          'WeekCountDivTotal': g.TimeRule.WeekCountDivTotal
        };
        const gEntry: Record<string, Object> = {
          'Name': g.Name,
          'TimeLayoutId': g.TimeLayoutId,
          'IsEnabled': g.IsEnabled,
          'IsOverlay': g.IsOverlay,
          'TimeRule': trObj,
          'Classes': classesArr
        };
        cpObj[g.key] = gEntry;
      }
      const root: Record<string, Object> = {
        'Name': this.selectedName || '标准课表',
        'ClassPlans': cpObj
      };
      this.rawJsonText = JSON.stringify(root, null, 2);
    } else if (this.resourceType === 'Policy') {
      this.rawJsonText = JSON.stringify(this.policyData, null, 2);
    } else if (this.resourceType === 'DefaultSettings') {
      this.rawJsonText = JSON.stringify(this.settingsData, null, 2);
    } else if (this.resourceType === 'Components') {
      const root: Record<string, Object> = {
        'Lines': this.componentLines as Object
      };
      this.rawJsonText = JSON.stringify(root, null, 2);
    } else if (this.resourceType === 'Credentials') {
      this.rawJsonText = JSON.stringify(this.credentialsData, null, 2);
    }
    return this.rawJsonText;
  }

  private async saveCurrentResource(): Promise<void> {
    if (!this.selectedName) {
      this.notifyStatus('请先选择或新建一个资源文件', true);
      return;
    }
    const contentToSave = this.editorTab === 'visual' ? this.syncVisualToJson() : this.rawJsonText;
    const res = await ApiService.get().writeResource(
      this.accountId,
      this.resourceType,
      this.selectedName,
      contentToSave
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
    if (this.resourceType === 'Subjects') { return '管理 ClassIsland 科目档案 (Subjects)'; }
    if (this.resourceType === 'TimeLayout') { return '管理 ClassIsland 作息时间表档案 (TimeLayout)'; }
    if (this.resourceType === 'ClassPlan') { return '管理 ClassIsland 课表与轮换规则档案 (ClassPlan)'; }
    if (this.resourceType === 'Policy') { return '管理 ClassIsland 集控安全策略档案 (Policy)'; }
    if (this.resourceType === 'DefaultSettings') { return '管理 ClassIsland 默认界面与提醒参数 (DefaultSettings)'; }
    if (this.resourceType === 'Components') { return '管理 ClassIsland 顶栏组件行与对齐配置 (Components)'; }
    return '管理 ClassIsland 客户端操作授权等级与密码哈希 (Credentials)';
  }

  @Builder
  buildFileSidebar() {
    Column({ space: 6 }) {
      Text('资源文件')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
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
  buildSubjectsVisual() {
    Column({ space: 10 }) {
      Row() {
        Text(`共 ${this.subjectsList.length} 门科目`)
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .layoutWeight(1)
        Button('+ 添加科目')
          .height(32)
          .fontSize(13)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgCard)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onClick(() => {
            const next: SubjectEntry[] = this.subjectsList.slice();
            next.push({
              key: generateUuid(),
              Name: '新科目',
              Initial: '新',
              TeacherName: '',
              IsOutDoor: false
            });
            this.subjectsList = next;
          })
      }
      .width('100%')

      ForEach(this.subjectsList, (sub: SubjectEntry, idx: number) => {
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Text(sub.Initial || (sub.Name ? sub.Name.substring(0, 1) : '?'))
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor(sub.IsOutDoor ? this.theme().successColor : this.theme().accentColor)
              .borderRadius(8)

            Column({ space: 4 }) {
              Text('科目名称 (Name)').fontSize(11).fontColor(this.theme().textSecondary)
              TextInput({ placeholder: '科目名称', text: sub.Name })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => {
                  this.subjectsList[idx].Name = v;
                  if (!this.subjectsList[idx].Initial && v.length > 0) {
                    this.subjectsList[idx].Initial = v.substring(0, 1);
                  }
                })
            }.alignItems(HorizontalAlign.Start).layoutWeight(2)

            Column({ space: 4 }) {
              Text('简称 (Initial)').fontSize(11).fontColor(this.theme().textSecondary)
              TextInput({ placeholder: '简称', text: sub.Initial })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => {
                  this.subjectsList[idx].Initial = v;
                })
            }.alignItems(HorizontalAlign.Start).width(80)

            Column({ space: 4 }) {
              Text('任课教师 (TeacherName)').fontSize(11).fontColor(this.theme().textSecondary)
              TextInput({ placeholder: '可选', text: sub.TeacherName })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => {
                  this.subjectsList[idx].TeacherName = v;
                })
            }.alignItems(HorizontalAlign.Start).layoutWeight(2)
          }
          .width('100%')

          Row({ space: 8 }) {
            Text(`科目 GUID: ${sub.key}`)
              .fontSize(11)
              .fontColor(this.theme().textSecondary)
              .layoutWeight(1)
              .maxLines(1)

            Text('户外课程')
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: sub.IsOutDoor })
              .onChange((val: boolean) => {
                this.subjectsList[idx].IsOutDoor = val;
              })

            Button('↑')
              .height(26)
              .fontSize(11)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(() => {
                if (idx > 0) {
                  const arr = this.subjectsList.slice();
                  const tmp = arr[idx - 1];
                  arr[idx - 1] = arr[idx];
                  arr[idx] = tmp;
                  this.subjectsList = arr;
                }
              })
            Button('↓')
              .height(26)
              .fontSize(11)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(() => {
                if (idx < this.subjectsList.length - 1) {
                  const arr = this.subjectsList.slice();
                  const tmp = arr[idx + 1];
                  arr[idx + 1] = arr[idx];
                  arr[idx] = tmp;
                  this.subjectsList = arr;
                }
              })
            Button('删除')
              .height(26)
              .fontSize(11)
              .fontColor(this.theme().dangerColor)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                const arr = this.subjectsList.slice();
                arr.splice(idx, 1);
                this.subjectsList = arr;
              })
          }
          .width('100%')
        }
        .padding(14)
        .backgroundColor(this.theme().bgCard)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      }, (sub: SubjectEntry) => sub.key)
    }
    .width('100%')
  }

  @Builder
  buildTimeLayoutVisual() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('时间表分组:')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().textPrimary)
        Button('+ 新增时间表')
          .height(28)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(() => {
            const arr = this.timeLayoutsList.slice();
            arr.push({
              key: generateUuid(),
              Name: `作息表 #${arr.length + 1}`,
              Layouts: []
            });
            this.timeLayoutsList = arr;
            this.selectedLayoutIdx = arr.length - 1;
          })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.timeLayoutsList, (g: TimeLayoutGroup, gIdx: number) => {
          Button(`${g.Name} (${g.Layouts.length})`)
            .height(30)
            .fontSize(12)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.selectedLayoutIdx === gIdx ? this.theme().accentColor : this.theme().textPrimary)
            .backgroundColor(this.selectedLayoutIdx === gIdx ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
            .border({ width: 1, color: this.selectedLayoutIdx === gIdx ? this.theme().accentColor : this.theme().borderColor, radius: 6 })
            .onClick(() => {
              this.selectedLayoutIdx = gIdx;
            })
        }, (g: TimeLayoutGroup) => g.key)
      }

      if (this.timeLayoutsList.length > 0 && this.selectedLayoutIdx < this.timeLayoutsList.length) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('当前时间表名称:')
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
            TextInput({
              text: this.timeLayoutsList[this.selectedLayoutIdx].Name,
              placeholder: '时间表名称'
            })
              .height(34)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.timeLayoutsList[this.selectedLayoutIdx].Name = v;
              })

            Button('+ 时间点')
              .height(30)
              .fontSize(12)
              .fontColor('#FFFFFF')
              .backgroundColor(this.theme().accentColor)
              .borderRadius(4)
              .onClick(() => {
                const groups = this.timeLayoutsList.slice();
                const pts = groups[this.selectedLayoutIdx].Layouts.slice();
                pts.push({
                  StartSecond: '08:00:00',
                  EndSecond: '08:45:00',
                  TimeType: 0,
                  DefaultClassId: '',
                  IsHideDefault: false,
                  BreakName: ''
                });
                groups[this.selectedLayoutIdx].Layouts = pts;
                this.timeLayoutsList = groups;
              })

            Button('按时间排序')
              .height(30)
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(() => {
                const groups = this.timeLayoutsList.slice();
                const pts = groups[this.selectedLayoutIdx].Layouts.slice();
                pts.sort((a: TimeLayoutPoint, b: TimeLayoutPoint) => a.StartSecond.localeCompare(b.StartSecond));
                groups[this.selectedLayoutIdx].Layouts = pts;
                this.timeLayoutsList = groups;
              })

            Button('删除此表')
              .height(30)
              .fontSize(12)
              .fontColor(this.theme().dangerColor)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                const groups = this.timeLayoutsList.slice();
                groups.splice(this.selectedLayoutIdx, 1);
                this.timeLayoutsList = groups;
                this.selectedLayoutIdx = 0;
              })
          }
          .width('100%')

          ForEach(this.timeLayoutsList[this.selectedLayoutIdx].Layouts, (pt: TimeLayoutPoint, pIdx: number) => {
            Column({ space: 6 }) {
              Row({ space: 6 }) {
                Text(`#${pIdx + 1}`)
                  .fontSize(12)
                  .fontColor(this.theme().textSecondary)
                  .width(28)

                Button(pt.TimeType === 0 ? '上课' : (pt.TimeType === 1 ? '课间' : (pt.TimeType === 2 ? '分割线' : '行动')))
                  .height(28)
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .backgroundColor(
                    pt.TimeType === 0 ? this.theme().accentColor :
                    (pt.TimeType === 1 ? this.theme().successColor :
                    (pt.TimeType === 2 ? this.theme().textSecondary : this.theme().warningColor))
                  )
                  .borderRadius(4)
                  .onClick(() => {
                    const groups = this.timeLayoutsList.slice();
                    groups[this.selectedLayoutIdx].Layouts[pIdx].TimeType = (pt.TimeType + 1) % 4;
                    this.timeLayoutsList = groups;
                  })

                TextInput({ text: pt.StartSecond, placeholder: 'HH:MM:SS' })
                  .height(32)
                  .fontSize(12)
                  .fontColor(this.theme().textPrimary)
                  .backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .layoutWeight(1)
                  .onChange((v: string) => {
                    this.timeLayoutsList[this.selectedLayoutIdx].Layouts[pIdx].StartSecond = v;
                  })

                Text('~').fontSize(12).fontColor(this.theme().textSecondary)

                TextInput({ text: pt.EndSecond, placeholder: 'HH:MM:SS' })
                  .height(32)
                  .fontSize(12)
                  .fontColor(this.theme().textPrimary)
                  .backgroundColor(this.theme().bgInput)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .layoutWeight(1)
                  .onChange((v: string) => {
                    this.timeLayoutsList[this.selectedLayoutIdx].Layouts[pIdx].EndSecond = v;
                  })

                Button('删除')
                  .height(28)
                  .fontSize(11)
                  .fontColor(this.theme().dangerColor)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    const groups = this.timeLayoutsList.slice();
                    const pts = groups[this.selectedLayoutIdx].Layouts.slice();
                    pts.splice(pIdx, 1);
                    groups[this.selectedLayoutIdx].Layouts = pts;
                    this.timeLayoutsList = groups;
                  })
              }
              .width('100%')

              if (pt.TimeType === 1) {
                Row({ space: 6 }) {
                  Text('课间名称:')
                    .fontSize(12)
                    .fontColor(this.theme().textSecondary)
                  TextInput({ text: pt.BreakName, placeholder: '如: 大课间 / 眼保健操' })
                    .height(30)
                    .fontSize(12)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .layoutWeight(1)
                    .onChange((v: string) => {
                      this.timeLayoutsList[this.selectedLayoutIdx].Layouts[pIdx].BreakName = v;
                    })
                }
              }
            }
            .padding(10)
            .backgroundColor(this.theme().bgCard)
            .borderRadius(6)
            .border({
              width: { left: 4, top: 1, right: 1, bottom: 1 },
              color: {
                left: pt.TimeType === 0 ? this.theme().accentColor : (pt.TimeType === 1 ? this.theme().successColor : (pt.TimeType === 2 ? this.theme().textSecondary : this.theme().warningColor)),
                top: this.theme().borderColor,
                right: this.theme().borderColor,
                bottom: this.theme().borderColor
              }
            })
          }, (_pt: TimeLayoutPoint, pIdx: number) => `pt_${pIdx}`)
        }
      }
    }
    .width('100%')
  }

  @Builder
  buildClassPlanVisual() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('课表列表:')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().textPrimary)
        Button('+ 新增课表')
          .height(28)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(() => {
            const arr = this.classPlansList.slice();
            const defaultTlId = this.refTimeLayoutsMap.length > 0 ? this.refTimeLayoutsMap[0].key : '';
            arr.push({
              key: generateUuid(),
              Name: `新课表 #${arr.length + 1}`,
              TimeLayoutId: defaultTlId,
              IsEnabled: true,
              IsOverlay: false,
              TimeRule: { WeekDay: 1, WeekCountDiv: 0, WeekCountDivTotal: 2 },
              Classes: [
                { SubjectId: this.refSubjectsMap.length > 0 ? this.refSubjectsMap[0].key : '' }
              ]
            });
            this.classPlansList = arr;
            this.selectedPlanIdx = arr.length - 1;
          })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.classPlansList, (cp: ClassPlanGroup, idx: number) => {
          Button(cp.Name)
            .height(30)
            .fontSize(12)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.selectedPlanIdx === idx ? this.theme().accentColor : this.theme().textPrimary)
            .backgroundColor(this.selectedPlanIdx === idx ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
            .border({ width: 1, color: this.selectedPlanIdx === idx ? this.theme().accentColor : this.theme().borderColor, radius: 6 })
            .onClick(() => {
              this.selectedPlanIdx = idx;
            })
        }, (cp: ClassPlanGroup) => cp.key)
      }

      if (this.classPlansList.length > 0 && this.selectedPlanIdx < this.classPlansList.length) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('课表名称:')
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
            TextInput({ text: this.classPlansList[this.selectedPlanIdx].Name })
              .height(32)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.classPlansList[this.selectedPlanIdx].Name = v;
              })

            Text('启用')
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: this.classPlansList[this.selectedPlanIdx].IsEnabled })
              .onChange((v: boolean) => {
                this.classPlansList[this.selectedPlanIdx].IsEnabled = v;
              })

            Button('删除课表')
              .height(28)
              .fontSize(11)
              .fontColor(this.theme().dangerColor)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                const arr = this.classPlansList.slice();
                arr.splice(this.selectedPlanIdx, 1);
                this.classPlansList = arr;
                this.selectedPlanIdx = 0;
              })
          }
          .width('100%')

          Row({ space: 6 }) {
            Text('触发星期:')
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
            ForEach([1, 2, 3, 4, 5, 6, 0], (wd: number) => {
              Button(wd === 0 ? '日' : `${wd}`)
                .height(26)
                .fontSize(11)
                .fontColor(this.classPlansList[this.selectedPlanIdx].TimeRule.WeekDay === wd ? '#FFFFFF' : this.theme().textPrimary)
                .backgroundColor(this.classPlansList[this.selectedPlanIdx].TimeRule.WeekDay === wd ? this.theme().accentColor : this.theme().bgSubtle)
                .borderRadius(4)
                .onClick(() => {
                  const arr = this.classPlansList.slice();
                  arr[this.selectedPlanIdx].TimeRule.WeekDay = wd;
                  this.classPlansList = arr;
                })
            }, (wd: number) => `wd_${wd}`)
          }
          .width('100%')

          Row({ space: 8 }) {
            Text('周次轮换:')
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
            ForEach([0, 1, 2], (div: number) => {
              Button(div === 0 ? '每周' : (div === 1 ? '单周' : '双周'))
                .height(26)
                .fontSize(11)
                .fontColor(this.classPlansList[this.selectedPlanIdx].TimeRule.WeekCountDiv === div ? '#FFFFFF' : this.theme().textPrimary)
                .backgroundColor(this.classPlansList[this.selectedPlanIdx].TimeRule.WeekCountDiv === div ? this.theme().accentColor : this.theme().bgSubtle)
                .borderRadius(4)
                .onClick(() => {
                  const arr = this.classPlansList.slice();
                  arr[this.selectedPlanIdx].TimeRule.WeekCountDiv = div;
                  this.classPlansList = arr;
                })
            }, (div: number) => `div_${div}`)

            Blank()
            Button('+ 增加课时槽位')
              .height(28)
              .fontSize(11)
              .fontColor('#FFFFFF')
              .backgroundColor(this.theme().accentColor)
              .borderRadius(4)
              .onClick(() => {
                const arr = this.classPlansList.slice();
                const slots = arr[this.selectedPlanIdx].Classes.slice();
                slots.push({ SubjectId: this.refSubjectsMap.length > 0 ? this.refSubjectsMap[0].key : '' });
                arr[this.selectedPlanIdx].Classes = slots;
                this.classPlansList = arr;
              })
          }
          .width('100%')

          ForEach(this.classPlansList[this.selectedPlanIdx].Classes, (slot: ClassPlanSlot, sIdx: number) => {
            Row({ space: 8 }) {
              Text(`第 ${sIdx + 1} 节`)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().accentColor)
                .width(64)

              TextInput({ placeholder: '科目 GUID 或点击右侧选择', text: slot.SubjectId })
                .height(32)
                .fontSize(12)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.classPlansList[this.selectedPlanIdx].Classes[sIdx].SubjectId = v;
                })

              if (this.refSubjectsMap.length > 0) {
                Button('切换科目')
                  .height(28)
                  .fontSize(11)
                  .fontColor(this.theme().textPrimary)
                  .backgroundColor(this.theme().bgSubtle)
                  .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                  .onClick(() => {
                    const arr = this.classPlansList.slice();
                    let curIdx = -1;
                    for (let k = 0; k < this.refSubjectsMap.length; k++) {
                      if (this.refSubjectsMap[k].key === slot.SubjectId) {
                        curIdx = k;
                        break;
                      }
                    }
                    const nextIdx = (curIdx + 1) % this.refSubjectsMap.length;
                    arr[this.selectedPlanIdx].Classes[sIdx].SubjectId = this.refSubjectsMap[nextIdx].key;
                    this.classPlansList = arr;
                  })
              }

              Button('删')
                .height(28)
                .fontSize(11)
                .fontColor(this.theme().dangerColor)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  const arr = this.classPlansList.slice();
                  const slots = arr[this.selectedPlanIdx].Classes.slice();
                  slots.splice(sIdx, 1);
                  arr[this.selectedPlanIdx].Classes = slots;
                  this.classPlansList = arr;
                })
            }
            .width('100%')
            .padding(8)
            .backgroundColor(this.theme().bgCard)
            .borderRadius(6)
            .border({ width: 1, color: this.theme().borderColor })
          }, (_s: ClassPlanSlot, sIdx: number) => `slot_${sIdx}`)
        }
      }
    }
    .width('100%')
  }

  @Builder
  buildPolicySwitchRow(title: string, desc: string, isOn: boolean, onToggle: (v: boolean) => void) {
    Row() {
      Column({ space: 2 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
        Text(desc).fontSize(12).fontColor(this.theme().textSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((v: boolean) => {
          onToggle(v);
        })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 4, right: 4 })
    .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
  }

  @Builder
  buildPolicyVisual() {
    Column({ space: 4 }) {
      this.buildPolicySwitchRow(
        '禁止编辑课表 (DisableProfileClassPlanEditing)',
        '锁定客户端本地课表修改权限',
        this.policyData.DisableProfileClassPlanEditing,
        (v: boolean) => { this.policyData.DisableProfileClassPlanEditing = v; }
      )
      this.buildPolicySwitchRow(
        '禁止编辑时间表 (DisableProfileTimeLayoutEditing)',
        '锁定客户端本地作息时间表修改权限',
        this.policyData.DisableProfileTimeLayoutEditing,
        (v: boolean) => { this.policyData.DisableProfileTimeLayoutEditing = v; }
      )
      this.buildPolicySwitchRow(
        '禁止编辑科目 (DisableProfileSubjectsEditing)',
        '锁定客户端本地科目列表修改权限',
        this.policyData.DisableProfileSubjectsEditing,
        (v: boolean) => { this.policyData.DisableProfileSubjectsEditing = v; }
      )
      this.buildPolicySwitchRow(
        '禁止编辑全部档案 (DisableProfileEditing)',
        '完全禁止客户端修改本地档案',
        this.policyData.DisableProfileEditing,
        (v: boolean) => { this.policyData.DisableProfileEditing = v; }
      )
      this.buildPolicySwitchRow(
        '禁止修改应用设置 (DisableSettingsEditing)',
        '锁定客户端设置界面',
        this.policyData.DisableSettingsEditing,
        (v: boolean) => { this.policyData.DisableSettingsEditing = v; }
      )
      this.buildPolicySwitchRow(
        '禁止自定义启动画面 (DisableSplashCustomize)',
        '锁定客户端启动页个性化配置',
        this.policyData.DisableSplashCustomize,
        (v: boolean) => { this.policyData.DisableSplashCustomize = v; }
      )
      this.buildPolicySwitchRow(
        '禁用调试菜单 (DisableDebugMenu)',
        '隐藏开发者与调试入口',
        this.policyData.DisableDebugMenu,
        (v: boolean) => { this.policyData.DisableDebugMenu = v; }
      )
      this.buildPolicySwitchRow(
        '允许退出集控模式 (AllowExitManagement)',
        '是否允许客户端终端主动脱离集控',
        this.policyData.AllowExitManagement,
        (v: boolean) => { this.policyData.AllowExitManagement = v; }
      )
      this.buildPolicySwitchRow(
        '禁用彩蛋 (DisableEasterEggs)',
        '关闭应用内置彩蛋特性',
        this.policyData.DisableEasterEggs,
        (v: boolean) => { this.policyData.DisableEasterEggs = v; }
      )
    }
    .width('100%')
  }

  @Builder
  buildDefaultSettingsVisual() {
    Column({ space: 10 }) {
      Column({ space: 8 }) {
        Text('窗口停靠位置 (0=左上, 1=顶中, 2=右上, 3=左下, 4=底中, 5=右下)')
          .fontSize(13)
          .fontColor(this.theme().textPrimary)
        Row({ space: 6 }) {
          ForEach([0, 1, 2, 3, 4, 5], (loc: number) => {
            Button(['左上', '顶中', '右上', '左下', '底中', '右下'][loc])
              .height(28)
              .fontSize(11)
              .fontColor(this.settingsData.WindowDockingLocation === loc ? '#FFFFFF' : this.theme().textPrimary)
              .backgroundColor(this.settingsData.WindowDockingLocation === loc ? this.theme().accentColor : this.theme().bgSubtle)
              .borderRadius(4)
              .onClick(() => {
                this.settingsData.WindowDockingLocation = loc;
              })
          }, (loc: number) => `loc_${loc}`)
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)

      Row({ space: 8 }) {
        Text('窗口层级:').fontSize(13).fontColor(this.theme().textPrimary)
        Button('置底 (0)')
          .height(28)
          .fontSize(12)
          .fontColor(this.settingsData.WindowLayer === 0 ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(this.settingsData.WindowLayer === 0 ? this.theme().accentColor : this.theme().bgSubtle)
          .borderRadius(4)
          .onClick(() => { this.settingsData.WindowLayer = 0; })
        Button('置顶 (1)')
          .height(28)
          .fontSize(12)
          .fontColor(this.settingsData.WindowLayer === 1 ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(this.settingsData.WindowLayer === 1 ? this.theme().accentColor : this.theme().bgSubtle)
          .borderRadius(4)
          .onClick(() => { this.settingsData.WindowLayer = 1; })

        Blank()
        Text('主题:').fontSize(13).fontColor(this.theme().textPrimary)
        ForEach([0, 1, 2], (th: number) => {
          Button(['跟随系统', '浅色', '深色'][th])
            .height(28)
            .fontSize(12)
            .fontColor(this.settingsData.Theme === th ? '#FFFFFF' : this.theme().textPrimary)
            .backgroundColor(this.settingsData.Theme === th ? this.theme().accentColor : this.theme().bgSubtle)
            .borderRadius(4)
            .onClick(() => { this.settingsData.Theme = th; })
        }, (th: number) => `th_${th}`)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)

      Row({ space: 8 }) {
        Text('主色调:').fontSize(13).fontColor(this.theme().textPrimary)
        TextInput({ text: this.settingsData.PrimaryColor, placeholder: '#0078D4' })
          .height(32)
          .fontSize(12)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgInput)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .width(110)
          .onChange((v: string) => { this.settingsData.PrimaryColor = v; })

        Text('缩放比例:').fontSize(13).fontColor(this.theme().textPrimary)
        TextInput({ text: `${this.settingsData.Scale}`, placeholder: '1.0' })
          .height(32)
          .fontSize(12)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgInput)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .width(70)
          .onChange((v: string) => {
            const n = Number(v);
            if (!isNaN(n)) {
              this.settingsData.Scale = n;
            }
          })

        Text('时间偏移(秒):').fontSize(13).fontColor(this.theme().textPrimary)
        TextInput({ text: `${this.settingsData.TimeOffsetSeconds}`, placeholder: '0' })
          .height(32)
          .fontSize(12)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgInput)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .width(70)
          .onChange((v: string) => {
            const n = Number(v);
            if (!isNaN(n)) {
              this.settingsData.TimeOffsetSeconds = n;
            }
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)

      this.buildPolicySwitchRow(
        '启用提醒通知 (IsNotificationEnabled)',
        '允许客户端弹窗显示提醒横幅',
        this.settingsData.IsNotificationEnabled,
        (v: boolean) => { this.settingsData.IsNotificationEnabled = v; }
      )
      this.buildPolicySwitchRow(
        '启用通知特效与音效 (Effect & Sound)',
        '播放醒目动画与提示音',
        this.settingsData.IsNotificationEffectEnabled,
        (v: boolean) => {
          this.settingsData.IsNotificationEffectEnabled = v;
          this.settingsData.IsNotificationSoundEnabled = v;
        }
      )
      this.buildPolicySwitchRow(
        '启用 TTS 语音播报 (IsSpeechEnabled)',
        '使用语音引擎朗读通知内容',
        this.settingsData.IsSpeechEnabled,
        (v: boolean) => { this.settingsData.IsSpeechEnabled = v; }
      )

      // ManagementPreset.json Generator
      Column({ space: 8 }) {
        Text('ManagementPreset.json 集控预设生成器')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().accentColor)
        Row({ space: 8 }) {
          TextInput({ placeholder: '可选预设班级标识 (如 高一(1)班)', text: this.presetClassIdentity })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.presetClassIdentity = v; })
          Button('拉取并生成预设')
            .height(34)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(async () => {
              const r = await ApiService.get().getManagementPresetJson(this.accountId);
              if (r.ok && r.data) {
                try {
                  const obj = JSON.parse(r.data) as Record<string, Object>;
                  if (this.presetClassIdentity.trim().length > 0) {
                    obj['ClassIdentity'] = this.presetClassIdentity.trim();
                  }
                  this.generatedPresetJson = JSON.stringify(obj, null, 2);
                } catch (_e) {
                  this.generatedPresetJson = r.data;
                }
              }
            })
        }
        if (this.generatedPresetJson.length > 0) {
          TextArea({ text: this.generatedPresetJson })
            .height(100)
            .fontSize(11)
            .fontFamily('monospace')
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgCard)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)
    }
    .width('100%')
  }

  @Builder
  buildComponentsVisual() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(`共 ${this.componentLines.length} 个组件行`)
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .layoutWeight(1)
        Button('+ 新增组件行')
          .height(28)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(() => {
            const lines = this.componentLines.slice();
            lines.push({
              Children: [],
              IsMainLine: lines.length === 0,
              IsEnabled: true,
              IslandSeparationMode: 0
            });
            this.componentLines = lines;
            this.selectedLineIdx = lines.length - 1;
          })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.componentLines, (line: ComponentLineData, lIdx: number) => {
          Button(`第 ${lIdx + 1} 行 ${line.IsMainLine ? '[主行]' : ''} (${line.Children.length})`)
            .height(28)
            .fontSize(12)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.selectedLineIdx === lIdx ? this.theme().accentColor : this.theme().textPrimary)
            .backgroundColor(this.selectedLineIdx === lIdx ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
            .border({ width: 1, color: this.selectedLineIdx === lIdx ? this.theme().accentColor : this.theme().borderColor, radius: 6 })
            .onClick(() => {
              this.selectedLineIdx = lIdx;
              this.selectedCompIdx = -1;
            })
        }, (_l: ComponentLineData, lIdx: number) => `line_${lIdx}`)
      }

      if (this.componentLines.length > 0 && this.selectedLineIdx < this.componentLines.length) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('启用该行').fontSize(12).fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: this.componentLines[this.selectedLineIdx].IsEnabled })
              .onChange((v: boolean) => {
                this.componentLines[this.selectedLineIdx].IsEnabled = v;
              })

            Text('设为主行').fontSize(12).fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: this.componentLines[this.selectedLineIdx].IsMainLine })
              .onChange((v: boolean) => {
                this.componentLines[this.selectedLineIdx].IsMainLine = v;
              })

            Blank()
            Button('删除当前行')
              .height(26)
              .fontSize(11)
              .fontColor(this.theme().dangerColor)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                const lines = this.componentLines.slice();
                lines.splice(this.selectedLineIdx, 1);
                this.componentLines = lines;
                this.selectedLineIdx = 0;
              })
          }
          .width('100%')

          Text('快速添加内置组件:')
            .fontSize(12)
            .fontColor(this.theme().textSecondary)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(BUILTIN_COMPONENTS, (def: BuiltinComponentDef) => {
              Button(`+ ${def.name}`)
                .height(26)
                .fontSize(11)
                .margin({ right: 6, bottom: 6 })
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgSubtle)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onClick(() => {
                  const lines = this.componentLines.slice();
                  const children = lines[this.selectedLineIdx].Children.slice();
                  children.push({
                    Id: def.id,
                    NameCache: def.name,
                    HorizontalAlignment: 1,
                    IsResourceOverridingEnabled: false,
                    MainWindowSecondaryFontSize: 14,
                    MainWindowBodyFontSize: 16,
                    MainWindowEmphasizedFontSize: 18,
                    MainWindowLargeFontSize: 20,
                    IsCustomForegroundColorEnabled: false,
                    ForegroundColor: '#FFFFFF',
                    IsCustomBackgroundColorEnabled: false,
                    BackgroundColor: '#000000',
                    IsCustomBackgroundOpacityEnabled: false,
                    BackgroundOpacity: 0.5,
                    IsCustomCornerRadiusEnabled: false,
                    CustomCornerRadius: 8,
                    Opacity: 1.0,
                    IsMinWidthEnabled: false,
                    MinWidth: 100,
                    IsMaxWidthEnabled: false,
                    MaxWidth: 500,
                    IsFixedWidthEnabled: false,
                    FixedWidth: 200,
                    HideOnRule: false
                  });
                  lines[this.selectedLineIdx].Children = children;
                  this.componentLines = lines;
                })
            }, (def: BuiltinComponentDef) => def.id)
          }

          ForEach(this.componentLines[this.selectedLineIdx].Children, (comp: ComponentItemData, cIdx: number) => {
            Row({ space: 8 }) {
              Text(`${cIdx + 1}. ${comp.NameCache}`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme().textPrimary)
                .layoutWeight(1)
              Text(`对齐:${['左', '中', '右', '拉伸'][comp.HorizontalAlignment] || '中'}`)
                .fontSize(11)
                .fontColor(this.theme().textSecondary)
              Button('切换对齐')
                .height(26)
                .fontSize(11)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgSubtle)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onClick(() => {
                  const lines = this.componentLines.slice();
                  lines[this.selectedLineIdx].Children[cIdx].HorizontalAlignment = (comp.HorizontalAlignment + 1) % 4;
                  this.componentLines = lines;
                })
              Button('移除')
                .height(26)
                .fontSize(11)
                .fontColor(this.theme().dangerColor)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  const lines = this.componentLines.slice();
                  const ch = lines[this.selectedLineIdx].Children.slice();
                  ch.splice(cIdx, 1);
                  lines[this.selectedLineIdx].Children = ch;
                  this.componentLines = lines;
                })
            }
            .width('100%')
            .padding(10)
            .backgroundColor(this.theme().bgCard)
            .borderRadius(6)
            .border({ width: 1, color: this.theme().borderColor })
          }, (_c: ComponentItemData, cIdx: number) => `comp_${cIdx}`)
        }
      }
    }
    .width('100%')
  }

  @Builder
  buildAuthLevelRow(label: string, curVal: number, onSelect: (lv: number) => void) {
    Row({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.theme().textPrimary)
        .layoutWeight(1)
      ForEach([0, 1, 2], (lv: number) => {
        Button(['无限制 (0)', '用户凭据 (1)', '管理员凭据 (2)'][lv])
          .height(26)
          .fontSize(11)
          .fontColor(curVal === lv ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(curVal === lv ? this.theme().accentColor : this.theme().bgSubtle)
          .borderRadius(4)
          .onClick(() => {
            onSelect(lv);
          })
      }, (lv: number) => `lv_${lv}`)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
  }

  @Builder
  buildCredentialsVisual() {
    Column({ space: 8 }) {
      Column({ space: 6 }) {
        Text('用户凭据 (UserCredential) 密码哈希生成')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Row({ space: 6 }) {
          TextInput({ placeholder: '输入明文密码以生成加盐哈希', text: this.plainUserPassword })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.plainUserPassword = v; })
          Button('生成哈希')
            .height(34)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(async () => {
              if (!this.plainUserPassword) {
                return;
              }
              const r = await ApiService.get().encodePasswordCredential(this.accountId, this.plainUserPassword);
              if (r.ok && r.data) {
                this.credentialsData.UserCredential = r.data;
                this.notifyStatus('已生成用户凭据哈希', false);
              }
            })
        }
        Text(`当前值: ${this.credentialsData.UserCredential || '(未设置)'}`)
          .fontSize(11)
          .fontColor(this.theme().textSecondary)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)

      Column({ space: 6 }) {
        Text('管理员凭据 (AdminCredential) 密码哈希生成')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Row({ space: 6 }) {
          TextInput({ placeholder: '输入管理员明文密码', text: this.plainAdminPassword })
            .height(34)
            .fontSize(12)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .layoutWeight(1)
            .onChange((v: string) => { this.plainAdminPassword = v; })
          Button('生成哈希')
            .height(34)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(async () => {
              if (!this.plainAdminPassword) {
                return;
              }
              const r = await ApiService.get().encodePasswordCredential(this.accountId, this.plainAdminPassword);
              if (r.ok && r.data) {
                this.credentialsData.AdminCredential = r.data;
                this.notifyStatus('已生成管理员凭据哈希', false);
              }
            })
        }
        Text(`当前值: ${this.credentialsData.AdminCredential || '(未设置)'}`)
          .fontSize(11)
          .fontColor(this.theme().textSecondary)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)

      this.buildAuthLevelRow('编辑档案权限 (EditProfile)', this.credentialsData.EditProfileAuthorizeLevel, (lv: number) => {
        this.credentialsData.EditProfileAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('编辑策略权限 (EditPolicy)', this.credentialsData.EditPolicyAuthorizeLevel, (lv: number) => {
        this.credentialsData.EditPolicyAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('退出集控权限 (ExitManagement)', this.credentialsData.ExitManagementAuthorizeLevel, (lv: number) => {
        this.credentialsData.ExitManagementAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('修改应用设置权限 (EditSettings)', this.credentialsData.EditSettingsAuthorizeLevel, (lv: number) => {
        this.credentialsData.EditSettingsAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('切换档案权限 (SwitchProfile)', this.credentialsData.SwitchProfileAuthorizeLevel, (lv: number) => {
        this.credentialsData.SwitchProfileAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('创建临时层权限 (TempOverlayClassPlan)', this.credentialsData.TempOverlayClassPlanAuthorizeLevel, (lv: number) => {
        this.credentialsData.TempOverlayClassPlanAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('调整时间偏移权限 (ChangeTimeOffset)', this.credentialsData.ChangeTimeOffsetAuthorizeLevel, (lv: number) => {
        this.credentialsData.ChangeTimeOffsetAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('退出应用权限 (ExitApplication)', this.credentialsData.ExitApplicationAuthorizeLevel, (lv: number) => {
        this.credentialsData.ExitApplicationAuthorizeLevel = lv;
      })
      this.buildAuthLevelRow('重启应用权限 (RestartApplication)', this.credentialsData.RestartApplicationAuthorizeLevel, (lv: number) => {
        this.credentialsData.RestartApplicationAuthorizeLevel = lv;
      })
    }
    .width('100%')
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

        Button(this.editorTab === 'json' ? '切换可视化编辑' : 'JSON 源码')
          .height(32)
          .fontSize(12)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgSubtle)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onClick(() => {
            if (this.editorTab === 'json') {
              this.parseJsonIntoVisual(this.rawJsonText);
              this.editorTab = 'visual';
            } else {
              this.syncVisualToJson();
              this.editorTab = 'json';
            }
          })

        if (this.selectedName.length > 0) {
          Button('删除')
            .height(32)
            .fontSize(12)
            .fontColor(this.theme().dangerColor)
            .backgroundColor(this.theme().bgCard)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onClick(() => {
              this.deleteCurrentResource();
            })
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

      if (this.editorTab === 'json') {
        TextArea({ text: this.rawJsonText })
          .height(380)
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgSubtle)
          .border({ width: 1, color: this.theme().borderColor, radius: 6 })
          .onChange((v: string) => {
            this.rawJsonText = v;
          })
      } else {
        if (this.resourceType === 'Subjects') {
          this.buildSubjectsVisual()
        } else if (this.resourceType === 'TimeLayout') {
          this.buildTimeLayoutVisual()
        } else if (this.resourceType === 'ClassPlan') {
          this.buildClassPlanVisual()
        } else if (this.resourceType === 'Policy') {
          this.buildPolicyVisual()
        } else if (this.resourceType === 'DefaultSettings') {
          this.buildDefaultSettingsVisual()
        } else if (this.resourceType === 'Components') {
          this.buildComponentsVisual()
        } else if (this.resourceType === 'Credentials') {
          this.buildCredentialsVisual()
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
      // Trigger reload if resourceType or accountId changed
      if (this.lastLoadedType !== this.resourceType || this.lastLoadedAccount !== this.accountId) {
        Row()
          .height(0)
          .onAppear(() => {
            this.reloadIfNeeded();
          })
      }

      // Page Header (.page-header) matching web/app/profiles/*/page.tsx
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

        Button('新建文件')
          .height(34)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme().accentColor)
          .borderRadius(4)
          .onClick(() => {
            this.showCreateModal = !this.showCreateModal;
          })
        Button('刷新')
          .height(34)
          .fontSize(13)
          .fontColor(this.theme().textPrimary)
          .backgroundColor(this.theme().bgCard)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onClick(() => {
            this.reloadIfNeeded();
          })
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
