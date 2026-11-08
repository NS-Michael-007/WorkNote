import SwiftUI

/// 三个 Tab：主界面 / 日程 / 我。不做第四个 Tab，搜索、回收站都收在右上角 ⋯ 里。
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @State private var tab: Tab = .home

    enum Tab: Hashable { case home, schedule, profile }

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("主界面", systemImage: "house.fill") }
                .tag(Tab.home)

            ScheduleView()
                .tabItem { Label("日程", systemImage: "calendar") }
                .tag(Tab.schedule)

            ProfileView()
                .tabItem { Label("我", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
        .tint(Theme.accent)
        .dynamicTypeSize(Self.typeSize(for: settings.fontLevel))
    }

    /// 字号 1~10 档 -> 系统字号档位（近似映射，避免自绘字号导致布局到处要改）
    static func typeSize(for level: Int) -> DynamicTypeSize {
        switch level {
        case 1: return .extraSmall
        case 2: return .small
        case 3: return .medium
        case 4: return .large
        case 5: return .xLarge
        case 6: return .xxLarge
        case 7: return .xxxLarge
        case 8: return .accessibility1
        case 9: return .accessibility2
        default: return .accessibility3
        }
    }
}
