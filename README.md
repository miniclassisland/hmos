# MINI ClassIsland — HarmonyOS Next 原生集控客户端

<p align="center">
  <a href="https://miniclassisland.com" target="_blank" rel="noopener noreferrer">
    <img src="assets/miniclassisland.png" alt="MINI ClassIsland Logo" width="128" height="128" />
  </a>
</p>


**MINI ClassIsland HarmonyOS**（包名：`org.miniopensource.miniclassisland`）是基于 **ArkTS + ArkUI 声明式框架（HarmonyOS Next API 12+）** 构建的原生鸿蒙多设备集控与平台治理客户端。

---

## 核心特性

### 1. 全场景多设备自适应与自由多窗（`freeMultiWindow`）
- 原生支持 **手机（`phone`）**、**平板（`tablet`）** 与 **二合一 PC（`2in1`）** 设备形态。
- 支持全屏（`fullscreen`）、分屏（`split`）与悬浮窗（`floating`）模式，通过监听 `windowSizeChange` 与 `windowStatusChange` 实时切换 `sm` / `md` / `lg` 响应式断点布局。

### 2. 租户集控套件（Management API `:27042`）
- **引导与安全认证**：支持自定义服务端地址、OOBE 首次初始化向导、登录/注册、2FA TOTP 动态口令及恢复码验证。
- **集控总览看板**：实时展示租户在线终端指标、配额占用详情，支持一键导出 `ManagementPreset.json`。
- **7 类配置资源可视化与源码编辑器**：
  - 完整覆盖 `Subjects`、`TimeLayout`、`ClassPlan`、`Policy`、`DefaultSettings`、`Components`、`Credentials`。
- **终端巡检与远程指令**：
  - 查看教室终端在线状态、IP、分组及下发方案绑定。
  - 远程触发应用重启、配置刷新、运行日志抓取（`ConfigTypes.Logs`）与配置快照对比。
  - 实时横幅预览并下发单机/全校广播通知（普通通知与紧急全屏通知）。
- **准入控制与组织安全**：
  - 支持开放接入（`open`）、6 位配对码审批（`pairing`）、预注册白名单（`pre_reg`）与批量导入。
  - 支持成员角色管理、邀请码生成、API 密钥轮换与操作审计日志查询。

### 3. 超级管理员全局治理（Admin API `:27043`）
- 全局平台实时统计（总租户、总终端、实时在线终端、待审批用户）。
- 租户配额动态调整、一键跨租户进入集控编辑、用户封禁/解封与注册审批工作流。

---

## 目录结构

```text
hmos/
├── AppScope/                   # 全局应用配置与资源 (app.json5)
├── entry/
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/   # EntryAbility 窗口生命周期与断点监听
│   │   │   ├── model/          # 数据模型与 ClassIsland 资源结构定义
│   │   │   ├── network/        # HTTP 客户端封装 (:27042 / :27043)
│   │   │   └── pages/          # 自适应主界面、资源编辑器、终端管理与超管视图
│   │   ├── resources/          # 多语言与深浅色主题资源
│   │   └── module.json5        # 模块配置与权限声明 (ohos.permission.INTERNET)
│   └── build-profile.json5
├── build-profile.json5
└── hvigorfile.ts
```

---

## 本地构建与运行

1. 使用 **DevEco Studio 5.0+** 打开 `hmos` 目录。
2. 同步 Hvigor 依赖：
   ```bash
   hvigorw --sync
   ```
3. 构建 HAP 安装包：
   ```bash
   hvigorw assembleHap
   ```
