import SwiftUI

struct GarageFocusRoomHeader: View {
    let sessionTitle: String
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 24, padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(GarageFocusRoomCopy.focusRoomHeaderEyebrow)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.8)
                        .foregroundStyle(GarageProTheme.textSecondary)

                    Text(sessionTitle)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text(drillPositionText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(GarageProTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("Complete")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.8)
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }
        }
    }
}
