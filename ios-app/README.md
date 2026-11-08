# 工作便签提醒 · iOS 端

路线 A 下的 iOS 独立原生工程。**只与 Android / 鸿蒙共享两样东西**：数据模型和 `.taskbak` 备份格式，见 `../docs/三端共享契约（数据模型与备份格式）.md`。

## 先读这段：为什么代码在 Windows 上写、却只能在 macOS 上编

| 事实 | 后果 |
| ---- | ---- |
| Xcode 与 iOS 模拟器只随 macOS 提供 | Windows 本机**无法**编译 iOS App，也**无法**跑模拟器 |
| Apple 的授权条款只允许在 Apple 硬件上运行 macOS | 拿 Windows 装虚拟机跑 macOS 不合规，也不可靠 |
| Swift 工具链虽有 Windows 版，但不含 UIKit / SwiftUI / 模拟器 | 只能在 Windows 上做纯逻辑编译，跑不起 App |

所以本工程用 **XcodeGen 声明式工程**（`project.yml`），由 CI 在你的 GitHub 仓库里用 **macOS runner** 生成 `.xcodeproj`、编译、跑单测、装模拟器截图。这套流程不需要你有一台 Mac。

## 目录

```
ios-app/
├── project.yml                 # XcodeGen 工程定义（唯一工程来源，不提交 .xcodeproj）
├── Sources/
│   ├── Core/                   # 纯逻辑，无 UI 依赖，可单测
│   │   ├── Models.swift        # Note / 状态机 / 循环 / 按钮
│   │   ├── TimeKey.swift       # 本地日历、dateKey、毫秒换算
│   │   ├── ReminderPlanner.swift  # 下一次该响的时刻（含月末夹取）
│   │   ├── BackupCodec.swift   # .taskbak 读写 + 导入规则
│   │   └── NoteStore.swift     # 本机持久化（原子写）
│   ├── App/                    # 应用装配与系统能力
│   │   ├── WorkNoteApp.swift
│   │   ├── AppModel.swift      # 业务总闸
│   │   ├── ReminderCenter.swift# 本地通知排期（含高频催办）
│   │   ├── NotificationRouter.swift
│   │   └── SettingsStore.swift
│   └── UI/                     # 三 Tab 界面
│       ├── RootView.swift
│       ├── HomeView.swift
│       ├── NoteEditorView.swift
│       ├── ScheduleView.swift
│       └── ProfileView.swift
└── Tests/
    ├── BackupCodecTests.swift
    ├── ReminderPlannerTests.swift
    └── Fixtures/               # 与 contract/ 同一批样本，三端共用
```

## 本地（有 Mac 时）

```bash
brew install xcodegen
cd ios-app
xcodegen generate
open WorkNote.xcodeproj
```

命令行验证：

```bash
xcodebuild test -scheme WorkNoteCoreTests -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild build -scheme WorkNote -destination 'platform=iOS Simulator,name=iPhone 15'
```

## CI（没有 Mac 时的唯一验证路径）

推代码后 `.github/workflows/ios.yml` 会自动：生成工程 → 跑核心层单测 → 编译 App → 装进 iPhone 15 模拟器 → 截图 → 上传 artifact。一次跑完约 5–8 分钟。

看结果：仓库 Actions 页面 → 最近一次 run → 下载 `ios-verification` artifact，里面有 `shot_home.png`（模拟器首屏）和测试报告。

## 已知差异（必须写清，不能装看不见）

**"不处理就关不掉的强提醒"在 iOS 上物理做不到。** 系统不允许 App 阻止用户划掉通知，也不允许长期置顶浮层。本工程的等价实现是：

1. 到点发**时效性通知**（`interruptionLevel = .timeSensitive`，可穿透专注模式）；
2. 没处理就按 `repeatMinutes` 间隔**补发**，一条便签最多补 5 次（`ReminderCenter.maxFollowUps`）；
3. 通知带三个动作按钮：标记完成 / 延后 / 先放着（`UNNotificationCategory`）；
4. 用户硬划掉通知也拦不住——这种情况只取消本次提醒，任务继续挂着。

强度弱于 Android 版（那边是前台服务 + 悬浮卡片，确实关不掉）。界面与文案里要如实写明，不做兑现不了的承诺。

## 其它两点客观限制

- **精确到点**：本地通知的到达时刻由系统调度，不保证秒级；Android 的 `setExactAndAllowWhileIdle` 那种精度在 iOS 上无法复现。
- **后台唤醒**：iOS 不允许为这类用途常驻后台，所以"补发"是靠**提前登记**多条未来通知实现的，不是靠 App 在后台循环。

## 当前状态

- 已写完：核心层（模型 / 时间 / 排期 / 备份 / 存储）、设置、通知排期、三 Tab 界面、编辑页、年月选择、备份导出导入、25 个单测用例。
- **尚未编译验证**：本机是 Windows，没有任何 Swift/Xcode 工具链。第一次真编译要等 CI 跑通；编译报错会按日志修。
- 界面是第一版（结构对齐 Android，视觉细节待 CI 出图后调）。
