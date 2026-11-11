import SwiftUI
import AVFoundation

/// 功能说明页：把 App 的各页功能逐条讲清（设置页自身除外，各分组在自己页面里已有说明）。
/// 顶部可开关「内容播报」：开了之后点小节标题只读这一节，点按钮读整页。
struct HelpView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.colorScheme) private var scheme

    @StateObject private var speaker = HelpSpeaker()

    private var sections: [HelpSection] { HelpContent.sections }

    private var wholeText: String {
        ([HelpContent.intro] + sections.map { "\($0.title)。\($0.text)" }).joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(HelpContent.intro)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText(scheme))
                    .padding(.top, 12)

                Toggle(isOn: Binding(
                    get: { settings.helpTts },
                    set: { newValue in
                        settings.helpTts = newValue
                        if newValue { speaker.speak(wholeText) } else { speaker.stop() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("内容播报")
                            .font(.system(size: 15))
                        Text("打开后朗读说明内容，关掉只显示文字")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText(scheme))
                    }
                }
                .padding(.top, 16)

                Text(settings.helpTts ? "播报已开启：点小节标题只读这一节" : "播报已关闭：只显示文字")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText(scheme))
                    .padding(.top, 6)

                if settings.helpTts {
                    Button {
                        speaker.speak(wholeText)
                    } label: {
                        Text("播报整页说明")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }

                ForEach(sections) { section in
                    Text(section.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primaryText(scheme))
                        .padding(.top, 22)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if settings.helpTts {
                                speaker.speak("\(section.title)。\(section.text)")
                            }
                        }
                    Text(section.text)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText(scheme))
                        .lineSpacing(4)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.bottom, 28)
        }
        .background(Theme.pageBackground(scheme))
        .navigationTitle("功能说明")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }
}

struct HelpSection: Identifiable {
    let id: Int
    let title: String
    let text: String
}

/// 系统语音播报。语言跟随 App 当前语言，语速略慢一点（0.95 倍）听着更清楚。
final class HelpSpeaker: ObservableObject {
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        if let code = Locale.preferredLanguages.first,
           let voice = AVSpeechSynthesisVoice(language: code) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        }
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}

/// 说明正文。三端用同一套话术，涉及系统差异的段落按本端实际情况写。
enum HelpContent {
    static let intro = "下面按功能逐项讲清这个 App 怎么用。设置页各分组在自己页面里已有说明，这里不再重复。"

    static let sections: [HelpSection] = [
        HelpSection(
            id: 1,
            title: "主界面：便签列表",
            text: "一条便签一行：左边是标题与备注，右边是提醒时间与状态角标。右上角 ＋ 新建便签，旁边的菜单里有「显示全部便签 / 只看未处理」「搜索便签」「回收站」。角标含义：待提醒显示「待」，已经弹过通知但没处理显示已弹次数，已处理不再显示角标。列表按「等你处理 → 待提醒 → 已延后 → 已处理」的先后排，点任意一行进入详情页，左滑可以直接改状态。"
        ),
        HelpSection(
            id: 2,
            title: "日程：下拉模式与日历模式",
            text: "顶部右边两个按钮：左边是显示模式，右边是选年月。下拉模式把当月 1 号到月末纵向罗列，点某一天展开当天便签，角标是这天还没处理完的条数。日历模式是整月七列网格，点某一天在网格下方列出当天便签。两种模式看的是同一份数据，只是呈现方式不同，切换不影响任何便签内容。"
        ),
        HelpSection(
            id: 3,
            title: "新建与编辑便签",
            text: "要填的项：便签标题（必填）、备注说明、关联日期、提醒方式（定时提醒 / 循环重复 / 未处理就再弹，三种可以任意组合）、自定义操作按钮。点保存后立刻按当前设置重新排通知；修改一条便签会先取消旧通知，再按新时间重排，不会留下旧提醒。"
        ),
        HelpSection(
            id: 4,
            title: "关联日期、定时提醒、循环怎么配合",
            text: """
            三者各管一件事：关联日期决定这条便签归到日程的哪一天，只影响日程页的归类；定时提醒是一个绝对的时刻（年月日时分），决定什么时候弹通知；循环决定每次处理完之后下一次什么时候再来（每天 / 每周 / 每月）。
            编辑页里它们是联动的：选关联日期时，提醒时间会一起落到那一天的 09:00；反过来选提醒时间时，关联日期也会跟着变成同一天。所以默认状态下，日程归类和提醒时刻都落在同一天。
            到点之后按你点的按钮走：点「标记完成」，开了循环就顺延到下一个周期（每天 / 每周 / 每月），状态回到待提醒，关联日期改成下一次那天，到点继续弹；没开循环就直接结束，状态变已处理，提醒时间清零。点「延后 N 分钟」，提醒时间改成现在加 N 分钟，关联日期不动，到点再弹。点「仅关闭」，只关掉这一次通知，任务仍是待处理，但这一次不会再弹。
            另外，「未处理就再弹」是独立的：通知发出后没点任何按钮，就按设定的间隔（默认 15 分钟）继续补发，直到你点按钮为止；它和循环不冲突，一个是「这一次催到底」，一个是「下一次什么时候来」。
            """
        ),
        HelpSection(
            id: 5,
            title: "自定义操作按钮",
            text: "每条便签可以配自己的按钮文字（例如「我已提交」「十分钟后再说」），动作只有三种：标记完成、延后 N 分钟、仅关闭。通知上只会出现你配的这些按钮，另加系统的关闭入口（iOS 允许用户划掉通知，App 无法阻止）。"
        ),
        HelpSection(
            id: 6,
            title: "强提醒通知",
            text: "到点发一条时效性通知，并把通知上的按钮换成你给这条便签配的那几个。iOS 不允许 App 阻止用户划掉通知，也没有浮窗，所以这里的强提醒是「时效性通知 + 没处理就按间隔补发」，强度弱于 Android 版；要确保准时，请在系统设置里允许通知并关掉低电量模式。"
        ),
        HelpSection(
            id: 7,
            title: "便签详情页",
            text: "详情页显示完整标题、备注、关联日期、提醒时间、循环方式、未处理重弹间隔、当前状态，以及这条便签的全部按钮。点这里的按钮等于在通知上点同一个按钮。底部还有「编辑这条便签」「翻译便签文字」（交给系统翻译能力，不可用时复制到剪贴板）和删除（移到回收站，可再恢复）。"
        ),
        HelpSection(
            id: 8,
            title: "回收站",
            text: "默认是逐条处理：每行右边有「恢复」和「彻底删除」。右上角「多选」进入多选模式：逐条勾选后用底部「删除所选」一次删掉；「全选 / 取消全选」一次勾选全部或全部取消；「全部删除」直接清空整个回收站。彻底删除的记录只能靠以前的备份文件找回，恢复不回来。"
        ),
        HelpSection(
            id: 9,
            title: "通知与系统设置",
            text: "首次使用请允许通知；想让通知带声音，就在系统设置里给 App 开声音权限，并在「我」页选好提醒铃声。低电量模式、专注模式、短信/来电都可能把通知压掉，重要提醒建议不要放在这些模式下。"
        ),
        HelpSection(
            id: 10,
            title: "备份与恢复",
            text: "导出会生成一个 .taskbak 文件（内容是纯 JSON），用系统文件选择器存到你指定的位置；卸载 App 不会删掉它。导入是覆盖式的：先清空本机现有便签，再写入备份里的内容，并把全部提醒重新排一遍。换手机之前先导出。"
        ),
        HelpSection(
            id: 11,
            title: "界面与显示",
            text: "深色模式：跟随系统 / 浅色 / 深色。字体大小 1 到 10 档，越大字越大。背景图从相册选一张，主界面、日程、我三个 Tab 共用同一张底图。语言四档：跟随系统 / 简体中文 / 繁體中文 / English，切换后需要重新打开 App 才生效。便签文字翻译调用系统翻译能力。"
        ),
        HelpSection(
            id: 12,
            title: "数据与隐私",
            text: "所有便签只存在本机 App 沙盒里的一个 JSON 文件，没有网络请求、没有账号、没有云同步、没有统计埋点。卸载 App 会连数据一起删掉，所以换机前先到「我」页导出备份。"
        )
    ]
}
