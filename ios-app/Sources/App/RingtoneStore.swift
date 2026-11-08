import Foundation
import AVFoundation
import UniformTypeIdentifiers

/// iOS 的提醒铃声只能来自 App 自己的沙盒：必须落在 `Library/Sounds/` 里，
/// 格式只认 aiff / wav / caf，且播放时长上限 30 秒（系统硬限制，超了会静默不响）。
/// 所以这里的做法是：用户从「文件」里选一首 → 复制进 Library/Sounds → 记住文件名。
public final class RingtoneStore {

    public static let shared = RingtoneStore()

    /// iOS 允许作为通知铃声的扩展名
    public static let allowedExtensions: Set<String> = ["wav", "aif", "aiff", "caf"]
    public static let maxSeconds: Double = 30

    private let defaultsKey = "ringtone_file_name"

    private var soundsDir: URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 当前自定义铃声文件名；nil 表示走系统默认
    public var fileName: String? {
        get { UserDefaults.standard.string(forKey: defaultsKey) }
    }

    public var currentFileURL: URL? {
        guard let name = fileName else { return nil }
        let url = soundsDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public enum ImportError: LocalizedError {
        case unsupportedFormat
        case tooLong(seconds: Double)
        case unreadable

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "iOS 的通知铃声只支持 wav / aiff / caf，换一个这种格式的文件吧"
            case .tooLong(let seconds):
                return "这段音频有 \(Int(seconds)) 秒，iOS 通知铃声最长 30 秒"
            case .unreadable:
                return "这个音频读不出来，换一个试试"
            }
        }
    }

    /// 复制用户选中的音频进沙盒；返回落盘后的文件名
    @discardableResult
    public func importAudio(from url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        guard Self.allowedExtensions.contains(ext) else {
            throw ImportError.unsupportedFormat
        }

        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite && seconds > Self.maxSeconds {
            throw ImportError.tooLong(seconds: seconds)
        }

        // 覆盖同名文件前先删，避免旧的残留
        let target = soundsDir.appendingPathComponent("worknote_ringtone.\(ext)")
        cleanup()
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: url, to: target)
        } catch {
            throw ImportError.unreadable
        }
        guard let size = try? FileManager.default.attributesOfItem(atPath: target.path)[.size] as? NSNumber,
              size.intValue > 0 else {
            throw ImportError.unreadable
        }
        UserDefaults.standard.set(target.lastPathComponent, forKey: defaultsKey)
        return target.lastPathComponent
    }

    public func reset() {
        cleanup()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func cleanup() {
        let files = (try? FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil)) ?? []
        for f in files where f.lastPathComponent.hasPrefix("worknote_ringtone") {
            try? FileManager.default.removeItem(at: f)
        }
    }
}
