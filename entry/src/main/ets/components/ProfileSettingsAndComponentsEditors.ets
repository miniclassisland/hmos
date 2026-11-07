import {
  BUILTIN_COMPONENTS,
  BuiltinComponentDef,
  normalizeComponentId,
  findComponentDef
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { ApiService } from '../service/ApiService';
import { HmosIconButton, HmosIconTextButton } from './HmosIcons';

@Component
export struct ProfileSettingsAndComponentsEditors {
  @Prop accountId: number = 0;
  @Prop resourceType: string = 'Policy'; // 'Policy' | 'DefaultSettings' | 'Components' | 'Credentials'
  @Prop rawJsonText: string = '{}';
  @Prop themeMode: string = 'light';
  public onJsonMutated: (nextJson: string) => void = () => {};
  public onStatusFeedback: (msg: string, err: boolean) => void = () => {};

  @State parsedRoot: Record<string, Object> = {};
  @State settingsTab: string = 'general'; // 15 tabs matching web/app/profiles/default-settings/page.tsx
  @State presetClassIdentity: string = '';
  @State generatedPresetJson: string = '';

  // Components State
  @State selectedLineIdx: number = 0;
  @State selectedCompIdx: number = -1;
  @State compInspectorTab: string = 'lib'; // 'lib' | 'settings' | 'advanced' | 'layout'
  @State containerPath: string = ''; // Nested container drill-down status

  // Credentials State
  @State plainUserPassword: string = '';
  @State plainAdminPassword: string = '';

  private lastInputJson: string = '';

  aboutToAppear(): void {
    this.syncFromInputJson();
  }

  private theme(): WebThemePalette {
    return getWebPalette(this.themeMode);
  }

  private syncFromInputJson(): void {
    this.lastInputJson = this.rawJsonText;
    try {
      this.parsedRoot = JSON.parse(this.rawJsonText || '{}') as Record<string, Object>;
    } catch (_e) {
      this.parsedRoot = {};
    }
  }

  private commitRoot(): void {
    const nextStr = JSON.stringify(this.parsedRoot, null, 2);
    this.lastInputJson = nextStr;
    this.onJsonMutated(nextStr);
  }

  @Builder
  buildSwitchItem(title: string, desc: string, fieldKey: string, defaultVal: boolean = false) {
    Row() {
      Column({ space: 2 }) {
        Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.theme().textPrimary)
        if (desc.length > 0) {
          Text(desc).fontSize(11).fontColor(this.theme().textSecondary)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({
        type: ToggleType.Switch,
        isOn: this.parsedRoot[fieldKey] !== undefined ? Boolean(this.parsedRoot[fieldKey]) : defaultVal
      })
        .onChange((v: boolean) => {
          this.parsedRoot[fieldKey] = v;
          this.commitRoot();
        })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 4, right: 4 })
    .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
  }

  @Builder
  buildNumberField(label: string, fieldKey: string, defaultVal: number) {
    Row({ space: 8 }) {
      Text(label).fontSize(12).fontColor(this.theme().textPrimary).layoutWeight(1)
      TextInput({
        text: `${this.parsedRoot[fieldKey] !== undefined ? Number(this.parsedRoot[fieldKey]) : defaultVal}`
      })
        .height(32)
        .width(100)
        .fontSize(12)
        .fontColor(this.theme().textPrimary)
        .backgroundColor(this.theme().bgInput)
        .border({ width: 1, color: this.theme().borderColor, radius: 4 })
        .onChange((v: string) => {
          const n = Number(v);
          if (!isNaN(n)) {
            this.parsedRoot[fieldKey] = n;
            this.commitRoot();
          }
        })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  buildStringField(label: string, fieldKey: string, defaultVal: string) {
    Row({ space: 8 }) {
      Text(label).fontSize(12).fontColor(this.theme().textPrimary).width(120)
      TextInput({
        text: String(this.parsedRoot[fieldKey] !== undefined ? this.parsedRoot[fieldKey] : defaultVal)
      })
        .height(32)
        .fontSize(12)
        .fontColor(this.theme().textPrimary)
        .backgroundColor(this.theme().bgInput)
        .border({ width: 1, color: this.theme().borderColor, radius: 4 })
        .layoutWeight(1)
        .onChange((v: string) => {
          this.parsedRoot[fieldKey] = v;
          this.commitRoot();
        })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  // ==================== 4. POLICY EDITOR (All 12 Upstream ManagementPolicy Fields) ====================
  @Builder
  buildPolicyEditor() {
    Column({ space: 4 }) {
      this.buildSwitchItem('禁止编辑课表', '锁定客户端本地课表修改权限', 'DisableProfileClassPlanEditing', false)
      this.buildSwitchItem('禁止编辑时间表', '锁定客户端本地作息时间表修改权限', 'DisableProfileTimeLayoutEditing', false)
      this.buildSwitchItem('禁止编辑科目', '锁定客户端本地科目列表修改权限', 'DisableProfileSubjectsEditing', false)
      this.buildSwitchItem('禁止编辑全部档案', '完全禁止客户端修改本地档案', 'DisableProfileEditing', false)
      this.buildSwitchItem('禁止修改应用设置', '锁定客户端应用设置界面', 'DisableSettingsEditing', false)
      this.buildSwitchItem('禁止自定义启动画面', '锁定客户端启动页个性化配置', 'DisableSplashCustomize', false)
      this.buildSwitchItem('禁用调试菜单', '隐藏开发者与调试入口', 'DisableDebugMenu', false)
      this.buildSwitchItem('允许退出集控模式', '是否允许客户端终端主动脱离集控', 'AllowExitManagement', true)
      this.buildSwitchItem('禁用彩蛋特性', '关闭应用内置彩蛋', 'DisableEasterEggs', false)
      this.buildSwitchItem('禁用崩溃上报', '关闭客户端自动崩溃遥测收集', 'DisableSentry', false)
      this.buildSwitchItem('禁止安装与管理插件', '锁定插件市场与外部插件加载', 'DisablePluginInstalling', false)
      this.buildSwitchItem('禁用自动化工作流', '关闭客户端本地自动化触发规则', 'DisableAutomation', false)
    }
    .width('100%')
  }

  // ==================== 5. DEFAULT SETTINGS EDITOR (15 Tabs + Visual 6-Point Screen Monitor) ====================
  @Builder
  buildDefaultSettingsEditor() {
    Column({ space: 12 }) {
      // 15 Category Tabs
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach([
          ['general', '基本与时间'],
          ['window', '窗口停靠'],
          ['appearance', '外观与字体'],
          ['Wallpaper', '壁纸与主题色'],
          ['hide', '自动隐藏'],
          ['notification', '提醒全局'],
          ['speech', '语音合成'],
          ['weather', '气象服务'],
          ['automation', '自动化'],
          ['plugins', '插件源'],
          ['update', '更新通道'],
          ['storage', '存储备份'],
          ['privacy', '隐私遥测'],
          ['debug', '渲染性能'],
          ['preset', '引导预设生成']
        ], (tab: string[]) => {
          Button(tab[1])
            .height(28)
            .fontSize(11)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.settingsTab === tab[0] ? '#FFFFFF' : this.theme().textPrimary)
            .backgroundColor(this.settingsTab === tab[0] ? this.theme().accentColor : this.theme().bgSubtle)
            .borderRadius(6)
            .onClick(() => {
              this.settingsTab = tab[0];
            })
        }, (tab: string[]) => tab[0])
      }

      if (this.settingsTab === 'general') {
        Column({ space: 6 }) {
          this.buildNumberField('时间偏移秒数', 'TimeOffsetSeconds', 0)
          this.buildSwitchItem('启用精确计时偏移自动校准', '按日自动微调系统时钟偏差', 'IsTimeAutoAdjustEnabled', false)
          this.buildNumberField('每日自动调整秒数', 'TimeAutoAdjustSeconds', 0)
          this.buildSwitchItem('显示启动加载画面', '启动时展示欢迎动画', 'IsSplashEnabled', true)
          this.buildStringField('自定义启动副标题', 'SplashCustomText', '')
          this.buildSwitchItem('显示任务栏托盘图标', '在系统托盘常驻快捷菜单', 'IsShowTaskbarIcon', true)
        }.width('100%')
      } else if (this.settingsTab === 'window') {
        Column({ space: 10 }) {
          Text('可视化屏幕 6 点停靠位置选择器')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
          // 16:9 Screen Monitor Preview with Top 3 & Bottom 3 Docking Pills
          Column() {
            Row({ space: 12 }) {
              ForEach([[0, '左上'], [1, '顶中'], [2, '右上']], (item: (number | string)[]) => {
                Button(String(item[1]))
                  .height(28)
                  .fontSize(11)
                  .layoutWeight(1)
                  .fontColor(Number(this.parsedRoot['WindowDockingLocation'] ?? 1) === Number(item[0]) ? '#FFFFFF' : this.theme().textPrimary)
                  .backgroundColor(Number(this.parsedRoot['WindowDockingLocation'] ?? 1) === Number(item[0]) ? this.theme().accentColor : this.theme().bgCard)
                  .borderRadius(6)
                  .onClick(() => {
                    this.parsedRoot['WindowDockingLocation'] = Number(item[0]);
                    this.commitRoot();
                  })
              }, (item: (number | string)[]) => `top_${item[0]}`)
            }.width('100%')

            Blank()
            Text('主屏幕区域预览')
              .fontSize(11)
              .fontColor(this.theme().textSecondary)
            Blank()

            Row({ space: 12 }) {
              ForEach([[3, '左下'], [4, '底中'], [5, '右下']], (item: (number | string)[]) => {
                Button(String(item[1]))
                  .height(28)
                  .fontSize(11)
                  .layoutWeight(1)
                  .fontColor(Number(this.parsedRoot['WindowDockingLocation'] ?? 1) === Number(item[0]) ? '#FFFFFF' : this.theme().textPrimary)
                  .backgroundColor(Number(this.parsedRoot['WindowDockingLocation'] ?? 1) === Number(item[0]) ? this.theme().accentColor : this.theme().bgCard)
                  .borderRadius(6)
                  .onClick(() => {
                    this.parsedRoot['WindowDockingLocation'] = Number(item[0]);
                    this.commitRoot();
                  })
              }, (item: (number | string)[]) => `bot_${item[0]}`)
            }.width('100%')
          }
          .width('100%')
          .height(140)
          .padding(14)
          .backgroundColor(this.theme().bgSubtle)
          .borderRadius(10)
          .border({ width: 2, color: this.theme().borderColor })

          this.buildNumberField('水平停靠偏移量', 'WindowDockingOffsetX', 0)
          this.buildNumberField('垂直停靠偏移量', 'WindowDockingOffsetY', 0)
          this.buildNumberField('窗口层级', 'WindowLayer', 1)
          this.buildNumberField('目标显示器索引', 'WindowDockingMonitorIndex', 0)
          this.buildSwitchItem('启用鼠标穿透点击', '鼠标点击穿过主界面到达底层窗口', 'IsMouseClickingThroughEnabled', false)
        }.width('100%')
      } else if (this.settingsTab === 'appearance') {
        Column({ space: 6 }) {
          this.buildNumberField('明暗主题', 'Theme', 0)
          this.buildNumberField('全局界面缩放比例', 'Scale', 1.0)
          this.buildNumberField('背景不透明度', 'Opacity', 0.85)
          this.buildNumberField('主界面圆角半径', 'Radius', 8)
          this.buildNumberField('组件行间距', 'MainWindowLineVerticalMargin', 4)
          this.buildStringField('自定义主字体名称', 'MainWindowFont', 'HarmonyOS Sans SC')
          this.buildNumberField('次要字号', 'MainWindowSecondaryFontSize', 14)
          this.buildNumberField('正文字号', 'MainWindowBodyFontSize', 16)
          this.buildNumberField('强调字号', 'MainWindowEmphasizedFontSize', 18)
          this.buildNumberField('大标题字号', 'MainWindowLargeFontSize', 20)
        }.width('100%')
      } else if (this.settingsTab === 'Wallpaper') {
        Column({ space: 6 }) {
          this.buildNumberField('主题色来源', 'ColorSource', 0)
          this.buildStringField('主色调颜色值', 'PrimaryColor', '#0078D4')
          this.buildStringField('次色调颜色值', 'SecondaryColor', '#2B88D8')
          this.buildNumberField('壁纸取色自动刷新间隔 (秒)', 'WallpaperAutoUpdateIntervalSeconds', 60)
        }.width('100%')
      } else if (this.settingsTab === 'hide') {
        Column({ space: 6 }) {
          this.buildNumberField('隐藏策略模式', 'HideMode', 0)
          this.buildSwitchItem('上课时自动隐藏主界面', '进入上课时间段时自动收起顶栏', 'HideOnClass', false)
          this.buildSwitchItem('前台全屏程序时自动隐藏', '检测到全屏应用或演示文稿时隐藏', 'HideOnFullscreen', false)
          this.buildSwitchItem('前台窗口最大化时自动隐藏', '检测到最大化窗口时隐藏', 'HideOnMaxWindow', false)
        }.width('100%')
      } else if (this.settingsTab === 'notification') {
        Column({ space: 6 }) {
          this.buildSwitchItem('启用全局提醒通知', '允许显示课堂与集控横幅提醒', 'IsNotificationEnabled', true)
          this.buildSwitchItem('启用提醒醒目动画特效', '展示全屏波纹与横幅过渡动画', 'IsNotificationEffectEnabled', true)
          this.buildSwitchItem('启用提醒提示音效', '播放上下课与通知提示音', 'IsNotificationSoundEnabled', true)
          this.buildNumberField('通知音效音量', 'NotificationSoundVolume', 1.0)
          this.buildSwitchItem('提醒期间强制置顶主窗口', '通知展示时置于屏幕最顶层', 'IsNotificationTopmostEnabled', true)
        }.width('100%')
      } else if (this.settingsTab === 'speech') {
        Column({ space: 6 }) {
          this.buildSwitchItem('启用语音播报', '使用语音引擎朗读通知内容', 'IsSpeechEnabled', true)
          this.buildNumberField('语音引擎', 'SpeechSource', 0)
          this.buildNumberField('语音播报音量', 'SpeechVolume', 1.0)
          this.buildStringField('EdgeTTS 发音人标识', 'EdgeTtsVoiceName', 'zh-CN-XiaoxiaoNeural')
        }.width('100%')
      } else if (this.settingsTab === 'weather') {
        Column({ space: 6 }) {
          this.buildStringField('城市编码', 'CityId', '101010100')
          this.buildStringField('城市名称', 'CityName', '北京')
          this.buildNumberField('气象数据自动刷新分钟数', 'WeatherAutoRefreshIntervalMinutes', 30)
          this.buildSwitchItem('启用气象灾害预警弹窗提醒', '收到极端天气预警时自动弹窗', 'IsWeatherAlertEnabled', true)
        }.width('100%')
      } else if (this.settingsTab === 'automation') {
        Column({ space: 6 }) {
          this.buildSwitchItem('启用自动化引擎', '允许按时间点或事件执行自动化动作', 'IsAutomationEnabled', true)
          this.buildStringField('当前激活自动化配置方案', 'CurrentAutomationConfig', 'default')
        }.width('100%')
      } else if (this.settingsTab === 'plugins') {
        Column({ space: 6 }) {
          this.buildStringField('插件市场镜像源地址', 'PluginIndexMirrorUrl', 'https://plugins.classisland.tech')
          this.buildSwitchItem('自动检查插件更新', '启动时自动检测已安装插件新版本', 'IsPluginAutoUpdateEnabled', true)
        }.width('100%')
      } else if (this.settingsTab === 'update') {
        Column({ space: 6 }) {
          this.buildNumberField('更新模式', 'UpdateMode', 1)
          this.buildStringField('更新通道标识', 'SelectedUpdateChannelV2', 'stable')
        }.width('100%')
      } else if (this.settingsTab === 'storage') {
        Column({ space: 6 }) {
          this.buildSwitchItem('启用本地档案自动备份', '定期备份本地配置档案文件', 'IsAutoBackupEnabled', true)
          this.buildNumberField('自动备份保留份数上限', 'AutoBackupLimit', 16)
        }.width('100%')
      } else if (this.settingsTab === 'privacy') {
        Column({ space: 6 }) {
          this.buildSwitchItem('允许崩溃诊断信息上传', '帮助改进稳定性', 'IsSentryEnabled', true)
          this.buildSwitchItem('允许匿名使用统计', '收集基础功能使用频次', 'IsReportingEnabled', true)
        }.width('100%')
      } else if (this.settingsTab === 'debug') {
        Column({ space: 6 }) {
          this.buildSwitchItem('启用硬件加速渲染', '使用 GPU 加速界面绘制', 'IsHardwareAccelerationEnabled', true)
          this.buildSwitchItem('低性能设备兼容模式', '降低动画帧率与模糊特效', 'IsCompatibleWindowTransparentEnabled', false)
        }.width('100%')
      } else if (this.settingsTab === 'preset') {
        Column({ space: 8 }) {
          Text('ManagementPreset.json 集控引导预设生成器')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().accentColor)
          Row({ space: 8 }) {
            TextInput({ placeholder: '可选预设班级标识', text: this.presetClassIdentity })
              .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
              .onChange((v: string) => { this.presetClassIdentity = v; })
            HmosIconTextButton(
              $r('sys.symbol.folder'),
              '生成预设配置',
              '#FFFFFF',
              this.theme().accentColor,
              Color.Transparent,
              async () => {
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
              },
              34,
              12
            )
          }
          if (this.generatedPresetJson.length > 0) {
            TextArea({ text: this.generatedPresetJson })
              .height(110).fontSize(11).fontFamily('monospace')
              .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgCard)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.theme().bgSubtle)
        .borderRadius(8)
      }
    }
    .width('100%')
  }

  // ==================== 6. COMPONENTS EDITOR (11 Real Upstream Components + Container Drill-Down + 4 Tabs) ====================
  private getLines(): Record<string, Object>[] {
    return ((this.parsedRoot['Lines'] || []) as Record<string, Object>[]);
  }

  private getActiveLineChildren(): Record<string, Object>[] {
    const lines = this.getLines();
    if (this.selectedLineIdx < 0 || this.selectedLineIdx >= lines.length) {
      return [];
    }
    return ((lines[this.selectedLineIdx]['Children'] || []) as Record<string, Object>[]);
  }

  @Builder
  buildComponentsEditor() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(`共 ${this.getLines().length} 个主界面组件行`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)

        HmosIconTextButton(
          $r('sys.symbol.plus'),
          '新增组件行',
          '#FFFFFF',
          this.theme().accentColor,
          Color.Transparent,
          () => {
            const lines = this.getLines().slice();
            lines.push({
              'Children': [],
              'IsMainLine': lines.length === 0,
              'IsEnabled': true,
              'IslandSeparationMode': 0
            });
            this.parsedRoot['Lines'] = lines;
            this.selectedLineIdx = lines.length - 1;
            this.selectedCompIdx = -1;
            this.commitRoot();
          },
          30,
          12
        )
      }
      .width('100%')

      // Line selector pills
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.getLines(), (line: Record<string, Object>, lIdx: number) => {
          Button(`第 ${lIdx + 1} 行 ${Boolean(line['IsMainLine']) ? '[主行]' : ''} (${((line['Children'] || []) as Object[]).length})`)
            .height(28)
            .fontSize(12)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.selectedLineIdx === lIdx ? this.theme().accentColor : this.theme().textPrimary)
            .backgroundColor(this.selectedLineIdx === lIdx ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
            .border({
              width: 1,
              color: this.selectedLineIdx === lIdx ? this.theme().accentColor : this.theme().borderColor,
              radius: 6
            })
            .onClick(() => {
              this.selectedLineIdx = lIdx;
              this.selectedCompIdx = -1;
            })
        }, (_line: Record<string, Object>, lIdx: number) => `line_${lIdx}`)
      }

      if (this.getLines().length > 0 && this.selectedLineIdx < this.getLines().length) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text('启用该行').fontSize(12).fontColor(this.theme().textPrimary)
            Toggle({
              type: ToggleType.Switch,
              isOn: Boolean(this.getLines()[this.selectedLineIdx]['IsEnabled'] !== false)
            })
              .onChange((v: boolean) => {
                const lines = this.getLines();
                lines[this.selectedLineIdx]['IsEnabled'] = v;
                this.commitRoot();
              })

            Text('设为主行').fontSize(12).fontColor(this.theme().textPrimary)
            Toggle({
              type: ToggleType.Switch,
              isOn: Boolean(this.getLines()[this.selectedLineIdx]['IsMainLine'])
            })
              .onChange((v: boolean) => {
                const lines = this.getLines();
                lines[this.selectedLineIdx]['IsMainLine'] = v;
                this.commitRoot();
              })

            Blank()
            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              this.theme().borderColor,
              () => {
                const lines = this.getLines().slice();
                lines.splice(this.selectedLineIdx, 1);
                this.parsedRoot['Lines'] = lines;
                this.selectedLineIdx = 0;
                this.selectedCompIdx = -1;
                this.commitRoot();
              },
              28,
              14
            )
          }
          .width('100%')

          // Active line components list
          ForEach(this.getActiveLineChildren(), (comp: Record<string, Object>, cIdx: number) => {
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(`${cIdx + 1}. ${String(comp['NameCache'] || findComponentDef(String(comp['Id'] || ''))?.name || '组件')}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textPrimary)
                Text(`对齐: ${['左对齐', '居中', '右对齐', '拉伸'][Number(comp['HorizontalAlignment'] ?? 1)] || '居中'}${findComponentDef(String(comp['Id'] || ''))?.isContainer ? ' · 容器组件' : ''}`)
                  .fontSize(11)
                  .fontColor(this.theme().textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('切换对齐')
                .height(26)
                .fontSize(11)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgSubtle)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onClick(() => {
                  comp['HorizontalAlignment'] = (Number(comp['HorizontalAlignment'] ?? 1) + 1) % 4;
                  this.commitRoot();
                })

              HmosIconButton(
                $r('sys.symbol.arrow_up'),
                this.theme().textPrimary,
                this.theme().bgSubtle,
                this.theme().borderColor,
                () => {
                  if (cIdx > 0) {
                    const ch = this.getActiveLineChildren().slice();
                    const tmp = ch[cIdx - 1];
                    ch[cIdx - 1] = ch[cIdx];
                    ch[cIdx] = tmp;
                    this.getLines()[this.selectedLineIdx]['Children'] = ch;
                    this.commitRoot();
                  }
                },
                26,
                12
              )

              HmosIconButton(
                $r('sys.symbol.arrow_down'),
                this.theme().textPrimary,
                this.theme().bgSubtle,
                this.theme().borderColor,
                () => {
                  const ch = this.getActiveLineChildren().slice();
                  if (cIdx < ch.length - 1) {
                    const tmp = ch[cIdx + 1];
                    ch[cIdx + 1] = ch[cIdx];
                    ch[cIdx] = tmp;
                    this.getLines()[this.selectedLineIdx]['Children'] = ch;
                    this.commitRoot();
                  }
                },
                26,
                12
              )

              HmosIconButton(
                $r('sys.symbol.trash'),
                this.theme().dangerColor,
                Color.Transparent,
                Color.Transparent,
                () => {
                  const ch = this.getActiveLineChildren().slice();
                  ch.splice(cIdx, 1);
                  this.getLines()[this.selectedLineIdx]['Children'] = ch;
                  if (this.selectedCompIdx === cIdx) {
                    this.selectedCompIdx = -1;
                  }
                  this.commitRoot();
                },
                26,
                13
              )
            }
            .width('100%')
            .padding(10)
            .backgroundColor(this.selectedCompIdx === cIdx ? this.theme().bgAccentSubtle : this.theme().bgCard)
            .borderRadius(6)
            .border({
              width: 1,
              color: this.selectedCompIdx === cIdx ? this.theme().accentColor : this.theme().borderColor
            })
            .onClick(() => {
              this.selectedCompIdx = cIdx;
              this.compInspectorTab = 'settings';
            })
          }, (_c: Record<string, Object>, cIdx: number) => `comp_${cIdx}`)

          // 4 Right-Pane Inspector Tabs: 组件库 | 组件设置 | 高级外观设置 | 布局与行配置
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach([
              ['lib', '组件库'],
              ['settings', '组件专属设置'],
              ['advanced', '高级外观与宽度'],
              ['layout', '岛分离与行布局']
            ], (t: string[]) => {
              Button(t[1])
                .height(28).fontSize(11).margin({ right: 6, bottom: 6 })
                .fontColor(this.compInspectorTab === t[0] ? '#FFFFFF' : this.theme().textPrimary)
                .backgroundColor(this.compInspectorTab === t[0] ? this.theme().accentColor : this.theme().bgSubtle)
                .borderRadius(6)
                .onClick(() => { this.compInspectorTab = t[0]; })
            }, (t: string[]) => t[0])
          }

          if (this.compInspectorTab === 'lib') {
            Column({ space: 6 }) {
              ForEach(BUILTIN_COMPONENTS, (def: BuiltinComponentDef) => {
                Row({ space: 8 }) {
                  Column({ space: 2 }) {
                    Text(`${def.name}${def.isContainer ? ' [容器]' : ''}`)
                      .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
                    Text(def.desc).fontSize(11).fontColor(this.theme().textSecondary)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  HmosIconTextButton(
                    $r('sys.symbol.plus'),
                    '添加',
                    '#FFFFFF',
                    this.theme().accentColor,
                    Color.Transparent,
                    () => {
                      const ch = this.getActiveLineChildren().slice();
                      const emptyChildren: Record<string, Object>[] = [];
                      const initSettings: Record<string, Object> = def.isContainer ? { 'Children': emptyChildren } : {};
                      const newComp: Record<string, Object> = {
                        'Id': def.id,
                        'NameCache': def.name,
                        'HorizontalAlignment': 1,
                        'Settings': initSettings
                      };
                      ch.push(newComp);
                      this.getLines()[this.selectedLineIdx]['Children'] = ch;
                      this.selectedCompIdx = ch.length - 1;
                      this.commitRoot();
                    },
                    28,
                    11
                  )
                }
                .width('100%')
                .padding(8)
                .backgroundColor(this.theme().bgSubtle)
                .borderRadius(6)
              }, (def: BuiltinComponentDef) => def.id)
            }
          } else if (this.compInspectorTab === 'settings') {
            if (this.selectedCompIdx < 0 || this.selectedCompIdx >= this.getActiveLineChildren().length) {
              Text('请先在上方点击选中一个已添加的组件以配置其专属参数')
                .fontSize(12).fontColor(this.theme().textSecondary).padding(12)
            } else {
              this.buildSelectedComponentSettings(this.getActiveLineChildren()[this.selectedCompIdx])
            }
          } else if (this.compInspectorTab === 'advanced') {
            if (this.selectedCompIdx < 0 || this.selectedCompIdx >= this.getActiveLineChildren().length) {
              Text('请先点击选中一个组件以调整其字号覆盖、颜色与固定宽度')
                .fontSize(12).fontColor(this.theme().textSecondary).padding(12)
            } else {
              this.buildSelectedComponentAdvanced(this.getActiveLineChildren()[this.selectedCompIdx])
            }
          } else {
            Column({ space: 6 }) {
              Text('组件行岛分离模式')
                .fontSize(12).fontColor(this.theme().textPrimary)
              Row({ space: 6 }) {
                ForEach([0, 1, 2], (mode: number) => {
                  Button(['继承默认', '合并显示', '分离多岛'][mode])
                    .height(28).fontSize(11)
                    .fontColor(Number(this.getLines()[this.selectedLineIdx]['IslandSeparationMode'] || 0) === mode ? '#FFFFFF' : this.theme().textPrimary)
                    .backgroundColor(Number(this.getLines()[this.selectedLineIdx]['IslandSeparationMode'] || 0) === mode ? this.theme().accentColor : this.theme().bgSubtle)
                    .borderRadius(4)
                    .onClick(() => {
                      this.getLines()[this.selectedLineIdx]['IslandSeparationMode'] = mode;
                      this.commitRoot();
                    })
                }, (mode: number) => `sep_${mode}`)
              }
            }
          }
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  buildSelectedComponentSettings(comp: Record<string, Object>) {
    Column({ space: 8 }) {
      Text(`当前组件: ${String(comp['NameCache'] || '组件')}`)
        .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme().accentColor)

      // LessonControl (7c645d35-8151-48ba-b4ac-15017460d994)
      if (normalizeComponentId(String(comp['Id'] || '')) === '7c645d35-8151-48ba-b4ac-15017460d994') {
        Row() {
          Text('展示附加信息（如下节课时间）').fontSize(12).fontColor(this.theme().textPrimary).layoutWeight(1)
          Toggle({
            type: ToggleType.Switch,
            isOn: Boolean(((comp['Settings'] || {}) as Record<string, Object>)['ShowExtraInfoOnTimePoint'] !== false)
          }).onChange((v: boolean) => {
            const st = ((comp['Settings'] || {}) as Record<string, Object>);
            st['ShowExtraInfoOnTimePoint'] = v;
            comp['Settings'] = st;
            this.commitRoot();
          })
        }.width('100%')
      }

      // Clock (9812679e-482b-4729-8854-02d20999290d)
      if (normalizeComponentId(String(comp['Id'] || '')) === '9812679e-482b-4729-8854-02d20999290d') {
        Row() {
          Text('显示秒针数字').fontSize(12).fontColor(this.theme().textPrimary).layoutWeight(1)
          Toggle({
            type: ToggleType.Switch,
            isOn: Boolean(((comp['Settings'] || {}) as Record<string, Object>)['ShowSeconds'])
          }).onChange((v: boolean) => {
            const st = ((comp['Settings'] || {}) as Record<string, Object>);
            st['ShowSeconds'] = v;
            comp['Settings'] = st;
            this.commitRoot();
          })
        }.width('100%')
      }

      // CountDown (54e81232-9f91-4526-851d-4d5f05079438)
      if (normalizeComponentId(String(comp['Id'] || '')) === '54e81232-9f91-4526-851d-4d5f05079438') {
        Row({ space: 6 }) {
          Text('倒计时事件名称:').fontSize(12).fontColor(this.theme().textPrimary)
          TextInput({ text: String(((comp['Settings'] || {}) as Record<string, Object>)['CountDownName'] || '高考') })
            .height(32).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => {
              const st = ((comp['Settings'] || {}) as Record<string, Object>);
              st['CountDownName'] = v;
              comp['Settings'] = st;
              this.commitRoot();
            })
        }.width('100%')
        Row({ space: 6 }) {
          Text('目标日期:').fontSize(12).fontColor(this.theme().textPrimary)
          TextInput({ text: String(((comp['Settings'] || {}) as Record<string, Object>)['OverTime'] || '2026-06-07') })
            .height(32).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => {
              const st = ((comp['Settings'] || {}) as Record<string, Object>);
              st['OverTime'] = v;
              comp['Settings'] = st;
              this.commitRoot();
            })
        }.width('100%')
      }

      // Text Component (df3f8295-21f6-482e-ada2-f0ab5f19a9d6)
      if (normalizeComponentId(String(comp['Id'] || '')) === 'df3f8295-21f6-482e-ada2-f0ab5f19a9d6') {
        Row({ space: 6 }) {
          Text('自定义文本内容:').fontSize(12).fontColor(this.theme().textPrimary)
          TextInput({ text: String(((comp['Settings'] || {}) as Record<string, Object>)['TextContent'] || '') })
            .height(32).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => {
              const st = ((comp['Settings'] || {}) as Record<string, Object>);
              st['TextContent'] = v;
              comp['Settings'] = st;
              this.commitRoot();
            })
        }.width('100%')
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(this.theme().bgSubtle)
    .borderRadius(8)
  }

  @Builder
  buildSelectedComponentAdvanced(comp: Record<string, Object>) {
    Column({ space: 8 }) {
      Row() {
        Text('按条件自动隐藏组件').fontSize(12).fontColor(this.theme().textPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: Boolean(comp['HideOnRule']) })
          .onChange((v: boolean) => {
            comp['HideOnRule'] = v;
            this.commitRoot();
          })
      }.width('100%')

      Row() {
        Text('启用固定宽度').fontSize(12).fontColor(this.theme().textPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: Boolean(comp['IsFixedWidthEnabled']) })
          .onChange((v: boolean) => {
            comp['IsFixedWidthEnabled'] = v;
            this.commitRoot();
          })
      }.width('100%')

      if (Boolean(comp['IsFixedWidthEnabled'])) {
        Row({ space: 6 }) {
          Text('固定宽度像素值:').fontSize(12).fontColor(this.theme().textPrimary)
          TextInput({ text: `${Number(comp['FixedWidth'] || 200)}` })
            .height(32).width(90).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => {
              const n = Number(v);
              if (!isNaN(n)) {
                comp['FixedWidth'] = n;
                this.commitRoot();
              }
            })
        }.width('100%')
      }

      Row() {
        Text('启用自定义前景色').fontSize(12).fontColor(this.theme().textPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: Boolean(comp['IsCustomForegroundColorEnabled']) })
          .onChange((v: boolean) => {
            comp['IsCustomForegroundColorEnabled'] = v;
            this.commitRoot();
          })
      }.width('100%')

      if (Boolean(comp['IsCustomForegroundColorEnabled'])) {
        Row({ space: 6 }) {
          Text('前景色值:').fontSize(12).fontColor(this.theme().textPrimary)
          TextInput({ text: String(comp['ForegroundColor'] || '#FFFFFF') })
            .height(32).width(110).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 })
            .onChange((v: string) => {
              comp['ForegroundColor'] = v;
              this.commitRoot();
            })
        }.width('100%')
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(this.theme().bgSubtle)
    .borderRadius(8)
  }

  // ==================== 7. CREDENTIALS EDITOR (/credentials/encode + 9 Authorize Levels) ====================
  @Builder
  buildAuthLevelRow(label: string, fieldKey: string) {
    Row({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.theme().textPrimary)
        .layoutWeight(1)
      ForEach([0, 1, 2], (lv: number) => {
        Button(['无限制', '用户凭据', '管理员凭据'][lv])
          .height(26)
          .fontSize(11)
          .fontColor(Number(this.parsedRoot[fieldKey] || 0) === lv ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(Number(this.parsedRoot[fieldKey] || 0) === lv ? this.theme().accentColor : this.theme().bgSubtle)
          .borderRadius(4)
          .onClick(() => {
            this.parsedRoot[fieldKey] = lv;
            this.commitRoot();
          })
      }, (lv: number) => `lv_${fieldKey}_${lv}`)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: this.theme().borderSubtle })
  }

  @Builder
  buildCredentialsEditor() {
    Column({ space: 10 }) {
      Column({ space: 6 }) {
        Text('用户凭据密码哈希生成')
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
        Row({ space: 6 }) {
          TextInput({ placeholder: '输入明文密码以生成加盐哈希', text: this.plainUserPassword })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.plainUserPassword = v; })
          Button('生成哈希')
            .height(34).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
            .onClick(async () => {
              if (!this.plainUserPassword) { return; }
              const r = await ApiService.get().encodePasswordCredential(this.accountId, this.plainUserPassword);
              if (r.ok && r.data) {
                this.parsedRoot['UserCredential'] = r.data;
                this.commitRoot();
                this.onStatusFeedback('已生成用户凭据哈希', false);
              }
            })
        }
        Text(`当前值: ${String(this.parsedRoot['UserCredential'] || '（未设置）')}`)
          .fontSize(11).fontColor(this.theme().textSecondary)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)

      Column({ space: 6 }) {
        Text('管理员凭据密码哈希生成')
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
        Row({ space: 6 }) {
          TextInput({ placeholder: '输入管理员明文密码', text: this.plainAdminPassword })
            .height(34).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
            .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
            .onChange((v: string) => { this.plainAdminPassword = v; })
          Button('生成哈希')
            .height(34).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.theme().accentColor).borderRadius(4)
            .onClick(async () => {
              if (!this.plainAdminPassword) { return; }
              const r = await ApiService.get().encodePasswordCredential(this.accountId, this.plainAdminPassword);
              if (r.ok && r.data) {
                this.parsedRoot['AdminCredential'] = r.data;
                this.commitRoot();
                this.onStatusFeedback('已生成管理员凭据哈希', false);
              }
            })
        }
        Text(`当前值: ${String(this.parsedRoot['AdminCredential'] || '（未设置）')}`)
          .fontSize(11).fontColor(this.theme().textSecondary)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.theme().bgSubtle)
      .borderRadius(8)

      this.buildAuthLevelRow('编辑档案权限', 'EditProfileAuthorizeLevel')
      this.buildAuthLevelRow('编辑策略权限', 'EditPolicyAuthorizeLevel')
      this.buildAuthLevelRow('退出集控权限', 'ExitManagementAuthorizeLevel')
      this.buildAuthLevelRow('修改应用设置权限', 'EditSettingsAuthorizeLevel')
      this.buildAuthLevelRow('切换档案权限', 'SwitchProfileAuthorizeLevel')
      this.buildAuthLevelRow('创建临时层权限', 'TempOverlayClassPlanAuthorizeLevel')
      this.buildAuthLevelRow('调整时间偏移权限', 'ChangeTimeOffsetAuthorizeLevel')
      this.buildAuthLevelRow('退出应用权限', 'ExitApplicationAuthorizeLevel')
      this.buildAuthLevelRow('重启应用权限', 'RestartApplicationAuthorizeLevel')
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.lastInputJson !== this.rawJsonText) {
        Row().height(0).onAppear(() => {
          this.syncFromInputJson();
        })
      }

      if (this.resourceType === 'Policy') {
        this.buildPolicyEditor()
      } else if (this.resourceType === 'DefaultSettings') {
        this.buildDefaultSettingsEditor()
      } else if (this.resourceType === 'Components') {
        this.buildComponentsEditor()
      } else {
        this.buildCredentialsEditor()
      }
    }
    .width('100%')
  }
}
