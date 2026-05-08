import Foundation

enum GarageAdaptiveRecommendationKind: String, Hashable {
    case repeatDrill
    case remedialDrill
    case progressionDrill
    case categoryMaintenance
    case categoryRecovery
    case balancedDietCorrection
    case focusTagRecommendation
}

struct GarageAdaptiveRecommendation: Identifiable, Hashable {
    let id: String
    let kind: GarageAdaptiveRecommendationKind
    let title: String
    let detail: String
    let drillID: String?
    let category: GarageDrillLibraryCategory?
    let faultTag: String?
    let scoreImpact: Double
    let relatedDrillIDs: [String]
    let focusTags: Set<String>

    init(
        kind: GarageAdaptiveRecommendationKind,
        title: String,
        detail: String,
        drillID: String? = nil,
        category: GarageDrillLibraryCategory? = nil,
        faultTag: String? = nil,
        scoreImpact: Double,
        relatedDrillIDs: [String] = [],
        focusTags: Set<String> = []
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.drillID = drillID
        self.category = category
        self.faultTag = faultTag
        self.scoreImpact = scoreImpact
        self.relatedDrillIDs = relatedDrillIDs
        self.focusTags = focusTags
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

struct GarageCoachRead: Hashable {
    let summary: String
    let recommendation: String
    let supportingSignals: [GarageAdaptiveRecommendation]

    static func baseline(for environment: PracticeEnvironment) -> GarageCoachRead {
        GarageCoachRead(
            summary: "No pattern is established yet.",
            recommendation: "Start with a balanced \(environment.displayName.lowercased()) session and log the reps honestly.",
            supportingSignals: []
        )
    }
}

enum GarageAdaptiveRecommendationEngine {
    static func recommendations(
        for profile: GarageSkillProfile,
        environment: PracticeEnvironment? = nil
    ) -> [GarageAdaptiveRecommendation] {
        var recommendations: [GarageAdaptiveRecommendation] = []

        for signal in profile.recurringWeaknesses {
            switch signal.kind {
            case .recurringWeakness, .recentWeakness:
                if let drillID = signal.drillID,
                   let drill = DrillVault.drill(for: drillID) {
                    recommendations.append(
                        GarageAdaptiveRecommendation(
                            kind: .repeatDrill,
                            title: "Repeat \(drill.title)",
                            detail: signal.detail,
                            drillID: drillID,
                            category: DrillVault.metadata(for: drill).primaryCategory,
                            scoreImpact: signal.weight,
                            focusTags: DrillVault.metadata(for: drill).promptTags
                        )
                    )

                    if let remedialDrillID = drill.remedialDrillID,
                       let remedial = DrillVault.drill(for: remedialDrillID),
                       environment == nil || remedial.environment == environment {
                        recommendations.append(
                            GarageAdaptiveRecommendation(
                                kind: .remedialDrill,
                                title: "Use \(remedial.title) as the regression",
                                detail: "The last pattern points toward a simpler remedial drill before progressing.",
                                drillID: remedialDrillID,
                                category: DrillVault.metadata(for: remedial).primaryCategory,
                                scoreImpact: signal.weight + 4,
                                relatedDrillIDs: [drillID],
                                focusTags: DrillVault.metadata(for: remedial).promptTags
                            )
                        )
                    }
                }

                if let category = signal.category {
                    recommendations.append(
                        GarageAdaptiveRecommendation(
                            kind: .categoryRecovery,
                            title: "Bias toward \(category.displayName)",
                            detail: signal.detail,
                            category: category,
                            scoreImpact: signal.weight
                        )
                    )
                }

                if let faultTag = signal.faultTag {
                    recommendations.append(
                        GarageAdaptiveRecommendation(
                            kind: .focusTagRecommendation,
                            title: "Watch \(faultTag.garageHumanizedAdaptiveTag)",
                            detail: signal.detail,
                            faultTag: faultTag,
                            scoreImpact: signal.weight,
                            focusTags: [faultTag]
                        )
                    )
                }
            case .undertrained:
                if let category = signal.category {
                    recommendations.append(
                        GarageAdaptiveRecommendation(
                            kind: .balancedDietCorrection,
                            title: "Reintroduce \(category.displayName)",
                            detail: signal.detail,
                            category: category,
                            scoreImpact: signal.weight
                        )
                    )
                }
            case .overtrained:
                if let category = signal.category {
                    recommendations.append(
                        GarageAdaptiveRecommendation(
                            kind: .balancedDietCorrection,
                            title: "Ease off \(category.displayName)",
                            detail: signal.detail,
                            category: category,
                            scoreImpact: signal.weight
                        )
                    )
                }
            case .improving:
                break
            }
        }

        for signal in profile.improvingSignals {
            if let drillID = signal.drillID,
               let drill = DrillVault.drill(for: drillID) {
                let metadata = DrillVault.metadata(for: drill)
                let progressionIDs = metadata.progressionIDs.filter { id in
                    guard let progression = DrillVault.drill(for: id) else {
                        return false
                    }

                    return environment == nil || progression.environment == environment
                }

                if let progressionID = progressionIDs.first,
                   let progression = DrillVault.drill(for: progressionID) {
                    recommendations.append(
                        GarageAdaptiveRecommendation(
                            kind: .progressionDrill,
                            title: "Progress to \(progression.title)",
                            detail: signal.detail,
                            drillID: progressionID,
                            category: DrillVault.metadata(for: progression).primaryCategory,
                            scoreImpact: signal.weight,
                            relatedDrillIDs: [drillID],
                            focusTags: DrillVault.metadata(for: progression).promptTags
                        )
                    )
                }
            }

            if let category = signal.category {
                recommendations.append(
                    GarageAdaptiveRecommendation(
                        kind: .categoryMaintenance,
                        title: "Maintain \(category.displayName)",
                        detail: signal.detail,
                        category: category,
                        scoreImpact: signal.weight
                    )
                )
            }
        }

        for focusTag in profile.recommendedFocusTags.sorted().prefix(4) {
            recommendations.append(
                GarageAdaptiveRecommendation(
                    kind: .focusTagRecommendation,
                    title: "Keep \(focusTag.garageHumanizedAdaptiveTag) in the plan",
                    detail: "Recent lower-scoring reps pointed at this tag.",
                    faultTag: focusTag,
                    scoreImpact: 4,
                    focusTags: [focusTag]
                )
            )
        }

        return Array(
            recommendations
                .sorted { lhs, rhs in
                    if lhs.scoreImpact == rhs.scoreImpact {
                        return lhs.title < rhs.title
                    }

                    return lhs.scoreImpact > rhs.scoreImpact
                }
                .prefix(8)
        )
    }

    static func coachRead(
        for profile: GarageSkillProfile,
        recommendations: [GarageAdaptiveRecommendation],
        environment: PracticeEnvironment
    ) -> GarageCoachRead {
        guard profile.isEmpty == false else {
            return .baseline(for: environment)
        }

        let primary = recommendations.first
        let summary: String

        if let improving = profile.improvingSignals.first {
            summary = improving.title
        } else if let recurring = profile.recurringWeaknesses.first {
            summary = recurring.title
        } else {
            summary = "\(environment.displayName) practice has enough history for a balanced adjustment."
        }

        let recommendation: String
        if let primary {
            recommendation = primary.title
        } else if let undertrained = profile.undertrainedCategories.first {
            recommendation = "Next session should reintroduce \(undertrained.displayName)."
        } else {
            recommendation = "Next session should stay balanced and preserve the current carry-forward cue."
        }

        return GarageCoachRead(
            summary: summary,
            recommendation: recommendation,
            supportingSignals: Array(recommendations.prefix(3))
        )
    }

    static func validationErrors() -> [String] {
        let profile = GaragePracticeHistoryAnalyzer.skillProfile(from: [])
        let recommendations = recommendations(for: profile)
        if recommendations.isEmpty == false {
            return ["Recommendation engine should return an empty recommendation set for empty history."]
        }

        return []
    }
}

private extension String {
    var garageHumanizedAdaptiveTag: String {
        split(separator: "_")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
