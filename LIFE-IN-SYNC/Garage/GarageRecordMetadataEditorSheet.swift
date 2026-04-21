import SwiftData
import SwiftUI

struct GarageRecordMetadataEditorSheet: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var isPresented: Bool
    let record: SwingRecord

    @State private var title: String
    @State private var clubType: String
    @State private var isLeftHanded: Bool
    @State private var cameraAngle: String
    @State private var notes: String

    private let clubOptions = [
        "Driver", "3 Wood", "5 Wood",
        "3 Hybrid", "4 Hybrid", "5 Hybrid",
        "4 Iron", "5 Iron", "6 Iron",
        "7 Iron", "8 Iron", "9 Iron",
        "PW", "SW"
    ]
    private let cameraOptions = ["Down the Line", "Face On"]
    private let handednessOptions: [(label: String, value: Bool)] = [("Righty", false), ("Lefty", true)]
    private let clubColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    init(isPresented: Binding<Bool>, record: SwingRecord) {
        _isPresented = isPresented
        self.record = record
        _title = State(initialValue: record.title)
        _clubType = State(initialValue: record.resolvedClubType)
        _isLeftHanded = State(initialValue: record.resolvedIsLeftHanded)
        _cameraAngle = State(initialValue: record.resolvedCameraAngle)
        _notes = State(initialValue: record.notes)
    }

    var body: some View {
        Color.clear
            .garageModal(
                isPresented: $isPresented,
                title: "Swing Metadata"
            ) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        metadataFieldCard
                        handednessCard
                        cameraAngleCard
                        clubGridCard
                        notesCard
                    }
                    .padding(ModuleSpacing.large)
                    .padding(.bottom, ModuleSpacing.large)
                }
                .background(Color.vibeBackground.ignoresSafeArea())
            } bottomDock: {
                GarageDockSurface {
                    HStack(spacing: 12) {
                        GarageDockWideButton(
                            title: "Close",
                            systemImage: "xmark",
                            isPrimary: false,
                            isEnabled: true,
                            action: {
                                isPresented = false
                            }
                        )

                        GarageDockWideButton(
                            title: "Save",
                            systemImage: "checkmark",
                            isPrimary: true,
                            isEnabled: true,
                            action: saveChanges
                        )
                    }
                }
            }
    }

    private var metadataFieldCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Label")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            TextField("Swing title", text: $title)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.headline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    GarageInsetPanelBackground(
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        fill: .vibeBackground,
                        stroke: Color.white.opacity(0.08)
                    )
                )
        }
        .padding(18)
        .background(panelBackground)
    }

    private var handednessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Handedness")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            HStack(spacing: 10) {
                ForEach(handednessOptions, id: \.label) { option in
                    metadataSelectionButton(
                        title: option.label,
                        isSelected: isLeftHanded == option.value,
                        shape: Capsule()
                    ) {
                        isLeftHanded = option.value
                    }
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var cameraAngleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Angle")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            HStack(spacing: 10) {
                ForEach(cameraOptions, id: \.self) { option in
                    metadataSelectionButton(
                        title: option,
                        isSelected: cameraAngle == option,
                        shape: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    ) {
                        cameraAngle = option
                    }
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var clubGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Club")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            LazyVGrid(columns: clubColumns, spacing: 9) {
                ForEach(clubOptions, id: \.self) { club in
                    Button {
                        clubType = club
                    } label: {
                        Text(club)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(clubType == club ? ModuleTheme.electricCyan : AppModule.garage.theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .padding(.horizontal, 8)
                            .background(
                                GarageInsetPanelBackground(
                                    shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                                    fill: clubType == club ? .vibeSurface : .vibeBackground,
                                    stroke: clubType == club ? ModuleTheme.electricCyan.opacity(0.42) : Color.white.opacity(0.08)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            TextEditor(text: $notes)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .padding(10)
                .background(
                    GarageInsetPanelBackground(
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        fill: .vibeBackground,
                        stroke: Color.white.opacity(0.08)
                    )
                )
                .foregroundStyle(garageReviewReadableText)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        GarageRaisedPanelBackground(
            shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
            fill: .vibeSurface,
            stroke: ModuleTheme.electricCyan.opacity(0.20),
            glow: ModuleTheme.electricCyan.opacity(0.7)
        )
    }

    private func metadataSelectionButton(
        title: String,
        isSelected: Bool,
        shape: some InsettableShape,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? ModuleTheme.electricCyan : garageReviewReadableText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(
                    GarageInsetPanelBackground(
                        shape: shape,
                        fill: isSelected ? .vibeSurface : .vibeBackground,
                        stroke: isSelected ? ModuleTheme.electricCyan.opacity(0.42) : Color.white.opacity(0.08)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.title = trimmedTitle.isEmpty ? record.title : trimmedTitle
        record.clubType = clubType
        record.isLeftHanded = isLeftHanded
        record.cameraAngle = cameraAngle
        record.notes = notes

        try? modelContext.save()
        isPresented = false
    }
}

private struct GarageRecordMetadataEditorSheetPreviewSurface: View {
    @State private var isPresented = true

    private let record = SwingRecord(
        title: "Canvas Session",
        clubType: "7 Iron",
        isLeftHanded: false,
        cameraAngle: "Down the Line",
        notes: "Keep the hands quieter through transition."
    )

    var body: some View {
        ZStack {
            garageReviewBackground.ignoresSafeArea()

            GarageRecordMetadataEditorSheet(
                isPresented: $isPresented,
                record: record
            )
        }
    }
}

#Preview("Garage Metadata Editor") {
    PreviewScreenContainer {
        GarageRecordMetadataEditorSheetPreviewSurface()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: SwingRecord.self, inMemory: true)
}
