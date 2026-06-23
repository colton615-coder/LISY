#if DEBUG
import AVFoundation
import Combine
import SwiftUI

enum GuidedSwingSamplePreviewSlot: String, CaseIterable, Identifiable, Sendable {
    case backswingPremiumLiftHill = "backswing_premium_lift_hill"
    case impactGolfSwing = "impact_golf_swing"

    var id: String { rawValue }

    var offset: TimeInterval {
        switch self {
        case .backswingPremiumLiftHill: 0.00
        case .impactGolfSwing: 2.00
        }
    }
}

enum GuidedSwingSamplePreviewAssetState: String, Equatable, Sendable {
    case present = "Present"
    case missing = "Missing"
    case unreadable = "Unreadable"
}

struct GuidedSwingSamplePreviewAssetResolver {
    let assetURL: (String) -> URL?
    let canDecode: (URL) -> Bool

    static let bundled = Self(
        assetURL: { name in
            Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "GuidedSwing_Audio")
                ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Garage/GuidedSwing_Audio")
                ?? Bundle.main.url(forResource: name, withExtension: "wav")
        },
        canDecode: { url in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
            return player.prepareToPlay()
        }
    )

    func state(for slot: GuidedSwingSamplePreviewSlot) -> GuidedSwingSamplePreviewAssetState {
        guard let url = assetURL(slot.rawValue) else { return .missing }
        return canDecode(url) ? .present : .unreadable
    }
}

struct GuidedSwingSamplePreviewDefinition {
    static let title = "Premium Lift Hill"
    static let slots = GuidedSwingSamplePreviewSlot.allCases
    static let backswingEnd: TimeInterval = 1.50
    static let impactOffset: TimeInterval = 2.00
    static let silentTopPause: TimeInterval = impactOffset - backswingEnd
    static let allowsGeneratedFallback = false

    static func states(
        using resolver: GuidedSwingSamplePreviewAssetResolver
    ) -> [GuidedSwingSamplePreviewSlot: GuidedSwingSamplePreviewAssetState] {
        Dictionary(uniqueKeysWithValues: slots.map { ($0, resolver.state(for: $0)) })
    }

    static func canPreview(using resolver: GuidedSwingSamplePreviewAssetResolver) -> Bool {
        states(using: resolver).values.allSatisfy { $0 == .present }
    }
}

@MainActor
final class GuidedSwingSamplePreviewPlayer: ObservableObject {
    @Published private(set) var slotStates: [GuidedSwingSamplePreviewSlot: GuidedSwingSamplePreviewAssetState] = [:]
    @Published private(set) var isPlaying = false
    @Published private(set) var statusText = "Waiting for two production WAV files"

    private let resolver: GuidedSwingSamplePreviewAssetResolver
    private var players: [AVAudioPlayer] = []
    private var previewTask: Task<Void, Never>?

    init(resolver: GuidedSwingSamplePreviewAssetResolver = .bundled) {
        self.resolver = resolver
        refreshAvailability()
    }

    var canPreview: Bool {
        GuidedSwingSamplePreviewDefinition.slots.allSatisfy { slotStates[$0] == .present }
    }

    func refreshAvailability() {
        slotStates = GuidedSwingSamplePreviewDefinition.states(using: resolver)
        if isPlaying == false {
            statusText = canPreview ? "Two samples ready" : "Samples missing or unreadable"
        }
    }

    func togglePreview() {
        isPlaying ? stop() : play()
    }

    func stop() {
        previewTask?.cancel()
        previewTask = nil
        stopPlayers()
        isPlaying = false
        statusText = "Preview stopped"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play() {
        refreshAvailability()
        guard canPreview else {
            statusText = "Preview unavailable"
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            statusText = "Audio session unavailable"
            return
        }

        isPlaying = true
        statusText = "Playing sample-backed audition"
        previewTask = Task { [weak self] in
            guard let self else { return }

            guard await playBackswingSlot(.backswingPremiumLiftHill, after: 0) else { return }

            await sleep(seconds: GuidedSwingSamplePreviewDefinition.backswingEnd)
            guard Task.isCancelled == false else { return }
            stopPlayers()

            await sleep(seconds: GuidedSwingSamplePreviewDefinition.silentTopPause)
            guard Task.isCancelled == false else { return }
            guard playSlot(.impactGolfSwing) else { return }

            await sleep(seconds: 0.50)
            guard Task.isCancelled == false else { return }
            finishPlayback()
        }
    }

    private func playBackswingSlot(_ slot: GuidedSwingSamplePreviewSlot, after delay: TimeInterval) async -> Bool {
        await sleep(seconds: delay)
        guard Task.isCancelled == false else { return false }
        return playSlot(slot)
    }

    @discardableResult
    private func playSlot(_ slot: GuidedSwingSamplePreviewSlot) -> Bool {
        guard
            let url = resolver.assetURL(slot.rawValue),
            resolver.canDecode(url),
            let player = try? AVAudioPlayer(contentsOf: url),
            player.prepareToPlay()
        else {
            stopPlayers()
            isPlaying = false
            refreshAvailability()
            statusText = "Could not decode \(slot.rawValue).wav"
            return false
        }

        player.volume = 0.72
        players.removeAll { $0.isPlaying == false }
        players.append(player)
        player.play()
        return true
    }

    private func stopPlayers() {
        players.forEach { $0.stop() }
        players.removeAll()
    }

    private func finishPlayback() {
        stopPlayers()
        previewTask = nil
        isPlaying = false
        statusText = "Preview complete"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

struct GuidedSwingSamplePreviewSection: View {
    @ObservedObject var player: GuidedSwingSamplePreviewPlayer
    let onPreviewStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(GuidedSwingSamplePreviewDefinition.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("DEBUG audition · real WAV samples only")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }

            Divider().overlay(GarageProTheme.border)

            ForEach(GuidedSwingSamplePreviewDefinition.slots) { slot in
                slotRow(slot)
            }

            Text("Chain lift to 1.50s, exact silence to 2.00s, then the supplied golf-swing WAV.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)

            Text("This sample-backed lane does not replace live Guided Swing.")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(GaragePremiumPalette.gold)

            HStack(spacing: 10) {
                Text(player.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer(minLength: 8)

                Button(player.isPlaying ? "Stop" : "Preview") {
                    if player.isPlaying == false {
                        onPreviewStart()
                    }
                    player.togglePreview()
                }
                .buttonStyle(GarageSamplePreviewButtonStyle(isActive: player.isPlaying))
                .disabled(player.canPreview == false && player.isPlaying == false)
                .accessibilityHint(player.canPreview ? "Plays the two-sample lift hill audition" : "Requires two present and decodable WAV files")
            }
        }
        .padding(.vertical, 4)
        .onAppear { player.refreshAvailability() }
    }

    private func slotRow(_ slot: GuidedSwingSamplePreviewSlot) -> some View {
        let state = player.slotStates[slot] ?? .missing

        return HStack(spacing: 10) {
            Text("\(slot.rawValue).wav")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(GarageProTheme.textPrimary)

            Spacer(minLength: 8)

            Label(state.rawValue, systemImage: statusSymbol(state))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor(state))
        }
        .accessibilityElement(children: .combine)
    }

    private func statusSymbol(_ state: GuidedSwingSamplePreviewAssetState) -> String {
        switch state {
        case .present: "checkmark.circle.fill"
        case .missing: "minus.circle"
        case .unreadable: "exclamationmark.triangle.fill"
        }
    }

    private func statusColor(_ state: GuidedSwingSamplePreviewAssetState) -> Color {
        switch state {
        case .present: GaragePremiumPalette.mintText
        case .missing: GarageProTheme.textSecondary
        case .unreadable: .orange
        }
    }
}

private struct GarageSamplePreviewButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(isActive ? GaragePremiumPalette.emeraldDeep : GarageProTheme.textPrimary)
            .frame(minWidth: 76, minHeight: 44)
            .background(isActive ? GaragePremiumPalette.gold : GarageProTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(GarageProTheme.border, lineWidth: isActive ? 0 : 1))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}
#endif
