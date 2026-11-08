import XCTest

/// 备份契约的回归测试。fixtures 就是 `contract/` 目录里那批文件，
/// 三端（Android 的 Python 校验器、iOS 的这套测试、鸿蒙的单测）跑的是同一批样本。
final class BackupCodecTests: XCTestCase {

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            throw XCTSkip("测试包里没有 \(name) 这个 fixtures，检查 XcodeGen 有没有把它当资源打包")
        }
        return try Data(contentsOf: url)
    }

    // MARK: - 合法文件

    func testDecodeSampleKeepsContractFields() throws {
        let data = try fixture("sample.taskbak")
        let (notes, report) = try BackupCodec.decode(data: data)

        XCTAssertTrue(report.isValid, "样例不该有错误：\(report.errors)")
        XCTAssertEqual(notes.count, 2)

        let first = notes[0]
        XCTAssertEqual(first.title, "接待客人")
        XCTAssertEqual(first.remark, "刘总安排接待")
        XCTAssertEqual(first.dateKey, "2026-11-09")
        XCTAssertEqual(first.loopType, .none)
        XCTAssertTrue(first.repeatEnabled)
        XCTAssertEqual(first.repeatMinutes, 15)
        XCTAssertEqual(first.actions.count, 3)
        XCTAssertEqual(first.actions.first?.type, .done)

        // 导入规则：remindCount 归零
        XCTAssertEqual(first.remindCount, 0)
        // 导入规则：非 DELETED 一律回落 PENDING
        XCTAssertEqual(first.status, .pending)
        XCTAssertEqual(notes[1].status, .pending)
        XCTAssertEqual(notes[1].loopType, .weekly)
    }

    func testExportImportRoundTrip() throws {
        let notes = [
            Note(title: "写周报", remark: "周五前", dateKey: "2026-11-13", remindAt: 1_794_600_000_000,
                 loopType: .weekly, repeatEnabled: true, repeatMinutes: 20, status: .pending,
                 createdAt: 1_794_500_000_000, remindCount: 2,
                 actions: [NoteAction(text: "交完了", type: .done), NoteAction(text: "再拖一天", type: .delay)]),
            Note(title: "报销", dateKey: "2026-11-14", createdAt: 1_794_500_000_000)
        ]

        let data = BackupCodec.encode(notes: notes, exportedAt: 1_794_600_000_000)
        let (decoded, report) = try BackupCodec.decode(data: data)

        XCTAssertTrue(report.isValid, "自己导出的文件必须能自己读回来：\(report.errors)")
        XCTAssertEqual(decoded.count, notes.count)
        XCTAssertEqual(decoded[0].title, notes[0].title)
        XCTAssertEqual(decoded[0].remindAt, notes[0].remindAt)
        XCTAssertEqual(decoded[0].actions.count, 2)
        XCTAssertEqual(decoded[0].remindCount, 0)
        XCTAssertNotEqual(decoded[0].id, notes[0].id, "id 是本机 UUID，导入时必须重新生成")
    }

    // MARK: - 坏文件必须被拦住

    func testRejectMissingTitle() throws {
        let data = try fixture("bad_missing_title.taskbak")
        let report = BackupCodec.validate(data: data)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.contains("title") })
    }

    func testRejectUnknownStatus() throws {
        let data = try fixture("bad_enum.taskbak")
        let report = BackupCodec.validate(data: data)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.contains("status") })
    }

    func testRejectImpossibleDate() throws {
        let data = try fixture("bad_date.taskbak")
        let report = BackupCodec.validate(data: data)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.contains("dateKey") })
    }

    func testRejectWrongVersion() throws {
        let data = try fixture("bad_version.taskbak")
        XCTAssertThrowsError(try BackupCodec.decode(data: data)) { error in
            guard case BackupError.unsupportedVersion = error else {
                return XCTFail("应该是版本不支持，实际：\(error)")
            }
        }
    }

    func testRejectTooLongActionText() throws {
        let data = try fixture("bad_action_len.taskbak")
        let report = BackupCodec.validate(data: data)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.contains("actions") })
    }

    func testRejectForeignFile() throws {
        let data = Data(#"{"app":"别的App","version":1,"exportedAt":1,"notes":[{"title":"x","dateKey":"2026-11-09","remindAt":0,"loopType":"NONE","status":"PENDING","createdAt":1}]}"#.utf8)
        XCTAssertThrowsError(try BackupCodec.decode(data: data))
    }

    func testRejectEmptyNotes() throws {
        let data = Data(#"{"app":"工作便签提醒","version":1,"exportedAt":1,"notes":[]}"#.utf8)
        XCTAssertThrowsError(try BackupCodec.decode(data: data)) { error in
            guard case BackupError.emptyNotes = error else { return XCTFail("空备份应报错") }
        }
    }

    func testDeletedStatusIsPreserved() throws {
        var note = Note(title: "已经删掉的", dateKey: "2026-11-09", status: .deleted, createdAt: 1_794_500_000_000)
        let data = BackupCodec.encode(notes: [note])
        let (decoded, _) = try BackupCodec.decode(data: data)
        note = decoded[0]
        XCTAssertEqual(note.status, .deleted, "DELETED 要保留在回收站，不能复活")
    }
}
