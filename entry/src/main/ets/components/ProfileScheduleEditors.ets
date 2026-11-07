import {
  SubjectEntry,
  TimeLayoutGroup,
  TimeLayoutPoint,
  BUILTIN_ACTIONS,
  BuiltinActionDef,
  EMPTY_GUID,
  generateUuid,
  extractIsoTimePart
} from '../model/Types';
import { WebThemePalette, getWebPalette } from '../model/Theme';
import { HmosIconButton, HmosIconTextButton } from './HmosIcons';

@Component
export struct ProfileScheduleEditors {
  @Prop resourceType: string = 'Subjects'; // 'Subjects' | 'TimeLayout' | 'ClassPlan'
  @Prop rawJsonText: string = '{}';
  @Prop refSubjectsMap: SubjectEntry[] = [];
  @Prop refTimeLayoutsMap: TimeLayoutGroup[] = [];
  @Prop themeMode: string = 'light';
  public onJsonMutated: (nextJson: string) => void = () => {};

  @State parsedRoot: Record<string, Object> = {};
  @State selectedTlKey: string = '';
  @State selectedTlPointIdx: number = 0;

  @State selectedGroupKey: string = EMPTY_GUID;
  @State selectedPlanKey: string = '';
  @State selectedClassSlotIdx: number = 0;
  @State autoMoveNextSlot: boolean = true;
  @State newGroupName: string = '';

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
    if (this.resourceType === 'TimeLayout') {
      const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Object>;
      const keys = Object.keys(tls);
      if (keys.length > 0 && (!this.selectedTlKey || !tls[this.selectedTlKey])) {
        this.selectedTlKey = keys[0];
        this.selectedTlPointIdx = 0;
      }
    } else if (this.resourceType === 'ClassPlan') {
      const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Object>;
      const keys = Object.keys(cps);
      if (keys.length > 0 && (!this.selectedPlanKey || !cps[this.selectedPlanKey])) {
        this.selectedPlanKey = keys[0];
        this.selectedClassSlotIdx = 0;
      }
    }
  }

  private commitRoot(): void {
    const nextStr = JSON.stringify(this.parsedRoot, null, 2);
    this.lastInputJson = nextStr;
    this.onJsonMutated(nextStr);
  }

  // ==================== 1. SUBJECTS EDITOR ====================
  @Builder
  buildSubjectsEditor() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(`共 ${Object.keys((this.parsedRoot['Subjects'] || {}) as Record<string, Object>).length} 门科目`)
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .layoutWeight(1)

        HmosIconTextButton(
          $r('sys.symbol.plus'),
          '添加科目',
          '#FFFFFF',
          this.theme().accentColor,
          Color.Transparent,
          () => {
            const subs = ((this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>);
            const newId = generateUuid();
            const emptyAttached: Record<string, Object> = {};
            const newSub: Record<string, Object> = {
              'Name': '新科目',
              'Initial': '新',
              'TeacherName': '',
              'IsOutDoor': false,
              'AttachedObjects': emptyAttached
            };
            subs[newId] = newSub;
            this.parsedRoot['Subjects'] = subs;
            this.commitRoot();
          },
          32,
          12
        )
      }
      .width('100%')

      ForEach(Object.keys((this.parsedRoot['Subjects'] || {}) as Record<string, Object>), (subKey: string, idx: number) => {
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Text(
              String((((this.parsedRoot['Subjects'] as Record<string, Record<string, Object>>)[subKey] || {})['Initial']) ||
                String((((this.parsedRoot['Subjects'] as Record<string, Record<string, Object>>)[subKey] || {})['Name']) || '?').substring(0, 1))
            )
              .width(38)
              .height(38)
              .textAlign(TextAlign.Center)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor(
                Boolean(((this.parsedRoot['Subjects'] as Record<string, Record<string, Object>>)[subKey] || {})['IsOutDoor'])
                  ? this.theme().successColor
                  : this.theme().accentColor
              )
              .borderRadius(8)

            Column({ space: 4 }) {
              Text('科目名称').fontSize(11).fontColor(this.theme().textSecondary)
              TextInput({
                placeholder: '科目名称',
                text: String(((this.parsedRoot['Subjects'] as Record<string, Record<string, Object>>)[subKey] || {})['Name'] || '')
              })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => {
                  const subs = (this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>;
                  if (subs[subKey]) {
                    subs[subKey]['Name'] = v;
                    if (!subs[subKey]['Initial'] && v.length > 0) {
                      subs[subKey]['Initial'] = v.substring(0, 1);
                    }
                    this.commitRoot();
                  }
                })
            }.alignItems(HorizontalAlign.Start).layoutWeight(2)

            Column({ space: 4 }) {
              Text('简称').fontSize(11).fontColor(this.theme().textSecondary)
              TextInput({
                placeholder: '简称',
                text: String(((this.parsedRoot['Subjects'] as Record<string, Record<string, Object>>)[subKey] || {})['Initial'] || '')
              })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => {
                  const subs = (this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>;
                  if (subs[subKey]) {
                    subs[subKey]['Initial'] = v;
                    this.commitRoot();
                  }
                })
            }.alignItems(HorizontalAlign.Start).width(76)

            Column({ space: 4 }) {
              Text('任课教师').fontSize(11).fontColor(this.theme().textSecondary)
              TextInput({
                placeholder: '可选',
                text: String(((this.parsedRoot['Subjects'] as Record<string, Record<string, Object>>)[subKey] || {})['TeacherName'] || '')
              })
                .height(34)
                .fontSize(13)
                .fontColor(this.theme().textPrimary)
                .backgroundColor(this.theme().bgInput)
                .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                .onChange((v: string) => {
                  const subs = (this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>;
                  if (subs[subKey]) {
                    subs[subKey]['TeacherName'] = v;
                    this.commitRoot();
                  }
                })
            }.alignItems(HorizontalAlign.Start).layoutWeight(2)
          }
          .width('100%')

          Row({ space: 8 }) {
            Text('户外课程')
              .fontSize(12)
              .fontColor(this.theme().textPrimary)
            Toggle({
              type: ToggleType.Switch,
              isOn: Boolean(((this.parsedRoot['Subjects'] as Record<string, Record<string, Object>>)[subKey] || {})['IsOutDoor'])
            })
              .onChange((val: boolean) => {
                const subs = (this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>;
                if (subs[subKey]) {
                  subs[subKey]['IsOutDoor'] = val;
                  this.commitRoot();
                }
              })

            Blank()

            HmosIconButton(
              $r('sys.symbol.arrow_up'),
              this.theme().textPrimary,
              this.theme().bgSubtle,
              this.theme().borderColor,
              () => {
                const subs = (this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>;
                const keys = Object.keys(subs);
                if (idx > 0) {
                  const reordered: Record<string, Record<string, Object>> = {};
                  const tmp = keys[idx - 1];
                  keys[idx - 1] = keys[idx];
                  keys[idx] = tmp;
                  for (let k = 0; k < keys.length; k++) {
                    reordered[keys[k]] = subs[keys[k]];
                  }
                  this.parsedRoot['Subjects'] = reordered;
                  this.commitRoot();
                }
              },
              28,
              13
            )

            HmosIconButton(
              $r('sys.symbol.arrow_down'),
              this.theme().textPrimary,
              this.theme().bgSubtle,
              this.theme().borderColor,
              () => {
                const subs = (this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>;
                const keys = Object.keys(subs);
                if (idx < keys.length - 1) {
                  const reordered: Record<string, Record<string, Object>> = {};
                  const tmp = keys[idx + 1];
                  keys[idx + 1] = keys[idx];
                  keys[idx] = tmp;
                  for (let k = 0; k < keys.length; k++) {
                    reordered[keys[k]] = subs[keys[k]];
                  }
                  this.parsedRoot['Subjects'] = reordered;
                  this.commitRoot();
                }
              },
              28,
              13
            )

            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              this.theme().borderColor,
              () => {
                const subs = (this.parsedRoot['Subjects'] || {}) as Record<string, Record<string, Object>>;
                const nextSubs: Record<string, Record<string, Object>> = {};
                const keys = Object.keys(subs);
                for (let k = 0; k < keys.length; k++) {
                  if (keys[k] !== subKey) {
                    nextSubs[keys[k]] = subs[keys[k]];
                  }
                }
                this.parsedRoot['Subjects'] = nextSubs;
                this.commitRoot();
              },
              28,
              13
            )
          }
          .width('100%')
        }
        .padding(12)
        .backgroundColor(this.theme().bgCard)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      }, (subKey: string) => subKey)
    }
    .width('100%')
  }

  // ==================== 2. TIMELAYOUT EDITOR (1:1 with Upstream & Web) ====================
  private addTimePoint(timeType: number): void {
    const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
    const curTl = tls[this.selectedTlKey];
    if (!curTl) { return; }
    const pts = ((curTl['Layouts'] || []) as Record<string, Object>[]).slice();
    let startStr = '08:00:00';
    let endStr = '08:40:00';
    if (pts.length > 0 && this.selectedTlPointIdx >= 0 && this.selectedTlPointIdx < pts.length) {
      const prevEnd = extractIsoTimePart(String(pts[this.selectedTlPointIdx]['EndSecond'] || '08:00:00'));
      startStr = prevEnd;
      endStr = timeType === 2 ? prevEnd : prevEnd;
    }
    const newPt: Record<string, Object> = {
      'StartSecond': startStr,
      'EndSecond': endStr,
      'TimeType': timeType,
      'DefaultClassId': '',
      'IsHideDefault': false,
      'BreakName': timeType === 1 ? '课间休息' : ''
    };
    if (timeType === 3) {
      const emptyActions: Record<string, Object>[] = [];
      const newActionSet: Record<string, Object> = {
        'IsEnabled': true,
        'Name': '自动化行动组',
        'Guid': generateUuid(),
        'IsRevertEnabled': false,
        'Actions': emptyActions
      };
      newPt['ActionSet'] = newActionSet;
    }
    pts.push(newPt);
    curTl['Layouts'] = pts;
    this.selectedTlPointIdx = pts.length - 1;
    this.commitRoot();
  }

  @Builder
  buildTimeLayoutEditor() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('时间表列表:')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Blank()
        HmosIconTextButton(
          $r('sys.symbol.plus'),
          '新建时间表',
          '#FFFFFF',
          this.theme().accentColor,
          Color.Transparent,
          () => {
            const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
            const newId = generateUuid();
            const emptyLayouts: Record<string, Object>[] = [];
            const emptyAttached: Record<string, Object> = {};
            const newTl: Record<string, Object> = {
              'Name': `新时间表 ${Object.keys(tls).length + 1}`,
              'Layouts': emptyLayouts,
              'AttachedObjects': emptyAttached
            };
            tls[newId] = newTl;
            this.parsedRoot['TimeLayouts'] = tls;
            this.selectedTlKey = newId;
            this.selectedTlPointIdx = 0;
            this.commitRoot();
          },
          30,
          12
        )
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(Object.keys((this.parsedRoot['TimeLayouts'] || {}) as Record<string, Object>), (tlKey: string) => {
          Button(
            String((((this.parsedRoot['TimeLayouts'] as Record<string, Record<string, Object>>)[tlKey] || {})['Name']) || '时间表')
          )
            .height(30)
            .fontSize(12)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.selectedTlKey === tlKey ? this.theme().accentColor : this.theme().textPrimary)
            .backgroundColor(this.selectedTlKey === tlKey ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
            .border({
              width: 1,
              color: this.selectedTlKey === tlKey ? this.theme().accentColor : this.theme().borderColor,
              radius: 6
            })
            .onClick(() => {
              this.selectedTlKey = tlKey;
              this.selectedTlPointIdx = 0;
            })
        }, (tlKey: string) => tlKey)
      }

      if (this.selectedTlKey && ((this.parsedRoot['TimeLayouts'] || {}) as Record<string, Object>)[this.selectedTlKey]) {
        Column({ space: 10 }) {
          Row({ space: 6 }) {
            Text('名称:').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({
              text: String((((this.parsedRoot['TimeLayouts'] as Record<string, Record<string, Object>>)[this.selectedTlKey] || {})['Name']) || '')
            })
              .height(32)
              .fontSize(13)
              .fontColor(this.theme().textPrimary)
              .backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 })
              .layoutWeight(1)
              .onChange((v: string) => {
                const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
                if (tls[this.selectedTlKey]) {
                  tls[this.selectedTlKey]['Name'] = v;
                  this.commitRoot();
                }
              })

            HmosIconTextButton(
              $r('sys.symbol.plus'),
              '复制时间表',
              this.theme().textPrimary,
              this.theme().bgSubtle,
              this.theme().borderColor,
              () => {
                const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
                const cur = tls[this.selectedTlKey];
                if (cur) {
                  const copyId = generateUuid();
                  const cloned = JSON.parse(JSON.stringify(cur)) as Record<string, Object>;
                  cloned['Name'] = `${String(cur['Name'] || '时间表')} - 副本`;
                  tls[copyId] = cloned;
                  this.selectedTlKey = copyId;
                  this.commitRoot();
                }
              },
              30,
              11
            )

            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              this.theme().borderColor,
              () => {
                const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
                const nextTls: Record<string, Record<string, Object>> = {};
                const keys = Object.keys(tls);
                for (let k = 0; k < keys.length; k++) {
                  if (keys[k] !== this.selectedTlKey) {
                    nextTls[keys[k]] = tls[keys[k]];
                  }
                }
                this.parsedRoot['TimeLayouts'] = nextTls;
                const remKeys = Object.keys(nextTls);
                this.selectedTlKey = remKeys.length > 0 ? remKeys[0] : '';
                this.commitRoot();
              },
              30,
              14
            )
          }
          .width('100%')

          // Toolbar to add 4 types of TimePoint + sort
          Flex({ wrap: FlexWrap.Wrap }) {
            HmosIconTextButton($r('sys.symbol.plus'), '添加上课', '#FFFFFF', this.theme().accentColor, Color.Transparent, () => { this.addTimePoint(0); }, 28, 11)
            Row().width(6)
            HmosIconTextButton($r('sys.symbol.plus'), '添加课间', '#FFFFFF', this.theme().successColor, Color.Transparent, () => { this.addTimePoint(1); }, 28, 11)
            Row().width(6)
            HmosIconTextButton($r('sys.symbol.plus'), '添加分割线', this.theme().textPrimary, this.theme().bgSubtle, this.theme().borderColor, () => { this.addTimePoint(2); }, 28, 11)
            Row().width(6)
            HmosIconTextButton($r('sys.symbol.plus'), '添加行动', '#FFFFFF', this.theme().warningColor, Color.Transparent, () => { this.addTimePoint(3); }, 28, 11)
            Row().width(6)
            HmosIconTextButton(
              $r('sys.symbol.arrow_clockwise'),
              '按时间排序',
              this.theme().textPrimary,
              this.theme().bgSubtle,
              this.theme().borderColor,
              () => {
                const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
                const cur = tls[this.selectedTlKey];
                if (cur) {
                  const pts = ((cur['Layouts'] || []) as Record<string, Object>[]).slice();
                  pts.sort((a: Record<string, Object>, b: Record<string, Object>) =>
                    extractIsoTimePart(String(a['StartSecond'] || '')).localeCompare(extractIsoTimePart(String(b['StartSecond'] || '')))
                  );
                  cur['Layouts'] = pts;
                  this.commitRoot();
                }
              },
              28,
              11
            )
          }

          // TimePoints List
          ForEach(
            ((((this.parsedRoot['TimeLayouts'] as Record<string, Record<string, Object>>)[this.selectedTlKey] || {})['Layouts']) || []) as Record<string, Object>[],
            (pt: Record<string, Object>, pIdx: number) => {
              Column({ space: 8 }) {
                Row({ space: 6 }) {
                  Text(`#${pIdx + 1}`)
                    .fontSize(12)
                    .fontColor(this.theme().textSecondary)
                    .width(28)

                  ForEach([0, 1, 2, 3], (tt: number) => {
                    Button(['上课', '课间', '分割线', '行动'][tt])
                      .height(24)
                      .fontSize(10)
                      .fontColor(Number(pt['TimeType'] || 0) === tt ? '#FFFFFF' : this.theme().textPrimary)
                      .backgroundColor(
                        Number(pt['TimeType'] || 0) === tt
                          ? (tt === 0 ? this.theme().accentColor : (tt === 1 ? this.theme().successColor : (tt === 2 ? this.theme().textSecondary : this.theme().warningColor)))
                          : this.theme().bgSubtle
                      )
                      .borderRadius(4)
                      .onClick(() => {
                        pt['TimeType'] = tt;
                        if (tt === 3 && !pt['ActionSet']) {
                          const emptyActs: Record<string, Object>[] = [];
                          const initActionSet: Record<string, Object> = {
                            'IsEnabled': true,
                            'Name': '自动化行动组',
                            'Guid': generateUuid(),
                            'IsRevertEnabled': false,
                            'Actions': emptyActs
                          };
                          pt['ActionSet'] = initActionSet;
                        }
                        this.commitRoot();
                      })
                  }, (tt: number) => `tt_${tt}`)

                  Blank()

                  HmosIconButton(
                    $r('sys.symbol.trash'),
                    this.theme().dangerColor,
                    Color.Transparent,
                    Color.Transparent,
                    () => {
                      const tls = (this.parsedRoot['TimeLayouts'] || {}) as Record<string, Record<string, Object>>;
                      const cur = tls[this.selectedTlKey];
                      if (cur) {
                        const pts = ((cur['Layouts'] || []) as Record<string, Object>[]).slice();
                        pts.splice(pIdx, 1);
                        cur['Layouts'] = pts;
                        this.commitRoot();
                      }
                    },
                    26,
                    13
                  )
                }
                .width('100%')

                Row({ space: 6 }) {
                  Text('开始:').fontSize(12).fontColor(this.theme().textSecondary)
                  TextInput({ text: extractIsoTimePart(String(pt['StartSecond'] || '08:00:00')) })
                    .height(32)
                    .fontSize(12)
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgInput)
                    .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                    .layoutWeight(1)
                    .onChange((v: string) => {
                      pt['StartSecond'] = v;
                      if (Number(pt['TimeType'] || 0) === 2 || Number(pt['TimeType'] || 0) === 3) {
                        pt['EndSecond'] = v;
                      }
                      this.commitRoot();
                    })

                  if (Number(pt['TimeType'] || 0) === 0 || Number(pt['TimeType'] || 0) === 1) {
                    Text('结束:').fontSize(12).fontColor(this.theme().textSecondary)
                    TextInput({ text: extractIsoTimePart(String(pt['EndSecond'] || '08:45:00')) })
                      .height(32)
                      .fontSize(12)
                      .fontColor(this.theme().textPrimary)
                      .backgroundColor(this.theme().bgInput)
                      .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                      .layoutWeight(1)
                      .onChange((v: string) => {
                        pt['EndSecond'] = v;
                        this.commitRoot();
                      })
                  }

                  Text('默认隐藏').fontSize(11).fontColor(this.theme().textSecondary)
                  Toggle({ type: ToggleType.Switch, isOn: Boolean(pt['IsHideDefault']) })
                    .onChange((v: boolean) => {
                      pt['IsHideDefault'] = v;
                      this.commitRoot();
                    })
                }
                .width('100%')

                // Type 0: DefaultSubject selector
                if (Number(pt['TimeType'] || 0) === 0 && this.refSubjectsMap.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    Text('默认科目:').fontSize(11).fontColor(this.theme().textSecondary).margin({ right: 6, top: 4 })
                    Button('无')
                      .height(22).fontSize(10).margin({ right: 4, bottom: 4 })
                      .fontColor(!pt['DefaultClassId'] ? '#FFFFFF' : this.theme().textPrimary)
                      .backgroundColor(!pt['DefaultClassId'] ? this.theme().accentColor : this.theme().bgSubtle)
                      .borderRadius(4)
                      .onClick(() => {
                        pt['DefaultClassId'] = '';
                        this.commitRoot();
                      })
                    ForEach(this.refSubjectsMap, (sub: SubjectEntry) => {
                      Button(sub.Name)
                        .height(22).fontSize(10).margin({ right: 4, bottom: 4 })
                        .fontColor(String(pt['DefaultClassId'] || '') === sub.key ? '#FFFFFF' : this.theme().textPrimary)
                        .backgroundColor(String(pt['DefaultClassId'] || '') === sub.key ? this.theme().accentColor : this.theme().bgSubtle)
                        .borderRadius(4)
                        .onClick(() => {
                          pt['DefaultClassId'] = sub.key;
                          this.commitRoot();
                        })
                    }, (sub: SubjectEntry) => sub.key)
                  }
                }

                // Type 1: BreakName
                if (Number(pt['TimeType'] || 0) === 1) {
                  Row({ space: 6 }) {
                    Text('课间名称:').fontSize(12).fontColor(this.theme().textSecondary)
                    TextInput({ text: String(pt['BreakName'] || ''), placeholder: '如：课间休息 / 眼保健操 / 大课间' })
                      .height(30).fontSize(12).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
                      .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
                      .onChange((v: string) => {
                        pt['BreakName'] = v;
                        this.commitRoot();
                      })
                  }.width('100%')
                }

                // Type 3: ActionSet Editor (8 Upstream Built-in Actions)
                if (Number(pt['TimeType'] || 0) === 3) {
                  Column({ space: 6 }) {
                    Text('行动组配置 (添加内置自动化动作):')
                      .fontSize(11)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.theme().warningColor)
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(BUILTIN_ACTIONS, (actDef: BuiltinActionDef) => {
                        Button(actDef.name)
                          .height(24).fontSize(10).margin({ right: 4, bottom: 4 })
                          .fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgSubtle)
                          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
                          .onClick(() => {
                            if (!pt['ActionSet']) {
                              const emptyActs: Record<string, Object>[] = [];
                              const initActionSet: Record<string, Object> = {
                                'IsEnabled': true,
                                'Name': '自动化行动组',
                                'Guid': generateUuid(),
                                'IsRevertEnabled': false,
                                'Actions': emptyActs
                              };
                              pt['ActionSet'] = initActionSet;
                            }
                            const aSet = pt['ActionSet'] as Record<string, Object>;
                            const acts = ((aSet['Actions'] || []) as Record<string, Object>[]).slice();
                            const emptySettings: Record<string, Object> = {};
                            const newAct: Record<string, Object> = { 'Id': actDef.id, 'Settings': emptySettings };
                            acts.push(newAct);
                            aSet['Actions'] = acts;
                            this.commitRoot();
                          })
                      }, (actDef: BuiltinActionDef) => actDef.id)
                    }
                  }
                  .width('100%')
                  .padding(8)
                  .backgroundColor(this.theme().bgSubtle)
                  .borderRadius(6)
                }
              }
              .padding(10)
              .backgroundColor(this.theme().bgCard)
              .borderRadius(6)
              .border({
                width: { left: 4, top: 1, right: 1, bottom: 1 },
                color: {
                  left: Number(pt['TimeType'] || 0) === 0 ? this.theme().accentColor :
                    (Number(pt['TimeType'] || 0) === 1 ? this.theme().successColor :
                      (Number(pt['TimeType'] || 0) === 2 ? this.theme().textSecondary : this.theme().warningColor)),
                  top: this.theme().borderColor,
                  right: this.theme().borderColor,
                  bottom: this.theme().borderColor
                }
              })
            },
            (_pt: Record<string, Object>, pIdx: number) => `tl_pt_${pIdx}`
          )
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  // ==================== 3. CLASSPLAN EDITOR (1:1 with Upstream & Web) ====================
  @Builder
  buildClassPlanEditor() {
    Column({ space: 12 }) {
      // ClassPlanGroups Bar
      Row({ space: 6 }) {
        Text('课表群组:').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
        Button('全部')
          .height(26).fontSize(11)
          .fontColor(this.selectedGroupKey === '' ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(this.selectedGroupKey === '' ? this.theme().accentColor : this.theme().bgSubtle)
          .borderRadius(4)
          .onClick(() => { this.selectedGroupKey = ''; })
        Button('默认群组')
          .height(26).fontSize(11)
          .fontColor(this.selectedGroupKey === EMPTY_GUID ? '#FFFFFF' : this.theme().textPrimary)
          .backgroundColor(this.selectedGroupKey === EMPTY_GUID ? this.theme().accentColor : this.theme().bgSubtle)
          .borderRadius(4)
          .onClick(() => { this.selectedGroupKey = EMPTY_GUID; })
        Blank()
        TextInput({ placeholder: '新群组名称', text: this.newGroupName })
          .height(28).width(110).fontSize(11).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
          .border({ width: 1, color: this.theme().borderColor, radius: 4 })
          .onChange((v: string) => { this.newGroupName = v; })
        HmosIconTextButton(
          $r('sys.symbol.plus'),
          '新建群组',
          this.theme().textPrimary,
          this.theme().bgSubtle,
          this.theme().borderColor,
          () => {
            if (!this.newGroupName.trim()) { return; }
            const grps = ((this.parsedRoot['ClassPlanGroups'] || {}) as Record<string, Record<string, Object>>);
            const gid = generateUuid();
            grps[gid] = { 'Name': this.newGroupName.trim(), 'IsGlobal': false };
            this.parsedRoot['ClassPlanGroups'] = grps;
            this.newGroupName = '';
            this.selectedGroupKey = gid;
            this.commitRoot();
          },
          28,
          11
        )
      }
      .width('100%')

      // ClassPlans List + Add / Duplicate / Temp Overlay
      Row({ space: 8 }) {
        Text('课表列表:')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Blank()
        HmosIconTextButton(
          $r('sys.symbol.plus'),
          '新建课表',
          '#FFFFFF',
          this.theme().accentColor,
          Color.Transparent,
          () => {
            const cps = ((this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>);
            const newId = generateUuid();
            const defaultTlId = this.refTimeLayoutsMap.length > 0 ? this.refTimeLayoutsMap[0].key : '';
            const defaultTimeRule: Record<string, Object> = { 'WeekDay': 1, 'WeekCountDiv': 0, 'WeekCountDivTotal': 2 };
            const emptyClasses: Record<string, Object>[] = [];
            const newCp: Record<string, Object> = {
              'Name': `新课表 ${Object.keys(cps).length + 1}`,
              'TimeLayoutId': defaultTlId,
              'IsEnabled': true,
              'IsOverlay': false,
              'AssociatedGroup': this.selectedGroupKey || EMPTY_GUID,
              'TimeRule': defaultTimeRule,
              'Classes': emptyClasses
            };
            cps[newId] = newCp;
            this.parsedRoot['ClassPlans'] = cps;
            this.selectedPlanKey = newId;
            this.selectedClassSlotIdx = 0;
            this.commitRoot();
          },
          30,
          12
        )
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(Object.keys((this.parsedRoot['ClassPlans'] || {}) as Record<string, Object>), (cpKey: string) => {
          Button(
            String((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[cpKey] || {})['Name']) || '课表')
          )
            .height(30)
            .fontSize(12)
            .margin({ right: 6, bottom: 6 })
            .fontColor(this.selectedPlanKey === cpKey ? this.theme().accentColor : this.theme().textPrimary)
            .backgroundColor(this.selectedPlanKey === cpKey ? this.theme().bgAccentSubtle : this.theme().bgSubtle)
            .border({
              width: 1,
              color: this.selectedPlanKey === cpKey ? this.theme().accentColor : this.theme().borderColor,
              radius: 6
            })
            .onClick(() => {
              this.selectedPlanKey = cpKey;
              this.selectedClassSlotIdx = 0;
            })
        }, (cpKey: string) => cpKey)
      }

      if (this.selectedPlanKey && ((this.parsedRoot['ClassPlans'] || {}) as Record<string, Object>)[this.selectedPlanKey]) {
        Column({ space: 10 }) {
          Row({ space: 6 }) {
            Text('课表名称:').fontSize(12).fontColor(this.theme().textSecondary)
            TextInput({
              text: String((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['Name']) || '')
            })
              .height(32).fontSize(13).fontColor(this.theme().textPrimary).backgroundColor(this.theme().bgInput)
              .border({ width: 1, color: this.theme().borderColor, radius: 4 }).layoutWeight(1)
              .onChange((v: string) => {
                const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                if (cps[this.selectedPlanKey]) {
                  cps[this.selectedPlanKey]['Name'] = v;
                  this.commitRoot();
                }
              })

            Text('默认启用').fontSize(12).fontColor(this.theme().textPrimary)
            Toggle({
              type: ToggleType.Switch,
              isOn: Boolean((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['IsEnabled']) !== false)
            })
              .onChange((v: boolean) => {
                const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                if (cps[this.selectedPlanKey]) {
                  cps[this.selectedPlanKey]['IsEnabled'] = v;
                  this.commitRoot();
                }
              })

            HmosIconTextButton(
              $r('sys.symbol.plus'),
              '复制',
              this.theme().textPrimary,
              this.theme().bgSubtle,
              this.theme().borderColor,
              () => {
                const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                const cur = cps[this.selectedPlanKey];
                if (cur) {
                  const cid = generateUuid();
                  const cloned = JSON.parse(JSON.stringify(cur)) as Record<string, Object>;
                  cloned['Name'] = `${String(cur['Name'] || '课表')} - 副本`;
                  cps[cid] = cloned;
                  this.selectedPlanKey = cid;
                  this.commitRoot();
                }
              },
              28,
              11
            )

            HmosIconButton(
              $r('sys.symbol.trash'),
              this.theme().dangerColor,
              Color.Transparent,
              this.theme().borderColor,
              () => {
                const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                const nextCps: Record<string, Record<string, Object>> = {};
                const keys = Object.keys(cps);
                for (let k = 0; k < keys.length; k++) {
                  if (keys[k] !== this.selectedPlanKey) {
                    nextCps[keys[k]] = cps[keys[k]];
                  }
                }
                this.parsedRoot['ClassPlans'] = nextCps;
                const remKeys = Object.keys(nextCps);
                this.selectedPlanKey = remKeys.length > 0 ? remKeys[0] : '';
                this.commitRoot();
              },
              28,
              14
            )
          }
          .width('100%')

          // TimeLayout selector
          if (this.refTimeLayoutsMap.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              Text('关联时间表:').fontSize(12).fontColor(this.theme().textSecondary).margin({ right: 6, top: 4 })
              ForEach(this.refTimeLayoutsMap, (tl: TimeLayoutGroup) => {
                Button(tl.Name)
                  .height(26).fontSize(11).margin({ right: 6, bottom: 4 })
                  .fontColor(
                    String((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['TimeLayoutId']) || '') === tl.key
                      ? '#FFFFFF' : this.theme().textPrimary
                  )
                  .backgroundColor(
                    String((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['TimeLayoutId']) || '') === tl.key
                      ? this.theme().accentColor : this.theme().bgSubtle
                  )
                  .borderRadius(4)
                  .onClick(() => {
                    const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                    if (cps[this.selectedPlanKey]) {
                      cps[this.selectedPlanKey]['TimeLayoutId'] = tl.key;
                      this.commitRoot();
                    }
                  })
              }, (tl: TimeLayoutGroup) => tl.key)
            }
          }

          // TimeRule: WeekDay & Multi-week rotation (2..4 weeks)
          Row({ space: 6 }) {
            Text('触发星期:').fontSize(12).fontColor(this.theme().textSecondary)
            ForEach([1, 2, 3, 4, 5, 6, 0], (wd: number) => {
              Button(['周日', '周一', '周二', '周三', '周四', '周五', '周六'][wd])
                .height(26)
                .fontSize(11)
                .fontColor(
                  Number(((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['TimeRule'] as Record<string, Object> || {})['WeekDay']) ?? 1) === wd
                    ? '#FFFFFF' : this.theme().textPrimary
                )
                .backgroundColor(
                  Number(((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['TimeRule'] as Record<string, Object> || {})['WeekDay']) ?? 1) === wd
                    ? this.theme().accentColor : this.theme().bgSubtle
                )
                .borderRadius(4)
                .onClick(() => {
                  const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                  if (cps[this.selectedPlanKey]) {
                    const tr = (cps[this.selectedPlanKey]['TimeRule'] || {}) as Record<string, Object>;
                    tr['WeekDay'] = wd;
                    cps[this.selectedPlanKey]['TimeRule'] = tr;
                    this.commitRoot();
                  }
                })
            }, (wd: number) => `wd_${wd}`)
          }
          .width('100%')

          Row({ space: 6 }) {
            Text('多周轮换:').fontSize(12).fontColor(this.theme().textSecondary)
            ForEach([0, 1, 2, 3, 4], (div: number) => {
              Button(div === 0 ? '不限' : `第${div}周`)
                .height(26)
                .fontSize(11)
                .fontColor(
                  Number(((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['TimeRule'] as Record<string, Object> || {})['WeekCountDiv']) || 0) === div
                    ? '#FFFFFF' : this.theme().textPrimary
                )
                .backgroundColor(
                  Number(((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['TimeRule'] as Record<string, Object> || {})['WeekCountDiv']) || 0) === div
                    ? this.theme().accentColor : this.theme().bgSubtle
                )
                .borderRadius(4)
                .onClick(() => {
                  const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                  if (cps[this.selectedPlanKey]) {
                    const tr = (cps[this.selectedPlanKey]['TimeRule'] || {}) as Record<string, Object>;
                    tr['WeekCountDiv'] = div;
                    cps[this.selectedPlanKey]['TimeRule'] = tr;
                    this.commitRoot();
                  }
                })
            }, (div: number) => `div_${div}`)

            Blank()
            HmosIconTextButton(
              $r('sys.symbol.plus'),
              '增加课节',
              '#FFFFFF',
              this.theme().accentColor,
              Color.Transparent,
              () => {
                const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                if (cps[this.selectedPlanKey]) {
                  const cls = ((cps[this.selectedPlanKey]['Classes'] || []) as Record<string, Object>[]).slice();
                  cls.push({ 'SubjectId': '', 'IsEnabled': true });
                  cps[this.selectedPlanKey]['Classes'] = cls;
                  this.selectedClassSlotIdx = cls.length - 1;
                  this.commitRoot();
                }
              },
              28,
              11
            )
          }
          .width('100%')

          // Quick Subject Picker Grid (with Auto-Advance toggle)
          if (this.refSubjectsMap.length > 0) {
            Column({ space: 6 }) {
              Row() {
                Text(`快速排课面板（点击科目填入第 ${this.selectedClassSlotIdx + 1} 节）`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme().textPrimary)
                  .layoutWeight(1)
                Text('选后自动跳下一节').fontSize(11).fontColor(this.theme().textSecondary)
                Toggle({ type: ToggleType.Switch, isOn: this.autoMoveNextSlot })
                  .onChange((v: boolean) => { this.autoMoveNextSlot = v; })
              }.width('100%')

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.refSubjectsMap, (sub: SubjectEntry) => {
                  Button(`${sub.Initial ? `[${sub.Initial}] ` : ''}${sub.Name}`)
                    .height(28)
                    .fontSize(12)
                    .margin({ right: 6, bottom: 6 })
                    .fontColor(this.theme().textPrimary)
                    .backgroundColor(this.theme().bgCard)
                    .border({ width: 1, color: this.theme().borderColor, radius: 6 })
                    .onClick(() => {
                      const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                      const cur = cps[this.selectedPlanKey];
                      if (cur) {
                        const cls = ((cur['Classes'] || []) as Record<string, Object>[]).slice();
                        if (cls.length === 0) {
                          cls.push({ 'SubjectId': sub.key, 'IsEnabled': true });
                          this.selectedClassSlotIdx = 0;
                        } else {
                          const targetIdx = Math.min(this.selectedClassSlotIdx, cls.length - 1);
                          cls[targetIdx]['SubjectId'] = sub.key;
                          if (this.autoMoveNextSlot && targetIdx < cls.length - 1) {
                            this.selectedClassSlotIdx = targetIdx + 1;
                          }
                        }
                        cur['Classes'] = cls;
                        this.commitRoot();
                      }
                    })
                }, (sub: SubjectEntry) => sub.key)
              }
            }
            .width('100%')
            .padding(10)
            .backgroundColor(this.theme().bgSubtle)
            .borderRadius(8)
          }

          // Classes slots list
          ForEach(
            ((((this.parsedRoot['ClassPlans'] as Record<string, Record<string, Object>>)[this.selectedPlanKey] || {})['Classes']) || []) as Record<string, Object>[],
            (slot: Record<string, Object>, sIdx: number) => {
              Row({ space: 8 }) {
                Text(`第 ${sIdx + 1} 节`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedClassSlotIdx === sIdx ? this.theme().accentColor : this.theme().textPrimary)
                  .width(64)

                Text(this.resolveSubjectLabel(String(slot['SubjectId'] || '')))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme().textPrimary)
                  .layoutWeight(1)

                HmosIconButton(
                  $r('sys.symbol.trash'),
                  this.theme().dangerColor,
                  Color.Transparent,
                  Color.Transparent,
                  () => {
                    const cps = (this.parsedRoot['ClassPlans'] || {}) as Record<string, Record<string, Object>>;
                    const cur = cps[this.selectedPlanKey];
                    if (cur) {
                      const cls = ((cur['Classes'] || []) as Record<string, Object>[]).slice();
                      cls.splice(sIdx, 1);
                      cur['Classes'] = cls;
                      this.commitRoot();
                    }
                  },
                  26,
                  13
                )
              }
              .width('100%')
              .padding(10)
              .backgroundColor(this.selectedClassSlotIdx === sIdx ? this.theme().bgAccentSubtle : this.theme().bgCard)
              .borderRadius(6)
              .border({
                width: 1,
                color: this.selectedClassSlotIdx === sIdx ? this.theme().accentColor : this.theme().borderColor
              })
              .onClick(() => {
                this.selectedClassSlotIdx = sIdx;
              })
            },
            (_slot: Record<string, Object>, sIdx: number) => `cp_slot_${sIdx}`
          )
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  private resolveSubjectLabel(subId: string): string {
    if (!subId) {
      return '（未排课）';
    }
    for (let i = 0; i < this.refSubjectsMap.length; i++) {
      if (this.refSubjectsMap[i].key === subId) {
        const s = this.refSubjectsMap[i];
        return `${s.Name}${s.TeacherName ? ` · ${s.TeacherName}` : ''}`;
      }
    }
    return subId;
  }

  build() {
    Column() {
      if (this.lastInputJson !== this.rawJsonText) {
        Row().height(0).onAppear(() => {
          this.syncFromInputJson();
        })
      }

      if (this.resourceType === 'Subjects') {
        this.buildSubjectsEditor()
      } else if (this.resourceType === 'TimeLayout') {
        this.buildTimeLayoutEditor()
      } else {
        this.buildClassPlanEditor()
      }
    }
    .width('100%')
  }
}
