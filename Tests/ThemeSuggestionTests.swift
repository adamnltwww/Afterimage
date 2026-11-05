import XCTest
import SwiftData
@testable import Afterimage

final class ThemeSuggestionTests: XCTestCase {
    func testMatchesNewThemesFromTitleAndBody() {
        XCTAssertEqual(Set(ThemeSuggestions.names(title: "湖边拍日出", text: "", existing: [])), Set(["湖边", "摄影", "日出日落"]))
        XCTAssertTrue(ThemeSuggestions.names(title: "", text: "下班后去喝咖啡", existing: []).contains("咖啡"))
    }

    func testExistingAliasRetainsUserSpellingInsteadOfCreatingSynonym() {
        let names = ThemeSuggestions.names(title: "在湖畔散步", text: "", existing: ["Lake", "lake"])
        XCTAssertTrue(names.contains("Lake"))
        XCTAssertFalse(names.contains("湖边"))
        XCTAssertEqual(names.filter { $0.lowercased() == "lake" }.count, 1)
    }

    func testCustomExistingThemeAndEnglishWordBoundaries() {
        XCTAssertEqual(ThemeSuggestions.names(title: "Blake", text: "", existing: ["Blake", "Lake"]), ["Blake"])
        XCTAssertTrue(ThemeSuggestions.names(title: "CAFE", text: "", existing: ["Café"]).contains("Café"))
        XCTAssertTrue(ThemeSuggestions.names(title: "在紫金山走了很久", text: "", existing: ["紫金山"]).contains("紫金山"))
    }

    func testVariedScenariosAndRecommendationLimit() {
        for (text, tag) in [("去美术馆看展", "展览"), ("猫咪睡在窗台上", "宠物"), ("第一次烤可颂", "烘焙"), ("调试代码到深夜", "编程"), ("收到生日礼物", "生日"), ("雨后樱花开了", "花草")] {
            XCTAssertTrue(ThemeSuggestions.names(title: text, text: "", existing: []).contains(tag), text)
        }
        XCTAssertEqual(ThemeSuggestions.names(title: "拍照喝咖啡看展听歌", text: "", existing: []).count, 3)
        XCTAssertTrue(ThemeSuggestions.names(title: "湖边", text: "", existing: [], limit: 0).isEmpty)
        XCTAssertTrue(ThemeSuggestions.names(title: "", text: "嗯", existing: []).isEmpty)
    }

    func testExtractsUnlistedEnglishNoun() {
        let names = ThemeSuggestions.names(title: "Telescope", text: "", existing: [])
        XCTAssertTrue(names.contains { $0.lowercased() == "telescope" })
        XCTAssertTrue(ThemeSuggestions.names(title: "望远镜", text: "", existing: []).contains("望远镜"))
        XCTAssertTrue(ThemeSuggestions.names(title: "今天", text: "", existing: []).isEmpty)
    }

    @MainActor
    func testSuggestedThemeReusesStoredThemeAndCreatesConnections() throws {
        let container = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try MemoryStore.save(record: nil, text: "旧记录", occurredAt: Date(), photoData: nil, tagText: "Lake", in: context)
        let tag = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryTag>()).first)
        tag.colorIndex = 4
        let names = ThemeSuggestions.names(title: "湖畔散步", text: "", existing: [tag.name])
        try MemoryStore.save(record: nil, text: "新记录", occurredAt: Date(), photoData: nil, tagText: names.joined(separator: "、"), in: context)
        let records = try context.fetch(FetchDescriptor<MemoryRecord>())
        XCTAssertEqual(records.filter { $0.tags.contains { $0.key == tag.key } }.count, 2)
        XCTAssertEqual(tag.colorIndex, 4)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MemoryTag>()).filter { $0.name == "Lake" }.count, 1)
    }
}
