import Foundation

enum GarageCoachingSignalKind: String, Hashable {
    case recentWeakness
    case recurringWeakness
    case improving
    case undertrained
    case overtrained
}

struct GarageSkillScore: Hashable {
    let id: String
    let title: String
    let successfulReps: Int
    let totalReps: Int
    let sessionCount: Int
    let recentSuccessfulReps: Int
    let recentTotalReps: Int
    let previousSuccessfulReps: Int
    let previousTotalReps: Int
    let lastPracticedAt: Date?

    var successRatio: Double {
        guard totalReps > 0 else {
            return 0
        }

        return Double(successfulReps) / Double(totalReps)
    }

    var recentSuccessRatio: Double {
        guard recentTotalReps > 0 else {
            return successRatio
        }

        return Double(recentSuccessfulReps) / Double(recentTotalReps)
    }

    var previousSuccessRatio: Double? {
        guard previousTotalReps > 0 else {
            return nil
        }

        return Double(previousSuccessfulReps) / Double(previousTotalReps)
    }

    var trendDelta: Double {
        recentSuccessRatio - (previousSuccessRatio ?? successRatio)
    }

    var feelSuccessPercentage: Int {
        Int((successRatio * 100).rounded())
    }
}

struct GarageCoachingSignal: Identifiable, Hashable {
    let id: String
    let kind: GarageCoachingSignalKind
    let title: String
    let detail: String
    let drillID: String?
    let category: GarageDrillLibraryCategory?
    let faultTag: String?
    let weight: Double

    init(
        kind: GarageCoachingSignalKind,
        title: String,
        detail: String,
        drillID: String? = nil,
        category: GarageDrillLibraryCategory? = nil,
        faultTag: String? = nil,
        weight: Double
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.drillID = drillID
        self.category = category
        self.faultTag = faultTag
        self.weight = weight
        self.id = [
            kind.rawValue,
            drillID,
            category?.rawValue,
            faultTag,
            title
        ]
        .compactMap { $0 }
        .joined(separator: ":")
    }
}

struct GarageSkillProfile: Hashable {
    let environment: PracticeEnvironment?
    let generatedAt: Date
    let drillScores: [String: GarageSkillScore]
    let categoryScores: [GarageDrillLibraryCategory: GarageSkillScore]
    let faultTagScores: [String: GarageSkillScore]
    let environmentScores: [PracticeEnvironment: GarageSkillScore]
    let undertrainedCategories: [GarageDrillLibraryCategory]
    let overtrainedCategories: [GarageDrillLibraryCategory]
    let recurringWeaknesses: [GarageCoachingSignal]
    let improvingSignals: [GarageCoachingSignal]
    let recommendedFocusTags: Set<String>

    var isEmpty: Bool {
        drillScores.isEmpty && categoryScores.isEmpty && faultTagScores.isEmpty
    }

    var isNeutral: Bool {
        isEmpty
            && environmentScores.isEmpty
            && undertrainedCategories.isEmpty
            && overtrainedCategories.isEmpty
            && recurringWeaknesses.isEmpty
            && improvingSignals.isEmpty
            && recommendedFocusTags.isEmpty
    }
}

enum GaragePracticeHistoryAnalyzer {
    static func skillProfile(
        from records: [PracticeSessionRecord],
        environment: PracticeEnvironment? = nil,
        referenceDate: Date = .now
    ) -> GarageSkillProfile {
        let filteredRecords = records
            .filter { record in
                guard let environment else {
                    return true
                }

                return record.environment == environment.rawValue
            }
            .sorted { $0.date > $1.date }

        var drillBuckets: [String: GarageSkillAccumulator] = [:]
        var categoryBuckets: [GarageDrillLibraryCategory: GarageSkillAccumulator] = [:]
        var faultTagBuckets: [String: GarageSkillAccumulator] = [:]
        var environmentBuckets: [PracticeEnvironment: GarageSkillAccumulator] = [:]
        var recentCategoryAttempts: [GarageDrillLibraryCategory: Int] = [:]
        var focusTags = Set<String>()

        for record in filteredRecords {
            let recordEnvironment = PracticeEnvironment(rawValue: record.environment)
            let isRecent = record.date >= referenceDate.addingTimeInterval(-14 * 86_400)
            let isPrevious = record.date < referenceDate.addingTimeInterval(-14 * 86_400)
                && record.date >= referenceDate.addingTimeInterval(-30 * 86_400)

            for result in record.drillResults where result.totalReps > 0 {
                guard let metadata = result.garageMetadataSnapshot else {
                    continue
                }

                let title = DrillVault.drill(for: metadata.drillID)?.title ?? result.name
                drillBuckets[metadata.drillID, default: GarageSkillAccumulator(id: metadata.drillID, title: title)]
                    .record(result, date: record.date, isRecent: isRecent, isPrevious: isPrevious)

                categoryBuckets[metadata.primaryCategory, default: GarageSkillAccumulator(id: metadata.primaryCategory.rawValue, title: metadata.primaryCategory.displayName)]
                    .record(result, date: record.date, isRecent: isRecent, isPrevious: isPrevious)

                if isRecent {
                    recentCategoryAttempts[metadata.primaryCategory, default: 0] += result.totalReps
                }

                for tag in metadata.faultTags {
                    faultTagBuckets[tag, default: GarageSkillAccumulator(id: tag, title: tag.garageHumanizedTag)]
                        .record(result, date: record.date, isRecent: isRecent, isPrevious: isPrevious)
                }

                for tag in metadata.promptTags where result.successRatio < 0.65 {
                    focusTags.insert(tag)
                }

                if let recordEnvironment {
                    environmentBuckets[recordEnvironment, default: GarageSkillAccumulator(id: recordEnvironment.rawValue, title: recordEnvironment.displayName)]
                        .record(result, date: record.date, isRecent: isRecent, isPrevious: isPrevious)
                }
            }
        }

        let drillScores = drillBuckets.mapValues(\.score)
        let categoryScores = categoryBuckets.mapValues(\.score)
        let faultTagScores = faultTagBuckets.mapValues(\.score)
        let environmentScores = environmentBuckets.mapValues(\.score)

        guard drillScores.isEmpty == false
            || categoryScores.isEmpty == false
            || faultTagScores.isEmpty == false else {
            return neutralProfile(environment: environment, referenceDate: referenceDate)
        }

        let eligibleCategories = eligibleCategories(for: environment)
        let totalRecentAttempts = recentCategoryAttempts.values.reduce(0, +)

        let undertrainedCategories = eligibleCategories.filter { category in
            guard totalRecentAttempts > 0 else {
                return false
            }

            let share = Double(recentCategoryAttempts[category, default: 0]) / Double(totalRecentAttempts)
            return share < 0.12
        }

        let overtrainedCategories = eligibleCategories.count > 1
            ? eligibleCategories.filter { category in
                guard totalRecentAttempts > 0 else {
                    return false
                }

                let share = Double(recentCategoryAttempts[category, default: 0]) / Double(totalRecentAttempts)
                return share > 0.55
            }
            : []

        let recurringWeaknesses = recurringWeaknessSignals(
            drillScores: drillScores,
            categoryScores: categoryScores,
            faultTagScores: faultTagScores
        ) + undertrainedCategories.map { category in
            GarageCoachingSignal(
                kind: .undertrained,
                title: "\(category.displayName) has gone quiet",
                detail: "This category is underrepresented in the recent practice mix.",
                category: category,
                weight: 5
            )
        } + overtrainedCategories.map { category in
            GarageCoachingSignal(
                kind: .overtrained,
                title: "\(category.displayName) is dominating the diet",
                detail: "Recent practice is leaning heavily into this category.",
                category: category,
                weight: -7
            )
        }

        let improvingSignals = improvingSignals(
            drillScores: drillScores,
            categoryScores: categoryScores
        )

        return GarageSkillProfile(
            environment: environment,
            generatedAt: referenceDate,
            drillScores: drillScores,
            categoryScores: categoryScores,
            faultTagScores: faultTagScores,
            environmentScores: environmentScores,
            undertrainedCategories: undertrainedCategories,
            overtrainedCategories: overtrainedCategories,
            recurringWeaknesses: recurringWeaknesses,
            improvingSignals: improvingSignals,
            recommendedFocusTags: focusTags
        )
    }

    static func validationErrors() -> [String] {
        var errors: [String] = []
        let emptyProfile = skillProfile(from: [])
        if emptyProfile.isNeutral == false {
            errors.append("Analyzer empty-history profile should not contain scored history or coaching signals.")
        }

        let unknownMetadataProfile = skillProfile(
            from: [
                PracticeSessionRecord(
                    date: Date(timeIntervalSince1970: 0),
                    templateName: "Unknown Metadata Sample",
                    environment: PracticeEnvironment.net.rawValue,
                    completedDrills: 1,
                    totalDrills: 1,
                    drillResults: [
                        DrillResult(
                            name: "Deleted Drill Name",
                            successfulReps: 1,
                            totalReps: 10
                        )
                    ]
                )
            ],
            environment: .net,
            referenceDate: Date(timeIntervalSince1970: 86_400)
        )

        if unknownMetadataProfile.isNeutral == false {
            errors.append("Analyzer unknown-metadata profile should stay neutral instead of inferring from catalog availability.")
        }

        return errors
    }

    private static func neutralProfile(
        environment: PracticeEnvironment?,
        referenceDate: Date
    ) -> GarageSkillProfile {
        GarageSkillProfile(
            environment: environment,
            generatedAt: referenceDate,
            drillScores: [:],
            categoryScores: [:],
            faultTagScores: [:],
            environmentScores: [:],
            undertrainedCategories: [],
            overtrainedCategories: [],
            recurringWeaknesses: [],
            improvingSignals: [],
            recommendedFocusTags: []
        )
    }

    private static func eligibleCategories(for environment: PracticeEnvironment?) -> [GarageDrillLibraryCategory] {
        let drills: [GarageDrill]

        if let environment {
            drills = DrillVault.drills(in: environment)
        } else {
            drills = DrillVault.masterPlaybook
        }

        return Array(Set(drills.map(\.libraryCategory))).sorted { $0.rawValue < $1.rawValue }
    }

    private static func recurringWeaknessSignals(
        drillScores: [String: GarageSkillScore],
        categoryScores: [GarageDrillLibraryCategory: GarageSkillScore],
        faultTagScores: [String: GarageSkillScore]
    ) -> [GarageCoachingSignal] {
        let weakDrills = drillScores.values
            .filter { $0.sessionCount >= 2 && $0.recentSuccessRatio < 0.6 }
            .sorted { $0.recentSuccessRatio < $1.recentSuccessRatio }
            .prefix(3)
            .map { score in
                GarageCoachingSignal(
                    kind: .recurringWeakness,
                    title: "\(score.title) is still limiting progress",
                    detail: "Recent success is \(Int((score.recentSuccessRatio * 100).rounded()))% across repeated attempts.",
                    drillID: score.id,
                    weight: 12
                )
            }

        let weakCategories = categoryScores
            .filter { $0.value.sessionCount >= 2 && $0.value.recentSuccessRatio < 0.65 }
            .sorted { $0.value.recentSuccessRatio < $1.value.recentSuccessRatio }
            .prefix(2)
            .map { category, score in
                GarageCoachingSignal(
                    kind: .recentWeakness,
                    title: "\(category.displayName) needs attention",
                    detail: "Recent category success is \(Int((score.recentSuccessRatio * 100).rounded()))%.",
                    category: category,
                    weight: 8
                )
            }

        let weakFaultTags = faultTagScores.values
            .filter { $0.sessionCount >= 2 && $0.recentSuccessRatio < 0.65 }
            .sorted { $0.recentSuccessRatio < $1.recentSuccessRatio }
            .prefix(3)
            .map { score in
                GarageCoachingSignal(
                    kind: .recurringWeakness,
                    title: "\(score.title) is repeating",
                    detail: "This fault tag remains below target across recent reps.",
                    faultTag: score.id,
                    weight: 7
                )
            }

        return Array(weakDrills + weakCategories + weakFaultTags)
    }

    private static func improvingSignals(
        drillScores: [String: GarageSkillScore],
        categoryScores: [GarageDrillLibraryCategory: GarageSkillScore]
    ) -> [GarageCoachingSignal] {
        let improvingDrills = drillScores.values
            .filter { $0.sessionCount >= 2 && $0.trendDelta >= 0.12 && $0.recentSuccessRatio >= 0.72 }
            .sorted { $0.trendDelta > $1.trendDelta }
            .prefix(2)
            .map { score in
                GarageCoachingSignal(
                    kind: .improving,
                    title: "\(score.title) is trending up",
                    detail: "Recent success is up \(Int((score.trendDelta * 100).rounded())) points.",
                    drillID: score.id,
                    weight: 5
                )
            }

        let improvingCategories = categoryScores
            .filter { $0.value.sessionCount >= 2 && $0.value.trendDelta >= 0.1 && $0.value.recentSuccessRatio >= 0.7 }
            .sorted { $0.value.trendDelta > $1.value.trendDelta }
            .prefix(2)
            .map { category, score in
                GarageCoachingSignal(
                    kind: .improving,
                    title: "\(category.displayName) is improving",
                    detail: "Recent category success is up \(Int((score.trendDelta * 100).rounded())) points.",
                    category: category,
                    weight: 4
                )
            }

        return Array(improvingDrills + improvingCategories)
    }
}

private struct GarageSkillAccumulator {
    let id: String
    let title: String
    private(set) var successfulReps = 0
    private(set) var totalReps = 0
    private(set) var sessionCount = 0
    private(set) var recentSuccessfulReps = 0
    private(set) var recentTotalReps = 0
    private(set) var previousSuccessfulReps = 0
    private(set) var previousTotalReps = 0
    private(set) var lastPracticedAt: Date?
    private var sessionDates = Set<Date>()

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    mutating func record(
        _ result: DrillResult,
        date: Date,
        isRecent: Bool,
        isPrevious: Bool
    ) {
        successfulReps += result.successfulReps
        totalReps += result.totalReps

        if sessionDates.insert(date).inserted {
            sessionCount += 1
        }

        if let lastPracticedAt {
            self.lastPracticedAt = max(lastPracticedAt, date)
        } else {
            lastPracticedAt = date
        }

        if isRecent {
            recentSuccessfulReps += result.successfulReps
            recentTotalReps += result.totalReps
        } else if isPrevious {
            previousSuccessfulReps += result.successfulReps
            previousTotalReps += result.totalReps
        }
    }

    var score: GarageSkillScore {
        GarageSkillScore(
            id: id,
            title: title,
            successfulReps: successfulReps,
            totalReps: totalReps,
            sessionCount: sessionCount,
            recentSuccessfulReps: recentSuccessfulReps,
            recentTotalReps: recentTotalReps,
            previousSuccessfulReps: previousSuccessfulReps,
            previousTotalReps: previousTotalReps,
            lastPracticedAt: lastPracticedAt
        )
    }
}

private extension String {
    var garageHumanizedTag: String {
        split(separator: "_")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
