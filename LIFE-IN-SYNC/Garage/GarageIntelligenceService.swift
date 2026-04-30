import Foundation

struct GarageCoachingInsight: Codable, Equatable {
    let keyCues: [String]
    let focusDrills: [String]?

    var normalized: GarageCoachingInsight {
        GarageCoachingInsight(
            keyCues: keyCues
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
                .prefix(2)
                .map { String($0) },
            focusDrills: focusDrills?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
                .prefix(2)
                .map { String($0) }
        )
    }

    var isUsable: Bool {
        normalized.keyCues.isEmpty == false
    }

    var primaryCue: String? {
        normalized.keyCues.first
    }

    static func decode(from rawValue: String?) -> GarageCoachingInsight? {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GarageCoachingInsight.self, from: data) else {
            return nil
        }

        let normalized = decoded.normalized
        return normalized.isUsable ? normalized : nil
    }

    func focusDrillNames(matching drillResults: [DrillResult]) -> [String] {
        let normalizedInsight = normalized
        let availableDrillNames = drillResults.map(\.name)

        if let explicitFocusDrills = normalizedInsight.focusDrills, explicitFocusDrills.isEmpty == false {
            let resolvedFocusDrills = availableDrillNames.filter { drillName in
                explicitFocusDrills.contains { focusedName in
                    focusedName.caseInsensitiveCompare(drillName) == .orderedSame
                }
            }

            if resolvedFocusDrills.isEmpty == false {
                return resolvedFocusDrills
            }
        }

        let cueCorpus = normalizedInsight.keyCues.joined(separator: " ").lowercased()
        let heuristicMatches = availableDrillNames.filter { drillName in
            cueCorpus.contains(drillName.lowercased())
        }

        if heuristicMatches.isEmpty == false {
            return heuristicMatches
        }

        return availableDrillNames
    }
}

struct GarageCoachingInsightInput: Sendable {
    let templateName: String
    let environmentName: String
    let sessionFeelNote: String
    let drillResults: [DrillResult]
    let previousSessionEfficiencyPercentage: Int?
    let currentSessionEfficiencyPercentage: Int
    let previousCue: String?
}

enum GarageIntelligenceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case noInsight

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Gemini API key is missing."
        case .invalidResponse:
            "Gemini returned an invalid coaching response."
        case .noInsight:
            "No coaching insight was generated."
        }
    }
}

actor GarageIntelligenceService {
    static let shared = GarageIntelligenceService()

    private let session: URLSession
    private let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateInsight(for input: GarageCoachingInsightInput) async throws -> String {
        let apiKey = try apiKey()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(makeRequestBody(for: input))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw GarageIntelligenceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(GarageGeminiResponse.self, from: data)
        guard let rawText = decoded.candidates.first?.content.parts.first?.text,
              let insightData = rawText.data(using: .utf8) else {
            throw GarageIntelligenceError.invalidResponse
        }

        let insight = try JSONDecoder().decode(GarageCoachingInsight.self, from: insightData).normalized
        guard insight.isUsable else {
            throw GarageIntelligenceError.noInsight
        }

        let normalizedData = try JSONEncoder().encode(insight)
        guard let normalizedString = String(data: normalizedData, encoding: .utf8) else {
            throw GarageIntelligenceError.invalidResponse
        }

        return normalizedString
    }

    private func apiKey() throws -> String {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], key.isEmpty == false {
            return key
        }

        if let key = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"], key.isEmpty == false {
            return key
        }

        throw GarageIntelligenceError.missingAPIKey
    }

    private func makeRequestBody(for input: GarageCoachingInsightInput) -> GarageGeminiRequest {
        let feelNote = input.sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let drillLines = input.drillResults.map { result in
            "\(result.name): \(result.successfulReps)/\(result.totalReps) (\(Int((result.successRatio * 100).rounded()))%)"
        }.joined(separator: "\n")
        let previousCue = input.previousCue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousEfficiency = input.previousSessionEfficiencyPercentage.map { "\($0)%" } ?? "None"
        let previousCueText: String

        if let previousCue, previousCue.isEmpty == false {
            previousCueText = previousCue
        } else {
            previousCueText = "None"
        }

        let prompt = """
        Session template: \(input.templateName)
        Environment: \(input.environmentName)
        Previous session efficiency: \(previousEfficiency)
        Current session efficiency: \(input.currentSessionEfficiencyPercentage)%
        Previous cue: \(previousCueText)
        Session feel note: \(feelNote.isEmpty ? "None" : feelNote)
        Drill results:
        \(drillLines)
        """

        return GarageGeminiRequest(
            system_instruction: .init(parts: [
                .init(
                    text: "You are a professional coach. The user's last session was [X]% efficient. They are currently at [Y]%. Based on their previous cue '[LastCue]', refine your tactical advice for today. Return 2 concise tactical key cues and identify up to 2 drill names those cues apply to. Keep the key cues under 40 words total."
                )
            ]),
            contents: [
                .init(parts: [
                    .init(text: prompt)
                ])
            ],
            generationConfig: .init(
                responseMimeType: "application/json",
                responseJsonSchema: [
                    "type": "object",
                    "properties": [
                        "keyCues": [
                            "type": "array",
                            "description": "Two concise tactical coaching cues for the next session.",
                            "items": [
                                "type": "string",
                                "description": "A concise tactical coaching cue."
                            ],
                            "minItems": 2,
                            "maxItems": 2
                        ],
                        "focusDrills": [
                            "type": "array",
                            "description": "Up to two drill names from the provided session results that the cues primarily target.",
                            "items": [
                                "type": "string",
                                "description": "A drill name from the provided session results."
                            ],
                            "minItems": 0,
                            "maxItems": 2
                        ]
                    ],
                    "required": ["keyCues"]
                ].anyEncodableMap
            )
        )
    }
}

private struct GarageGeminiRequest: Encodable {
    let system_instruction: GarageGeminiContent
    let contents: [GarageGeminiContent]
    let generationConfig: GarageGeminiGenerationConfig
}

private struct GarageGeminiContent: Encodable {
    let parts: [GarageGeminiPart]
}

private struct GarageGeminiPart: Encodable {
    let text: String
}

private struct GarageGeminiGenerationConfig: Encodable {
    let responseMimeType: String
    let responseJsonSchema: [String: AnyEncodable]
}

private struct GarageGeminiResponse: Decodable {
    let candidates: [GarageGeminiCandidate]
}

private struct GarageGeminiCandidate: Decodable {
    let content: GarageGeminiCandidateContent
}

private struct GarageGeminiCandidateContent: Decodable {
    let parts: [GarageGeminiCandidatePart]
}

private struct GarageGeminiCandidatePart: Decodable {
    let text: String?
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

private extension Dictionary where Key == String, Value == Any {
    var anyEncodableMap: [String: AnyEncodable] {
        reduce(into: [String: AnyEncodable]()) { partialResult, item in
            partialResult[item.key] = AnyEncodable(item.value)
        }
    }
}

private extension AnyEncodable {
    init(_ value: Any) {
        switch value {
        case let value as String:
            self.init(value)
        case let value as Int:
            self.init(value)
        case let value as Double:
            self.init(value)
        case let value as Bool:
            self.init(value)
        case let value as [String]:
            self.init(value)
        case let value as [Any]:
            self.init(value.map(AnyEncodable.init))
        case let value as [String: Any]:
            self.init(value.mapValues(AnyEncodable.init))
        case let value as [String: AnyEncodable]:
            self.init(value)
        default:
            self.init(String(describing: value))
        }
    }
}
