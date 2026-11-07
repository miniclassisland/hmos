// Complete Data Models & Upstream ClassIsland Constants for HarmonyOS
// 1:1 Aligned with web/lib/types.ts & web/lib/api.ts

export interface UserInfo {
  id: string;
  username: string;
  email: string;
  display_name: string;
  role: string;
  role_code?: string;
  status?: string;
  is_active: boolean;
  can_create_account: boolean;
  totp_enabled: boolean;
  created_at?: number;
}

export interface StoredLoginCert {
  cert_id: string;
  cert_secret: string;
  generation: number;
  max_generation: number;
  expires_at: number;
  device_name: string;
}

export interface AccountSummary {
  id: string;
  name: string;
  slug: string;
  api_key?: string;
  registration_mode?: string;
  is_active?: boolean;
  role: string;
}

export interface AccountInfo {
  id: string;
  name: string;
  slug: string;
  owner_id: string;
  api_key: string;
  registration_mode: string;
  is_active: boolean;
  created_at?: number;
}

export interface QuotaItem {
  id?: string;
  account_id?: string;
  quota_key: string;
  quota_type?: string;
  max_value: number;
  limit_value?: number;
  current_value: number;
}

export interface MemberItem {
  id?: string;
  account_id?: string;
  user_id: string;
  username: string;
  email: string;
  display_name: string;
  role: string;
  joined_at?: number;
}

export interface InvitationItem {
  id: string;
  account_id?: string;
  code: string;
  role: string;
  max_uses: number;
  used_count: number;
  expires_at?: number;
  created_at?: number;
}

export interface ResourceItem {
  id: string;
  account_id?: string;
  resource_type: string;
  resource_name: string;
  version: number;
  content: string;
  updated_at?: number;
}

export interface ResourceVersionItem {
  version: number;
  created_at: number;
  content?: Object;
}

export interface ClientProfileRecord {
  cp_resource_name?: string;
  tl_resource_name?: string;
  sub_resource_name?: string;
  pol_resource_name?: string;
  ds_resource_name?: string;
  com_resource_name?: string;
  cred_resource_name?: string;
  ClassPlan?: string;
  TimeLayout?: string;
  Subjects?: string;
  Policy?: string;
  DefaultSettings?: string;
  Components?: string;
  Credentials?: string;
}

export interface ClientRecord {
  id?: string;
  account_id?: string;
  uid: string;
  client_id: string;
  display_name: string;
  mac: string;
  status: string; // 'online' | 'offline' | 'disabled'
  is_online?: boolean;
  last_ip: string;
  last_seen_at: number;
  registered_at: number;
  profile?: ClientProfileRecord;
}

export interface PairingRequestItem {
  id: string;
  account_id?: string;
  client_uid: string;
  client_id: string;
  mac: string;
  ip: string;
  pairing_code: string;
  code?: string;
  status: string; // 'pending' | 'approved' | 'rejected'
  created_at: number;
}

export interface PreRegItem {
  id: string;
  account_id?: string;
  label: string;
  class_identity: string;
  mac_address: string;
  cp_resource_name: string;
  tl_resource_name: string;
  sub_resource_name: string;
  pol_resource_name: string;
  ds_resource_name: string;
  com_resource_name: string;
  cred_resource_name: string;
  paired_client_uid: string;
  created_at: number;
}

export interface AuditLogItem {
  id: string;
  account_id?: string;
  client_uid: string;
  client_id: string;
  event: number;
  event_type?: number;
  event_name?: string;
  payload: string;
  decoded?: Record<string, Object>;
  timestamp_utc: number;
  created_at: number;
}

export interface ConfigSnapshotItem {
  id: string;
  request_guid: string;
  client_uid: string;
  config_type: number;
  payload: string;
  created_at: number;
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

export interface GlobalStats {
  total_users: number;
  pending_users: number;
  total_accounts: number;
  active_accounts: number;
  total_clients: number;
  online_clients: number;
}

export interface AdminUserItem {
  id: string;
  username: string;
  email: string;
  display_name: string;
  role: string;
  role_code?: string;
  status: string;
  is_active: boolean;
  can_create_account: boolean;
  totp_enabled: boolean;
  created_at: number;
}

export interface AdminAccountItem {
  id: string;
  name: string;
  slug: string;
  owner_id: string;
  api_key: string;
  registration_mode: string;
  is_active: boolean;
  client_count?: number;
  member_count?: number;
  created_at: number;
}

export interface TicketMessageItem {
  id: string;
  sender_id?: string;
  sender_name: string;
  sender_role: string;
  is_staff_reply: boolean;
  content: string;
  created_at: string;
}

export interface TicketItem {
  id: string;
  ticket_no: string;
  subject: string;
  category: string;
  priority: string;
  status: string;
  created_at: string;
  updated_at: string;
  messages?: TicketMessageItem[];
}

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
  TimeType: number; // 0=上课, 1=课间, 2=分割线, 3=行动
  DefaultClassId: string;
  IsHideDefault: boolean;
  BreakName: string;
  ActionSet?: Record<string, Object>;
}

export interface TimeLayoutGroup {
  key: string;
  Name: string;
  Layouts: TimeLayoutPoint[];
}

export interface ClassPlanEntry {
  key: string;
  Name: string;
  TimeLayoutId: string;
  IsEnabled: boolean;
  IsOverlay: boolean;
  AssociatedGroup: string;
  WeekDay: number;
  WeekCountDiv: number;
  WeekCountDivTotal: number;
  Classes: string[];
}

export interface BuiltinComponentDef {
  id: string;
  name: string;
  desc: string;
  isContainer: boolean;
}

export const BUILTIN_COMPONENTS: BuiltinComponentDef[] = [
  {
    id: 'df3f8295-21f6-482e-ada2-f0ab5f19a9d6',
    name: '文本',
    desc: '显示自定义文本内容，支持字号与颜色配置。',
    isContainer: false
  },
  {
    id: '7c645d35-8151-48ba-b4ac-15017460d994',
    name: '课程表',
    desc: '显示当前的课程表信息，联动当前时间表与课表。',
    isContainer: false
  },
  {
    id: '9812679e-482b-4729-8854-02d20999290d',
    name: '日期',
    desc: '显示今日星期、公历与农历日期。',
    isContainer: false
  },
  {
    id: '9d53da09-392b-4082-b959-55b887a0c154',
    name: '时钟',
    desc: '显示当前精确时间，支持秒针显示与闪烁分隔符。',
    isContainer: false
  },
  {
    id: '54e81232-9f91-4526-851d-4d5f05079438',
    name: '倒计时',
    desc: '显示距离指定目标日期的剩余天数倒计时。',
    isContainer: false
  },
  {
    id: 'a0563932-c393-4e0e-89d7-5f1289b6d0d5',
    name: '天气简报',
    desc: '显示实时天气状况、温度、湿度及气象预警。',
    isContainer: false
  },
  {
    id: 'c1291320-6f2c-44c0-8c3b-e6a41b5c146c',
    name: '分组容器',
    desc: '将多个子组件水平组合在一起的容器组件。',
    isContainer: true
  },
  {
    id: 'ef982d8f-2e57-4689-b63b-37f4b2390b34',
    name: '轮播容器',
    desc: '按设定动画与时间间隔轮流展示内部多个子组件。',
    isContainer: true
  },
  {
    id: 'b22b8473-61a8-4663-b6c1-6c6e3b60e98c',
    name: '滚动容器',
    desc: '将内部子组件内容以跑马灯形式持续横向滚动展示。',
    isContainer: true
  },
  {
    id: '1664023a-b799-4a1c-a3d3-d93b931a3d0f',
    name: '分割线',
    desc: '在同行相邻组件之间显示垂直视觉分隔线。',
    isContainer: false
  },
  {
    id: '6989f11b-755c-414b-a1d8-94180268a4d6',
    name: '今日课表概览',
    desc: '横向或纵向集中预览全天所有课程安排。',
    isContainer: false
  }
];

export interface BuiltinActionDef {
  id: string;
  name: string;
  category: string;
}

export const BUILTIN_ACTIONS: BuiltinActionDef[] = [
  { id: 'classisland.notice', name: '显示提醒横幅', category: '提醒与播报' },
  { id: 'classisland.broadcast.weather', name: '播报天气预报', category: '提醒与播报' },
  { id: 'classisland.os.run', name: '运行程序 / 打开文件或网页', category: '系统与进程' },
  { id: 'classisland.os.power', name: '关机 / 重启 / 睡眠系统', category: '系统与进程' },
  { id: 'classisland.os.volume', name: '调整系统音量 / 静音', category: '系统与进程' },
  { id: 'classisland.settings.modify', name: '修改应用设置项', category: '应用控制' },
  { id: 'classisland.profile.tempOverlay', name: '创建临时课表层', category: '课表控制' },
  { id: 'classisland.app.quit', name: '退出或重启 ClassIsland', category: '应用控制' }
];

export interface AuditEventLabelDef {
  event: number;
  label: string;
}

export const AUDIT_EVENT_LABELS: AuditEventLabelDef[] = [
  { event: 0, label: '未知事件' },
  { event: 1, label: '授权通过' },
  { event: 2, label: '授权失败' },
  { event: 3, label: '时间表切换' },
  { event: 4, label: '课表更新' },
  { event: 5, label: '设置变更' },
  { event: 6, label: '插件安装' },
  { event: 7, label: '插件卸载' },
  { event: 8, label: '应用启动' },
  { event: 9, label: '应用退出' },
  { event: 10, label: '应用崩溃' },
  { event: 11, label: '集控策略更新' },
  { event: 12, label: '天气更新' },
  { event: 13, label: '时间偏移变更' }
];

export const EMPTY_GUID: string = '00000000-0000-0000-0000-000000000000';

export function getAuditEventLabel(ev: number): string {
  for (let i = 0; i < AUDIT_EVENT_LABELS.length; i++) {
    if (AUDIT_EVENT_LABELS[i].event === ev) {
      return AUDIT_EVENT_LABELS[i].label;
    }
  }
  return `事件 #${ev}`;
}

export function getQuotaLabel(key: string): string {
  if (key === 'max_clients') { return '最大注册客户端数'; }
  if (key === 'max_grpc_connections') { return '最大实时并发连接数'; }
  if (key === 'max_bandwidth_mb') { return '每月最大流量配额'; }
  if (key === 'feature.ota') { return '远程更新与分发'; }
  if (key === 'feature.audit') { return '客户端行为审计'; }
  return key;
}

export function getAccountRoleLabel(role: string): string {
  if (role === 'owner') { return '所有者'; }
  if (role === 'admin') { return '管理员'; }
  if (role === 'member' || role === 'editor') { return '成员'; }
  if (role === 'viewer') { return '只读观察者'; }
  return role;
}

export function getSystemRoleLabel(role: string): string {
  if (role === 'superadmin') { return '超级管理员'; }
  if (role === 'admin') { return '系统管理员'; }
  if (role === 'user') { return '标准用户'; }
  if (role === 'guest') { return '受限访客'; }
  return role;
}

export function getTicketStatusLabel(status: string): string {
  if (status === 'open') { return '待处理'; }
  if (status === 'in_progress') { return '处理中'; }
  if (status === 'resolved') { return '已解决'; }
  if (status === 'closed') { return '已关闭'; }
  return status;
}

export function getTicketPriorityLabel(priority: string): string {
  if (priority === 'low') { return '低'; }
  if (priority === 'normal') { return '普通'; }
  if (priority === 'high') { return '高'; }
  if (priority === 'urgent') { return '紧急'; }
  return priority;
}

export function getTicketCategoryLabel(cat: string): string {
  if (cat === 'general') { return '一般咨询'; }
  if (cat === 'bug') { return '故障报告'; }
  if (cat === 'quota') { return '配额申请'; }
  if (cat === 'account') { return '账户与安全'; }
  return cat;
}

export function normalizeComponentId(id: string): string {
  return (id || '').trim().toLowerCase();
}

export function findComponentDef(id: string): BuiltinComponentDef | null {
  const norm = normalizeComponentId(id);
  for (let i = 0; i < BUILTIN_COMPONENTS.length; i++) {
    if (BUILTIN_COMPONENTS[i].id === norm) {
      return BUILTIN_COMPONENTS[i];
    }
  }
  return null;
}

export function generateUuid(): string {
  const hex = '0123456789abcdef';
  let out = '';
  for (let i = 0; i < 36; i++) {
    if (i === 8 || i === 13 || i === 18 || i === 23) {
      out += '-';
    } else if (i === 14) {
      out += '4';
    } else {
      const r = Math.floor(Math.random() * 16);
      out += hex.charAt(i === 19 ? ((r & 0x3) | 0x8) : r);
    }
  }
  return out;
}

export function extractIsoTimePart(raw: string): string {
  if (!raw) {
    return '08:00:00';
  }
  const tIdx = raw.indexOf('T');
  if (tIdx >= 0 && raw.length >= tIdx + 9) {
    return raw.substring(tIdx + 1, tIdx + 9);
  }
  if (raw.length >= 8) {
    return raw.substring(0, 8);
  }
  return raw;
}

export function formatTimestamp(ts?: number): string {
  if (!ts || ts <= 0) {
    return '-';
  }
  const ms = ts > 10000000000 ? ts : ts * 1000;
  const d = new Date(ms);
  const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
