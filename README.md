# 工作便签提醒（WorkNote）

一个**完全本地、不联网、不用账号**的强提醒便签 App：到点弹一张盖在屏幕最上层的卡片，卡片上没有关闭按钮，**必须点了自己配的按钮才会消失**。

单机自用为主，顺便开源出来给需要的人，**不上架任何应用商店**。

- 许可证：**GPL-3.0**（全文见 [LICENSE](LICENSE)）
- 版本：1.0.0（三端同一份数据模型，同一个包名 `com.workspace.worknote`）
- 语言：跟随系统 / 简体中文 / 繁體中文 / English（三端都是四档）
- 主题：跟随系统 / 浅色 / 深色；字号 1~10 档

## 一、开源声明

这个项目是**自用项目**：先满足我自己的需求，功能优先，不追求商店级的打磨。代码按 GPL-3.0 公开，你可以免费用、改、二次分发，但**改完再发布必须同样以 GPL-3.0 开源并保留出处**。没有担保，装在自己手机上有任何问题自行承担。

如果你用它改出了更好的版本，欢迎提 issue / PR；自用分支的节奏可能跟不上你的期望，fork 走自己的路也完全没问题。

## 二、三个平台现在到哪一步了（请按此预期使用）

| 平台 | 代码 | 能不能装 | 说明 |
| --- | --- | --- | --- |
| Android | 完成 | **能**，签名 release 包已在真机跑过 | 只有它在真机上完整验证过，强提醒卡片、悬浮窗、自定义铃声、三档语言都实测过 |
| iOS | 完成 | **暂时不能** | Swift 源码与 CI 工作流都在，但 iOS 出安装包必须有 macOS + Xcode + 签名；本开发机是 Windows，只能靠 GitHub Actions 的 macOS runner 编译（目前只编模拟器版，不出 `.ipa`） |
| HarmonyOS NEXT | 完成 | **暂时不能** | ArkTS 源码与工程骨架都在，出 `.hap` 必须有 DevEco Studio 与本机签名证书；本开发机没有这套工具链 |

说直白点：**现在只有 Android 有真正的安装包**，iOS 与 HarmonyOS 交的是可编译源码。谁有对应工具链，谁就能自己编出来。

## 三、下载与安装

### Android（可用）

从本仓库的 [Releases](../../releases) 下载 `WorkNote-1.0.0-android-release.apk`，传到手机点开安装（需允许"安装未知来源应用"）。

或用 adb：

```powershell
adb install -r WorkNote-1.0.0-android-release.apk
```

装好后务必进【我】页把四项权限点亮（悬浮窗、忽略电池优化、通知、精确闹钟），国产 ROM 还要单独打开"自启动"和"后台运行"，否则到点可能不弹卡片。

### iOS（源码，需自编）

```bash
cd ios-app
brew install xcodegen
xcodegen generate --spec project.yml
open WorkNote.xcodeproj      # 用 Xcode 选真机运行，签名用你自己的 Apple ID
```

`project.yml` 里默认关闭了自动签名（`CODE_SIGNING_ALLOWED` 关），真机跑之前要在 Xcode 的 Signing & Capabilities 里选自己的 Team。

### HarmonyOS NEXT（源码，需自编）

用 DevEco Studio 打开 `ohos-app/`，`compatibleSdkVersion` 是 `5.0.0(12)`。真机安装需要先在 DevEco 里配好签名（自动签名或手动 p12 + p7b），否则只能跑模拟器。

## 四、三端各做了什么（功能对照）

| 能力 | Android | iOS | HarmonyOS NEXT |
| --- | --- | --- | --- |
| 强提醒卡片（不可随手关闭） | 悬浮窗置顶卡片，无 ×、无"稍后再说"，点遮罩/返回键都关不掉 | 通知 + 前台高频催办（系统不给第三方全局悬浮窗） | 通知 + 实况窗（同上，系统限制） |
| 关联日期 | 年/月/日 滚轮，底部「今天 / 取消 / 确定」 | 年月日圆盘 + 「今天」按钮 | 年月日选择框 + 「今天」按钮 |
| 定时提醒 | 年月日 + 时分五段滚轮 | 年月日 + 时分圆盘 + 「改到今天」 | 先选日期再选时分 + 「改到今天」 |
| 循环（每天/每周/每月） | 有 | 有 | 有 |
| 未处理就再弹 | 有（分钟级冷却） | 有 | 有 |
| 自定义提醒铃声 | 从本地音乐选一首，复制进应用私有目录，通知渠道静音、代码层出声 | 从文件选，`AVAudioPlayer` 播 | 从文件选，`AVPlayer` 播 |
| 自定义操作按钮 | 每条便签自己配文字与动作（完成 / 延后 / 只关卡片） | 同 | 同 |
| 备份 `*.taskbak` | 有，三端同一格式 | 有 | 有 |
| 深色 / 字号 / 四档语言 | 有 | 有 | 有 |
| 背景图（三个 Tab 都显示） | 有 | 有 | 有 |

三端共享的数据契约（字段、状态、备份 JSON 结构）见 `docs/三端共享契约（数据模型与备份格式）.md`，校验脚本在 `contract/`。

## 五、强提醒是怎么做到的（Android 为例）

1. 到点由 `AlarmManager` 广播唤醒，前台服务 `ReminderService` 用 `TYPE_APPLICATION_OVERLAY` 把卡片盖在最上层，背景压暗。
2. 卡片上**没有关闭按钮**，也没有"稍后再说"；点背景、按返回键都不消失。
3. 每条便签的按钮自己配：文字自定，动作三选一 —— 标记完成 / 延后 / 只关卡片。
4. 没给悬浮窗权限时，自动退回全屏 `ReminderActivity`，规则完全一样。
5. 前台服务会在通知栏留一条常驻通知，这是 Android 对前台服务的硬性要求，不是任务提醒，删不掉。

## 六、数据在哪、隐私

- 所有便签只存在本机 SQLite（`worknote.db`），**没有网络请求、没有账号、没有云同步、没有统计埋点**。
- 备份文件 `WorkNote_年月日_时分.taskbak` 写在系统"下载/工作便签提醒"目录，纯 JSON，你自己能打开看。
- 卸载 App 会连同数据库一起删掉（系统行为），所以换签名、换机前先在【我】页导出备份。

## 七、自己编译（Android）

环境：Android Studio（AGP 9.1.0 / Gradle 9.3.1 / JDK 21）、compileSdk 36、minSdk 26。

```powershell
.\gradlew.bat assembleDebug      # 调试包
.\gradlew.bat assembleRelease    # 正式签名包
```

正式包需要你自己准备签名：在工程根放 `keystore.properties`（`storeFile / storePassword / keyAlias / keyPassword`）并放好 `.jks`。**这两个都不在仓库里**，仓库里也刻意 `.gitignore` 掉了 —— 我的签名私钥不会上传，谁要发自己的正式包就用自己的钥匙。

> 注意：debug 包与 release 包签名不同，互相覆盖会报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`，切换前必须卸载（会清空数据库，先导出 `.taskbak`）。

## 八、验证情况（如实写）

**已经真机验证（realme RMX5080 / Android 16，1080×2376）**

- 启动页、主界面、日程页、编辑页、「我」页全部截图核对
- 中文 / 繁體中文 / English 三档切换，界面文案整体跟着变
- 年月日滚轮：编辑页显示 `2026年11月8日 周日（今天）`，转到 11 日后变 `2026年11月11日 周三`，提醒时间同步
- 强提醒卡片弹出：遮罩 + 「我已处理」，无 ×、无稍后再说
- 自定义铃声：文件复制进私有目录成功，通知渠道 `mSound=null`（渠道静音、代码层出声）
- 签名 release 包 `adb install` 成功，`run-as` 报 `package not debuggable`（确认是正式包）

**还没验证到的**

- 自定义铃声"开关全开状态下到点真的响一声"的声学证据（两次卡片弹出时响铃开关是关的）
- iOS 与 HarmonyOS 的**任何编译**：本机没有 Xcode / DevEco，两边的代码只做过静态检查（JSON 能解析、三档语言键集合相等、括号配平）
- iOS 的 25 条单元测试从未执行

## 九、目录结构

```
app/                 Android 工程（Kotlin + XML + 原生 SQLite）
ios-app/             iOS 工程（SwiftUI，XcodeGen 生成工程）
ohos-app/            HarmonyOS NEXT 工程（ArkTS Stage 模型）
contract/            三端共享数据契约与 .taskbak 校验脚本
docs/                各功能的设计与验机记录
.github/workflows/   iOS 的 macOS CI（编译 + 模拟器截图）
```

更细的模块说明见 `docs/`：
- `docs/关联日期与提醒时间（三端）.md`
- `docs/自定义提醒铃声（三端）.md`
- `docs/三端繁体语言方案.md`
- `docs/发布与签名说明.md`
- `docs/界面与间距规范.md`

## 十、已知限制

1. **只有 Android 能做"不可关闭的置顶卡片"**。iOS 与 HarmonyOS 不开放第三方全局悬浮窗，同一需求在那边只能降级成"通知 + 高频催办"，用户仍可划掉通知。
2. 国产 ROM 的省电策略会延迟甚至杀掉后台闹钟，需要手动加白名单。
3. 前台服务常驻通知无法隐藏，系统强制。
4. 日程页按当月实际天数纵向罗列（28~31 行），二月没有 30、31 号。
5. HarmonyOS 端英文界面里日期单位「年 / 月 / 日」仍是中文，与 Android 不完全一致，待后续统一。
