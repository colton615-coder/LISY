import Foundation
import SwiftData

enum PracticeEnvironment: String, CaseIterable, Codable, Identifiable, Hashable {
    case net
    case range
    case puttingGreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .net:
            return "Net"
        case .range:
            return "Range"
        case .puttingGreen:
            return "Putting Green"
        }
    }

    var systemImage: String {
        switch self {
        case .net:
            return "figure.golf"
        case .range:
            return "flag.pattern.checkered"
        case .puttingGreen:
            return "circle.grid.2x2"
        }
    }

    var description: String {
        switch self {
        case .net:
            return "Tight feedback loops for mechanics, contact, and rehearsal."
        case .range:
            return "Ball-flight practice with target windows and club-specific patterns."
        case .puttingGreen:
            return "Start line, pace control, and green-reading reps."
        }
    }
}

@Model
final class PracticeDrillDefinition {
    var id: UUID
    var title: String
    var focusArea: String
    var targetClub: String
    var defaultRepCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        focusArea: String,
        targetClub: String,
        defaultRepCount: Int
    ) {
        self.id = id
        self.title = title
        self.focusArea = focusArea
        self.targetClub = targetClub
        self.defaultRepCount = defaultRepCount
    }
}

struct PracticeTemplateDrill: Identifiable, Hashable, Codable {
    let id: UUID
    let definitionID: UUID?
    let title: String
    let focusArea: String
    let targetClub: String
    let defaultRepCount: Int

    init(
        id: UUID = UUID(),
        definitionID: UUID? = nil,
        title: String,
        focusArea: String,
        targetClub: String,
        defaultRepCount: Int
    ) {
        self.id = id
        self.definitionID = definitionID
        self.title = title
        self.focusArea = focusArea
        self.targetClub = targetClub
        self.defaultRepCount = defaultRepCount
    }

    init(definition: PracticeDrillDefinition) {
        self.init(
            definitionID: definition.id,
            title: definition.title,
            focusArea: definition.focusArea,
            targetClub: definition.targetClub,
            defaultRepCount: definition.defaultRepCount
        )
    }

    var metadataSummary: String {
        var parts: [String] = []

        if focusArea.isEmpty == false {
            parts.append(focusArea)
        }

        if targetClub.isEmpty == false {
            parts.append(targetClub)
        }

        parts.append("\(defaultRepCount) reps")
        return parts.joined(separator: " • ")
    }
}

@Model
final class PracticeTemplate {
    var id: UUID
    var title: String
    var environment: String
    var drills: [PracticeTemplateDrill]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        environment: String,
        drills: [PracticeTemplateDrill],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.environment = environment
        self.drills = drills
        self.createdAt = createdAt
    }
}

struct PracticeDrillProgress: Hashable, Codable {
    let drillID: UUID
    var isCompleted: Bool
    var note: String

    init(
        drillID: UUID,
        isCompleted: Bool = false,
        note: String = ""
    ) {
        self.drillID = drillID
        self.isCompleted = isCompleted
        self.note = note
    }
}

struct ActivePracticeSession: Identifiable, Hashable, Codable {
    let id: UUID
    let templateID: UUID?
    let templateName: String
    let environment: PracticeEnvironment
    let startedAt: Date
    var endedAt: Date?
    let drills: [PracticeTemplateDrill]
    var drillProgress: [PracticeDrillProgress]

    init(
        id: UUID = UUID(),
        template: PracticeTemplate,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        drillProgress: [PracticeDrillProgress]? = nil
    ) {
        let environmentValue = PracticeEnvironment(rawValue: template.environment) ?? .net

        self.id = id
        self.templateID = template.id
        self.templateName = template.title
        self.environment = environmentValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.drills = template.drills
        self.drillProgress = drillProgress ?? template.drills.map {
            PracticeDrillProgress(drillID: $0.id)
        }
    }
}

@Model
final class PracticeSessionRecord {
    var id: UUID
    var date: Date
    var templateName: String
    var environment: String
    var completedDrills: Int
    var totalDrills: Int
    var aggregatedNotes: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        templateName: String,
        environment: String,
        completedDrills: Int,
        totalDrills: Int,
        aggregatedNotes: String = ""
    ) {
        self.id = id
        self.date = date
        self.templateName = templateName
        self.environment = environment
        self.completedDrills = completedDrills
        self.totalDrills = totalDrills
        self.aggregatedNotes = aggregatedNotes
    }
}

extension PracticeTemplate {
    var environmentValue: PracticeEnvironment {
        PracticeEnvironment(rawValue: environment) ?? .net
    }

    var environmentDisplayName: String {
        environmentValue.displayName
    }
}

extension PracticeDrillDefinition {
    var metadataSummary: String {
        PracticeTemplateDrill(definition: self).metadataSummary
    }
}

extension ActivePracticeSession {
    var completedDrillCount: Int {
        drillProgress.filter(\.isCompleted).count
    }

    var totalDrillCount: Int {
        drills.count
    }

    var orderedDrillEntries: [PracticeSessionDrillEntry] {
        drills.map { drill in
            PracticeSessionDrillEntry(
                drill: drill,
                progress: progress(for: drill.id) ?? PracticeDrillProgress(drillID: drill.id)
            )
        }
    }

    mutating func toggleCompletion(for drillID: UUID) {
        guard let index = drillProgress.firstIndex(where: { $0.drillID == drillID }) else {
            return
        }

        drillProgress[index].isCompleted.toggle()
    }

    mutating func updateNote(_ note: String, for drillID: UUID) {
        guard let index = drillProgress.firstIndex(where: { $0.drillID == drillID }) else {
            return
        }

        drillProgress[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func progress(for drillID: UUID) -> PracticeDrillProgress? {
        drillProgress.first(where: { $0.drillID == drillID })
    }

    var aggregatedNotes: String {
        orderedDrillEntries
            .compactMap { entry in
                let note = entry.progress.note.trimmingCharacters(in: .whitespacesAndNewlines)
                guard note.isEmpty == false else {
                    return nil
                }

                return "\(entry.drill.title): \(note)"
            }
            .joined(separator: "\n")
    }

    var record: PracticeSessionRecord {
        PracticeSessionRecord(
            templateName: templateName,
            environment: environment.rawValue,
            completedDrills: completedDrillCount,
            totalDrills: totalDrillCount,
            aggregatedNotes: aggregatedNotes
        )
    }
}

struct PracticeSessionDrillEntry: Identifiable, Hashable {
    let drill: PracticeTemplateDrill
    let progress: PracticeDrillProgress

    var id: UUID { drill.id }
}

extension PracticeSessionRecord {
    var completionRatioText: String {
        "\(completedDrills)/\(totalDrills)"
    }

    var environmentDisplayName: String {
        PracticeEnvironment(rawValue: environment)?.displayName ?? environment
    }
}
