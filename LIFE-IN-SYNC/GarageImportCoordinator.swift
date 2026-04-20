import Combine
import Foundation
import PhotosUI
import SwiftData
import SwiftUI

struct GarageImportNavigation {
    let showAnalyzerRecords: () -> Void
    let openReview: (String) -> Void
    let presentPicker: () -> Void
    let didMutatePersistence: () -> Void
}

func garagePerformRetryableOperation<T>(
    delayNanoseconds: UInt64 = 500_000_000,
    sleep: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
    onRetry: ((Error) async -> Void)? = nil,
    operation: () async throws -> T
) async throws -> T {
    var hasRetried = false

    while true {
        do {
            return try await operation()
        } catch {
            guard hasRetried == false, garageShouldRetryImportAfterFailure(error) else {
                throw error
            }

            hasRetried = true
            if let onRetry {
                await onRetry(error)
            }
            try await sleep(delayNanoseconds)
        }
    }
}

private func garageDiscardDetachedExportDerivative(at exportURL: URL) {
    guard FileManager.default.fileExists(atPath: exportURL.path) else {
        return
    }

    try? FileManager.default.removeItem(at: exportURL)
}

private func garageBackfillExportDerivative(
    using modelContainer: ModelContainer,
    recordID: PersistentIdentifier,
    reviewMasterURL: URL
) async {
    guard let exportURL = await GarageMediaStore.createExportDerivative(from: reviewMasterURL) else {
        return
    }

    let backgroundContext = ModelContext(modelContainer)

    guard let savedRecord = backgroundContext.model(for: recordID) as? SwingRecord else {
        garageDiscardDetachedExportDerivative(at: exportURL)
        return
    }

    savedRecord.hydrateExportDerivative(
        filename: exportURL.lastPathComponent,
        bookmark: GarageMediaStore.bookmarkData(for: exportURL)
    )

    do {
        try await garagePerformRetryableOperation {
            try backgroundContext.save()
        }
    } catch {
        garageDiscardDetachedExportDerivative(at: exportURL)

        let nsError = error as NSError
        let exportMessage = [
            "Garage export derivative save failed.",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            nsError.localizedDescription
        ].joined(separator: " ")
        NSLog("%@", exportMessage)
    }
}

@MainActor
final class GarageImportCoordinator: ObservableObject {
    @Published private(set) var importPresentationState: GarageImportPresentationState = .idle

    private(set) var activeImportRecordID: PersistentIdentifier?

    private var recoverableImportRecordID: PersistentIdentifier?
    private var pendingImportMovie: GaragePickedMovie?
    private var pendingPreFlightSelection = GaragePreFlightSelection()
    private var activeSessionID: UUID?
    private var selectionTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?

    deinit {
        selectionTask?.cancel()
        importTask?.cancel()
    }

    func dismissImportPresentation(navigation: GarageImportNavigation) {
        resetSession()
        pendingImportMovie = nil
        importPresentationState = .idle
        navigation.showAnalyzerRecords()
    }

    func prepareSelectedVideo(
        _ item: PhotosPickerItem,
        inferredSelection: GaragePreFlightSelection,
        modelContext: ModelContext,
        navigation: GarageImportNavigation
    ) {
        let sessionID = beginSession()
        pendingImportMovie = nil
        pendingPreFlightSelection = inferredSelection
        recoverableImportRecordID = nil
        importPresentationState = .preparing
        navigation.showAnalyzerRecords()

        selectionTask = Task { [weak self] in
            guard let self else { return }

            do {
                guard let movie = try await item.loadTransferable(type: GaragePickedMovie.self) else {
                    throw GarageImportError.unableToLoadSelection
                }

                guard self.isCurrentSession(sessionID) else {
                    return
                }

                await self.launchImport(
                    movie,
                    selection: inferredSelection,
                    modelContext: modelContext,
                    navigation: navigation,
                    sessionID: sessionID
                )
            } catch is CancellationError {
                return
            } catch {
                await self.presentFailureIfCurrent(
                    garageImportFailureMessage(from: error),
                    sessionID: sessionID,
                    navigation: navigation
                )
            }
        }
    }

    func startImport(
        _ movie: GaragePickedMovie,
        selection: GaragePreFlightSelection,
        modelContext: ModelContext,
        navigation: GarageImportNavigation
    ) {
        let sessionID = beginSession()
        Task {
            await launchImport(
                movie,
                selection: selection,
                modelContext: modelContext,
                navigation: navigation,
                sessionID: sessionID
            )
        }
    }

    func retryImport(
        modelContext: ModelContext,
        navigation: GarageImportNavigation
    ) {
        if let recoverableImportRecord = pendingRecord(for: recoverableImportRecordID, modelContext: modelContext) {
            repairRecord(recoverableImportRecord, modelContext: modelContext, navigation: navigation)
            return
        }

        if let pendingImportMovie {
            startImport(
                pendingImportMovie,
                selection: pendingPreFlightSelection,
                modelContext: modelContext,
                navigation: navigation
            )
            return
        }

        importPresentationState = .idle
        navigation.showAnalyzerRecords()
        navigation.presentPicker()
    }

    func repairRecord(
        _ record: SwingRecord,
        modelContext: ModelContext,
        navigation: GarageImportNavigation
    ) {
        let fallbackStatus: GarageImportStatus = record.isRecoverableFailedImport ? .failed : .complete
        let repairReason: GarageRepairReason = record.isRecoverableFailedImport ? .importFailed : .corruptedDerivedPayload

        guard let reviewMasterURL = GarageMediaStore.resolvedReviewVideoURL(for: record) else {
            record.markRepairFailure(
                fallbackStatus: fallbackStatus,
                repairReason: .missingReviewVideo
            )
            try? modelContext.save()
            recoverableImportRecordID = record.isRecoverableFailedImport ? record.persistentModelID : nil
            navigation.didMutatePersistence()
            return
        }

        let sessionID = beginSession()
        let recordID = record.persistentModelID
        pendingImportMovie = nil
        activeImportRecordID = recordID
        recoverableImportRecordID = nil
        importPresentationState = .analyzing(step: .loadingVideo, frameCount: 0, totalFrames: 0)
        navigation.showAnalyzerRecords()

        importTask = Task { [weak self] in
            guard let self else { return }

            do {
                if record.isRecoverableFailedImport {
                    try await self.persistRetryingStatus(
                        recordID: recordID,
                        modelContext: modelContext
                    )
                }

                let output = try await self.analyzeReviewMaster(
                    at: reviewMasterURL,
                    recordID: recordID,
                    modelContext: modelContext,
                    sessionID: sessionID,
                    navigation: navigation
                )
                let reviewKey = try await self.finalizeImportedRecord(
                    recordID: recordID,
                    output: output,
                    modelContext: modelContext,
                    sessionID: sessionID
                )

                await self.handleSuccessfulImport(
                    reviewKey: reviewKey,
                    recordID: recordID,
                    reviewMasterURL: reviewMasterURL,
                    modelContainer: modelContext.container,
                    sessionID: sessionID,
                    navigation: navigation
                )
            } catch is CancellationError {
                return
            } catch {
                let failureMessage = garageImportFailureMessage(from: error)
                NSLog("%@", failureMessage)
                await self.persistReanalysisFailure(
                    recordID: recordID,
                    fallbackStatus: fallbackStatus,
                    repairReason: repairReason,
                    message: failureMessage,
                    modelContext: modelContext,
                    sessionID: sessionID,
                    navigation: navigation
                )
            }
        }
    }

    private func launchImport(
        _ movie: GaragePickedMovie,
        selection: GaragePreFlightSelection,
        modelContext: ModelContext,
        navigation: GarageImportNavigation,
        sessionID: UUID
    ) async {
        guard isCurrentSession(sessionID) else {
            return
        }

        pendingImportMovie = movie
        pendingPreFlightSelection = selection
        recoverableImportRecordID = nil
        importPresentationState = .analyzing(step: .loadingVideo, frameCount: 0, totalFrames: 0)
        navigation.showAnalyzerRecords()

        let sourceMovieURL = movie.url
        let displayName = movie.displayName
        let clubType = selection.clubType
        let isLeftHanded = selection.isLeftHanded
        let cameraAngle = selection.cameraAngle

        importTask = Task { [weak self] in
            guard let self else { return }

            var pendingRecordID: PersistentIdentifier?

            do {
                let reviewMasterURL = try GarageMediaStore.persistReviewMaster(from: sourceMovieURL)
                let resolvedTitle = garageSuggestedRecordTitle(for: displayName, fallbackURL: reviewMasterURL)
                let reviewMasterBookmark = GarageMediaStore.bookmarkData(for: reviewMasterURL)

                pendingRecordID = try await self.persistPendingImportRecord(
                    title: resolvedTitle,
                    clubType: clubType,
                    isLeftHanded: isLeftHanded,
                    cameraAngle: cameraAngle,
                    reviewMasterURL: reviewMasterURL,
                    reviewMasterBookmark: reviewMasterBookmark,
                    modelContext: modelContext
                )

                guard self.isCurrentSession(sessionID) else {
                    return
                }

                let output = try await self.analyzeReviewMaster(
                    at: reviewMasterURL,
                    recordID: pendingRecordID,
                    modelContext: modelContext,
                    sessionID: sessionID,
                    navigation: navigation
                )
                let reviewKey = try await self.finalizeImportedRecord(
                    recordID: pendingRecordID,
                    output: output,
                    modelContext: modelContext,
                    sessionID: sessionID
                )

                await self.handleSuccessfulImport(
                    reviewKey: reviewKey,
                    recordID: pendingRecordID,
                    reviewMasterURL: reviewMasterURL,
                    modelContainer: modelContext.container,
                    sessionID: sessionID,
                    navigation: navigation
                )
            } catch is CancellationError {
                return
            } catch {
                let failureMessage = garageImportFailureMessage(from: error)
                NSLog("%@", failureMessage)
                await self.persistRecoverableImportFailure(
                    recordID: pendingRecordID,
                    message: failureMessage,
                    modelContext: modelContext,
                    sessionID: sessionID,
                    navigation: navigation
                )
            }
        }
    }

    private func beginSession() -> UUID {
        selectionTask?.cancel()
        importTask?.cancel()

        let sessionID = UUID()
        activeSessionID = sessionID
        activeImportRecordID = nil
        return sessionID
    }

    private func resetSession() {
        selectionTask?.cancel()
        importTask?.cancel()
        activeSessionID = nil
        activeImportRecordID = nil
    }

    private func isCurrentSession(_ sessionID: UUID) -> Bool {
        activeSessionID == sessionID
    }

    private func pendingRecord(
        for identifier: PersistentIdentifier?,
        modelContext: ModelContext
    ) -> SwingRecord? {
        guard let identifier else { return nil }
        return modelContext.registeredModel(for: identifier) ?? (modelContext.model(for: identifier) as? SwingRecord)
    }

    private func presentImportProgress(
        _ progress: GarageAnalysisProgressUpdate,
        sessionID: UUID,
        navigation: GarageImportNavigation
    ) {
        guard isCurrentSession(sessionID) else { return }
        navigation.showAnalyzerRecords()
        importPresentationState = .analyzing(
            step: progress.step,
            frameCount: progress.frameCount,
            totalFrames: progress.totalFrames
        )
    }

    private func saveContext(_ modelContext: ModelContext) throws {
        try modelContext.save()
    }

    private func persistPendingImportRecord(
        title: String,
        clubType: String,
        isLeftHanded: Bool,
        cameraAngle: String,
        reviewMasterURL: URL,
        reviewMasterBookmark: Data?,
        modelContext: ModelContext
    ) async throws -> PersistentIdentifier {
        let record = SwingRecord.pendingImportRecord(
            title: title,
            clubType: clubType,
            isLeftHanded: isLeftHanded,
            cameraAngle: cameraAngle,
            reviewMasterURL: reviewMasterURL,
            reviewMasterBookmark: reviewMasterBookmark
        )
        modelContext.insert(record)

        return try await garagePerformRetryableOperation {
            try saveContext(modelContext)
            activeImportRecordID = record.persistentModelID
            return record.persistentModelID
        }
    }

    private func persistRetryingStatus(
        recordID: PersistentIdentifier?,
        modelContext: ModelContext
    ) async throws {
        let _: Void = try await garagePerformRetryableOperation {
            guard let record = pendingRecord(for: recordID, modelContext: modelContext) else {
                return
            }

            record.markImportRetrying()
            try saveContext(modelContext)
        }
    }

    private func analyzeReviewMaster(
        at reviewMasterURL: URL,
        recordID: PersistentIdentifier?,
        modelContext: ModelContext,
        sessionID: UUID,
        navigation: GarageImportNavigation
    ) async throws -> GarageAnalysisOutput {
        try await garagePerformRetryableOperation(
            onRetry: { [weak self] _ in
                guard let self else { return }
                try? await self.persistRetryingStatus(
                    recordID: recordID,
                    modelContext: modelContext
                )
            }
        ) {
            try await GarageAnalysisPipeline.analyzeVideo(at: reviewMasterURL) { progress in
                await MainActor.run {
                    self.presentImportProgress(
                        progress,
                        sessionID: sessionID,
                        navigation: navigation
                    )
                }
            }
        }
    }

    private func finalizeImportedRecord(
        recordID: PersistentIdentifier?,
        output: GarageAnalysisOutput,
        modelContext: ModelContext,
        sessionID: UUID
    ) async throws -> String {
        if isCurrentSession(sessionID) {
            importPresentationState = .analyzing(
                step: .savingSwing,
                frameCount: max(output.swingFrames.count, 0),
                totalFrames: max(output.swingFrames.count, 0)
            )
        }

        let approvedKeyFrames = GarageAnalysisPipeline.autoApprovedKeyFrames(
            from: output.keyFrames,
            reviewReport: output.handPathReviewReport
        )
        let validationStatus: KeyframeValidationStatus = output.handPathReviewReport.requiresManualReview ? .pending : .approved

        return try await garagePerformRetryableOperation {
            guard let savedRecord = pendingRecord(for: recordID, modelContext: modelContext) else {
                throw GarageImportError.unableToLoadSelection
            }

            savedRecord.applyAnalysisOutput(
                output,
                approvedKeyFrames: approvedKeyFrames,
                validationStatus: validationStatus
            )
            try saveContext(modelContext)
            activeImportRecordID = nil
            recoverableImportRecordID = nil
            pendingImportMovie = nil

            return garageRecordSelectionKey(for: savedRecord)
        }
    }

    private func handleSuccessfulImport(
        reviewKey: String,
        recordID: PersistentIdentifier?,
        reviewMasterURL: URL,
        modelContainer: ModelContainer,
        sessionID: UUID,
        navigation: GarageImportNavigation
    ) async {
        guard isCurrentSession(sessionID) else { return }

        pendingImportMovie = nil
        importPresentationState = .idle
        navigation.didMutatePersistence()
        navigation.openReview(reviewKey)

        guard let recordID else { return }
        Task.detached(priority: .utility) {
            await garageBackfillExportDerivative(
                using: modelContainer,
                recordID: recordID,
                reviewMasterURL: reviewMasterURL
            )
        }
    }

    private func persistRecoverableImportFailure(
        recordID: PersistentIdentifier?,
        message: String,
        modelContext: ModelContext,
        sessionID: UUID,
        navigation: GarageImportNavigation
    ) async {
        activeImportRecordID = nil

        do {
            try await garagePerformRetryableOperation {
                if let record = pendingRecord(for: recordID, modelContext: modelContext) {
                    record.markImportFailed()
                    recoverableImportRecordID = record.persistentModelID
                } else {
                    recoverableImportRecordID = nil
                }

                try saveContext(modelContext)
            }
            navigation.didMutatePersistence()
        } catch {
            let nsError = error as NSError
            NSLog(
                "%@",
                "Garage import failure preservation save failed. domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
            )
        }

        await presentFailureIfCurrent(message, sessionID: sessionID, navigation: navigation)
    }

    private func persistReanalysisFailure(
        recordID: PersistentIdentifier?,
        fallbackStatus: GarageImportStatus,
        repairReason: GarageRepairReason,
        message: String,
        modelContext: ModelContext,
        sessionID: UUID,
        navigation: GarageImportNavigation
    ) async {
        activeImportRecordID = nil

        do {
            try await garagePerformRetryableOperation {
                if let record = pendingRecord(for: recordID, modelContext: modelContext) {
                    record.markRepairFailure(
                        fallbackStatus: fallbackStatus,
                        repairReason: repairReason
                    )
                    recoverableImportRecordID = fallbackStatus.isFailed ? record.persistentModelID : nil
                }

                try saveContext(modelContext)
            }
            navigation.didMutatePersistence()
        } catch {
            let nsError = error as NSError
            NSLog(
                "%@",
                "Garage repair failure save failed. domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
            )
        }

        await presentFailureIfCurrent(message, sessionID: sessionID, navigation: navigation)
    }

    private func presentFailureIfCurrent(
        _ message: String,
        sessionID: UUID,
        navigation: GarageImportNavigation
    ) async {
        guard isCurrentSession(sessionID) else { return }
        navigation.showAnalyzerRecords()
        importPresentationState = .failure(message)
    }
}
