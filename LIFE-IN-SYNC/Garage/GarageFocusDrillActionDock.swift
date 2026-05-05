import SwiftUI

struct GarageFocusDrillActionDock: View {
    let backEnabled: Bool
    let noteTitle: String
    let primaryTitle: String
    let onBack: () -> Void
    let onNote: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GarageFocusDockSecondaryButton(
                    title: GarageFocusRoomCopy.focusRoomBackCta,
                    systemImage: "chevron.left",
                    isEnabled: backEnabled,
                    action: onBack
                )

                GarageFocusDockSecondaryButton(
                    title: noteTitle,
                    systemImage: noteTitle == GarageFocusRoomCopy.focusRoomNoteAddCta ? "square.and.pencil" : "note.text",
                    action: onNote
                )
            }

            GarageProPrimaryButton(
                title: primaryTitle,
                systemImage: primaryTitle == GarageFocusRoomCopy.focusRoomEnterReviewCta ? "checkmark.seal.fill" : "checkmark.circle.fill",
                action: onPrimary
            )
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(GarageProTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
        .shadow(color: GarageProTheme.darkShadow.opacity(0.8), radius: 12, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct GarageFocusDockSecondaryButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else {
                return
            }

            garageTriggerSelection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 10)
                .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
