// Comprehensive Type Definitions for MINI ClassIsland Control App (HarmonyOS)

export interface UserInfo {
  id: number;
  username: string;
  email: string;
  display_name: string;
  role: string;
  totp_enabled: boolean;
  can_create_account: boolean;
}

export interface AuthResponse {
  token: string;
  token_type: string;
  totp_required: boolean;
  totp_session: string;
  user: UserInfo;
}

export interface AccountSummary {
  id: number;
  name: string;
  slug: string;
  api_key: string;
  is_active: boolean;
  role: string;
  registration_mode?: string;
}

export interface AccountInfo {
  id: number;
  name: string;
  slug: string;
  api_key: string;
  owner_id: number;
  is_active: boolean;
  registration_mode: string; // 'open' | 'pairing' | 'pre_reg'
  created_at: number;
  updated_at: number;
}

export interface QuotaItem {
  id: number;
  account_id: number;
  quota_type: string;
  limit_value: number;
  current_value: number;
}

export interface MemberItem {
  id: number;
  account_id: number;
  user_id: number;
  role: string;
  username: string;
  email: string;
  display_name: string;
  created_at: number;
}

export interface InvitationItem {
  id: number;
  account_id: number;
  code: string;
  role: string;
  max_uses: number;
  used_count: number;
  expires_at: number;
  created_by: number;
  is_active: boolean;
  created_at: number;
}

export interface ClientRecord {
  id: number;
  account_id: number;
  uid: string;
  client_id: string;
  mac: string;
  display_name: string;
  status: string; // 'online' | 'offline' | 'disabled'
  last_ip: string;
  last_seen_at: number;
  registered_at: number;
}

export interface ClientProfileRecord {
  id: number;
  account_id: number;
  client_uid: string;
  cp_resource_name: string;
  tl_resource_name: string;
  sub_resource_name: string;
  pol_resource_name: string;
  ds_resource_name: string;
  com_resource_name: string;
  cred_resource_name: string;
  updated_at: number;
}

export interface ResourceItem {
  id: number;
  account_id: number;
  resource_name: string;
  resource_type: string;
  version: number;
  content: string;
  created_at: number;
  updated_at: number;
}

export interface AuditLogItem {
  id: number;
  account_id: number;
  client_uid: string;
  client_id: string;
  event: number;
  payload: string;
  timestamp_utc: number;
  created_at: number;
}

export interface ConfigSnapshotItem {
  id: number;
  account_id: number;
  client_uid: string;
  request_guid: string;
  config_type: number;
  payload: string;
  created_at: number;
}

export interface PairingRequestItem {
  id: number;
  account_id: number;
  client_uid: string;
  client_id: string;
  mac: string;
  pairing_code: string;
  status: string; // 'pending' | 'approved' | 'rejected' | 'expired'
  ip: string;
  expires_at: number;
  created_at: number;
  resolved_at: number;
}

export interface PreRegItem {
  id: number;
  account_id: number;
  label: string;
  class_identity: string;
  mac_address: string;
  preset_token: string;
  is_enabled: boolean;
  paired_client_uid: string;
  paired_at: number;
  cp_resource_name: string;
  tl_resource_name: string;
  sub_resource_name: string;
  pol_resource_name: string;
  ds_resource_name: string;
  com_resource_name: string;
  cred_resource_name: string;
  created_at: number;
  updated_at: number;
}

export interface NotificationPayload {
  MessageMask: string;
  MessageContent: string;
  OverlayIconLeft: number;
  OverlayIconRight: number;
  IsEmergency: boolean;
  IsSpeechEnabled: boolean;
  IsSoundEnabled: boolean;
  IsEffectEnabled: boolean;
  IsTopmost: boolean;
  DurationSeconds: number;
  RepeatCounts: number;
}

// 7 Profile Visual Data Models
export interface SubjectEntry {
  key: string;
  Name: string;
  Initial: string;
  TeacherName: string;
  IsOutDoor: boolean;
}

export interface TimeLayoutPoint {
  StartSecond: string;
  EndSecond: string;
  TimeType: number; // 0: 上课, 1: 课间休息, 2: 分割线, 3: 行动
  DefaultClassId: string;
  IsHideDefault: boolean;
  BreakName: string;
}

export interface TimeLayoutGroup {
  key: string;
  Name: string;
  Layouts: TimeLayoutPoint[];
}

export interface ClassPlanSlot {
  SubjectId: string;
}

export interface ClassPlanRule {
  WeekDay: number;
  WeekCountDiv: number;
  WeekCountDivTotal: number;
}

export interface ClassPlanGroup {
  key: string;
  Name: string;
  TimeLayoutId: string;
  IsEnabled: boolean;
  IsOverlay: boolean;
  TimeRule: ClassPlanRule;
  Classes: ClassPlanSlot[];
}

export interface PolicyData {
  DisableProfileClassPlanEditing: boolean;
  DisableProfileTimeLayoutEditing: boolean;
  DisableProfileSubjectsEditing: boolean;
  DisableProfileEditing: boolean;
  DisableSettingsEditing: boolean;
  DisableSplashCustomize: boolean;
  DisableDebugMenu: boolean;
  AllowExitManagement: boolean;
  DisableEasterEggs: boolean;
}

export interface DefaultSettingsData {
  WindowDockingLocation: number;
  WindowLayer: number;
  WindowDockingOffsetX: number;
  WindowDockingOffsetY: number;
  Scale: number;
  IsNotificationEnabled: boolean;
  IsNotificationEffectEnabled: boolean;
  IsNotificationSoundEnabled: boolean;
  IsSpeechEnabled: boolean;
  SpeechVolume: number;
  Theme: number;
  PrimaryColor: string;
  TimeOffsetSeconds: number;
}

export interface ComponentItemData {
  Id: string;
  NameCache: string;
  HorizontalAlignment: number;
  IsResourceOverridingEnabled: boolean;
  MainWindowSecondaryFontSize: number;
  MainWindowBodyFontSize: number;
  MainWindowEmphasizedFontSize: number;
  MainWindowLargeFontSize: number;
  IsCustomForegroundColorEnabled: boolean;
  ForegroundColor: string;
  IsCustomBackgroundColorEnabled: boolean;
  BackgroundColor: string;
  IsCustomBackgroundOpacityEnabled: boolean;
  BackgroundOpacity: number;
  IsCustomCornerRadiusEnabled: boolean;
  CustomCornerRadius: number;
  Opacity: number;
  IsMinWidthEnabled: boolean;
  MinWidth: number;
  IsMaxWidthEnabled: boolean;
  MaxWidth: number;
  IsFixedWidthEnabled: boolean;
  FixedWidth: number;
  HideOnRule: boolean;
}

export interface ComponentLineData {
  Children: ComponentItemData[];
  IsMainLine: boolean;
  IsEnabled: boolean;
  IslandSeparationMode: number;
}

export interface CredentialsData {
  UserCredential: string;
  AdminCredential: string;
  EditProfileAuthorizeLevel: number;
  EditPolicyAuthorizeLevel: number;
  ExitManagementAuthorizeLevel: number;
  EditSettingsAuthorizeLevel: number;
  SwitchProfileAuthorizeLevel: number;
  TempOverlayClassPlanAuthorizeLevel: number;
  ChangeTimeOffsetAuthorizeLevel: number;
  ExitApplicationAuthorizeLevel: number;
  RestartApplicationAuthorizeLevel: number;
}

// SuperAdmin Governance Models
export interface GlobalStats {
  total_accounts: number;
  active_accounts: number;
  total_users: number;
  pending_users: number;
  total_clients: number;
  online_clients: number;
  total_audit_logs: number;
}

export interface AdminUserItem {
  id: number;
  username: string;
  email: string;
  display_name: string;
  role: string;
  is_active: boolean;
  is_approved: boolean;
  can_create_account: boolean;
  totp_enabled: boolean;
  created_at: number;
  updated_at: number;
}

export interface AdminAccountItem {
  id: number;
  name: string;
  slug: string;
  api_key: string;
  owner_id: number;
  is_active: boolean;
  registration_mode: string;
  created_at: number;
  updated_at: number;
}

export interface StoredLoginCert {
  cert_id: string;
  cert_secret: string;
  generation: number;
  max_generation: number;
  issued_at: number;
  expires_at: number;
  user_id?: number;
}

export interface ResourceVersionItem {
  version: number;
  content: string;
  created_at: number;
}

export interface BuiltinComponentDef {
  id: string;
  name: string;
  desc: string;
  isContainer: boolean;
}

export const EMPTY_GUID: string = '00000000-0000-0000-0000-000000000000';

export const BUILTIN_COMPONENTS: BuiltinComponentDef[] = [
  { id: 'df3f8295-21f6-482e-ada2-f0ab5f19a9d6', name: '文本', desc: '显示自定义文本内容，支持多行和大字模式。', isContainer: false },
  { id: '1e036932-96d9-4f87-a8b1-b8673a90603c', name: '分隔线', desc: '在组件之间显示分割线。', isContainer: false },
  { id: '7c645d35-8151-48ba-b4ac-15017460d994', name: '课程表', desc: '显示当前的课程表信息。', isContainer: false },
  { id: '9812679e-482b-4729-8854-02d20999290d', name: '时钟', desc: '显示当前时间，支持秒针和闪烁效果。', isContainer: false },
  { id: 'b65a523e-c179-461b-9c2d-99f38c251153', name: '日期', desc: '显示今天的日期和星期。', isContainer: false },
  { id: '54e81232-9f91-4526-851d-4d5f05079438', name: '倒计时', desc: '显示距离指定日期的剩余天数。', isContainer: false },
  { id: 'ca495086-e297-4beb-9603-c5c1c1a8551e', name: '天气简报', desc: '显示实时天气状况和气象预警。', isContainer: false },
  { id: '991c7d41-6191-4435-b25a-034a54694041', name: '分组容器', desc: '将多个组件组合在一起显示。', isContainer: true },
  { id: 'c08f0284-8216-44d3-85a4-33a90a2d6d62', name: '滚动组件容器', desc: '使内部组件循环滚动显示。', isContainer: true },
  { id: 'ea93c7e9-f173-4f18-a93a-1607a217a1a8', name: '轮播组件容器', desc: '轮流播放内部的多个组件。', isContainer: true },
  { id: 'd2f52a16-7721-4032-b48c-227a5763a015', name: '今日课表', desc: '通过跑马灯或摘要展示全天课程。', isContainer: false },
];

export const LEGACY_COMPONENT_GUID_MAP: Record<string, string> = {
  '1507b9a2-7884-4937-9499-4a1b54f4c855': '7c645d35-8151-48ba-b4ac-15017460d994',
  '908c5531-f80c-4c32-89d2-f935455d65c8': '9812679e-482b-4729-8854-02d20999290d',
  'f4c9a059-55b0-42b0-9b09-f506e068d801': 'b65a523e-c179-461b-9c2d-99f38c251153',
  '6fe32b24-b78c-4c62-b8c4-3f6838d167a8': 'ca495086-e297-4beb-9603-c5c1c1a8551e',
  'a79923a8-71d0-43b9-b9b2-611c8bf7186a': '54e81232-9f91-4526-851d-4d5f05079438',
  'df3f8295-21f6-482e-ada2-fa0e52b2620f': 'df3f8295-21f6-482e-ada2-f0ab5f19a9d6',
  'c2f3f06e-b62c-46a0-a080-322c0c492d91': '1e036932-96d9-4f87-a8b1-b8673a90603c',
  'b51c85d7-2069-413b-8347-5a8116eb209b': 'ea93c7e9-f173-4f18-a93a-1607a217a1a8',
  'e3148204-5f12-40a2-9c35-2b259c039a2b': '991c7d41-6191-4435-b25a-034a54694041'
};

export function normalizeComponentId(rawId: string): string {
  const lower = (rawId || '').trim().toLowerCase();
  return LEGACY_COMPONENT_GUID_MAP[lower] || lower;
}

export function findComponentDef(rawId: string): BuiltinComponentDef | null {
  const norm = normalizeComponentId(rawId);
  for (let i = 0; i < BUILTIN_COMPONENTS.length; i++) {
    if (BUILTIN_COMPONENTS[i].id.toLowerCase() === norm) {
      return BUILTIN_COMPONENTS[i];
    }
  }
  return null;
}

export interface BuiltinActionDef {
  id: string;
  name: string;
}

export const BUILTIN_ACTIONS: BuiltinActionDef[] = [
  { id: 'classisland.os.run', name: '运行程序 / 打开文件 / 网页' },
  { id: 'classisland.showNotification', name: '显示提醒通知' },
  { id: 'classisland.broadcastSignal', name: '广播触发信号' },
  { id: 'classisland.weather.Important', name: '播报天气简报' },
  { id: 'classisland.settings.CurrentComponentConfig', name: '切换组件配置方案' },
  { id: 'classisland.settings.Theme', name: '切换应用明暗主题' },
  { id: 'classisland.settings.WindowDockingLocation', name: '切换主界面停靠位置' },
  { id: 'classisland.app.quit', name: '退出 ClassIsland' },
];

export interface AuditEventLabelDef {
  event: number;
  label: string;
}

export const AUDIT_EVENT_LABELS: AuditEventLabelDef[] = [
  { event: 0, label: '未指定' },
  { event: 1, label: '应用启动' },
  { event: 2, label: '应用崩溃' },
  { event: 3, label: '应用退出' },
  { event: 4, label: '插件安装' },
  { event: 5, label: '插件卸载' },
  { event: 6, label: '时间偏移变更' },
  { event: 7, label: '授权认证成功' },
  { event: 8, label: '授权认证失败' },
  { event: 9, label: '设置修改' },
  { event: 10, label: '档案修改' },
  { event: 11, label: '退出集控' },
  { event: 12, label: '集控设置变更' },
  { event: 13, label: '同步失败' },
];

export function getAuditEventLabel(ev: number): string {
  for (let i = 0; i < AUDIT_EVENT_LABELS.length; i++) {
    if (AUDIT_EVENT_LABELS[i].event === ev) {
      return AUDIT_EVENT_LABELS[i].label;
    }
  }
  return `事件 #${ev}`;
}

export function formatTimestamp(ts: number): string {
  if (!ts || ts <= 0) {
    return '-';
  }
  const ms = ts > 100000000000 ? ts : ts * 1000;
  const d = new Date(ms);
  const pad = (n: number): string => n < 10 ? `0${n}` : `${n}`;
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function generateUuid(): string {
  const hex = '0123456789abcdef';
  const pattern = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
  let out = '';
  for (let i = 0; i < pattern.length; i++) {
    const ch = pattern.charAt(i);
    if (ch === 'x') {
      const r = Math.floor(Math.random() * 16);
      out += hex.charAt(r);
    } else if (ch === 'y') {
      const r = (Math.floor(Math.random() * 4) + 8);
      out += hex.charAt(r);
    } else {
      out += ch;
    }
  }
  return out;
}

export function extractIsoTimePart(val: string): string {
  if (!val) {
    return '08:00:00';
  }
  const tIdx = val.indexOf('T');
  if (tIdx >= 0) {
    const afterT = val.substring(tIdx + 1);
    return afterT.length >= 8 ? afterT.substring(0, 8) : afterT;
  }
  return val.length >= 8 ? val.substring(0, 8) : val;
}
