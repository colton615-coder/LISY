import SwiftUI
import PhotosUI
import AVFoundation
import SwiftData
import UniformTypeIdentifiers

struct AddSwingRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let autoPresentPicker: Bool
    let autoImportOnSelection: Bool
    let onSaved: (SwingRecord) -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var selectedVideoFilename = ""
    @State private var isShowingVideoPicker = false
    @State private var isPreparingSelection = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ModuleSpacing.large) {
                    ModuleRowSurface(theme: AppModule.garage.theme) {
                        if let selectedVideoURL {
                            GarageSelectedVideoPreview(
                                videoURL: selectedVideoURL,
                                filename: selectedVideoFilename,
                                replaceVideo: { isShowingVideoPicker = true },
                                removeVideo: removeSelectedVideo
                            )
                        } else {
                            VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                                Text("Select a swing video")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                Text("Start by choosing one clip. Garage will save it locally, then take you straight into review.")
                                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                                Button("Choose Video") {
                                    isShowingVideoPicker = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppModule.garage.theme.primary)
                            }
                        }
                    }

                    if autoImportOnSelection == false {
                        ModuleRowSurface(theme: AppModule.garage.theme) {
                            Text("Save Details")
                                .font(.headline)
                                .foregroundStyle(AppModule.garage.theme.textPrimary)

                            TextField("Title (optional)", text: $title)
                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                        }
                    }
                }
                .padding(.horizontal, ModuleSpacing.large)
                .padding(.vertical, ModuleSpacing.medium)
            }
            .navigationTitle(autoImportOnSelection ? "Import Swing Video" : "New Swing Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if autoImportOnSelection == false {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Saving..." : "Save") {
                            saveRecord()
                        }
                        .disabled(selectedVideoURL == nil || isPreparingSelection || isSaving)
                    }
                }
            }
            .photosPicker(
                isPresented: $isShowingVideoPicker,
                selection: $selectedVideoItem,
                matching: .videos,
                preferredItemEncoding: .current
            )
            .onChange(of: selectedVideoItem) { _, newItem in
                guard let newItem else { return }
                prepareSelectedVideo(newItem)
            }
            .task {
                guard autoPresentPicker, selectedVideoURL == nil, isShowingVideoPicker == false else { return }
                isShowingVideoPicker = true
            }
            .overlay {
                if isPreparingSelection || isSaving {
                    GarageAddRecordProgressOverlay(isSaving: isSaving)
                }
            }
            .alert(
                "Garage Video Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if isPresented == false {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func prepareSelectedVideo(_ item: PhotosPickerItem) {
        isPreparingSelection = true
        errorMessage = nil

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: GaragePickedMovie.self) else {
                    throw GarageImportError.unableToLoadSelection
                }

                await MainActor.run {
                    selectedVideoURL = movie.url
                    selectedVideoFilename = movie.displayName
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = suggestedTitle(for: movie.displayName)
                    }
                    isPreparingSelection = false
                    if autoImportOnSelection {
                        saveRecord()
                    }
                }
            } catch {
                await MainActor.run {
                    selectedVideoItem = nil
                    selectedVideoURL = nil
                    selectedVideoFilename = ""
                    isPreparingSelection = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeSelectedVideo() {
        selectedVideoItem = nil
        selectedVideoURL = nil
        selectedVideoFilename = ""
    }

    private func saveRecord() {
        guard let selectedVideoURL else { return }
        guard isSaving == false else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let reviewMasterURL = try GarageMediaStore.persistReviewMaster(from: selectedVideoURL)
                async let analysisTask = GarageAnalysisPipeline.analyzeVideo(at: reviewMasterURL)
                async let exportTask = GarageMediaStore.createExportDerivative(from: reviewMasterURL)

                let output = try await analysisTask
                let exportURL = await exportTask
                let resolvedTitle = resolvedRecordTitle(fallbackURL: reviewMasterURL)
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let reviewMasterBookmark = GarageMediaStore.bookmarkData(for: reviewMasterURL)
                let exportBookmark = exportURL.flatMap { GarageMediaStore.bookmarkData(for: $0) }

                let record = SwingRecord(
                    title: resolvedTitle,
                    mediaFilename: reviewMasterURL.lastPathComponent,
                    mediaFileBookmark: reviewMasterBookmark,
                    reviewMasterFilename: reviewMasterURL.lastPathComponent,
                    reviewMasterBookmark: reviewMasterBookmark,
                    exportAssetFilename: exportURL?.lastPathComponent,
                    exportAssetBookmark: exportBookmark,
                    notes: trimmedNotes,
                    frameRate: output.frameRate,
                    swingFrames: output.swingFrames,
                    keyFrames: output.keyFrames,
                    handAnchors: output.handAnchors,
                    pathPoints: output.pathPoints,
                    analysisResult: output.analysisResult
                )

                await MainActor.run {
                    modelContext.insert(record)
                    try? modelContext.save()
                    isSaving = false
                    onSaved(record)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resolvedRecordTitle(fallbackURL: URL) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty == false {
            return trimmedTitle
        }

        let preferredName = selectedVideoFilename.isEmpty ? fallbackURL.lastPathComponent : selectedVideoFilename
        return suggestedTitle(for: preferredName)
    }

    private func suggestedTitle(for filename: String) -> String {
        let stem = URL(filePath: filename).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stem.isEmpty == false {
            return stem
        }

        return "Swing \(Date.now.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct GarageSelectedVideoPreview: View {
    let videoURL: URL
    let filename: String
    let replaceVideo: () -> Void
    let removeVideo: () -> Void

    @State private var previewImage: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .fill(AppModule.garage.theme.surfaceSecondary)

                if let previewImage {
                    Image(decorative: previewImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppModule.garage.theme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )

            Text(filename)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: ModuleSpacing.small) {
                Button("Choose Different Video", action: replaceVideo)
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
                Button("Remove", role: .destructive, action: removeVideo)
                    .buttonStyle(.bordered)
            }
        }
        .task(id: videoURL) {
            previewImage = await GarageMediaStore.thumbnail(for: videoURL, at: 0)
        }
    }
}

private struct GarageAddRecordProgressOverlay: View {
    let isSaving: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack(alignment: .center, spacing: ModuleSpacing.medium) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppModule.garage.theme.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSaving ? "Importing swing" : "Loading preview")
                            .font(.headline)
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text("Please hold for a moment.")
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, ModuleSpacing.large)
        }
    }
}

private struct GaragePickedMovie: Transferable {
    let url: URL
    let displayName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let originalFilename = received.file.lastPathComponent.isEmpty ? "swing.mov" : received.file.lastPathComponent
            let stem = URL(fileURLWithPath: originalFilename).deletingPathExtension().lastPathComponent
            let ext = URL(fileURLWithPath: originalFilename).pathExtension.isEmpty ? "mov" : URL(fileURLWithPath: originalFilename).pathExtension
            let sanitizedStem = stem.replacingOccurrences(of: "/", with: "-")
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(sanitizedStem)-\(UUID().uuidString.prefix(8))")
                .appendingPathExtension(ext)

            if FileManager.default.fileExists(atPath: destinationURL.path()) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return GaragePickedMovie(url: destinationURL, displayName: originalFilename)
        }
    }
}

private enum GarageImportError: LocalizedError {
    case unableToLoadSelection

    var errorDescription: String? {
        switch self {
        case .unableToLoadSelection:
            "The selected video could not be loaded from Photos."
        }
    }
}
