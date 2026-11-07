import { http } from '@kit.NetworkKit';
import {
  UserInfo,
  AuthResponse,
  AccountSummary,
  AccountInfo,
  QuotaItem,
  MemberItem,
  InvitationItem,
  ClientRecord,
  ClientProfileRecord,
  ResourceItem,
  AuditLogItem,
  ConfigSnapshotItem,
  PairingRequestItem,
  PreRegItem,
  NotificationPayload,
  GlobalStats,
  AdminUserItem,
  AdminAccountItem,
  StoredLoginCert,
  ResourceVersionItem
} from '../model/Types';

export class ApiResult<T> {
  ok: boolean = false;
  status: number = 0;
  data: T | null = null;
  error: string = '';
  isOobe: boolean = false;
  rawText: string = '';
}

export class ApiService {
  private static instance: ApiService = new ApiService();

  public managementUrl: string = 'https://api.miniclassisland.com';
  public adminUrl: string = 'https://admin.miniclassisland.com/api';
  public token: string = '';
  public tokenExpiresAt: number = 0;
  public storedCertificate: StoredLoginCert | null = null;

  public static get(): ApiService {
    return ApiService.instance;
  }

  public setEndpoints(mgmtUrl: string, admUrl: string): void {
    const cleanMgmt = mgmtUrl.trim().replace(/\/+$/, '');
    const cleanAdm = admUrl.trim().replace(/\/+$/, '');
    if (cleanMgmt.length > 0) {
      this.managementUrl = cleanMgmt;
    }
    if (cleanAdm.length > 0) {
      this.adminUrl = cleanAdm;
    }
    AppStorage.setOrCreate<string>('managementUrl', this.managementUrl);
    AppStorage.setOrCreate<string>('adminUrl', this.adminUrl);
  }

  public setToken(t: string): void {
    this.token = t;
    AppStorage.setOrCreate<string>('authToken', t);
  }

  private async request(
    baseUrl: string,
    path: string,
    method: http.RequestMethod,
    bodyObj?: Object
  ): Promise<ApiResult<Record<string, Object>>> {
    const res = new ApiResult<Record<string, Object>>();
    const req = http.createHttp();
    const url = `${baseUrl}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (this.token.length > 0) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        readTimeout: 15000,
        connectTimeout: 10000,
        expectDataType: http.HttpDataType.STRING
      };
      if (bodyObj !== undefined) {
        options.extraData = JSON.stringify(bodyObj);
      }
      const httpRes = await req.request(url, options);
      res.status = httpRes.responseCode;
      const text = typeof httpRes.result === 'string' ? httpRes.result : JSON.stringify(httpRes.result);
      res.rawText = text;

      let parsed: Record<string, Object> = {};
      if (text && text.trim().length > 0) {
        try {
          parsed = JSON.parse(text) as Record<string, Object>;
        } catch (_e) {
          parsed = {};
        }
      }

      if (httpRes.responseCode === 503 && String(parsed['code'] || '') === 'ERR_SYSTEM_OOBE') {
        res.isOobe = true;
        res.error = '系统尚未完成初始化配置';
        return res;
      }

      if (httpRes.responseCode === 429) {
        res.error = String(parsed['message'] || parsed['error'] || '请求过于频繁，请稍后再试');
        return res;
      }

      if (httpRes.responseCode >= 200 && httpRes.responseCode < 300) {
        res.ok = true;
        res.data = parsed;
      } else {
        res.error = String(parsed['message'] || parsed['error'] || '请求失败');
      }
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : JSON.stringify(err);
      res.error = `网络请求异常: ${errMsg}`;
    } finally {
      req.destroy();
    }
    return res;
  }

  public async getRawJson(baseUrl: string, path: string): Promise<ApiResult<string>> {
    const r = await this.request(baseUrl, path, http.RequestMethod.GET);
    const out = new ApiResult<string>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    out.isOobe = r.isOobe;
    out.data = r.rawText;
    return out;
  }

  // ==================== OOBE ====================
  public async verifyOobe(passcode: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'passcode': passcode };
    return this.request(this.adminUrl, '/oobe/verify', http.RequestMethod.POST, payload);
  }

  public async configureOobe(payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, '/oobe/configure', http.RequestMethod.POST, payload);
  }

  // ==================== AUTH & 2FA ====================
  public async checkMailAvailability(email: string): Promise<ApiResult<boolean>> {
    const encoded = encodeURIComponent(email.trim());
    const r = await this.request(this.managementUrl, `/user/mail/availability?email=${encoded}`, http.RequestMethod.GET);
    const out = new ApiResult<boolean>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    out.isOobe = r.isOobe;
    if (r.ok && r.data) {
      out.data = Boolean(r.data['available']);
    }
    return out;
  }

  public async login(username: string, password: string, useAdminEndpoint: boolean): Promise<ApiResult<AuthResponse>> {
    const base = useAdminEndpoint ? this.adminUrl : this.managementUrl;
    const payload: Record<string, Object> = { 'email': username, 'username': username, 'password': password };
    const r = await this.request(base, '/user/auth', http.RequestMethod.POST, payload);
    const out = new ApiResult<AuthResponse>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    out.isOobe = r.isOobe;
    if (r.ok && r.data) {
      out.data = JSON.parse(r.rawText) as AuthResponse;
    }
    return out;
  }

  public async registerUser(
    username: string,
    email: string,
    password: string,
    displayName: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'username': username,
      'email': email,
      'password': password,
      'display_name': displayName
    };
    return this.request(this.managementUrl, '/user/apply', http.RequestMethod.POST, payload);
  }

  public async verifyTotp(totpSession: string, code: string, useAdminEndpoint: boolean): Promise<ApiResult<AuthResponse>> {
    const base = useAdminEndpoint ? this.adminUrl : this.managementUrl;
    const payload: Record<string, Object> = { 'temp_token': totpSession, 'totp_session': totpSession, 'code': code };
    const r = await this.request(base, '/user/2fa/totp/verify', http.RequestMethod.POST, payload);
    const out = new ApiResult<AuthResponse>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    if (r.ok) {
      out.data = JSON.parse(r.rawText) as AuthResponse;
    }
    return out;
  }

  public async recoverTotp(
    totpSession: string,
    recoveryCode: string,
    useAdminEndpoint: boolean
  ): Promise<ApiResult<AuthResponse>> {
    const base = useAdminEndpoint ? this.adminUrl : this.managementUrl;
    const payload: Record<string, Object> = { 'temp_token': totpSession, 'totp_session': totpSession, 'recovery_code': recoveryCode };
    const r = await this.request(base, '/user/2fa/totp/recover', http.RequestMethod.POST, payload);
    const out = new ApiResult<AuthResponse>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    if (r.ok) {
      out.data = JSON.parse(r.rawText) as AuthResponse;
    }
    return out;
  }

  public async getProfile(): Promise<ApiResult<UserInfo>> {
    const r = await this.request(this.managementUrl, '/user/info', http.RequestMethod.GET);
    const out = new ApiResult<UserInfo>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    out.isOobe = r.isOobe;
    if (r.ok) {
      out.data = JSON.parse(r.rawText) as UserInfo;
    }
    return out;
  }

  public async updateProfile(displayName: string, email: string, username: string): Promise<ApiResult<Record<string, Object>>> {
    let lastRes = new ApiResult<Record<string, Object>>();
    lastRes.ok = true;
    if (displayName.trim().length > 0) {
      const dnPayload: Record<string, Object> = { 'display_name': displayName.trim() };
      lastRes = await this.request(this.managementUrl, '/user/info/display-name', http.RequestMethod.POST, dnPayload);
    }
    if (lastRes.ok && username.trim().length > 0) {
      const unPayload: Record<string, Object> = { 'username': username.trim() };
      lastRes = await this.request(this.managementUrl, '/user/info/username', http.RequestMethod.POST, unPayload);
    }
    return lastRes;
  }

  public async changePassword(oldPassword: string, newPassword: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'old_password': oldPassword,
      'new_password': newPassword
    };
    return this.request(this.managementUrl, '/user/info/password/change', http.RequestMethod.POST, payload);
  }

  public async enableTotp(): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.managementUrl, '/user/2fa/totp/enable', http.RequestMethod.POST, empty);
  }

  public async confirmTotp(code: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'code': code };
    return this.request(this.managementUrl, '/user/2fa/totp/confirm', http.RequestMethod.POST, payload);
  }

  public async disableTotp(password: string, code: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'password': password, 'totp_code': code, 'code': code };
    return this.request(this.managementUrl, '/user/2fa/totp/disable', http.RequestMethod.POST, payload);
  }

  public async logout(): Promise<void> {
    if (this.token.length > 0) {
      const empty: Record<string, Object> = {};
      await this.request(this.managementUrl, '/token/deactivate', http.RequestMethod.POST, empty);
    }
    this.setToken('');
    this.tokenExpiresAt = 0;
  }

  // ==================== LOGIN SECURITY CERTIFICATE & REVERSE QR WEB LOGIN ====================
  public extractExchangeCode(raw: string): string {
    const trimmed = (raw || '').trim();
    const prefix = 'miniclassisland://exchange-certificate/';
    if (trimmed.toLowerCase().startsWith(prefix)) {
      return decodeURIComponent(trimmed.substring(prefix.length)).trim();
    }
    return trimmed;
  }

  public extractQrLoginCode(raw: string): string {
    const trimmed = (raw || '').trim();
    const prefix = 'miniclassisland://qr-login/';
    if (trimmed.toLowerCase().startsWith(prefix)) {
      return decodeURIComponent(trimmed.substring(prefix.length)).trim();
    }
    return trimmed;
  }

  public async redeemCertificate(codeOrUri: string): Promise<ApiResult<StoredLoginCert>> {
    const code = this.extractExchangeCode(codeOrUri);
    const payload: Record<string, Object> = { 'code': code, 'exchange_code': code };
    const r = await this.request(this.managementUrl, '/token/certificate/redeem', http.RequestMethod.POST, payload);
    const out = new ApiResult<StoredLoginCert>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    if (r.ok && r.data && r.data['certificate']) {
      const cert = r.data['certificate'] as StoredLoginCert;
      this.storedCertificate = cert;
      AppStorage.setOrCreate<string>('storedCertificateJson', JSON.stringify(cert));
      out.data = cert;
      const tok = String(r.data['token'] || '');
      if (tok.length > 0) {
        this.setToken(tok);
        const expIn = Number(r.data['expires_in'] || 3600);
        this.tokenExpiresAt = Math.floor(Date.now() / 1000) + expIn;
      }
    }
    return out;
  }

  public async requestSessionFromCertificate(ttlSeconds: number = 3600): Promise<ApiResult<Record<string, Object>>> {
    const cert = this.storedCertificate;
    if (!cert) {
      const err = new ApiResult<Record<string, Object>>();
      err.ok = false;
      err.error = '尚未保存登录安全证书';
      return err;
    }
    const clampedTtl = Math.max(60, Math.min(3600, ttlSeconds));
    const payload: Record<string, Object> = {
      'cert_id': cert.cert_id,
      'cert_secret': cert.cert_secret,
      'ttl': clampedTtl
    };
    const r = await this.request(this.managementUrl, '/token/certificate/session', http.RequestMethod.POST, payload);
    if (r.ok && r.data) {
      const tok = String(r.data['token'] || '');
      if (tok.length > 0) {
        this.setToken(tok);
        this.tokenExpiresAt = Number(r.data['expires_at'] || 0);
      }
    }
    return r;
  }

  public async rotateCertificateIfEligible(): Promise<ApiResult<StoredLoginCert>> {
    const cert = this.storedCertificate;
    if (!cert) {
      const err = new ApiResult<StoredLoginCert>();
      err.ok = false;
      err.error = '尚未保存登录安全证书';
      return err;
    }
    const payload: Record<string, Object> = {
      'cert_id': cert.cert_id,
      'cert_secret': cert.cert_secret
    };
    const r = await this.request(this.managementUrl, '/token/certificate/rotate', http.RequestMethod.POST, payload);
    const out = new ApiResult<StoredLoginCert>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    if (r.ok && r.data && r.data['certificate']) {
      const nextCert = r.data['certificate'] as StoredLoginCert;
      this.storedCertificate = nextCert;
      AppStorage.setOrCreate<string>('storedCertificateJson', JSON.stringify(nextCert));
      out.data = nextCert;
    }
    return out;
  }

  public async issueSecurityCertificate(
    password: string,
    totpCode: string,
    recoveryCode: string,
    deviceName: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'password': password,
      'device_name': deviceName || 'HarmonyOS 客户端'
    };
    if (totpCode.trim().length > 0) {
      payload['totp_code'] = totpCode.trim();
    }
    if (recoveryCode.trim().length > 0) {
      payload['recovery_code'] = recoveryCode.trim();
    }
    return this.request(this.managementUrl, '/user/certificate/issue', http.RequestMethod.POST, payload);
  }

  public async listSecurityCertificates(): Promise<ApiResult<Record<string, Object>[]>> {
    const r = await this.request(this.managementUrl, '/user/certificate/list', http.RequestMethod.GET);
    const out = new ApiResult<Record<string, Object>[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      out.data = (r.data['items'] as Record<string, Object>[]) || (r.data['certificates'] as Record<string, Object>[]) || [];
    }
    return out;
  }

  public async revokeSecurityCertificate(certId: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'cert_id': certId,
      'revoke_all': false
    };
    return this.request(
      this.managementUrl,
      '/user/certificate/revoke',
      http.RequestMethod.POST,
      payload
    );
  }

  public async authorizeWebQrLogin(codeOrUri: string): Promise<ApiResult<Record<string, Object>>> {
    const code = this.extractQrLoginCode(codeOrUri);
    const payload: Record<string, Object> = { 'code': code };
    if (this.storedCertificate !== null) {
      payload['cert_id'] = this.storedCertificate.cert_id;
      payload['cert_secret'] = this.storedCertificate.cert_secret;
    }
    return this.request(this.managementUrl, '/token/qr-login/authorize', http.RequestMethod.POST, payload);
  }

  // ==================== TENANT ACCOUNTS ====================
  public async listMyAccounts(): Promise<ApiResult<AccountSummary[]>> {
    const r = await this.request(this.managementUrl, '/account/list', http.RequestMethod.GET);
    const out = new ApiResult<AccountSummary[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const parsed = JSON.parse(r.rawText) as Record<string, AccountSummary[]>;
      out.data = parsed['accounts'] || [];
    }
    return out;
  }

  public async createTenantAccount(name: string, slug: string): Promise<ApiResult<AccountInfo>> {
    const payload: Record<string, Object> = { 'name': name, 'slug': slug };
    const r = await this.request(this.managementUrl, '/account/apply', http.RequestMethod.POST, payload);
    const out = new ApiResult<AccountInfo>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const parsed = JSON.parse(r.rawText) as Record<string, AccountInfo>;
      out.data = parsed['account'] || null;
    }
    return out;
  }

  public async getAccountInfo(accountId: number): Promise<ApiResult<AccountInfo>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/info`, http.RequestMethod.GET);
    const out = new ApiResult<AccountInfo>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      out.data = JSON.parse(r.rawText) as AccountInfo;
    }
    return out;
  }

  public async updateAccountInfo(
    accountId: number,
    name: string,
    slug: string,
    registrationMode?: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'name': name, 'slug': slug };
    if (registrationMode !== undefined && registrationMode.length > 0) {
      payload['registration_mode'] = registrationMode;
    }
    return this.request(this.managementUrl, `/account/${accountId}/info`, http.RequestMethod.PUT, payload);
  }

  public async regenerateApiKey(accountId: number): Promise<ApiResult<string>> {
    const empty: Record<string, Object> = {};
    const r = await this.request(this.managementUrl, `/account/${accountId}/apikey/regenerate`, http.RequestMethod.POST, empty);
    const out = new ApiResult<string>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      out.data = String(r.data['api_key'] || '');
    }
    return out;
  }

  public async getAccountQuotas(accountId: number): Promise<ApiResult<QuotaItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/quota`, http.RequestMethod.GET);
    const out = new ApiResult<QuotaItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, QuotaItem[]>;
      out.data = parsed['quotas'] || [];
    }
    return out;
  }

  public async deactivateAccount(accountId: number): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/deactivate`, http.RequestMethod.DELETE);
  }

  // ==================== MEMBERS & INVITATIONS ====================
  public async listMembers(accountId: number): Promise<ApiResult<MemberItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/access`, http.RequestMethod.GET);
    const out = new ApiResult<MemberItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, MemberItem[]>;
      out.data = parsed['members'] || [];
    }
    return out;
  }

  public async updateMemberRole(accountId: number, userId: number, role: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'role': role };
    return this.request(this.managementUrl, `/account/${accountId}/access/${userId}`, http.RequestMethod.PUT, payload);
  }

  public async removeMember(accountId: number, userId: number): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/access/${userId}`, http.RequestMethod.DELETE);
  }

  public async listInvitations(accountId: number): Promise<ApiResult<InvitationItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/invitations`, http.RequestMethod.GET);
    const out = new ApiResult<InvitationItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, InvitationItem[]>;
      out.data = parsed['invitations'] || [];
    }
    return out;
  }

  public async createInvitation(accountId: number, role: string, maxUses: number): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'role': role, 'max_uses': maxUses };
    return this.request(this.managementUrl, `/account/${accountId}/invitations`, http.RequestMethod.POST, payload);
  }

  public async revokeInvitation(accountId: number, invId: number): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/invitations/${invId}`, http.RequestMethod.DELETE);
  }

  public async acceptInvitation(code: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'code': code };
    return this.request(this.managementUrl, '/account/invitation/accept', http.RequestMethod.POST, payload);
  }

  // ==================== 7 PROFILE RESOURCES & VERSION HISTORY ====================
  public async listResources(accountId: number | string, resourceType: string): Promise<ApiResult<ResourceItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/${resourceType}/list`, http.RequestMethod.GET);
    const out = new ApiResult<ResourceItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, ResourceItem[]>;
      out.data = parsed['resources'] || [];
    }
    return out;
  }

  public async readResourceRaw(
    accountId: number | string,
    resourceType: string,
    resourceName: string
  ): Promise<ApiResult<string>> {
    return this.getRawJson(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/${encodeURIComponent(resourceName)}.json`
    );
  }

  public async createResource(
    accountId: number | string,
    resourceType: string,
    resourceName: string,
    content: string
  ): Promise<ApiResult<ResourceItem>> {
    let parsedContent: Record<string, Object> = {};
    try {
      parsedContent = JSON.parse(content) as Record<string, Object>;
    } catch (_e) {
      parsedContent = {};
    }
    const payload: Record<string, Object> = {
      'name': resourceName,
      'resource_name': resourceName,
      'content': parsedContent
    };
    const r = await this.request(this.managementUrl, `/account/${accountId}/${resourceType}/create`, http.RequestMethod.POST, payload);
    const out = new ApiResult<ResourceItem>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, ResourceItem>;
      out.data = parsed['resource'] || null;
    }
    return out;
  }

  public async writeResource(
    accountId: number | string,
    resourceType: string,
    resourceName: string,
    content: string
  ): Promise<ApiResult<ResourceItem>> {
    let parsedContent: Record<string, Object> = {};
    try {
      parsedContent = JSON.parse(content) as Record<string, Object>;
    } catch (_e) {
      parsedContent = {};
    }
    const payload: Record<string, Object> = { 'content': parsedContent };
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/${encodeURIComponent(resourceName)}/write`,
      http.RequestMethod.PUT,
      payload
    );
    const out = new ApiResult<ResourceItem>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, ResourceItem>;
      out.data = parsed['resource'] || null;
    }
    return out;
  }

  public async deleteResource(accountId: number | string, resourceType: string, resourceName: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/${encodeURIComponent(resourceName)}/deleteData`,
      http.RequestMethod.DELETE
    );
  }

  public async listResourceHistory(
    accountId: number | string,
    resourceType: string,
    resourceName: string
  ): Promise<ApiResult<ResourceVersionItem[]>> {
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/${encodeURIComponent(resourceName)}/history`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<ResourceVersionItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      out.data = (r.data['versions'] as ResourceVersionItem[]) || [];
    }
    return out;
  }

  public async readResourceHistoryVersion(
    accountId: number | string,
    resourceType: string,
    resourceName: string,
    version: number
  ): Promise<ApiResult<ResourceVersionItem>> {
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/${encodeURIComponent(resourceName)}/history/${version}`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<ResourceVersionItem>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      out.data = JSON.parse(r.rawText) as ResourceVersionItem;
    }
    return out;
  }

  public async encodePasswordCredential(accountId: number | string, password: string): Promise<ApiResult<string>> {
    const payload: Record<string, Object> = { 'raw': password, 'password': password };
    const r = await this.request(this.managementUrl, `/account/${accountId}/credentials/encode`, http.RequestMethod.POST, payload);
    const out = new ApiResult<string>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      out.data = String(r.data['credential'] || '');
    }
    return out;
  }

  public async getManagementPresetJson(accountId: number | string): Promise<ApiResult<string>> {
    return this.getRawJson(this.managementUrl, `/account/${accountId}/ManagementPreset.json`);
  }

  // ==================== CLIENTS & REMOTE CONTROL ====================
  public async listClients(accountId: number): Promise<ApiResult<ClientRecord[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/client/list`, http.RequestMethod.GET);
    const out = new ApiResult<ClientRecord[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, ClientRecord[]>;
      out.data = parsed['clients'] || [];
    }
    return out;
  }

  public async updateClient(
    accountId: number,
    uid: string,
    displayName: string,
    clientId: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'display_name': displayName,
      'client_id': clientId
    };
    return this.request(this.managementUrl, `/account/${accountId}/client/${encodeURIComponent(uid)}`, http.RequestMethod.PUT, payload);
  }

  public async deleteClient(accountId: number, uid: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/client/${encodeURIComponent(uid)}`, http.RequestMethod.DELETE);
  }

  public async clientActionPost(accountId: number, uid: string, actionPath: string): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/${actionPath}`,
      http.RequestMethod.POST,
      empty
    );
  }

  public async clientCommandGet(accountId: number, uid: string, cmdQuery: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/command/${cmdQuery}`,
      http.RequestMethod.GET
    );
  }

  public async batchClientOperation(
    accountId: number,
    clientUids: string[],
    action: string,
    profileMap?: Record<string, string>
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'client_uids': clientUids,
      'action': action
    };
    if (profileMap !== undefined) {
      payload['profile'] = profileMap;
    }
    return this.request(this.managementUrl, `/account/${accountId}/client/batch`, http.RequestMethod.POST, payload);
  }

  public async getDefaultProfile(accountId: number): Promise<ApiResult<ClientProfileRecord>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/default-profile`, http.RequestMethod.GET);
    const out = new ApiResult<ClientProfileRecord>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, ClientProfileRecord>;
      out.data = parsed['profile'] || null;
    }
    return out;
  }

  public async setDefaultProfile(accountId: number, profilePayload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/default-profile`, http.RequestMethod.PUT, profilePayload);
  }

  public async getClientProfile(accountId: number, uid: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/client/${encodeURIComponent(uid)}/profile`, http.RequestMethod.GET);
  }

  public async setClientProfile(
    accountId: number,
    uid: string,
    profilePayload: Record<string, Object>
  ): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/profile`,
      http.RequestMethod.PUT,
      profilePayload
    );
  }

  public async listConfigSnapshots(accountId: number, uid: string): Promise<ApiResult<ConfigSnapshotItem[]>> {
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/config-uploads`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<ConfigSnapshotItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, ConfigSnapshotItem[]>;
      out.data = parsed['uploads'] || [];
    }
    return out;
  }

  // ==================== NOTIFICATIONS ====================
  public async sendNotificationToClient(
    accountId: number,
    uid: string,
    payload: NotificationPayload
  ): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/command/send-notification`,
      http.RequestMethod.POST,
      payload as Object
    );
  }

  public async broadcastNotification(accountId: number, payload: NotificationPayload): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/broadcast/send-notification`,
      http.RequestMethod.POST,
      payload as Object
    );
  }

  // ==================== AUDIT LOGS ====================
  public async listAuditLogs(accountId: number, clientUid: string, eventFilter: string): Promise<ApiResult<AuditLogItem[]>> {
    let query = '?limit=200';
    if (clientUid.length > 0) {
      query += `&client_uid=${encodeURIComponent(clientUid)}`;
    }
    if (eventFilter.length > 0 && eventFilter !== 'all') {
      query += `&event=${encodeURIComponent(eventFilter)}`;
    }
    const r = await this.request(this.managementUrl, `/account/${accountId}/audit/list${query}`, http.RequestMethod.GET);
    const out = new ApiResult<AuditLogItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, AuditLogItem[]>;
      out.data = parsed['logs'] || [];
    }
    return out;
  }

  public async clearAuditLogs(accountId: number): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/audit/clear`, http.RequestMethod.DELETE);
  }

  // ==================== PAIRING & PRE-REGISTRATION ====================
  public async listPairingRequests(accountId: number, statusFilter: string): Promise<ApiResult<PairingRequestItem[]>> {
    const query = statusFilter === 'all' ? '' : `?status=${encodeURIComponent(statusFilter)}`;
    const r = await this.request(this.managementUrl, `/account/${accountId}/pairing/list${query}`, http.RequestMethod.GET);
    const out = new ApiResult<PairingRequestItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, PairingRequestItem[]>;
      out.data = parsed['requests'] || [];
    }
    return out;
  }

  public async approvePairingRequest(
    accountId: number,
    reqId: number,
    profilePayload: Record<string, Object>
  ): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/pairing/${reqId}/approve`,
      http.RequestMethod.POST,
      profilePayload
    );
  }

  public async rejectPairingRequest(accountId: number, reqId: number): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.managementUrl, `/account/${accountId}/pairing/${reqId}/reject`, http.RequestMethod.POST, empty);
  }

  public async listPreRegItems(accountId: number): Promise<ApiResult<PreRegItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/pre-registration/list`, http.RequestMethod.GET);
    const out = new ApiResult<PreRegItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, PreRegItem[]>;
      out.data = parsed['items'] || [];
    }
    return out;
  }

  public async createPreRegItem(accountId: number, payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/pre-registration/create`, http.RequestMethod.POST, payload);
  }

  public async batchCreatePreRegItems(
    accountId: number,
    items: Record<string, Object>[]
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'items': items };
    return this.request(this.managementUrl, `/account/${accountId}/pre-registration/batch`, http.RequestMethod.POST, payload);
  }

  public async updatePreRegItem(
    accountId: number,
    itemId: number,
    payload: Record<string, Object>
  ): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/pre-registration/${itemId}`, http.RequestMethod.PUT, payload);
  }

  public async deletePreRegItem(accountId: number, itemId: number): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/pre-registration/${itemId}`, http.RequestMethod.DELETE);
  }

  public async getPreRegPresetJson(accountId: number, itemId: number): Promise<ApiResult<string>> {
    return this.getRawJson(this.managementUrl, `/account/${accountId}/pre-registration/${itemId}/preset.json`);
  }

  // ==================== SUPERADMIN GOVERNANCE (ADMIN API) ====================
  public async getGlobalStats(): Promise<ApiResult<GlobalStats>> {
    const r = await this.request(this.adminUrl, '/stats', http.RequestMethod.GET);
    const out = new ApiResult<GlobalStats>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      out.data = JSON.parse(r.rawText) as GlobalStats;
    }
    return out;
  }

  public async listGlobalUsers(search: string): Promise<ApiResult<AdminUserItem[]>> {
    const q = search.trim().length > 0 ? `?limit=100&search=${encodeURIComponent(search.trim())}` : '?limit=100';
    const r = await this.request(this.adminUrl, `/user${q}`, http.RequestMethod.GET);
    const out = new ApiResult<AdminUserItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, AdminUserItem[]>;
      out.data = parsed['users'] || [];
    }
    return out;
  }

  public async createGlobalUser(payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, '/user', http.RequestMethod.POST, payload);
  }

  public async updateGlobalUser(userId: number, payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/user/${userId}`, http.RequestMethod.PUT, payload);
  }

  public async deleteGlobalUser(userId: number): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/user/${userId}`, http.RequestMethod.DELETE);
  }

  public async resetGlobalUserPassword(userId: number, newPassword: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'new_password': newPassword };
    return this.request(this.adminUrl, `/user/${userId}/reset-password`, http.RequestMethod.POST, payload);
  }

  public async disableGlobalUserTotp(userId: number): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.adminUrl, `/user/${userId}/disable-totp`, http.RequestMethod.POST, empty);
  }

  public async listPendingUsers(): Promise<ApiResult<AdminUserItem[]>> {
    const r = await this.request(this.adminUrl, '/user/pending?limit=100', http.RequestMethod.GET);
    const out = new ApiResult<AdminUserItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, AdminUserItem[]>;
      out.data = parsed['users'] || [];
    }
    return out;
  }

  public async approvePendingUser(userId: number): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.adminUrl, `/user/${userId}/approve`, http.RequestMethod.POST, empty);
  }

  public async rejectPendingUser(userId: number): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.adminUrl, `/user/${userId}/reject`, http.RequestMethod.POST, empty);
  }

  public async listGlobalAccounts(search: string): Promise<ApiResult<AdminAccountItem[]>> {
    const q = search.trim().length > 0 ? `?limit=100&search=${encodeURIComponent(search.trim())}` : '?limit=100';
    const r = await this.request(this.adminUrl, `/account${q}`, http.RequestMethod.GET);
    const out = new ApiResult<AdminAccountItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, AdminAccountItem[]>;
      out.data = parsed['accounts'] || [];
    }
    return out;
  }

  public async createGlobalAccount(payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, '/account', http.RequestMethod.POST, payload);
  }

  public async updateGlobalAccount(accountId: number, payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/account/${accountId}`, http.RequestMethod.PUT, payload);
  }

  public async deleteGlobalAccount(accountId: number): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/account/${accountId}`, http.RequestMethod.DELETE);
  }

  public async getGlobalAccountQuotas(accountId: number): Promise<ApiResult<QuotaItem[]>> {
    const r = await this.request(this.adminUrl, `/account/${accountId}/quotas`, http.RequestMethod.GET);
    const out = new ApiResult<QuotaItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const parsed = JSON.parse(r.rawText) as Record<string, QuotaItem[]>;
      out.data = parsed['quotas'] || [];
    }
    return out;
  }

  public async updateGlobalAccountQuotas(
    accountId: number,
    quotas: Record<string, number>
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'quotas': quotas };
    return this.request(this.adminUrl, `/account/${accountId}/quotas`, http.RequestMethod.PUT, payload);
  }

  public async getSystemSettings(): Promise<ApiResult<Record<string, string>>> {
    const r = await this.request(this.adminUrl, '/settings', http.RequestMethod.GET);
    const out = new ApiResult<Record<string, string>>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const parsed = JSON.parse(r.rawText) as Record<string, Record<string, string>>;
      out.data = parsed['settings'] || {};
    }
    return out;
  }

  public async updateSystemSettings(settings: Record<string, string>): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'settings': settings };
    return this.request(this.adminUrl, '/settings', http.RequestMethod.PUT, payload);
  }
}
