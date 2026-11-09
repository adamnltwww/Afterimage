import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import ImageIO

struct MemoryEditorView: View {
    @AppStorage(AppPreferences.suggestionsKey) private var suggestionsEnabled = true
    @AppStorage(AppPreferences.autoSelectKey) private var autoSelectSuggestions = true
    @AppStorage(AppPreferences.photoDateKey) private var usePhotoDate = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let record: MemoryRecord?
    @Query private var existingThemes: [MemoryTag]
    @State private var suggestionChoices: [String: Bool] = [:]
    @State private var matchedSuggestions: [String] = []
    @State private var matchedInput = ""
    @State private var text: String
    @State private var title: String
    @State private var occurredAt: Date
    @State private var tagText: String
    @State private var photoData: Data?
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var extraPhotos: [Data]
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?
    @State private var confirmDiscard = false
    @State private var photoChanged = false
    @State private var photoTimeMessage: String?
    @State private var initialDate: Date
    @State private var draftReady = false
    @State private var draftFinished = false
    @State private var draftStatus: String?
    @State private var photoRevision = 0
    @State private var dragSession = UUID().uuidString

    private var draftScope: String {
        context.container.configurations.first?.url.absoluteString ?? "default"
    }
    private var draftValue: EditorDraft {
        EditorDraft(title: title, text: text, date: occurredAt, tags: tagText, photos: currentPhotos, choices: suggestionChoices)
    }
    private var draftTrigger: String {
        [title, text, tagText, String(occurredAt.timeIntervalSince1970), String(photoRevision),
         suggestionChoices.keys.sorted().map { $0 + String(suggestionChoices[$0]!) }.joined()].joined(separator: "\u{0}")
    }

    init(record: MemoryRecord? = nil) {
        self.record = record
        let date = record?.occurredAt ?? Date()
        _text = State(initialValue: record?.text ?? "")
        _title = State(initialValue: record?.displayTitle ?? "")
        _occurredAt = State(initialValue: date)
        _initialDate = State(initialValue: date)
        _tagText = State(initialValue: record?.tags.map(\.name).sorted().joined(separator: "、") ?? "")
        _photoData = State(initialValue: record?.photoData)
        _extraPhotos = State(initialValue: Array((record?.photos ?? []).dropFirst()))
    }

    private var changed: Bool {
        title != (record?.displayTitle ?? "") || text != (record?.text ?? "") || occurredAt != initialDate || photoChanged ||
        tagText != (record?.tags.map(\.name).sorted().joined(separator: "、") ?? "") ||
        suggestionChoices.values.contains(true)
    }

    private var suggestions: [String] {
        guard suggestionsEnabled else { return [] }
        let manual = Set(TagInput.names(from: tagText).map { TagInput.key(for: $0) })
        return (matchedInput == matchingInput ? matchedSuggestions : [])
            .filter { !manual.contains(TagInput.key(for: $0)) }
    }

    private var matchingInput: String {
        String(suggestionsEnabled) + "\u{0}" + title + "\u{0}" + text + "\u{0}" + existingThemes.map(\.name).sorted().joined(separator: "\u{0}")
    }

    private func includesSuggestion(_ name: String) -> Bool {
        suggestionChoices[TagInput.key(for: name)] ?? (record == nil && autoSelectSuggestions)
    }

    private var savedTagText: String {
        (TagInput.names(from: tagText) + suggestions.filter { includesSuggestion($0) }).joined(separator: "、")
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if let draftStatus { Text(draftStatus).font(.caption).foregroundStyle(.secondary) }
                    Section {
                        TextField("给这个瞬间起个标题", text: $title, axis: .vertical)
                            .lineLimit(1...4)
                            .accessibilityIdentifier("memory.title")
                            .onChange(of: title) { _, value in
                                if value.count > 40 { title = String(value.prefix(40)) }
                            }
                    } header: { Text("标题") }
                    footer: { Text("显示在时间轴上，最多 40 字；留空时从正文首句生成。") }
                    Section {
                        TextField("把想记住的细节写在这里。", text: $text, axis: .vertical)
                            .lineLimit(4...12)
                            .accessibilityIdentifier("memory.text")
                    } header: { Text("正文 · 可选") }
                    footer: { Text("完整正文只在瞬间详情中显示。") }

                    Section {
                        DatePicker("发生时间", selection: $occurredAt)
                        TextField("例如：摄影、湖边", text: $tagText)
                            .accessibilityIdentifier("memory.tags")
                    } footer: { Text("手动添加主题，用顿号或逗号分隔。") }

                    if !suggestions.isEmpty {
                        Section {
                            ForEach(suggestions, id: \.self) { name in
                                Button {
                                    suggestionChoices[TagInput.key(for: name)] = !includesSuggestion(name)
                                } label: {
                                    HStack {
                                        Text(name).foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: includesSuggestion(name) ? "checkmark.circle.fill" : "circle")
                                    }
                                }
                                .accessibilityLabel("推荐主题：\(name)")
                                .accessibilityValue(includesSuggestion(name) ? "已选中" : "未选中")
                                .accessibilityHint("轻点切换，选中的主题将在保存时加入")
                                .accessibilityIdentifier("memory.suggestion.\(name)")
                            }
                        } header: { Text("自动匹配主题") }
                        footer: { Text(record == nil ? "根据标题和正文在本机匹配，已为你选中；轻点取消，保存后加入主题。" : "根据当前内容匹配，轻点选择要补充的主题。") }
                    }

                    Section {
                        ForEach(Array(currentPhotos.enumerated()), id: \.offset) { index, data in
                            VStack(alignment: .leading, spacing: 8) {
                                ReadingPhoto(data: data).frame(maxHeight: 220)
                                HStack {
                                    Text(index == 0 ? "封面" : "第 \(index + 1) 张").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    if index > 0 {
                                        Button("设为封面") { var photos = currentPhotos; let cover = photos.remove(at: index); photos.insert(cover, at: 0); setPhotos(photos) }.buttonStyle(.borderless)
                                        Button { var photos = currentPhotos; photos.swapAt(index, index - 1); setPhotos(photos) } label: { Image(systemName: "arrow.up") }
                                            .buttonStyle(.borderless).accessibilityLabel("向前移动照片")
                                    }
                                    Button(role: .destructive) { var photos = currentPhotos; photos.remove(at: index); setPhotos(photos) } label: { Image(systemName: "trash") }
                                        .buttonStyle(.borderless).accessibilityLabel("移除第 \(index + 1) 张照片")
                                }
                            }.disabled(isLoadingPhoto)
                                .draggable(dragSession + ":" + String(index))
                                .dropDestination(for: String.self) { items, _ in
                                    guard !isLoadingPhoto, let value = items.first,
                                          value.hasPrefix(dragSession + ":"), let source = Int(value.split(separator: ":").last ?? ""),
                                          currentPhotos.indices.contains(source), source != index else { return false }
                                    var photos = currentPhotos
                                    photos.insert(photos.remove(at: source), at: index)
                                    setPhotos(photos)
                                    return true
                                }
                        }
                        PhotosPicker(selection: $photoSelections, maxSelectionCount: max(1, 9 - currentPhotos.count), selectionBehavior: .ordered, matching: .images, preferredItemEncoding: .current, photoLibrary: .shared()) {
                            Label(currentPhotos.isEmpty ? "添加照片" : "继续添加照片", systemImage: "photo.on.rectangle.angled")
                        }
                        .disabled(isLoadingPhoto || currentPhotos.count >= 9)
                        if isLoadingPhoto { ProgressView("正在处理照片…") }
                        if let photoTimeMessage {
                            Text(photoTimeMessage).font(.footnote).foregroundStyle(.secondary)
                        }
                    } header: { Text("照片 · 可选") }
                    footer: { Text("最多 9 张，长按照片可拖动排序，也可使用向前移动按钮。第一张作为主轴封面。保存适合浏览的副本，原照片不受影响。") }
                }.listRowBackground(AfterimageStyle.surface)
            }
            .scrollContentBackground(.hidden).afterimageSheetSurface()
            .scrollDismissesKeyboard(.interactively)
            .background(AfterimageStyle.background)
            .navigationTitle(record == nil ? "记录瞬间" : "编辑瞬间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if changed { confirmDiscard = true } else { dismiss() }
                    }
                    .accessibilityIdentifier("memory.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!draftReady || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || isLoadingPhoto || (suggestionsEnabled && matchedInput != matchingInput))
                        .accessibilityIdentifier("memory.save")
                }
            }
            .interactiveDismissDisabled(changed || isLoadingPhoto)
            .confirmationDialog("如何保留这次编辑？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("保存草稿并退出") {
                    Task { if await persistDraft() { draftFinished = true; dismiss() } }
                }
                Button("放弃修改", role: .destructive) {
                    Task {
                        do {
                            draftFinished = true
                            try await EditorDraftStore.shared.remove(scope: draftScope, recordID: record?.id)
                            dismiss()
                        } catch { draftFinished = false; errorMessage = error.localizedDescription }
                    }
                }
                    .accessibilityIdentifier("memory.discard")
                Button("继续编辑", role: .cancel) {}
            }
            .alert("未能完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .task(id: matchingInput) {
                guard suggestionsEnabled else { matchedSuggestions = []; matchedInput = matchingInput; return }
                let input = matchingInput
                let heading = title
                let body = text
                let names = existingThemes.map(\.name)
                do {
                    try await Task.sleep(for: .milliseconds(250))
                    let result = await Task.detached(priority: .userInitiated) {
                        ThemeSuggestions.names(title: heading, text: body, existing: names)
                    }.value
                    try Task.checkCancellation()
                    matchedSuggestions = result
                    matchedInput = input
                } catch is CancellationError {
                    // The next keystroke replaces this match, including before saving.
                } catch { }
            }
            .task {
                guard !draftReady else { return }
                do {
                    if let draft = try await EditorDraftStore.shared.load(scope: draftScope, recordID: record?.id) {
                        title = draft.title; text = draft.text; occurredAt = draft.date; tagText = draft.tags
                        suggestionChoices = draft.choices
                        setPhotos(draft.photos)
                        draftStatus = "已恢复上次草稿"
                    }
                } catch { errorMessage = "草稿读取失败，原记录未改变。\n\(error.localizedDescription)" }
                draftReady = true
            }
            .task(id: draftTrigger) {
                guard draftReady, !draftFinished, changed else { return }
                do { try await Task.sleep(for: .milliseconds(700)); try Task.checkCancellation() }
                catch { return }
                _ = await persistDraft()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active && draftReady && !draftFinished && changed { Task { _ = await persistDraft() } }
            }
            .disabled(!draftReady || draftFinished)
            .task(id: photoSelections) {
                guard !photoSelections.isEmpty else { return }
                let selections = photoSelections
                isLoadingPhoto = true
                defer { isLoadingPhoto = false }
                do {
                    var imported: [Data] = []
                    var firstDate: Date?
                    for selection in selections.prefix(max(0, 9 - currentPhotos.count)) {
                        guard let data = try await selection.loadTransferable(type: Data.self) else { throw PhotoImportError.unreadable }
                        let processed = try await Task.detached(priority: .userInitiated) {
                            (try PhotoImport.prepare(data), PhotoImport.captureDate(from: data))
                        }.value
                        try Task.checkCancellation()
                        if imported.isEmpty { firstDate = processed.1 }
                        imported.append(processed.0)
                    }
                    if currentPhotos.isEmpty && usePhotoDate {
                        if let date = firstDate {
                            occurredAt = date
                            photoTimeMessage = "发生时间已对齐封面拍摄时间，你仍可手动修改。"
                        } else { photoTimeMessage = "封面未提供拍摄时间，已保留当前发生时间。" }
                    }
                    setPhotos(currentPhotos + imported)
                    photoSelections = []
                } catch is CancellationError {
                    // A newer selection replaces this request.
                } catch {
                    if !Task.isCancelled { errorMessage = "照片导入失败，原照片仍保留。\n\(error.localizedDescription)"; photoSelections = [] }
                }
            }
        }
    }

    private var currentPhotos: [Data] { (photoData.map { [$0] } ?? []) + extraPhotos }
    private func setPhotos(_ photos: [Data]) {
        photoData = photos.first
        extraPhotos = Array(photos.dropFirst())
        photoChanged = true
        photoRevision += 1
    }

    private func persistDraft() async -> Bool {
        guard !draftFinished else { return true }
        let value = draftValue
        do {
            try await EditorDraftStore.shared.save(value, scope: draftScope, recordID: record?.id)
            draftStatus = "草稿已保存在本机"
            return true
        } catch is CancellationError { return false }
        catch { errorMessage = "草稿保存失败，请保留此页面并重试。\n\(error.localizedDescription)"; return false }
    }

    private func save() {
        do {
            try MemoryStore.save(record: record, text: text, occurredAt: occurredAt,
                                 photoData: photoData, tagText: savedTagText, title: title, extraPhotos: extraPhotos, in: context)
            if AppPreferences.hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            draftFinished = true
            Task {
                do { try await EditorDraftStore.shared.remove(scope: draftScope, recordID: record?.id); dismiss() }
                catch { draftFinished = false; errorMessage = "记录已保存，但旧草稿未能清除。\n\(error.localizedDescription)" }
            }
        } catch {
            if AppPreferences.hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            errorMessage = "保存失败，编辑内容仍在此处，请重试。\n\(error.localizedDescription)"
        }
    }
}

enum PhotoImportError: LocalizedError {
    case unreadable
    var errorDescription: String? { "无法读取这张照片，请选择另一张。" }
}

enum PhotoImport {
    static func captureDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let timestamp = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        if let offset = exif["OffsetTimeOriginal"] as? String,
           offset.range(of: "^[+-][0-9]{2}:[0-9]{2}$", options: .regularExpression) != nil {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXX"
            return formatter.date(from: timestamp + offset)
        }
        // Older cameras omit their timezone. Interpret their wall time in the phone's current zone.
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: timestamp)
    }

    static func prepare(_ data: Data) throws -> Data {
        // Downsample before decoding large camera images. The rendered JPEG drops source EXIF/GPS.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2000
              ] as CFDictionary),
              let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.85) else {
            throw PhotoImportError.unreadable
        }
        return jpeg
    }
}
