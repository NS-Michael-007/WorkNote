import SwiftUI
import UniformTypeIdentifiers

/// 「我」页：界面与显示、存储、通知、提醒、备份。分组名称按命名规范写全，不用代号。
struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.colorScheme) private var scheme

    @State private var showExport = false
    @State private var showImport = false
    @State private var exportDoc = TaskBakDocument(data: Data())
    @State private var pendingCount = 0
    @State private var storageText = "计算中…"
    @State private var alertText: String?
    @State private var showRingtonePicker = false
    @State private var ringtoneRefresh = false

    private var ringtoneText: String {
        _ = ringtoneRefresh  // 让恢复默认后这一行跟着刷新
        guard let name = RingtoneStore.shared.fileName, RingtoneStore.shared.currentFileURL != nil else {
            return "系统默认"
        }
        return name
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TopBar(title: "我") { EmptyView() }

                List {
                    Section("界面与显示") {
                        Picker("深色模式", selection: $settings.darkMode) {
                            ForEach(SettingsStore.DarkMode.allCases) { mode in
                                Text(mode.titleZh).tag(mode)
                            }
                        }
                        Stepper("字体大小：第 \(settings.fontLevel) 档", value: $settings.fontLevel, in: 1...10)
                        Picker("语言", selection: $settings.language) {
                            ForEach(SettingsStore.Language.allCases) { lang in
                                Text(lang.titleZh).tag(lang)
                            }
                        }
                        .onChange(of: settings.language) { _ in
                            // 落盘到 AppleLanguages；iOS 不允许运行期换主语言，需重新打开 App 才生效
                            settings.applyLanguageToSystem()
                        }
                        Text("切换语言后需要重新打开 App 才会生效")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("背景图")
                            Spacer()
                            Text(settings.backgroundPath.isEmpty ? "默认纯色" : "已设置")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("存储空间") {
                        HStack {
                            Text("便签数据")
                            Spacer()
                            Text(storageText).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("便签条数")
                            Spacer()
                            Text("\(model.notes.count)").foregroundStyle(.secondary)
                        }
                    }

                    Section("通知与提醒") {
                        Toggle("提示音", isOn: $settings.notifySound)
                        Toggle("角标", isOn: $settings.notifyBadge)
                        Button {
                            showRingtonePicker = true
                        } label: {
                            HStack {
                                Text("提醒铃声")
                                Spacer()
                                Text(ringtoneText).foregroundStyle(.secondary)
                            }
                        }
                        if RingtoneStore.shared.fileName != nil {
                            Button("恢复系统默认铃声") {
                                RingtoneStore.shared.reset()
                                ringtoneRefresh.toggle()
                            }
                        }
                        Stepper("默认延后 \(settings.delayMinutes) 分钟", value: $settings.delayMinutes, in: 5...240, step: 5)
                        Stepper("重弹间隔 \(settings.repeatMinutes) 分钟", value: $settings.repeatMinutes, in: 5...240, step: 5)
                        HStack {
                            Text("已排提醒")
                            Spacer()
                            Text("\(pendingCount) 条").foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("iOS 不允许 App 阻止用户划掉通知，也没有浮窗。这里的强提醒是「时效性通知 + 没处理就按间隔补发」，强度弱于 Android 版。")
                    }

                    Section("备份") {
                        Button("导出 .taskbak") {
                            exportDoc = TaskBakDocument(data: model.exportData())
                            showExport = true
                        }
                        Button("从 .taskbak 恢复") { showImport = true }
                    } footer: {
                        Text("导出会写一条替换式备份：恢复时本机现有便签会被整体覆盖。换手机只认这一份文件。")
                    }

                    Section("关于") {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text("1.0.0").foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("包名")
                            Spacer()
                            Text("com.workspace.worknote").foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.pageBackground(scheme))
            .fileExporter(
                isPresented: $showExport,
                document: exportDoc,
                contentType: .taskBak,
                defaultFilename: BackupCodec.suggestedFileName()
            ) { _ in }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.taskBak, .json]) { result in
                handleImport(result)
            }
            .fileImporter(isPresented: $showRingtonePicker, allowedContentTypes: [.audio]) { result in
                handleRingtonePick(result)
            }
            .alert("提示", isPresented: Binding(
                get: { alertText != nil },
                set: { if !$0 { alertText = nil } }
            )) {
                Button("好", role: .cancel) { alertText = nil }
            } message: {
                Text(alertText ?? "")
            }
            .task {
                refreshStats()
            }
        }
    }

    private func handleRingtonePick(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try RingtoneStore.shared.importAudio(from: url)
                ringtoneRefresh.toggle()
                // 铃声变了，已排的通知要重登记才会用上新铃声
                model.reschedule()
            } catch {
                alertText = error.localizedDescription
            }
        case .failure:
            break
        }
    }

    private func refreshStats() {
        ReminderCenter.pendingCount { count in
            Task { @MainActor in pendingCount = count }
        }
        let bytes = model.exportData().count
        storageText = bytes < 1024 ? "\(bytes) B" : String(format: "%.1f KB", Double(bytes) / 1024.0)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let count = try model.importData(data)
                alertText = "已恢复 \(count) 条便签，提醒已重排"
                refreshStats()
            } catch {
                alertText = error.localizedDescription
            }
        case .failure(let error):
            alertText = error.localizedDescription
        }
    }
}

/// .taskbak 的文件包装，给 fileExporter 用
struct TaskBakDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.taskBak] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    /// 自定义扩展名：utt = 自定义类型，导出后是 .taskbak
    static let taskBak = UTType(exportedAs: "com.workspace.worknote.taskbak", conformingTo: .json)
}
