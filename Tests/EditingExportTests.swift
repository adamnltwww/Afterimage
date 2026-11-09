import XCTest
import SwiftUI
import UIKit
import PDFKit
@testable import Afterimage

@MainActor final class EditingExportTests: XCTestCase {
    func testDraftRoundtripIncludesPhotoOrderAndChoices() async throws {
        let scope = UUID().uuidString
        let id = UUID()
        let draft = EditorDraft(title: "标题", text: "完整正文\n下一行", date: Date(timeIntervalSince1970: 123), tags: "旅行", photos: [Data([3]), Data([1])], choices: ["旅行": false])
        try await EditorDraftStore.shared.save(draft, scope: scope, recordID: id)
        let restored = try await EditorDraftStore.shared.load(scope: scope, recordID: id)
        XCTAssertEqual(restored, draft)
        let unrelated = try await EditorDraftStore.shared.load(scope: scope, recordID: nil)
        XCTAssertNil(unrelated)
        try await EditorDraftStore.shared.remove(scope: scope, recordID: id)
        let removed = try await EditorDraftStore.shared.load(scope: scope, recordID: id)
        XCTAssertNil(removed)
    }
    func testDateFilterIncludesWholeDayAndCalendarBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var filter = TimelineDateFilter()
        filter.mode = .custom; filter.start = Date(timeIntervalSince1970: 0); filter.end = Date(timeIntervalSince1970: 86400)
        XCTAssertTrue(filter.contains(Date(timeIntervalSince1970: 172799), calendar: calendar))
        XCTAssertFalse(filter.contains(Date(timeIntervalSince1970: 172800), calendar: calendar))
        filter.mode = .month; filter.anchor = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(filter.contains(Date(timeIntervalSince1970: 31 * 86400 - 1), calendar: calendar))
        XCTAssertFalse(filter.contains(Date(timeIntervalSince1970: 31 * 86400), calendar: calendar))
    }
    func testZipPreservesTextAndImageBytes() throws {
        let photo = Data([0xff, 0xd8, 1, 2, 3])
        let moment = MemoryArchive.Moment(id: UUID(), title: "测试", text: "正文\n完整保留", occurredAt: Date(), createdAt: Date(), photos: [photo], themeKeys: [])
        let archive = MemoryArchive(memories: [moment], themes: [], links: [])
        let entries = try ContentExport.entries(archive: archive)
        XCTAssertEqual(entries.first(where: { $0.name.hasSuffix("01-cover.jpg") })?.data, photo)
        XCTAssertTrue(String(data: try XCTUnwrap(entries.first(where: { $0.name.hasSuffix("record.txt") })?.data), encoding: .utf8)!.contains("正文\n完整保留"))
        XCTAssertEqual(ContentExport.crc32(Data("123456789".utf8)), 0xcbf43926)
        let zip = try ContentExport.zip(entries)
        XCTAssertEqual(Array(zip.prefix(4)), [0x50, 0x4b, 0x03, 0x04])
        let attachment = XCTAttachment(data: zip, uniformTypeIdentifier: "public.zip-archive")
        attachment.name = "content-export-check.zip"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLongExportKeepsMoreThanTwelveRecordsAtFullResolution() async throws {
        let records = (0..<14).map { index -> MemoryRecord in
            let record = MemoryRecord(text: "第 \(index + 1) 个瞬间\n" + String(repeating: "正文不再被截断，所有细节都可以读到。\n", count: index == 13 ? 120 : 4), occurredAt: Date(timeIntervalSince1970: Double(index) * 86400))
            record.title = "瞬间 \(index + 1)"
            return record
        }
        let files = try await LongImageExport.render(records: records)
        XCTAssertGreaterThan(files.count, 1)
        for url in files {
            let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
            XCTAssertEqual(image.size.width, 1170)
            XCTAssertLessThanOrEqual(image.size.height, 9000)
        }
        for url in [files.first!, files.last!] {
            let attachment = XCTAttachment(image: try XCTUnwrap(UIImage(contentsOfFile: url.path)))
            attachment.name = url.lastPathComponent; attachment.lifetime = .keepAlways; add(attachment)
        }
        try FileManager.default.removeItem(at: files[0].deletingLastPathComponent())
    }
    func testPDFKeepsCompleteSearchableTextInOneDocument() async throws {
        let records = (0..<14).map { index -> MemoryRecord in
            let record = MemoryRecord(text: String(repeating: "Readable full text without truncation. ", count: 12) + " END-\(index)", occurredAt: Date())
            record.title = "Moment \(index)"
            return record
        }
        let url = try await LongImageExport.pdf(records: records)
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(document.pageCount, 1)
        let text = try XCTUnwrap(document.string)
        for index in 0..<14 { XCTAssertTrue(text.contains("END-\(index)")) }
        let attachment = XCTAttachment(data: try Data(contentsOf: url), uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "continuous-full-content.pdf"; attachment.lifetime = .keepAlways; add(attachment)
        try FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
