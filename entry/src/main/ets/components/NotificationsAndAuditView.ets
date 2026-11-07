import {
  ClientRecord,
  AuditLogItem,
  NotificationPayload,
  AUDIT_EVENT_LABELS,
  AuditEventLabelDef,
  getAuditEventLabel,
  formatTimestamp
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconTextButton } from './HmosIcons';

@Component
export struct NotificationsAndAuditView {
  @Prop accountId: string = '';
  @Prop subMode: string = 'notifications'; // 'notifications' | 'audit'
  @Prop fixedClientUid: string = '';
  @Prop clients: ClientRecord[] = [];
  @Prop themeMode: string = 'light';
  public onFeedback: (msg: string, err: boolean) => void = () => {};

  // Audit Logs
  @State auditLogs: AuditLogItem[] = [];
  @State auditClientFilter: string = '';
  @State auditEventFilter: string = 'all';
  @State selectedAuditDetail: string = '';

  // Notifications
  @State notifyTargetUid: string = '__broadcast__';
  @State notifyPayload: NotificationPayload = {
    MessageMask: '集控中心通知',
    MessageContent: '请各班注意查收最新课表安排',
    OverlayIconLeft: 0,
    OverlayIconRight: 0,
    IsEmergency: false,
    IsSpeechEnabled: true,
    IsSoundEnabled: true,
    IsEffectEnabled: true,
    IsTopmost: true,
    DurationSeconds: 10,
    RepeatCounts: 1
  };

  private lastAccount: string = '';
  private lastMode: string = '';

  aboutToAppear(): void {
    this.reloadIfNeeded();
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  public async reloadIfNeeded(): Promise<void> {
    this.lastAccount = this.accountId;
    this.lastMode = this.subMode;
    if (this.subMode === 'audit' && this.accountId.length > 0) {
      await this.loadAuditLogs();
    }
  }

  private async loadAuditLogs(): Promise<void> {
    const r = await ApiService.get().listAuditLogs(this.accountId, this.auditClientFilter, this.auditEventFilter);
    if (r.ok && r.data) {
      this.auditLogs = r.data;
    }
  }

  @Builder
  buildNotificationComposer() {
    Column({ space: 14 }) {
      Column({ space: 4 }) {
        Text('ClassIsland 提醒横幅预览')
          .fontSize(11)
          .fontColor(this.notifyPayload.IsEmergency ? '#D13438' : '#CCCCCC')
        Text(this.notifyPayload.MessageMask || '（遮罩标题）')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.notifyPayload.IsEmergency ? '#D13438' : '#FFFFFF')
        Text(this.notifyPayload.MessageContent || '（正文内容将在此滚动或居中展示）')
          .fontSize(14)
          .fontColor(this.notifyPayload.IsEmergency ? '#D13438' : '#F0F0F0')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 16, bottom: 16 })
      .backgroundColor(this.notifyPayload.IsEmergency ? '#FDE7E9' : '#1F1F1F')
      .borderRadius(8)
      .border({ width: 1, color: this.theme().borderColor })
      .alignItems(HorizontalAlign.Center)

      Column({ space: 12 }) {
        if (this.fixedClientUid.length === 0) {
          Column({ space: 6 }) {
            Text('目标客户端（单发时必选）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme().textPrimary)
            Flex({ wrap: FlexWrap.Wrap }) {
              Button('全体在线客户端广播')
                .height(28)
                .fontSize(12)
                .margin({ right: 6, bottom: 6 })
                .fontColor(this.notifyTargetUid === '__broadcast__' ? '#FFFFFF' : this.theme().textPrimary)
                .backgroundColor(this.notifyTargetUid === '__broadcast__' ? this.theme().accentColor : this.theme().bgSubtle)
                .borderRadius(4)
                .onClick(() => { this.notifyTargetUid = '__broadcast__'; })
              ForEach(this.clients, (c: ClientRecord) => {
                Button(c.display_name || c.client_id)
                  .height(28)
                  .fontSize(12)
                  .margin({ right: 6, bottom: 6 })
                  .fontColor(this.notifyTargetUid === c.uid ? '#FFFFFF' : this.theme().textPrimary)
                  .backgroundColor(this.notifyTargetUid === c.uid ? this.theme().accentColor : this.theme().bgSubtle)
                  .borderRadius(4)
                  .onClick(() => { this.notifyTargetUid = c.uid; })
              }, (c: ClientRecord) => c.uid)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Column({ space: 4 }) {
          Text('遮罩标题').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
          TextInput({ text: this.notifyPayload.MessageMask })
            .height(36)
            .fontSize(13)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => { this.notifyPayload.MessageMask = v; })
        }.width('100%').alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('通知正文').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
          TextInput({ text: this.notifyPayload.MessageContent })
            .height(36)
            .fontSize(13)
            .fontColor(this.theme().textPrimary)
            .backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => { this.notifyPayload.MessageContent = v; })
        }.width('100%').alignItems(HorizontalAlign.Start)

        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('显示持续秒数').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({ text: `${this.notifyPayload.DurationSeconds}` })
              .height(34)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onChange((v: string) => {
                const n = Number(v);
                if (!isNaN(n) && n > 0) {
                  this.notifyPayload.DurationSeconds = n;
                }
              })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('重复次数').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({ text: `${this.notifyPayload.RepeatCounts}` })
              .height(34)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onChange((v: string) => {
                const n = Number(v);
                if (!isNaN(n) && n > 0) {
                  this.notifyPayload.RepeatCounts = n;
                }
              })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          Row({ space: 4 }) {
            Text('紧急通知').fontSize(13).fontColor(this.theme().dangerColor)
            Toggle({ type: ToggleType.Switch, isOn: this.notifyPayload.IsEmergency })
              .onChange((v: boolean) => { this.notifyPayload.IsEmergency = v; })
          }.margin({ right: 16 })

          Row({ space: 4 }) {
            Text('启用语音播报').fontSize(13).fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: this.notifyPayload.IsSpeechEnabled })
              .onChange((v: boolean) => { this.notifyPayload.IsSpeechEnabled = v; })
          }.margin({ right: 16 })

          Row({ space: 4 }) {
            Text('启用提醒音效').fontSize(13).fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: this.notifyPayload.IsSoundEnabled })
              .onChange((v: boolean) => { this.notifyPayload.IsSoundEnabled = v; })
          }.margin({ right: 16 })

          Row({ space: 4 }) {
            Text('启用醒目特效').fontSize(13).fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: this.notifyPayload.IsEffectEnabled })
              .onChange((v: boolean) => { this.notifyPayload.IsEffectEnabled = v; })
          }.margin({ right: 16 })

          Row({ space: 4 }) {
            Text('强制窗口置顶').fontSize(13).fontColor(this.theme().textPrimary)
            Toggle({ type: ToggleType.Switch, isOn: this.notifyPayload.IsTopmost })
              .onChange((v: boolean) => { this.notifyPayload.IsTopmost = v; })
          }
        }

        Button('推送通知')
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .fontColor('#FFFFFF')
          .backgroundColor(this.notifyPayload.IsEmergency ? this.theme().dangerColor : this.theme().accentColor)
          .borderRadius(4)
          .onClick(async () => {
            const target = this.fixedClientUid.length > 0 ? this.fixedClientUid : this.notifyTargetUid;
            if (target === '__broadcast__') {
              const r = await ApiService.get().broadcastNotification(this.accountId, this.notifyPayload);
              this.onFeedback(r.ok ? '全员广播通知已下发' : (r.error || '广播失败'), !r.ok);
            } else {
              const r = await ApiService.get().sendNotificationToClient(this.accountId, target, this.notifyPayload);
              this.onFeedback(r.ok ? '单机通知已下发' : (r.error || '发送失败'), !r.ok);
            }
          })
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
  buildAuditLogsView() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Blank()
        HmosIconTextButton(
          $r('sys.symbol.arrow_clockwise'),
          '刷新日志',
          this.theme().textPrimary,
          this.theme().bgCard,
          this.theme().borderColor,
          () => {
            this.loadAuditLogs();
          },
          30,
          12
        )
        HmosIconTextButton(
          $r('sys.symbol.trash'),
          '清空全部日志',
          this.theme().dangerColor,
          this.theme().bgCard,
          this.theme().borderColor,
          async () => {
            const r = await ApiService.get().clearAuditLogs(this.accountId);
            if (r.ok) {
              this.auditLogs = [];
              this.onFeedback('审计日志已清空', false);
            }
          },
          30,
          12
        )
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        Button('全部事件')
          .height(26)
          .fontSize(11)
          .margin({ right: 6, bottom: 6 })
          .fontColor(this.auditEventFilter === 'all' ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(this.auditEventFilter === 'all' ? this.theme().accentColor : this.theme().bgSubtle)
          .borderRadius(4)
          .onClick(() => {
            this.auditEventFilter = 'all';
            this.loadAuditLogs();
          })
        ForEach(AUDIT_EVENT_LABELS, (def: AuditEventLabelDef) => {
          Button(def.label)
            .height(26)
            .fontSize(11)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.auditEventFilter === `${def.event}` ? '#FFFFFF' : this.theme().textPrimary)
            .backgroundColor(this.auditEventFilter === `${def.event}` ? this.theme().accentColor : this.theme().bgSubtle)
            .borderRadius(4)
            .onClick(() => {
              this.auditEventFilter = `${def.event}`;
              this.loadAuditLogs();
            })
        }, (def: AuditEventLabelDef) => `${def.event}`)
      }

      if (this.selectedAuditDetail.length > 0) {
        Column({ space: 4 }) {
          Row() {
            Text('审计事件载荷详情').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary).layoutWeight(1)
            Button('关闭').height(24).fontSize(11).fontColor(this.theme().textSecondary).backgroundColor(Color.Transparent)
              .onClick(() => { this.selectedAuditDetail = ''; })
          }
          Text(this.selectedAuditDetail)
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor(this.theme().textSecondary)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.theme().bgSubtle)
        .borderRadius(6)
        .border({ width: 1, color: this.theme().borderColor })
      }

      if (this.auditLogs.length === 0) {
        Text('暂无客户端审计事件记录')
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .padding(20)
      } else {
        ForEach(this.auditLogs, (log: AuditLogItem) => {
          Row({ space: 10 }) {
            Text(getAuditEventLabel(log.event))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme().badgeInfoFg)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.theme().badgeInfoBg)
              .borderRadius(99)
            Column({ space: 2 }) {
              Text(`客户端: ${log.client_id || log.client_uid}`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme().textPrimary)
              Text(formatTimestamp(log.timestamp_utc || log.created_at))
                .fontSize(11)
                .fontColor(this.theme().textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button('查看载荷')
              .height(26)
              .fontSize(11)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgSubtle)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .onClick(() => {
                this.selectedAuditDetail = log.payload || '(无附加载荷)';
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
        }, (log: AuditLogItem) => `${log.id}`)
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.theme().bgCard)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().borderColor })
  }

  build() {
    Column() {
      if (this.lastAccount !== this.accountId || this.lastMode !== this.subMode) {
        Row().height(0).onAppear(() => {
          this.reloadIfNeeded();
        })
      }

      if (this.subMode === 'audit') {
        this.buildAuditLogsView()
      } else {
        this.buildNotificationComposer()
      }
    }
    .width('100%')
  }
}
