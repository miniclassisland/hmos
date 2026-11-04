# MINI ClassIsland HarmonyOS 贡献指南 (Contributing Guide)

感谢你为 `miniclassisland/hmos` 做出贡献！在编写代码和提交 Pull Request 前，请遵循以下指南。

---

## 1. 开发环境要求

- **IDE**：DevEco Studio 5.0.0 或更高版本
- **SDK**：HarmonyOS Next SDK API 12+ (`5.0.0(12)`)
- **构建工具**：Hvigor (`hvigorw`)

---

## 2. 编码与架构规范

### 2.1 ArkTS 严格类型规范
- 严格遵守 ArkTS 静态类型约束，避免使用 `any` 或未声明结构的动态属性访问。
- 7 类配置资源（`Subjects`、`TimeLayout`、`ClassPlan`、`Policy`、`DefaultSettings`、`Components`、`Credentials`）的序列化属性必须保持与上游 ClassIsland C# 模型一致的 `PascalCase` 命名。

### 2.2 多设备响应式与自由多窗适配
- 新增页面或弹窗必须兼容 `sm`（手机竖屏）、`md`（折叠屏/分屏）与 `lg`（平板横屏/PC 自由多窗）三种断点。
- 禁止使用固定像素宽度硬编码主内容区，优先使用 `GridRow` / `GridCol`、`Flex` 或百分比弹性布局。

### 2.3 敏感信息与签名隔离
- 严禁提交 `.p12`、`.cer`、`.csr`、`.p7b` 等鸿蒙真机调试证书或签名私钥。
- `build-profile.json5` 中的本地自动签名配置在提交前请确保不包含个人凭据路径。

---

## 3. 提交前验证

在提交代码前，请在 DevEco Studio 或命令行中确认无编译与 ArkTS Lint 错误：

```bash
hvigorw assembleHap --no-daemon
```

---

## 4. Commit 规范与签名

- 使用 **Conventional Commits** 格式（如 `feat(hmos): ...`、`fix(network): ...`）。
- 请配置 Git SSH 签名并使用 `git commit -S` 提交。
