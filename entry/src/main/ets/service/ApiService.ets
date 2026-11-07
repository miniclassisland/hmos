import { http } from '@kit.NetworkKit';
import {
  UserInfo,
  AccountSummary,
  AccountInfo,
  QuotaItem,
  MemberItem,
  InvitationItem,
  ResourceItem,
  ResourceVersionItem,
  ClientRecord,
  ClientProfileRecord,
  PairingRequestItem,
  PreRegItem,
  AuditLogItem,
  ConfigSnapshotItem,
  NotificationPayload,
  GlobalStats,
  AdminUserItem,
  AdminAccountItem,
  StoredLoginCert,
  TicketItem,
  TicketMessageItem
} from '../model/Types';

export class ApiResult<T> {
  public ok: boolean = false;
  public status: number = 0;
  public data: T | null = null;
  public error: string = '';
  public rawText: string = '';
  public isOobe: boolean = false;
}

export class LoginResultData {
  public token: string = '';
  public expires_at: number = 0;
  public totp_required: boolean = false;
  public totp_session: string = '';
  public user: UserInfo = {
    id: '',
    username: '',
    email: '',
    display_name: '',
    role: 'user',
    role_code: 'user',
    status: 'active',
    is_active: true,
    can_create_account: true,
    totp_enabled: false
  };
}

export class ApiService {
  private static instance: ApiService = new ApiService();

  public managementUrl: string = 'https://api.miniclassisland.com';
  public adminUrl: string = 'https://admin.miniclassisland.com/api';
  public token: string = '';
  public tokenExpiresAt: number = 0;
  public storedCertificate: StoredLoginCert | null = null;
  private persistentInitialized: boolean = false;

  public static get(): ApiService {
    return ApiService.instance;
  }

  public initPersistentAuth(): void {
    if (this.persistentInitialized) {
      return;
    }
    this.persistentInitialized = true;
    try {
      PersistentStorage.persistProp('managementUrl', 'https://api.miniclassisland.com');
      PersistentStorage.persistProp('adminUrl', 'https://admin.miniclassisland.com/api');
      PersistentStorage.persistProp('authToken', '');
      PersistentStorage.persistProp('tokenExpiresAt', 0);
      PersistentStorage.persistProp('storedCertificateJson', '');
      PersistentStorage.persistProp('savedUserJson', '');
      PersistentStorage.persistProp('savedAccountsJson', '');
      PersistentStorage.persistProp('currentAccountId', '');
      PersistentStorage.persistProp('currentAccountName', '');
      PersistentStorage.persistProp('currentAccountSlug', '');
      PersistentStorage.persistProp('themeMode', 'light');
    } catch (_e) {
      // Ignore if PersistentStorage is called outside UI context
    }

    const savedMgmt = AppStorage.get<string>('managementUrl') || '';
    const savedAdmin = AppStorage.get<string>('adminUrl') || '';
    if (savedMgmt.trim().length > 0) {
      this.managementUrl = savedMgmt.trim();
    }
    if (savedAdmin.trim().length > 0) {
      this.adminUrl = savedAdmin.trim();
    }
    this.token = AppStorage.get<string>('authToken') || '';
    this.tokenExpiresAt = AppStorage.get<number>('tokenExpiresAt') || 0;
    const certRaw = AppStorage.get<string>('storedCertificateJson') || '';
    if (certRaw.trim().length > 0) {
      try {
        this.storedCertificate = JSON.parse(certRaw) as StoredLoginCert;
      } catch (_e) {
        this.storedCertificate = null;
      }
    }
  }

  public saveAuthSession(
    token: string,
    user: UserInfo | null,
    accounts: AccountSummary[],
    accountId: string,
    accountName: string,
    accountSlug: string
  ): void {
    this.token = token;
    AppStorage.setOrCreate<string>('authToken', token);
    AppStorage.setOrCreate<number>('tokenExpiresAt', this.tokenExpiresAt);
    AppStorage.setOrCreate<string>('managementUrl', this.managementUrl);
    AppStorage.setOrCreate<string>('adminUrl', this.adminUrl);
    if (this.storedCertificate !== null) {
      AppStorage.setOrCreate<string>('storedCertificateJson', JSON.stringify(this.storedCertificate));
    } else {
      AppStorage.setOrCreate<string>('storedCertificateJson', '');
    }
    if (user !== null) {
      AppStorage.setOrCreate<string>('savedUserJson', JSON.stringify(user));
    } else {
      AppStorage.setOrCreate<string>('savedUserJson', '');
    }
    AppStorage.setOrCreate<string>('savedAccountsJson', JSON.stringify(accounts || []));
    AppStorage.setOrCreate<string>('currentAccountId', accountId || '');
    AppStorage.setOrCreate<string>('currentAccountName', accountName || '');
    AppStorage.setOrCreate<string>('currentAccountSlug', accountSlug || '');
  }

  public clearAuthSession(): void {
    this.token = '';
    this.tokenExpiresAt = 0;
    AppStorage.setOrCreate<string>('authToken', '');
    AppStorage.setOrCreate<number>('tokenExpiresAt', 0);
    AppStorage.setOrCreate<string>('savedUserJson', '');
    AppStorage.setOrCreate<string>('savedAccountsJson', '');
    AppStorage.setOrCreate<string>('currentAccountId', '');
    AppStorage.setOrCreate<string>('currentAccountName', '');
    AppStorage.setOrCreate<string>('currentAccountSlug', '');
  }

  public setEndpoints(mgmt: string, adm: string): void {
    const cleanMgmt = mgmt.trim().replace(/\/+$/, '');
    const cleanAdm = adm.trim().replace(/\/+$/, '');
    if (cleanMgmt.length > 0) {
      this.managementUrl = cleanMgmt;
      AppStorage.setOrCreate<string>('managementUrl', cleanMgmt);
    }
    if (cleanAdm.length > 0) {
      this.adminUrl = cleanAdm;
      AppStorage.setOrCreate<string>('adminUrl', cleanAdm);
    }
  }

  private unwrapArray<T>(rawText: string, keys: string[]): T[] {
    try {
      const parsed: Object = JSON.parse(rawText);
      if (Array.isArray(parsed)) {
        return parsed as T[];
      }
      const obj = parsed as Record<string, Object>;
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        if (obj[k] !== undefined && Array.isArray(obj[k])) {
          return obj[k] as T[];
        }
      }
    } catch (_e) {
    }
    return [];
  }

  private async request(
    baseUrl: string,
    path: string,
    method: http.RequestMethod,
    bodyObj?: Object
  ): Promise<ApiResult<Record<string, Object>>> {
    const res = new ApiResult<Record<string, Object>>();
    const httpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };
      if (this.token.length > 0) {
        headers['Authorization'] = `Bearer ${this.token}`;
      }

      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 15000
      };
      if (bodyObj !== undefined) {
        options.extraData = typeof bodyObj === 'string' ? bodyObj : JSON.stringify(bodyObj);
      }

      const fullUrl = `${baseUrl}${path}`;
      const response = await httpRequest.request(fullUrl, options);
      res.status = response.responseCode;
      res.rawText = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result || {});

      if (res.status === 425) {
        res.isOobe = true;
        res.error = '系统尚未初始化，请完成首次引导配置';
        return res;
      }

      if (res.status >= 200 && res.status < 300) {
        res.ok = true;
        if (res.rawText.trim().length > 0) {
          try {
            res.data = JSON.parse(res.rawText) as Record<string, Object>;
          } catch (_e) {
            res.data = {};
          }
        } else {
          res.data = {};
        }
      } else {
        res.ok = false;
        try {
          const errJson = JSON.parse(res.rawText) as Record<string, Object>;
          res.error = String(errJson['error'] || errJson['message'] || errJson['detail'] || `请求失败 (${res.status})`);
        } catch (_e) {
          res.error = `请求失败 (${res.status})`;
        }
      }
    } catch (err) {
      res.ok = false;
      res.error = `网络连接失败: ${JSON.stringify(err)}`;
    } finally {
      httpRequest.destroy();
    }
    return res;
  }

  public async getRawJson(baseUrl: string, path: string): Promise<ApiResult<string>> {
    const r = await this.request(baseUrl, path, http.RequestMethod.GET);
    const out = new ApiResult<string>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    out.rawText = r.rawText;
    out.data = r.rawText;
    return out;
  }

  // ==================== OOBE & AUTH ====================
  public async verifyOobePasscode(code: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'passcode': code };
    return this.request(this.managementUrl, '/oobe/verify', http.RequestMethod.POST, payload);
  }

  public async completeOobeSetup(payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, '/oobe/setup', http.RequestMethod.POST, payload);
  }

  public async checkMailAvailability(email: string): Promise<ApiResult<boolean>> {
    const r = await this.request(
      this.managementUrl,
      `/mail/availability?email=${encodeURIComponent(email)}`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<boolean>();
    out.ok = r.ok;
    out.status = r.status;
    out.isOobe = r.isOobe;
    out.error = r.error;
    if (r.ok && r.data) {
      out.data = Boolean(r.data['available']);
    }
    return out;
  }

  public async login(identifier: string, password: string, useAdminEndpoint: boolean = false): Promise<ApiResult<LoginResultData>> {
    const base = useAdminEndpoint ? this.adminUrl : this.managementUrl;
    const payload: Record<string, Object> = {
      'username': identifier,
      'email': identifier,
      'password': password
    };
    const r = await this.request(base, '/token', http.RequestMethod.POST, payload);
    const out = new ApiResult<LoginResultData>();
    out.ok = r.ok;
    out.status = r.status;
    out.isOobe = r.isOobe;
    out.error = r.error;
    if (r.ok && r.data) {
      const d = new LoginResultData();
      d.totp_required = Boolean(r.data['totp_required']);
      d.totp_session = String(r.data['totp_session'] || '');
      d.token = String(r.data['token'] || r.data['access_token'] || '');
      d.expires_at = Number(r.data['expires_at'] || 0);
      if (r.data['user']) {
        const uObj = r.data['user'] as Record<string, Object>;
        const roleVal = String(uObj['role_code'] || uObj['role'] || 'user');
        d.user = {
          id: String(uObj['id'] || ''),
          username: String(uObj['username'] || ''),
          email: String(uObj['email'] || ''),
          display_name: String(uObj['display_name'] || uObj['username'] || ''),
          role: roleVal,
          role_code: roleVal,
          status: String(uObj['status'] || 'active'),
          is_active: uObj['is_active'] !== false,
          can_create_account: uObj['can_create_account'] !== false,
          totp_enabled: Boolean(uObj['totp_enabled'])
        };
      }
      if (d.token.length > 0) {
        this.token = d.token;
        this.tokenExpiresAt = d.expires_at;
        AppStorage.setOrCreate<string>('authToken', d.token);
        AppStorage.setOrCreate<number>('tokenExpiresAt', d.expires_at);
      }
      out.data = d;
    }
    return out;
  }

  public async registerUser(username: string, email: string, password: string, displayName: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'username': username,
      'email': email,
      'password': password,
      'display_name': displayName
    };
    return this.request(this.managementUrl, '/user/register', http.RequestMethod.POST, payload);
  }

  public async verifyTotp(totpSession: string, code: string, useAdminEndpoint: boolean = false): Promise<ApiResult<LoginResultData>> {
    const base = useAdminEndpoint ? this.adminUrl : this.managementUrl;
    const payload: Record<string, Object> = {
      'totp_session': totpSession,
      'code': code
    };
    const r = await this.request(base, '/token/2fa', http.RequestMethod.POST, payload);
    const out = new ApiResult<LoginResultData>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const d = new LoginResultData();
      d.token = String(r.data['token'] || r.data['access_token'] || '');
      d.expires_at = Number(r.data['expires_at'] || 0);
      if (r.data['user']) {
        const uObj = r.data['user'] as Record<string, Object>;
        const roleVal = String(uObj['role_code'] || uObj['role'] || 'user');
        d.user = {
          id: String(uObj['id'] || ''),
          username: String(uObj['username'] || ''),
          email: String(uObj['email'] || ''),
          display_name: String(uObj['display_name'] || uObj['username'] || ''),
          role: roleVal,
          role_code: roleVal,
          is_active: uObj['is_active'] !== false,
          can_create_account: uObj['can_create_account'] !== false,
          totp_enabled: Boolean(uObj['totp_enabled'])
        };
      }
      if (d.token.length > 0) {
        this.token = d.token;
        this.tokenExpiresAt = d.expires_at;
        AppStorage.setOrCreate<string>('authToken', d.token);
        AppStorage.setOrCreate<number>('tokenExpiresAt', d.expires_at);
      }
      out.data = d;
    }
    return out;
  }

  public async recoverTotp(totpSession: string, recoveryCode: string, useAdminEndpoint: boolean = false): Promise<ApiResult<LoginResultData>> {
    const base = useAdminEndpoint ? this.adminUrl : this.managementUrl;
    const payload: Record<string, Object> = {
      'totp_session': totpSession,
      'recovery_code': recoveryCode
    };
    const r = await this.request(base, '/token/2fa/recover', http.RequestMethod.POST, payload);
    const out = new ApiResult<LoginResultData>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const d = new LoginResultData();
      d.token = String(r.data['token'] || r.data['access_token'] || '');
      d.expires_at = Number(r.data['expires_at'] || 0);
      if (r.data['user']) {
        const uObj = r.data['user'] as Record<string, Object>;
        const roleVal = String(uObj['role_code'] || uObj['role'] || 'user');
        d.user = {
          id: String(uObj['id'] || ''),
          username: String(uObj['username'] || ''),
          email: String(uObj['email'] || ''),
          display_name: String(uObj['display_name'] || uObj['username'] || ''),
          role: roleVal,
          role_code: roleVal,
          is_active: uObj['is_active'] !== false,
          can_create_account: uObj['can_create_account'] !== false,
          totp_enabled: Boolean(uObj['totp_enabled'])
        };
      }
      if (d.token.length > 0) {
        this.token = d.token;
        this.tokenExpiresAt = d.expires_at;
        AppStorage.setOrCreate<string>('authToken', d.token);
        AppStorage.setOrCreate<number>('tokenExpiresAt', d.expires_at);
      }
      out.data = d;
    }
    return out;
  }

  public async getProfile(): Promise<ApiResult<UserInfo>> {
    const r = await this.request(this.managementUrl, '/user/info', http.RequestMethod.GET);
    const out = new ApiResult<UserInfo>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    if (r.ok && r.data) {
      const raw = (r.data['user'] || r.data) as Record<string, Object>;
      const roleVal = String(raw['role_code'] || raw['role'] || 'user');
      out.data = {
        id: String(raw['id'] || ''),
        username: String(raw['username'] || ''),
        email: String(raw['email'] || ''),
        display_name: String(raw['display_name'] || raw['username'] || ''),
        role: roleVal,
        role_code: roleVal,
        status: String(raw['status'] || 'active'),
        is_active: raw['is_active'] !== false,
        can_create_account: raw['can_create_account'] !== false,
        totp_enabled: Boolean(raw['totp_enabled'])
      };
    }
    return out;
  }

  public async updateProfile(displayName: string, email: string, username: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'display_name': displayName,
      'email': email,
      'username': username
    };
    return this.request(this.managementUrl, '/user/info', http.RequestMethod.POST, payload);
  }

  public async changePassword(oldPassword: string, newPassword: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'old_password': oldPassword,
      'new_password': newPassword
    };
    return this.request(this.managementUrl, '/user/password', http.RequestMethod.POST, payload);
  }

  public async enableTotp(): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.managementUrl, '/user/2fa/enable', http.RequestMethod.POST, empty);
  }

  public async confirmTotp(code: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'code': code };
    return this.request(this.managementUrl, '/user/2fa/confirm', http.RequestMethod.POST, payload);
  }

  public async disableTotp(password: string, code: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'password': password,
      'code': code,
      'totp_code': code
    };
    return this.request(this.managementUrl, '/user/2fa/disable', http.RequestMethod.POST, payload);
  }

  // ==================== LOGIN SECURITY CERTIFICATES & REVERSE QR WEB LOGIN ====================
  public async issueSecurityCertificate(
    password: string,
    totpCode: string,
    recoveryCode: string,
    deviceName: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'password': password,
      'totp_code': totpCode,
      'recovery_code': recoveryCode,
      'device_name': deviceName || 'HarmonyOS 客户端'
    };
    return this.request(this.managementUrl, '/user/certificate/issue', http.RequestMethod.POST, payload);
  }

  public async listSecurityCertificates(): Promise<ApiResult<Record<string, Object>[]>> {
    const r = await this.request(this.managementUrl, '/user/certificate/list', http.RequestMethod.GET);
    const out = new ApiResult<Record<string, Object>[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      out.data = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'certificates']);
    }
    return out;
  }

  public async revokeSecurityCertificate(certId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/user/certificate/revoke?cert_id=${encodeURIComponent(certId)}`,
      http.RequestMethod.DELETE
    );
  }

  public async redeemCertificate(rawCodeOrLink: string): Promise<ApiResult<StoredLoginCert>> {
    let code = rawCodeOrLink.trim();
    const prefix = 'miniclassisland://exchange-certificate/';
    if (code.toLowerCase().startsWith(prefix)) {
      code = code.substring(prefix.length).trim();
    } else if (code.toLowerCase().startsWith('miniclassisland://exchange-certificate')) {
      const qIdx = code.indexOf('code=');
      if (qIdx >= 0) {
        code = code.substring(qIdx + 5).split('&')[0];
      }
    }
    const qMarkIdx = code.indexOf('?');
    if (qMarkIdx >= 0) {
      code = code.substring(0, qMarkIdx).trim();
    }
    while (code.endsWith('/')) {
      code = code.substring(0, code.length - 1).trim();
    }
    const payload: Record<string, Object> = {
      'code': code,
      'exchange_code': code,
      'device_name': 'HarmonyOS 客户端'
    };
    const r = await this.request(this.managementUrl, '/token/certificate/redeem', http.RequestMethod.POST, payload);
    const out = new ApiResult<StoredLoginCert>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const certObj = (r.data['certificate'] || r.data) as Record<string, Object>;
      const cert: StoredLoginCert = {
        cert_id: String(certObj['cert_id'] || certObj['id'] || ''),
        cert_secret: String(certObj['cert_secret'] || certObj['secret'] || ''),
        generation: Number(certObj['generation'] ?? 0),
        max_generation: Number(certObj['max_generation'] || 12),
        expires_at: Number(certObj['expires_at'] || 0),
        device_name: String(certObj['device_name'] || 'HarmonyOS 客户端')
      };
      this.storedCertificate = cert;
      AppStorage.setOrCreate<string>('storedCertificateJson', JSON.stringify(cert));
      const directTok = String(r.data['token'] || r.data['access_token'] || '');
      if (directTok.length > 0) {
        this.token = directTok;
        this.tokenExpiresAt = Number(r.data['expires_at'] || 0);
        AppStorage.setOrCreate<string>('authToken', directTok);
        AppStorage.setOrCreate<number>('tokenExpiresAt', this.tokenExpiresAt);
      }
      out.data = cert;
    }
    return out;
  }

  public async requestSessionFromCertificate(ttlSeconds: number = 3600): Promise<ApiResult<LoginResultData>> {
    const out = new ApiResult<LoginResultData>();
    if (!this.storedCertificate) {
      out.ok = false;
      out.error = '本地未存储登录安全证书';
      return out;
    }
    const cappedTtl = Math.min(3600, Math.max(60, ttlSeconds));
    const payload: Record<string, Object> = {
      'cert_id': this.storedCertificate.cert_id,
      'cert_secret': this.storedCertificate.cert_secret,
      'ttl_seconds': cappedTtl
    };
    const r = await this.request(this.managementUrl, '/token/certificate/session', http.RequestMethod.POST, payload);
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const d = new LoginResultData();
      d.token = String(r.data['token'] || r.data['access_token'] || '');
      d.expires_at = Number(r.data['expires_at'] || 0);
      if (r.data['user']) {
        const uObj = r.data['user'] as Record<string, Object>;
        const roleVal = String(uObj['role_code'] || uObj['role'] || 'user');
        d.user = {
          id: String(uObj['id'] || ''),
          username: String(uObj['username'] || ''),
          email: String(uObj['email'] || ''),
          display_name: String(uObj['display_name'] || uObj['username'] || ''),
          role: roleVal,
          role_code: roleVal,
          is_active: uObj['is_active'] !== false,
          can_create_account: uObj['can_create_account'] !== false,
          totp_enabled: Boolean(uObj['totp_enabled'])
        };
      }
      if (d.token.length > 0) {
        this.token = d.token;
        this.tokenExpiresAt = d.expires_at;
        AppStorage.setOrCreate<string>('authToken', d.token);
        AppStorage.setOrCreate<number>('tokenExpiresAt', d.expires_at);
      }
      out.data = d;
    }
    return out;
  }

  public async rotateCertificateIfEligible(): Promise<ApiResult<StoredLoginCert>> {
    const out = new ApiResult<StoredLoginCert>();
    if (!this.storedCertificate) {
      out.ok = false;
      out.error = '本地未存储登录安全证书';
      return out;
    }
    const payload: Record<string, Object> = {
      'cert_id': this.storedCertificate.cert_id,
      'cert_secret': this.storedCertificate.cert_secret
    };
    const r = await this.request(this.managementUrl, '/token/certificate/rotate', http.RequestMethod.POST, payload);
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const certObj = (r.data['certificate'] || r.data) as Record<string, Object>;
      const cert: StoredLoginCert = {
        cert_id: String(certObj['cert_id'] || this.storedCertificate.cert_id),
        cert_secret: String(certObj['cert_secret'] || certObj['secret'] || this.storedCertificate.cert_secret),
        generation: Number(certObj['generation'] ?? (this.storedCertificate.generation + 1)),
        max_generation: Number(certObj['max_generation'] || 12),
        expires_at: Number(certObj['expires_at'] || 0),
        device_name: String(certObj['device_name'] || this.storedCertificate.device_name)
      };
      this.storedCertificate = cert;
      AppStorage.setOrCreate<string>('storedCertificateJson', JSON.stringify(cert));
      out.data = cert;
    }
    return out;
  }

  public async authorizeWebQrLogin(rawCodeOrLink: string): Promise<ApiResult<Record<string, Object>>> {
    let code = rawCodeOrLink.trim();
    const prefix = 'miniclassisland://qr-login/';
    if (code.toLowerCase().startsWith(prefix)) {
      code = code.substring(prefix.length).trim();
    } else if (code.toLowerCase().startsWith('miniclassisland://qr-login')) {
      const qIdx = code.indexOf('code=');
      if (qIdx >= 0) {
        code = code.substring(qIdx + 5).split('&')[0];
      }
    }
    const qMarkIdx = code.indexOf('?');
    if (qMarkIdx >= 0) {
      code = code.substring(0, qMarkIdx).trim();
    }
    while (code.endsWith('/')) {
      code = code.substring(0, code.length - 1).trim();
    }
    const payload: Record<string, Object> = {
      'code': code,
      'qr_code': code
    };
    if (this.storedCertificate) {
      payload['cert_id'] = this.storedCertificate.cert_id;
      payload['cert_secret'] = this.storedCertificate.cert_secret;
    }
    return this.request(this.managementUrl, '/token/qr-login/authorize', http.RequestMethod.POST, payload);
  }

  // ==================== SUPPORT TICKETS (MY TICKETS) ====================
  public async listMyTickets(statusFilter: string): Promise<ApiResult<TicketItem[]>> {
    const q = statusFilter && statusFilter !== 'all' ? `?status=${encodeURIComponent(statusFilter)}` : '';
    const r = await this.request(this.managementUrl, `/ticket/list${q}`, http.RequestMethod.GET);
    const out = new ApiResult<TicketItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      out.data = this.unwrapArray<TicketItem>(r.rawText, ['items', 'tickets']);
    }
    return out;
  }

  public async createTicket(
    subject: string,
    category: string,
    priority: string,
    content: string,
    accountId?: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'subject': subject,
      'category': category,
      'priority': priority,
      'content': content
    };
    if (accountId && accountId.length > 0) {
      payload['account_id'] = accountId;
    }
    return this.request(this.managementUrl, '/ticket', http.RequestMethod.POST, payload);
  }

  public async getTicketDetail(ticketId: string): Promise<ApiResult<TicketItem>> {
    const r = await this.request(this.managementUrl, `/ticket/${encodeURIComponent(ticketId)}`, http.RequestMethod.GET);
    const out = new ApiResult<TicketItem>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const raw = (r.data['ticket'] || r.data) as Record<string, Object>;
      out.data = {
        id: String(raw['id'] || ticketId),
        ticket_no: String(raw['ticket_no'] || ''),
        subject: String(raw['subject'] || ''),
        category: String(raw['category'] || 'general'),
        priority: String(raw['priority'] || 'normal'),
        status: String(raw['status'] || 'open'),
        created_at: String(raw['created_at'] || ''),
        updated_at: String(raw['updated_at'] || ''),
        messages: (raw['messages'] || []) as TicketMessageItem[]
      };
    }
    return out;
  }

  public async replyTicket(ticketId: string, content: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'content': content };
    return this.request(this.managementUrl, `/ticket/${encodeURIComponent(ticketId)}/reply`, http.RequestMethod.POST, payload);
  }

  public async closeTicket(ticketId: string): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.managementUrl, `/ticket/${encodeURIComponent(ticketId)}/close`, http.RequestMethod.POST, empty);
  }

  // ==================== TENANT ACCOUNTS ====================
  public async listMyAccounts(): Promise<ApiResult<AccountSummary[]>> {
    const r = await this.request(this.managementUrl, '/account/list', http.RequestMethod.GET);
    const out = new ApiResult<AccountSummary[]>();
    out.ok = r.ok;
    out.status = r.status;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'accounts']);
      const list: AccountSummary[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        list.push({
          id: String(it['id'] || ''),
          name: String(it['name'] || ''),
          slug: String(it['slug'] || ''),
          api_key: String(it['api_key'] || ''),
          registration_mode: String(it['registration_mode'] || 'open'),
          is_active: it['is_active'] !== false,
          role: String(it['role'] || 'owner')
        });
      }
      out.data = list;
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
      const accObj = (r.data['account'] || r.data) as Record<string, Object>;
      out.data = {
        id: String(accObj['id'] || ''),
        name: String(accObj['name'] || name),
        slug: String(accObj['slug'] || slug),
        owner_id: String(accObj['owner_id'] || ''),
        api_key: String(accObj['api_key'] || ''),
        registration_mode: String(accObj['registration_mode'] || 'open'),
        is_active: accObj['is_active'] !== false
      };
    }
    return out;
  }

  public async getAccountInfo(accountId: string): Promise<ApiResult<AccountInfo>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/info`, http.RequestMethod.GET);
    const out = new ApiResult<AccountInfo>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const accObj = (r.data['account'] || r.data) as Record<string, Object>;
      out.data = {
        id: String(accObj['id'] || accountId),
        name: String(accObj['name'] || ''),
        slug: String(accObj['slug'] || ''),
        owner_id: String(accObj['owner_id'] || ''),
        api_key: String(accObj['api_key'] || ''),
        registration_mode: String(accObj['registration_mode'] || 'open'),
        is_active: accObj['is_active'] !== false
      };
    }
    return out;
  }

  public async updateAccountInfo(
    accountId: string,
    name: string,
    slug: string,
    registrationMode?: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'name': name, 'slug': slug };
    if (registrationMode !== undefined && registrationMode.length > 0) {
      payload['registration_mode'] = registrationMode;
    }
    return this.request(this.managementUrl, `/account/${accountId}/info`, http.RequestMethod.POST, payload);
  }

  public async regenerateApiKey(accountId: string): Promise<ApiResult<string>> {
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

  public async getAccountQuotas(accountId: string): Promise<ApiResult<QuotaItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/quota`, http.RequestMethod.GET);
    const out = new ApiResult<QuotaItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'quotas']);
      const list: QuotaItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const qk = String(it['quota_key'] || it['quota_type'] || '');
        const mv = Number(it['max_value'] ?? it['limit_value'] ?? 0);
        const cv = Number(it['current_value'] ?? 0);
        list.push({
          id: String(it['id'] || qk),
          quota_key: qk,
          quota_type: qk,
          max_value: mv,
          limit_value: mv,
          current_value: cv
        });
      }
      out.data = list;
    }
    return out;
  }

  public async deactivateAccount(accountId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/deactivate`, http.RequestMethod.DELETE);
  }

  // ==================== MEMBERS & INVITATIONS ====================
  public async listMembers(accountId: string): Promise<ApiResult<MemberItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/access`, http.RequestMethod.GET);
    const out = new ApiResult<MemberItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'members']);
      const list: MemberItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        list.push({
          id: String(it['id'] || ''),
          user_id: String(it['user_id'] || ''),
          username: String(it['username'] || ''),
          email: String(it['email'] || ''),
          display_name: String(it['display_name'] || it['username'] || ''),
          role: String(it['role'] || 'member'),
          joined_at: Number(it['joined_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async updateMemberRole(accountId: string, userId: string, role: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'user_id': userId, 'role': role };
    return this.request(this.managementUrl, `/account/${accountId}/access`, http.RequestMethod.POST, payload);
  }

  public async removeMember(accountId: string, userId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/access?user_id=${encodeURIComponent(userId)}`,
      http.RequestMethod.DELETE
    );
  }

  public async listInvitations(accountId: string): Promise<ApiResult<InvitationItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/invitations`, http.RequestMethod.GET);
    const out = new ApiResult<InvitationItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'invitations']);
      const list: InvitationItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        list.push({
          id: String(it['id'] || ''),
          code: String(it['code'] || ''),
          role: String(it['role'] || 'member'),
          max_uses: Number(it['max_uses'] || 1),
          used_count: Number(it['used_count'] || 0),
          expires_at: Number(it['expires_at'] || 0),
          created_at: Number(it['created_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async createInvitation(accountId: string, role: string, maxUses: number): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'role': role, 'max_uses': maxUses };
    return this.request(this.managementUrl, `/account/${accountId}/invitations`, http.RequestMethod.POST, payload);
  }

  public async revokeInvitation(accountId: string, invId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/invitations/${encodeURIComponent(invId)}`, http.RequestMethod.DELETE);
  }

  public async acceptInvitation(code: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'code': code };
    return this.request(this.managementUrl, '/account/invitation/accept', http.RequestMethod.POST, payload);
  }

  // ==================== 7 PROFILE RESOURCES & VERSION HISTORY ====================
  public async listResources(accountId: string, resourceType: string): Promise<ApiResult<ResourceItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/${resourceType}/list`, http.RequestMethod.GET);
    const out = new ApiResult<ResourceItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const list: ResourceItem[] = [];
      try {
        const parsed: Object = JSON.parse(r.rawText);
        const arr: Object[] = Array.isArray(parsed)
          ? (parsed as Object[])
          : (((parsed as Record<string, Object>)['items'] || (parsed as Record<string, Object>)['resources'] || []) as Object[]);
        for (let i = 0; i < arr.length; i++) {
          const elem = arr[i];
          if (typeof elem === 'string') {
            list.push({
              id: elem,
              account_id: accountId,
              resource_type: resourceType,
              resource_name: elem,
              version: 1,
              content: ''
            });
          } else if (elem && typeof elem === 'object') {
            const obj = elem as Record<string, Object>;
            const rName = String(obj['resource_name'] || obj['name'] || '');
            list.push({
              id: String(obj['id'] || rName),
              account_id: accountId,
              resource_type: resourceType,
              resource_name: rName,
              version: Number(obj['version'] || 1),
              content: typeof obj['content'] === 'string'
                ? String(obj['content'])
                : (obj['content'] ? JSON.stringify(obj['content'], null, 2) : '')
            });
          }
        }
      } catch (_e) {
      }
      out.data = list;
    }
    return out;
  }

  public async readResourceRaw(
    accountId: string,
    resourceType: string,
    resourceName: string
  ): Promise<ApiResult<string>> {
    return this.getRawJson(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/${encodeURIComponent(resourceName)}`
    );
  }

  public async createResource(
    accountId: string,
    resourceType: string,
    resourceName: string,
    content: string
  ): Promise<ApiResult<ResourceItem>> {
    const createRes = await this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/create?name=${encodeURIComponent(resourceName)}`,
      http.RequestMethod.GET
    );
    if (content && content.trim().length > 0 && content.trim() !== '{}') {
      await this.writeResource(accountId, resourceType, resourceName, content);
    }
    const out = new ApiResult<ResourceItem>();
    out.ok = createRes.ok;
    out.error = createRes.error;
    if (createRes.ok) {
      out.data = {
        id: resourceName,
        account_id: accountId,
        resource_type: resourceType,
        resource_name: resourceName,
        version: 1,
        content: content
      };
    }
    return out;
  }

  public async writeResource(
    accountId: string,
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
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/write?name=${encodeURIComponent(resourceName)}`,
      http.RequestMethod.POST,
      parsedContent
    );
    const out = new ApiResult<ResourceItem>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      out.data = {
        id: resourceName,
        account_id: accountId,
        resource_type: resourceType,
        resource_name: resourceName,
        version: 1,
        content: content
      };
    }
    return out;
  }

  public async deleteResource(accountId: string, resourceType: string, resourceName: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/delete?name=${encodeURIComponent(resourceName)}`,
      http.RequestMethod.DELETE
    );
  }

  public async listResourceHistory(
    accountId: string,
    resourceType: string,
    resourceName: string
  ): Promise<ApiResult<ResourceVersionItem[]>> {
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/history?name=${encodeURIComponent(resourceName)}`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<ResourceVersionItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      out.data = this.unwrapArray<ResourceVersionItem>(r.rawText, ['items', 'versions']);
    }
    return out;
  }

  public async readResourceHistoryVersion(
    accountId: string,
    resourceType: string,
    resourceName: string,
    version: number
  ): Promise<ApiResult<ResourceVersionItem>> {
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/${resourceType}/history/${version}?name=${encodeURIComponent(resourceName)}`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<ResourceVersionItem>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const contentObj = r.data['content'] !== undefined ? r.data['content'] : r.data;
      out.data = {
        version: version,
        created_at: Number(r.data['created_at'] || 0),
        content: contentObj
      };
    }
    return out;
  }

  public async encodePasswordCredential(accountId: string, password: string): Promise<ApiResult<string>> {
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

  public async getManagementPresetJson(accountId: string): Promise<ApiResult<string>> {
    return this.getRawJson(this.managementUrl, `/account/${accountId}/ManagementPreset.json`);
  }

  // ==================== CLIENTS & REMOTE CONTROL ====================
  public async listClients(accountId: string): Promise<ApiResult<ClientRecord[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/client/list`, http.RequestMethod.GET);
    const out = new ApiResult<ClientRecord[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'clients']);
      const list: ClientRecord[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const isOnline = Boolean(it['is_online']) || String(it['status'] || '') === 'online';
        const statusStr = String(it['status'] || (isOnline ? 'online' : 'offline'));
        list.push({
          id: String(it['id'] || it['uid'] || ''),
          uid: String(it['uid'] || ''),
          client_id: String(it['client_id'] || ''),
          display_name: String(it['display_name'] || it['client_id'] || it['uid'] || ''),
          mac: String(it['mac'] || ''),
          status: statusStr,
          is_online: isOnline,
          last_ip: String(it['last_ip'] || ''),
          last_seen_at: Number(it['last_seen_at'] || it['last_seen'] || 0),
          registered_at: Number(it['registered_at'] || it['created_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async updateClient(
    accountId: string,
    uid: string,
    displayName: string,
    clientId: string
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'display_name': displayName,
      'client_id': clientId
    };
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/rename`,
      http.RequestMethod.POST,
      payload
    );
  }

  public async deleteClient(accountId: string, uid: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/client/${encodeURIComponent(uid)}`, http.RequestMethod.DELETE);
  }

  public async clientActionPost(accountId: string, uid: string, actionPath: string): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/${actionPath}`,
      http.RequestMethod.POST,
      empty
    );
  }

  public async clientCommandGet(accountId: string, uid: string, cmdQuery: string): Promise<ApiResult<Record<string, Object>>> {
    if (cmdQuery === 'force-sync' || cmdQuery === 'update-data') {
      const empty: Record<string, Object> = {};
      return this.request(
        this.managementUrl,
        `/account/${accountId}/client/${encodeURIComponent(uid)}/command/update-data`,
        http.RequestMethod.POST,
        empty
      );
    }
    if (cmdQuery === 'restart') {
      const empty: Record<string, Object> = {};
      return this.request(
        this.managementUrl,
        `/account/${accountId}/client/${encodeURIComponent(uid)}/command/restart`,
        http.RequestMethod.POST,
        empty
      );
    }
    if (cmdQuery.startsWith('get-config')) {
      const qIdx = cmdQuery.indexOf('config_type=');
      const cType = qIdx >= 0 ? Number(cmdQuery.substring(qIdx + 12)) || 1 : 1;
      const body: Record<string, Object> = { 'type': cType, 'config_type': cType };
      return this.request(
        this.managementUrl,
        `/account/${accountId}/client/${encodeURIComponent(uid)}/command/get-config`,
        http.RequestMethod.POST,
        body
      );
    }
    const emptyBody: Record<string, Object> = {};
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/command/${cmdQuery}`,
      http.RequestMethod.POST,
      emptyBody
    );
  }

  public async batchClientOperation(
    accountId: string,
    clientUids: string[],
    action: string,
    profileMap?: Record<string, string>
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = {
      'uids': clientUids,
      'client_uids': clientUids,
      'action': action
    };
    if (profileMap !== undefined) {
      payload['profile'] = profileMap;
    }
    return this.request(this.managementUrl, `/account/${accountId}/client/batch`, http.RequestMethod.POST, payload);
  }

  public async getDefaultProfile(accountId: string): Promise<ApiResult<ClientProfileRecord>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/default-profile`, http.RequestMethod.GET);
    const out = new ApiResult<ClientProfileRecord>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const prof = (r.data['profile'] || r.data) as Record<string, Object>;
      out.data = {
        cp_resource_name: String(prof['ClassPlan'] || prof['cp_resource_name'] || ''),
        tl_resource_name: String(prof['TimeLayout'] || prof['tl_resource_name'] || ''),
        sub_resource_name: String(prof['Subjects'] || prof['sub_resource_name'] || ''),
        pol_resource_name: String(prof['Policy'] || prof['pol_resource_name'] || ''),
        ds_resource_name: String(prof['DefaultSettings'] || prof['ds_resource_name'] || ''),
        com_resource_name: String(prof['Components'] || prof['com_resource_name'] || ''),
        cred_resource_name: String(prof['Credentials'] || prof['cred_resource_name'] || '')
      };
    }
    return out;
  }

  public async setDefaultProfile(accountId: string, profilePayload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    const merged: Record<string, Object> = {
      'ClassPlan': String(profilePayload['cp_resource_name'] || profilePayload['ClassPlan'] || ''),
      'TimeLayout': String(profilePayload['tl_resource_name'] || profilePayload['TimeLayout'] || ''),
      'Subjects': String(profilePayload['sub_resource_name'] || profilePayload['Subjects'] || ''),
      'Policy': String(profilePayload['pol_resource_name'] || profilePayload['Policy'] || ''),
      'DefaultSettings': String(profilePayload['ds_resource_name'] || profilePayload['DefaultSettings'] || ''),
      'Components': String(profilePayload['com_resource_name'] || profilePayload['Components'] || ''),
      'Credentials': String(profilePayload['cred_resource_name'] || profilePayload['Credentials'] || ''),
      'cp_resource_name': String(profilePayload['cp_resource_name'] || profilePayload['ClassPlan'] || ''),
      'tl_resource_name': String(profilePayload['tl_resource_name'] || profilePayload['TimeLayout'] || ''),
      'sub_resource_name': String(profilePayload['sub_resource_name'] || profilePayload['Subjects'] || ''),
      'pol_resource_name': String(profilePayload['pol_resource_name'] || profilePayload['Policy'] || ''),
      'ds_resource_name': String(profilePayload['ds_resource_name'] || profilePayload['DefaultSettings'] || ''),
      'com_resource_name': String(profilePayload['com_resource_name'] || profilePayload['Components'] || ''),
      'cred_resource_name': String(profilePayload['cred_resource_name'] || profilePayload['Credentials'] || '')
    };
    return this.request(this.managementUrl, `/account/${accountId}/default-profile`, http.RequestMethod.POST, merged);
  }

  public async getClientProfile(accountId: string, uid: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/client/${encodeURIComponent(uid)}/config`, http.RequestMethod.GET);
  }

  public async setClientProfile(
    accountId: string,
    uid: string,
    profilePayload: Record<string, Object>
  ): Promise<ApiResult<Record<string, Object>>> {
    const merged: Record<string, Object> = {
      'ClassPlan': String(profilePayload['cp_resource_name'] || profilePayload['ClassPlan'] || ''),
      'TimeLayout': String(profilePayload['tl_resource_name'] || profilePayload['TimeLayout'] || ''),
      'Subjects': String(profilePayload['sub_resource_name'] || profilePayload['Subjects'] || ''),
      'Policy': String(profilePayload['pol_resource_name'] || profilePayload['Policy'] || ''),
      'DefaultSettings': String(profilePayload['ds_resource_name'] || profilePayload['DefaultSettings'] || ''),
      'Components': String(profilePayload['com_resource_name'] || profilePayload['Components'] || ''),
      'Credentials': String(profilePayload['cred_resource_name'] || profilePayload['Credentials'] || '')
    };
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/${encodeURIComponent(uid)}/config`,
      http.RequestMethod.POST,
      merged
    );
  }

  public async listConfigSnapshots(accountId: string, uid: string): Promise<ApiResult<ConfigSnapshotItem[]>> {
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/config-uploads?client_uid=${encodeURIComponent(uid)}`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<ConfigSnapshotItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'uploads']);
      const list: ConfigSnapshotItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const cUid = String(it['client_uid'] || '');
        if (uid.length > 0 && cUid.length > 0 && cUid !== uid) {
          continue;
        }
        const rGuid = String(it['request_guid'] || it['id'] || '');
        list.push({
          id: rGuid,
          request_guid: rGuid,
          client_uid: cUid,
          config_type: Number(it['config_type'] || it['type'] || 0),
          payload: String(it['payload'] || it['content'] || ''),
          created_at: Number(it['created_at'] || it['uploaded_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async getConfigSnapshotDetail(accountId: string, requestGuid: string): Promise<ApiResult<string>> {
    const r = await this.request(
      this.managementUrl,
      `/account/${accountId}/config-upload/${encodeURIComponent(requestGuid)}`,
      http.RequestMethod.GET
    );
    const out = new ApiResult<string>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const p = r.data['payload'] !== undefined ? r.data['payload'] : (r.data['content'] !== undefined ? r.data['content'] : r.data);
      out.data = typeof p === 'string' ? p : JSON.stringify(p, null, 2);
    }
    return out;
  }

  // ==================== NOTIFICATIONS ====================
  public async sendNotificationToClient(
    accountId: string,
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

  public async broadcastNotification(accountId: string, payload: NotificationPayload): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/client/broadcast/send-notification`,
      http.RequestMethod.POST,
      payload as Object
    );
  }

  // ==================== AUDIT LOGS ====================
  public async listAuditLogs(accountId: string, clientUid: string, eventFilter: string): Promise<ApiResult<AuditLogItem[]>> {
    let query = '?limit=200';
    if (clientUid.length > 0) {
      query += `&client_uid=${encodeURIComponent(clientUid)}`;
    }
    if (eventFilter.length > 0 && eventFilter !== 'all') {
      query += `&event_type=${encodeURIComponent(eventFilter)}`;
    }
    const r = await this.request(this.managementUrl, `/account/${accountId}/audit/list${query}`, http.RequestMethod.GET);
    const out = new ApiResult<AuditLogItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'logs']);
      const list: AuditLogItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const ev = Number(it['event_type'] ?? it['event'] ?? 0);
        const decodedObj = it['decoded'] as Record<string, Object>;
        const payloadStr = decodedObj
          ? JSON.stringify(decodedObj, null, 2)
          : String(it['payload'] || '');
        list.push({
          id: String(it['id'] || `${i}`),
          client_uid: String(it['client_uid'] || ''),
          client_id: String(it['client_id'] || it['client_uid'] || ''),
          event: ev,
          event_type: ev,
          event_name: String(it['event_name'] || ''),
          payload: payloadStr,
          timestamp_utc: Number(it['timestamp_utc'] || it['created_at'] || 0),
          created_at: Number(it['created_at'] || it['timestamp_utc'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async clearAuditLogs(accountId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/audit/clear`, http.RequestMethod.DELETE);
  }

  // ==================== PAIRING & PRE-REGISTRATION ====================
  public async getPairingStatus(accountId: string): Promise<ApiResult<string>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/pairing/status`, http.RequestMethod.GET);
    const out = new ApiResult<string>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      out.data = String(r.data['registration_mode'] || r.data['mode'] || 'open');
    }
    return out;
  }

  public async setPairingMode(accountId: string, mode: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'mode': mode, 'registration_mode': mode };
    return this.request(this.managementUrl, `/account/${accountId}/pairing/mode`, http.RequestMethod.POST, payload);
  }

  public async listPairingRequests(accountId: string, statusFilter: string): Promise<ApiResult<PairingRequestItem[]>> {
    const query = statusFilter === 'all' ? '' : `?status=${encodeURIComponent(statusFilter)}`;
    const r = await this.request(this.managementUrl, `/account/${accountId}/pairing/list${query}`, http.RequestMethod.GET);
    const out = new ApiResult<PairingRequestItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'requests', 'codes']);
      const list: PairingRequestItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const codeStr = String(it['pairing_code'] || it['code'] || '');
        list.push({
          id: String(it['id'] || codeStr),
          client_uid: String(it['client_uid'] || ''),
          client_id: String(it['client_id'] || ''),
          mac: String(it['mac'] || ''),
          ip: String(it['ip'] || ''),
          pairing_code: codeStr,
          code: codeStr,
          status: String(it['status'] || 'pending'),
          created_at: Number(it['created_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async approvePairingRequest(
    accountId: string,
    reqId: string,
    profilePayload: Record<string, Object>
  ): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/pairing/${encodeURIComponent(reqId)}/approve`,
      http.RequestMethod.POST,
      profilePayload
    );
  }

  public async rejectPairingRequest(accountId: string, reqId: string): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(
      this.managementUrl,
      `/account/${accountId}/pairing/${encodeURIComponent(reqId)}/reject`,
      http.RequestMethod.POST,
      empty
    );
  }

  public async listPreRegItems(accountId: string): Promise<ApiResult<PreRegItem[]>> {
    const r = await this.request(this.managementUrl, `/account/${accountId}/pre-registration/list`, http.RequestMethod.GET);
    const out = new ApiResult<PreRegItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items']);
      const list: PreRegItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        list.push({
          id: String(it['id'] || ''),
          label: String(it['label'] || ''),
          class_identity: String(it['class_identity'] || ''),
          mac_address: String(it['mac_address'] || it['mac'] || ''),
          cp_resource_name: String(it['cp_resource_name'] || it['ClassPlan'] || ''),
          tl_resource_name: String(it['tl_resource_name'] || it['TimeLayout'] || ''),
          sub_resource_name: String(it['sub_resource_name'] || it['Subjects'] || ''),
          pol_resource_name: String(it['pol_resource_name'] || it['Policy'] || ''),
          ds_resource_name: String(it['ds_resource_name'] || it['DefaultSettings'] || ''),
          com_resource_name: String(it['com_resource_name'] || it['Components'] || ''),
          cred_resource_name: String(it['cred_resource_name'] || it['Credentials'] || ''),
          paired_client_uid: String(it['paired_client_uid'] || it['matched_client_uid'] || ''),
          created_at: Number(it['created_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async createPreRegItem(accountId: string, payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.managementUrl, `/account/${accountId}/pre-registration/create`, http.RequestMethod.POST, payload);
  }

  public async batchCreatePreRegItems(
    accountId: string,
    items: Record<string, Object>[]
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'items': items };
    return this.request(this.managementUrl, `/account/${accountId}/pre-registration/batch`, http.RequestMethod.POST, payload);
  }

  public async updatePreRegItem(
    accountId: string,
    itemId: string,
    payload: Record<string, Object>
  ): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/pre-registration/${encodeURIComponent(itemId)}`,
      http.RequestMethod.PUT,
      payload
    );
  }

  public async deletePreRegItem(accountId: string, itemId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(
      this.managementUrl,
      `/account/${accountId}/pre-registration/${encodeURIComponent(itemId)}`,
      http.RequestMethod.DELETE
    );
  }

  public async getPreRegPresetJson(accountId: string, itemId: string): Promise<ApiResult<string>> {
    return this.getRawJson(this.managementUrl, `/account/${accountId}/pre-registration/${encodeURIComponent(itemId)}/ManagementPreset.json`);
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
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'users']);
      const list: AdminUserItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const roleVal = String(it['role_code'] || it['role'] || 'user');
        list.push({
          id: String(it['id'] || ''),
          username: String(it['username'] || ''),
          email: String(it['email'] || ''),
          display_name: String(it['display_name'] || it['username'] || ''),
          role: roleVal,
          role_code: roleVal,
          status: String(it['status'] || 'active'),
          is_active: it['is_active'] !== false,
          can_create_account: it['can_create_account'] !== false,
          totp_enabled: Boolean(it['totp_enabled']),
          created_at: Number(it['created_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async createGlobalUser(payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, '/user', http.RequestMethod.POST, payload);
  }

  public async updateGlobalUser(userId: string, payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/user/${encodeURIComponent(userId)}`, http.RequestMethod.PUT, payload);
  }

  public async deleteGlobalUser(userId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/user/${encodeURIComponent(userId)}`, http.RequestMethod.DELETE);
  }

  public async resetGlobalUserPassword(userId: string, newPassword: string): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'new_password': newPassword };
    return this.request(this.adminUrl, `/user/${encodeURIComponent(userId)}/reset-password`, http.RequestMethod.POST, payload);
  }

  public async disableGlobalUserTotp(userId: string): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.adminUrl, `/user/${encodeURIComponent(userId)}/disable-totp`, http.RequestMethod.POST, empty);
  }

  public async listPendingUsers(): Promise<ApiResult<AdminUserItem[]>> {
    const r = await this.request(this.adminUrl, '/user/pending?limit=100', http.RequestMethod.GET);
    const out = new ApiResult<AdminUserItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'users']);
      const list: AdminUserItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const roleVal = String(it['role_code'] || it['role'] || 'user');
        list.push({
          id: String(it['id'] || ''),
          username: String(it['username'] || ''),
          email: String(it['email'] || ''),
          display_name: String(it['display_name'] || it['username'] || ''),
          role: roleVal,
          role_code: roleVal,
          status: String(it['status'] || 'pending'),
          is_active: it['is_active'] !== false,
          can_create_account: it['can_create_account'] !== false,
          totp_enabled: Boolean(it['totp_enabled']),
          created_at: Number(it['created_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async approvePendingUser(userId: string): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.adminUrl, `/user/${encodeURIComponent(userId)}/approve`, http.RequestMethod.POST, empty);
  }

  public async rejectPendingUser(userId: string): Promise<ApiResult<Record<string, Object>>> {
    const empty: Record<string, Object> = {};
    return this.request(this.adminUrl, `/user/${encodeURIComponent(userId)}/reject`, http.RequestMethod.POST, empty);
  }

  public async listGlobalAccounts(search: string): Promise<ApiResult<AdminAccountItem[]>> {
    const q = search.trim().length > 0 ? `?limit=100&search=${encodeURIComponent(search.trim())}` : '?limit=100';
    const r = await this.request(this.adminUrl, `/account${q}`, http.RequestMethod.GET);
    const out = new ApiResult<AdminAccountItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'accounts']);
      const list: AdminAccountItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        list.push({
          id: String(it['id'] || ''),
          name: String(it['name'] || ''),
          slug: String(it['slug'] || ''),
          owner_id: String(it['owner_id'] || ''),
          api_key: String(it['api_key'] || ''),
          registration_mode: String(it['registration_mode'] || 'open'),
          is_active: it['is_active'] !== false,
          client_count: Number(it['client_count'] || 0),
          member_count: Number(it['member_count'] || 0),
          created_at: Number(it['created_at'] || 0)
        });
      }
      out.data = list;
    }
    return out;
  }

  public async createGlobalAccount(payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, '/account', http.RequestMethod.POST, payload);
  }

  public async updateGlobalAccount(accountId: string, payload: Record<string, Object>): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/account/${encodeURIComponent(accountId)}`, http.RequestMethod.PUT, payload);
  }

  public async deleteGlobalAccount(accountId: string): Promise<ApiResult<Record<string, Object>>> {
    return this.request(this.adminUrl, `/account/${encodeURIComponent(accountId)}`, http.RequestMethod.DELETE);
  }

  public async getGlobalAccountQuotas(accountId: string): Promise<ApiResult<QuotaItem[]>> {
    const r = await this.request(this.adminUrl, `/account/${encodeURIComponent(accountId)}/quotas`, http.RequestMethod.GET);
    const out = new ApiResult<QuotaItem[]>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok) {
      const rawList = this.unwrapArray<Record<string, Object>>(r.rawText, ['items', 'quotas']);
      const list: QuotaItem[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const it = rawList[i];
        const qk = String(it['quota_key'] || it['quota_type'] || '');
        const mv = Number(it['max_value'] ?? it['limit_value'] ?? 0);
        const cv = Number(it['current_value'] ?? 0);
        list.push({
          id: String(it['id'] || qk),
          quota_key: qk,
          quota_type: qk,
          max_value: mv,
          limit_value: mv,
          current_value: cv
        });
      }
      out.data = list;
    }
    return out;
  }

  public async updateGlobalAccountQuotas(
    accountId: string,
    quotas: Record<string, number>
  ): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'quotas': quotas };
    return this.request(this.adminUrl, `/account/${encodeURIComponent(accountId)}/quotas`, http.RequestMethod.PUT, payload);
  }

  public async getSystemSettings(): Promise<ApiResult<Record<string, string>>> {
    const r = await this.request(this.adminUrl, '/settings', http.RequestMethod.GET);
    const out = new ApiResult<Record<string, string>>();
    out.ok = r.ok;
    out.error = r.error;
    if (r.ok && r.data) {
      const parsed = JSON.parse(r.rawText) as Record<string, Record<string, string>>;
      out.data = parsed['settings'] || (r.data as Object as Record<string, string>) || {};
    }
    return out;
  }

  public async updateSystemSettings(settings: Record<string, string>): Promise<ApiResult<Record<string, Object>>> {
    const payload: Record<string, Object> = { 'settings': settings };
    return this.request(this.adminUrl, '/settings', http.RequestMethod.PUT, payload);
  }
}
