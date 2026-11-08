# GitHub 发布记录（v1.0.0）

日期：2026-11-08
仓库：<https://github.com/NS-Michael-007/WorkNote>（公开，默认分支 `main`）
Release：<https://github.com/NS-Michael-007/WorkNote/releases/tag/v1.0.0>

## 一、仓库里放了什么

- 许可证 `LICENSE`：GPL-3.0 全文（GitHub 侧识别为 `GPL-3.0`，见仓库首页右侧 "License"）
- `README.md`：三端功能对照、装法、编译方法、已知限制、验证情况（都按实际状态写，没有夸大）
- `app/`：Android 源码（Kotlin + XML + 原生 SQLite）
- `ios-app/`：iOS 源码（SwiftUI + XcodeGen 工程定义 + 25 条单测）
- `ohos-app/`：HarmonyOS NEXT 源码（ArkTS Stage 工程）
- `contract/`：三端共享数据契约、`.taskbak` JSON Schema、校验脚本、合成样本（真机导出的样本已排除）
- `docs/`：各功能的落地说明与验机记录
- `.github/workflows/ios.yml`：iOS 的 macOS CI

**没有进仓库的东西（`.gitignore` 强制排除）**：`keystore/`、`keystore.properties`、`*.jks`、所有 `shot_*.png` 调试截图、数据库副本（含 `contract/real_worknote.db`、`contract/real_export.taskbak` 这两份真机数据）、测试音频、`dist/` 产物目录。

顺带把 `docs/发布与签名说明.md` 里的密钥库口令删掉了 —— 那份文档原本写着明文密码，发公开仓库等于把签名钥匙交出去。现在文档只留流程与证书指纹，口令只在本地 `keystore.properties` 里。

## 二、Release 附件（v1.0.0）

| 附件 | 大小 | 是什么 | 能直接装吗 |
| --- | --- | --- | --- |
| `WorkNote-1.0.0-android-release.apk` | 5,023,952 字节 | Android 正式签名安装包（release 私钥签名，包名 `com.workspace.worknote`，versionCode 1） | **能** |
| `WorkNote-1.0.0-ios-source.zip` | 49,459 字节 | iOS 源码包（`ios-app/` 整目录，含 XcodeGen 配置与单测） | 不能，要 Mac + Xcode 编 |
| `WorkNote-1.0.0-harmony-source.zip` | 32,050 字节 | HarmonyOS 源码包（`ohos-app/` 整目录） | 不能，要 DevEco Studio 编 |

三个附件加起来不是"三个安装包"：**只有 Android 那份是安装包**，iOS 与鸿蒙是源码。原因写在 README 第二节，简短说就是 Windows 开发机没有 Xcode 与 DevEco，也没有 macOS runner 配额。

## 三、iOS CI 为什么没跑成

- 初次 push 自动触发 2 次，手动 `workflow_dispatch` 又触发 1 次，三次结果一致：`completed / cancelled`，job 的 `steps` 数量是 0，也就是还没开始就被取消。
- 已核对：仓库 Actions 是 `enabled=True`、`allowed_actions=all`，工作流 `state=active`，YAML 本身能解析（文件是合法 UTF-8，缩进正常）。
- 结论：不是代码问题，是运行 macOS runner 的额度/计费限制。要跑通得在 GitHub 账号里放开 macOS 分钟数，或者干脆换台 Mac 本地编。

## 四、Android 正式版装机（本机）

手机：realme RMX5080 / Android 16，序列号 `HQDQBM6XMJBEPFLJ`。

1. 换装前先在【我】页导出备份：`/sdcard/Download/工作便签提醒/WorkNote_20261108_1355.taskbak.json`（1,255 字节，含当时全部便签），并另存一份到电脑 `backup_before_release_20261108_1355.taskbak.json`。
2. `adb uninstall com.workspace.worknote`（debug 与 release 签名不同，必须卸载）。
3. `adb install` release 包 —— realme 的安装器会拦一次"检测结果：涉及敏感权限"，要在手机上点「继续安装」才继续（这一步是系统行为，不是 adb 卡住）。
4. 装好后核对：`dumpsys package` 读到 `versionName=1.0.0`；`run-as` 报 `package not debuggable`，确认装的是正式包而不是调试包。
5. 数据恢复（已完成）：App【我】→「从备份恢复（会覆盖本地数据）」→ 系统文件选择器切到"文件"→"全部文件"→ Download → 工作便签提醒 → `WorkNote_20261108_1355.taskbak.json` → 确认「覆盖导入」。恢复后主界面那条便签回来了，关联日期"今天"、提醒时间"未设置"，跟备份里一致。
6. **换装后必须重开四项权限**（这一步最容易漏）：卸载重装会把所有授权清零，App 会显示"强提醒权限（必须全开）"下四项都是"未开启"。realme 上 `adb shell appops set` 与 `pm grant` 都会被拒（shell 没有 `MANAGE_APP_OPS_MODES` / `GRANT_RUNTIME_PERMISSIONS`），只能走系统设置界面点：
   - 悬浮窗：`am start -a android.settings.MANAGE_APP_OVERLAY_PERMISSION -d package:com.workspace.worknote`，把「授予悬浮窗权限」打开
   - 通知：`am start -a android.settings.APP_NOTIFICATION_SETTINGS --es android.provider.extra.APP_PACKAGE com.workspace.worknote`，打开「允许通知」，并把「置顶通知」也开（前台常驻通知要它）
   - 忽略电池优化：`adb shell dumpsys deviceidle whitelist +com.workspace.worknote` 可以成功，这一项不用点界面
   - 精确闹钟：应用声明了 `USE_EXACT_ALARM`，装好后默认就是已开启状态
7. 恢复后核对：四项都显示"已开启"；【我】页下层的「提醒时响铃 / 提醒时震动 / 提醒时亮屏 / 优先使用精确闹钟」四个开关本来就是默认打开，与换装前一致；「提醒铃声」仍是"系统默认"（换装前也没选过自定义铃声）。

## 五、复现命令（以后发新版照这个走）

```powershell
Set-Location "C:\Users\NAN SHENG CSUR\Doubao\chats\2026-11-08\new-chat-1"
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
.\gradlew.bat assembleRelease --console=plain

# 产物另存为发布用名字
Copy-Item app\build\outputs\apk\release\app-release.apk dist\WorkNote-<版本>-android-release.apk

# 传 Release 附件（需要 github.com 的凭据，git credential 里已有）
```

发布后自检：`apksigner verify --print-certs` 指纹应是 `2d9ebfc0…d0b2`（SHA-256），`aapt2 dump badging` 里不应出现 `application-debuggable`。
