import { GlobalStats } from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconTextButton } from './HmosIcons';

@Component
export struct DashboardView {
  @Prop isSuperAdminMode: boolean = false;
  @Prop isSuperAdminTakeover: boolean = false;
  @Prop currentAccountId: string = '';
  @Prop currentAccountName: string = '';
  @Prop currentAccountSlug: string = '';
  @Prop breakpoint: string = 'sm';
  @Prop themeMode: string = 'light';

  @Prop dashOnlineClients: number = 0;
  @Prop dashTotalClients: number = 0;
  @Prop dashPendingPairings: number = 0;
  @Prop dashTotalResources: number = 0;
  @Prop dashRecentAudits: number = 0;
  @Prop adminGlobalStats: GlobalStats | null = null;

  public onNavigateSection: (sec: string) => void = () => {};
  public onExitTakeover: () => void = () => {};
  public onRefreshStats: () => void = () => {};

  @State dashPresetJson: string = '';

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  @Builder
  buildStatCard(value: string, label: string, valueColor: string, targetSec: string) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
      Text(label)
        .fontSize(13)
        .fontColor(this.theme().textSecondary)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .backgroundColor(this.theme().bgCard)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().borderColor })
    .layoutWeight(1)
    .onClick(() => {
      this.onNavigateSection(targetSec);
    })
  }

  @Builder
  buildTenantDashboard() {
    Column({ space: 16 }) {
      if (this.isSuperAdminTakeover) {
        Row({ space: 8 }) {
          Text(`当前正在以超级管理员身份接管集控账户：${this.currentAccountName}`)
            .fontSize(13)
            .fontColor(this.theme().badgeWarningFg)
            .layoutWeight(1)
          Button('返回超管平台')
            .height(28)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.theme().accentColor)
            .borderRadius(4)
            .onClick(() => {
              this.onExitTakeover();
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.theme().badgeWarningBg)
        .borderRadius(6)
      }

      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('仪表盘')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text(`当前账户：${this.currentAccountName || '-'} — 实时集控运行状态总览`)
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        HmosIconTextButton(
          $r('sys.symbol.folder'),
          '下载通用配置',
          '#FFFFFF',
          this.theme().accentColor,
          Color.Transparent,
          async () => {
            const r = await ApiService.get().getManagementPresetJson(this.currentAccountId);
            if (r.ok && r.data) {
              this.dashPresetJson = r.data;
            }
          },
          34,
          13
        )
      }
      .width('100%')

      if (this.breakpoint === 'lg') {
        Row({ space: 16 }) {
          this.buildStatCard(`${this.dashOnlineClients} / ${this.dashTotalClients}`, '在线客户端 / 注册设备总数', this.theme().successColor, 'clients')
          this.buildStatCard(`${this.dashPendingPairings}`, '待审批配对码请求', this.theme().warningColor, 'pairing')
          this.buildStatCard(`${this.dashTotalResources}`, '已创建配置档案资源总数', this.theme().accentColor, 'res_Subjects')
          this.buildStatCard(`${this.dashRecentAudits}`, '近期客户端审计记录', this.theme().textPrimary, 'audit')
        }
        .width('100%')
      } else {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            this.buildStatCard(`${this.dashOnlineClients} / ${this.dashTotalClients}`, '在线客户端 / 注册总数', this.theme().successColor, 'clients')
            this.buildStatCard(`${this.dashPendingPairings}`, '待审批配对码请求', this.theme().warningColor, 'pairing')
          }.width('100%')
          Row({ space: 12 }) {
            this.buildStatCard(`${this.dashTotalResources}`, '已创建档案资源总数', this.theme().accentColor, 'res_Subjects')
            this.buildStatCard(`${this.dashRecentAudits}`, '近期客户端审计记录', this.theme().textPrimary, 'audit')
          }.width('100%')
        }
      }

      if (this.dashPresetJson.length > 0) {
        Column({ space: 8 }) {
          Row() {
            Text(`ManagementPreset-${this.currentAccountSlug || 'account'}-generic.json`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
              .layoutWeight(1)
            Button('关闭')
              .height(26)
              .fontSize(12)
              .fontColor(this.theme().textSecondary)
              .backgroundColor(this.theme().bgSubtle)
              .borderRadius(4)
              .onClick(() => { this.dashPresetJson = ''; })
          }.width('100%')

          TextArea({ text: this.dashPresetJson })
            .height(120)
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgSubtle)
            .border({ width: 1, color: this.theme().borderColor, radius: 6 })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.theme().bgCard)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      }

      Column({ space: 10 }) {
        Text('MINI ClassIsland 集控工作流指引')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)

        Text('1. 接入客户端：点击右上角「下载通用配置」并将生成的 ManagementPreset.json 放入 ClassIsland 程序目录；或在「接入管理 · 预注册客户端」中为指定班级生成带标识的专属引导配置，结合「配对码管理」完成设备准入。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)

        Text('2. 编写 7 大资源档案：在左侧「档案管理」下依次配置科目、时间表、课表、策略、默认设置、组件与凭据。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)

        Text('3. 按设备精准分配与控制：在「客户端 · 客户端管理」中可为不同班级绑定专属课表与策略，或实时推送通知横幅、强制同步与重启指令。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  @Builder
  buildSuperAdminDashboard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('全局平台总览')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          Text('MINI ClassIsland 超级管理平台实时运行指标与全局统计')
            .fontSize(13)
            .fontColor(this.theme().textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        HmosIconTextButton(
          $r('sys.symbol.arrow_clockwise'),
          '刷新数据',
          this.theme().textPrimary,
          this.theme().bgCard,
          this.theme().borderColor,
          () => {
            this.onRefreshStats();
          },
          34,
          13
        )
      }
      .width('100%')

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          this.buildStatCard(`${this.adminGlobalStats?.total_users ?? 0}`, '全局注册用户数', this.theme().accentColor, 'admin_users')
          this.buildStatCard(`${this.adminGlobalStats?.pending_users ?? 0}`, '待审核注册申请', this.theme().warningColor, 'admin_pending')
        }.width('100%')
        Row({ space: 12 }) {
          this.buildStatCard(`${this.adminGlobalStats?.total_accounts ?? 0}`, '集控账户总数', this.theme().accentColor, 'admin_accounts')
          this.buildStatCard(`${this.adminGlobalStats?.online_clients ?? 0} / ${this.adminGlobalStats?.total_clients ?? 0}`, '全局在线客户端 / 注册总数', this.theme().successColor, 'admin_accounts')
        }.width('100%')
      }

      Column({ space: 8 }) {
        Text('超级管理员工作台说明')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Text('您当前处于 MINI ClassIsland 超级管理平台。您可以在左侧导航中管理全局用户、审批新用户注册申请、配置各集控账户的资源配额，或一键接管任意集控账户。')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor(this.theme().bgCard)
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.isSuperAdminMode) {
        this.buildSuperAdminDashboard()
      } else {
        this.buildTenantDashboard()
      }
    }
    .width('100%')
  }
}
