import Foundation
import UIKit
import Vision

/// 从行程截图里认出「这是一趟什么行程」。
///
/// 识别用系统自带的 Vision 文字识别（离线，图片不出本机）；
/// 解析只做规则抽取，抓不到日期或时间就留空，交给用户在编辑页自己补。
struct TripGuess {
    var title: String
    var detail: String
    var year: Int?
    var month: Int?
    var day: Int?
    var hour: Int?
    var minute: Int?
    var kind: String
}

enum TripScanner {

    static let kindFlight = "flight"
    static let kindTrain = "train"
    static let kindOther = "other"

    private static let flightPattern = "(?<![A-Za-z0-9])([A-Za-z]{2}\\s?\\d{3,4})(?![0-9])"
    private static let trainPattern = "([GDCKTZ]\\s?\\d{1,4})(?![0-9])"
    private static let dateFullPattern = "(\\d{4})\\s*年\\s*(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日"
    private static let dateMonthDayPattern = "(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日"
    private static let dateDashPattern = "(\\d{4})[-/](\\d{1,2})[-/](\\d{1,2})"
    private static let timePattern = "(\\d{1,2})[:：](\\d{2})"
    private static let stationPattern = "([\\u4e00-\\u9fa5]{2,8}(?:站|机场|航站楼))"
    private static let routePattern = "([\\u4e00-\\u9fa5]{2,10})\\s*(?:→|->|—|至|到|飞往)\\s*([\\u4e00-\\u9fa5]{2,10})"
    private static let timeKeywordPattern = "起飞|出发|发车|始发|登机|开车|接机|送机|到达|抵达"

    /// 识别图片里的文字；失败或没有文字时返回 nil
    static func recognise(image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    static func parse(_ raw: String) -> TripGuess {
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let text = lines.joined(separator: " ")

        let flight = firstMatch(flightPattern, text)
        let train = flight == nil ? firstMatch(trainPattern, text) : nil
        let route = routeOf(text)
        let stations = stationsOf(text)

        var year: Int?
        var month: Int?
        var day: Int?
        if let m = matches(dateFullPattern, text) {
            year = Int(m[0]); month = Int(m[1]); day = Int(m[2])
        }
        if day == nil, let m = matches(dateDashPattern, text) {
            year = Int(m[0]); month = Int(m[1]); day = Int(m[2])
        }
        if day == nil, let m = matches(dateMonthDayPattern, text) {
            month = Int(m[0]); day = Int(m[1])
        }

        let time = pickTime(lines: lines, text: text)

        var title: String
        var kind: String
        if let flight {
            kind = kindFlight
            let code = flight.replacingOccurrences(of: " ", with: "").uppercased()
            var whereText = ""
            if let route {
                whereText = " \(route.0)→\(route.1)"
            } else if stations.count >= 2 {
                whereText = " \(stations[0])→\(stations[1])"
            }
            title = "航班 \(code)\(whereText)"
        } else if let train {
            kind = kindTrain
            let code = train.replacingOccurrences(of: " ", with: "").uppercased()
            var whereText = ""
            if stations.count >= 2 {
                whereText = " \(stations[0])→\(stations[1])"
            } else if let route {
                whereText = " \(route.0)→\(route.1)"
            }
            title = "车次 \(code)\(whereText)"
        } else {
            kind = kindOther
            let first = lines.first ?? ""
            title = first.isEmpty ? "行程" : String(first.prefix(28))
        }

        var detailParts: [String] = []
        if let flight { detailParts.append("航班：" + flight.replacingOccurrences(of: " ", with: "").uppercased()) }
        if let train { detailParts.append("车次：" + train.replacingOccurrences(of: " ", with: "").uppercased()) }
        if let route { detailParts.append("路线：\(route.0) → \(route.1)") }
        if !stations.isEmpty { detailParts.append("地点：" + stations.joined(separator: "、")) }
        let body = lines.prefix(6).joined(separator: "\n")
        if !body.isEmpty { detailParts.append("截图原文：\n" + body) }

        return TripGuess(
            title: title,
            detail: detailParts.joined(separator: "\n"),
            year: year,
            month: month,
            day: day,
            hour: time?.0,
            minute: time?.1,
            kind: kind
        )
    }

    private static func pickTime(lines: [String], text: String) -> (Int, Int)? {
        if let keywordLine = lines.first(where: { matches(timeKeywordPattern, $0) != nil && matches(timePattern, $0) != nil }),
           let m = matches(timePattern, keywordLine) {
            if let h = Int(m[0]), let min = Int(m[1]), (0...23).contains(h), (0...59).contains(min) { return (h, min) }
        }
        if let m = matches(timePattern, text), let h = Int(m[0]), let min = Int(m[1]), (0...23).contains(h), (0...59).contains(min) {
            return (h, min)
        }
        return nil
    }

    private static func firstMatch(_ pattern: String, _ text: String) -> String? {
        matches(pattern, text)?.first
    }

    private static func matches(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let result = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var groups: [String] = []
        for index in 1..<result.numberOfRanges {
            let range = result.range(at: index)
            groups.append(range.location == NSNotFound ? "" : ns.substring(with: range))
        }
        return groups.isEmpty ? nil : groups
    }

    private static func routeOf(_ text: String) -> (String, String)? {
        guard let groups = matches(routePattern, text), groups.count >= 2 else { return nil }
        return (groups[0], groups[1])
    }

    private static func stationsOf(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: stationPattern) else { return [] }
        let ns = text as NSString
        let found = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return found.prefix(4).compactMap { result -> String? in
            guard result.numberOfRanges > 1 else { return nil }
            let range = result.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            return ns.substring(with: range).replacingOccurrences(of: "站", with: "")
        }
    }
}
