import Foundation
import SwiftUI

struct TestPrepView: View {
    @StateObject private var historyStore = QuizHistoryStore()
    @State private var selectedState = DrivingRulesData.states.first ?? "CA"
    @State private var selectedDifficulty: QuizDifficulty = .easy
    @State private var currentQuestionIndex = 0
    @State private var selectedOptionIndex: Int?
    @State private var score = 0
    @State private var isSubmitted = false
    @State private var isQuizComplete = false
    @State private var missedReviews: [MissedQuestionReview] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statePickerCard
                    rulesCard
                    videosCard
                    quizCard
                    missedReviewCard
                    historyCard
                }
                .padding()
            }
            .background(AppTheme.appBackground)
            .navigationTitle("Test Prep")
            .onChange(of: selectedState) { _, _ in resetQuiz() }
            .onChange(of: selectedDifficulty) { _, _ in resetQuiz() }
        }
    }

    private var currentQuestions: [PrepQuestion] {
        DrivingRulesData.questions(for: selectedState, difficulty: selectedDifficulty)
    }

    private var currentQuestion: PrepQuestion? {
        guard currentQuestionIndex < currentQuestions.count else { return nil }
        return currentQuestions[currentQuestionIndex]
    }

    private var statePickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("State Driving Rules")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            Picker("State", selection: $selectedState) {
                ForEach(DrivingRulesData.states, id: \.self) { state in
                    Text(state).tag(state)
                }
            }
            .pickerStyle(.segmented)

            Picker("Difficulty", selection: $selectedDifficulty) {
                ForEach(QuizDifficulty.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var rulesCard: some View {
        let rules = DrivingRulesData.rulesByState[selectedState] ?? StateRules(dos: [], donts: [])
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(selectedState) Rules Summary")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            Text("Do")
                .font(.subheadline.weight(.semibold))
            ForEach(rules.dos, id: \.self) { rule in
                Text("• \(rule)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Don't")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)
            ForEach(rules.donts, id: \.self) { rule in
                Text("• \(rule)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var videosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Driving Dos/Don'ts Videos")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            ForEach(DrivingRulesData.videoResources) { video in
                Link(destination: video.url) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(video.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.navy)
                            Text(video.tagline)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.rectangle.fill")
                            .foregroundStyle(AppTheme.softBlue)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var quizCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(selectedState) Prep Quiz (\(selectedDifficulty.rawValue))")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            if isQuizComplete {
                Text("Final Score: \(score)/\(currentQuestions.count)")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.navy)
                Button("Start Again") { resetQuiz() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.navy)
            } else if let question = currentQuestion {
                Text("Question \(currentQuestionIndex + 1) of \(currentQuestions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(question.prompt)
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        guard !isSubmitted else { return }
                        selectedOptionIndex = index
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundStyle(AppTheme.navy)
                            Spacer()
                            if selectedOptionIndex == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.softBlue)
                            }
                        }
                        .padding(10)
                        .background(AppTheme.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                if isSubmitted {
                    Text(feedbackText(for: question))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(feedbackColor(for: question))
                }

                if !isSubmitted {
                    Button("Submit") { submitCurrentAnswer() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.navy)
                        .disabled(selectedOptionIndex == nil)
                } else {
                    Button(currentQuestionIndex + 1 == currentQuestions.count ? "Finish Quiz" : "Next") {
                        nextQuestion()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.navy)
                }
            } else {
                Text("No quiz questions available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var missedReviewCard: some View {
        Group {
            if isQuizComplete {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Missed Questions Review")
                        .font(.headline)
                        .foregroundStyle(AppTheme.navy)

                    if missedReviews.isEmpty {
                        Text("Great work - no missed questions on this attempt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(missedReviews) { review in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(review.prompt)
                                    .font(.subheadline.weight(.semibold))
                                Text("Your answer: \(review.selectedAnswer)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("Correct answer: \(review.correctAnswer)")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text(review.explanation)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(AppTheme.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Historical Scores")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            let attempts = historyStore.attemptsForStateAndDifficulty(selectedState, difficulty: selectedDifficulty)
            if attempts.isEmpty {
                Text("No \(selectedDifficulty.rawValue) attempts yet for \(selectedState).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attempts) { attempt in
                    HStack {
                        Text(attempt.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(attempt.score)/\(attempt.totalQuestions)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.navy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func submitCurrentAnswer() {
        guard let question = currentQuestion, let selectedOptionIndex else { return }

        if selectedOptionIndex == question.correctIndex {
            score += 1
        } else {
            missedReviews.append(
                MissedQuestionReview(
                    prompt: question.prompt,
                    selectedAnswer: question.options[selectedOptionIndex],
                    correctAnswer: question.options[question.correctIndex],
                    explanation: question.explanation
                )
            )
        }
        isSubmitted = true
    }

    private func nextQuestion() {
        if currentQuestionIndex + 1 < currentQuestions.count {
            currentQuestionIndex += 1
            selectedOptionIndex = nil
            isSubmitted = false
            return
        }

        isQuizComplete = true
        historyStore.addAttempt(
            state: selectedState,
            difficulty: selectedDifficulty,
            score: score,
            totalQuestions: currentQuestions.count
        )
    }

    private func resetQuiz() {
        currentQuestionIndex = 0
        selectedOptionIndex = nil
        score = 0
        isSubmitted = false
        isQuizComplete = false
        missedReviews = []
    }

    private func feedbackText(for question: PrepQuestion) -> String {
        guard let selectedOptionIndex else { return "" }
        return selectedOptionIndex == question.correctIndex ? "Correct" : "Not quite. \(question.explanation)"
    }

    private func feedbackColor(for question: PrepQuestion) -> Color {
        guard let selectedOptionIndex else { return .secondary }
        return selectedOptionIndex == question.correctIndex ? .green : .orange
    }
}

private struct VideoResource: Identifiable {
    let id = UUID()
    let title: String
    let tagline: String
    let url: URL
}

private struct PrepQuestion {
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

private struct StateRules {
    let dos: [String]
    let donts: [String]
}

private struct MissedQuestionReview: Identifiable {
    let id = UUID()
    let prompt: String
    let selectedAnswer: String
    let correctAnswer: String
    let explanation: String
}

private enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }
}

private struct QuizAttempt: Codable, Identifiable {
    let id: UUID
    let state: String
    let difficulty: String?
    let score: Int
    let totalQuestions: Int
    let timestamp: Date
}

private final class QuizHistoryStore: ObservableObject {
    @Published private(set) var attempts: [QuizAttempt] = [] {
        didSet { save() }
    }

    private let storageKey = "testPrepQuizAttemptsV1"

    init() {
        load()
    }

    func addAttempt(state: String, difficulty: QuizDifficulty, score: Int, totalQuestions: Int) {
        let attempt = QuizAttempt(
            id: UUID(),
            state: state,
            difficulty: difficulty.rawValue,
            score: score,
            totalQuestions: totalQuestions,
            timestamp: Date()
        )
        attempts.insert(attempt, at: 0)
    }

    func attemptsForStateAndDifficulty(_ state: String, difficulty: QuizDifficulty) -> [QuizAttempt] {
        attempts.filter {
            $0.state == state &&
            ($0.difficulty ?? QuizDifficulty.medium.rawValue) == difficulty.rawValue
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(attempts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        attempts = (try? decoder.decode([QuizAttempt].self, from: data)) ?? []
    }
}

private enum DrivingRulesData {
    static let states = ["CA", "TX", "NY", "FL", "WA"]

    static let videoResources: [VideoResource] = [
        VideoResource(
            title: "Defensive Driving Basics",
            tagline: "Do: anticipate traffic and maintain space",
            url: URL(string: "https://www.youtube.com/watch?v=Xk1vCqfYpos")!
        ),
        VideoResource(
            title: "Avoid Distracted Driving",
            tagline: "Don't: use phone while driving",
            url: URL(string: "https://www.youtube.com/watch?v=QyN96Qf8Q0Q")!
        ),
        VideoResource(
            title: "Safe Following Distance",
            tagline: "Do: keep 3-second gap",
            url: URL(string: "https://www.youtube.com/watch?v=q1xP3YfN2j0")!
        ),
        VideoResource(
            title: "Common Driving Mistakes",
            tagline: "Don't: speed through intersections",
            url: URL(string: "https://www.youtube.com/watch?v=uYQ3Q0kN9C8")!
        )
    ]

    static let rulesByState: [String: StateRules] = [
        "CA": StateRules(
            dos: [
                "Come to a full stop at red lights and stop signs.",
                "Yield to pedestrians in marked and unmarked crosswalks.",
                "Use hands-free mode for phone communication."
            ],
            donts: [
                "Do not exceed posted speed limits.",
                "Do not text or hold a phone while driving.",
                "Do not pass a stopped school bus with flashing red lights."
            ]
        ),
        "TX": StateRules(
            dos: [
                "Signal before lane changes and turns.",
                "Move over or slow down for emergency vehicles.",
                "Wear seatbelts at all times."
            ],
            donts: [
                "Do not drive while using a handheld phone in school zones.",
                "Do not ignore railroad crossing signals.",
                "Do not tailgate in high-speed roads."
            ]
        ),
        "NY": StateRules(
            dos: [
                "Reduce speed in work and school zones.",
                "Yield right-of-way when required at intersections.",
                "Keep headlights on in low visibility."
            ],
            donts: [
                "Do not use handheld electronic devices while driving.",
                "Do not block intersections.",
                "Do not pass emergency vehicles unsafely."
            ]
        ),
        "FL": StateRules(
            dos: [
                "Stop fully for school buses displaying stop signals.",
                "Use turn signals for all lane changes.",
                "Drive with headlights in rain."
            ],
            donts: [
                "Do not drive through flooded roads.",
                "Do not speed in residential neighborhoods.",
                "Do not drive distracted by mobile devices."
            ]
        ),
        "WA": StateRules(
            dos: [
                "Follow Move Over law for roadside incidents.",
                "Keep safe speed for wet and icy conditions.",
                "Stop for pedestrians at crossings."
            ],
            donts: [
                "Do not use handheld phones while driving.",
                "Do not pass where prohibited by signs/markings.",
                "Do not exceed speed in school zones."
            ]
        )
    ]

    private static let baseQuizzesByState: [String: [PrepQuestion]] = [
        "CA": [
            PrepQuestion(
                prompt: "What is required at a stop sign in California?",
                options: ["Slow down only", "Full stop behind limit line", "Stop only if traffic is present", "Honk and proceed"],
                correctIndex: 1,
                explanation: "California requires a complete stop at the limit line or before entering crosswalk/intersection."
            ),
            PrepQuestion(
                prompt: "Can you hold your phone while driving in CA?",
                options: ["Yes, briefly", "Only at red lights", "No, handheld use is prohibited", "Only under 25 mph"],
                correctIndex: 2,
                explanation: "Handheld phone use is prohibited while driving."
            ),
            PrepQuestion(
                prompt: "When must you yield to pedestrians?",
                options: ["Only in marked crosswalks", "Only at traffic lights", "At all crosswalks including unmarked", "Only when signaled by police"],
                correctIndex: 2,
                explanation: "Yielding applies to both marked and unmarked crosswalks."
            )
        ],
        "TX": [
            PrepQuestion(
                prompt: "What should you do when approaching stopped emergency vehicles?",
                options: ["Maintain speed", "Move over or slow down", "Honk and pass quickly", "Stop in your lane"],
                correctIndex: 1,
                explanation: "Texas Move Over law requires changing lanes or slowing down safely."
            ),
            PrepQuestion(
                prompt: "Handheld phone use is prohibited in Texas:",
                options: ["Everywhere", "Only in school zones", "Only on highways", "Only at night"],
                correctIndex: 1,
                explanation: "Texas law specifically prohibits handheld phone use in active school zones."
            ),
            PrepQuestion(
                prompt: "Why is signaling lane changes important?",
                options: ["It saves fuel", "It improves radio signal", "It informs nearby drivers", "It is optional at low speed"],
                correctIndex: 2,
                explanation: "Signals communicate intent and reduce crash risk."
            )
        ],
        "NY": [
            PrepQuestion(
                prompt: "In New York, using a handheld device while driving is:",
                options: ["Allowed briefly", "Allowed with one hand", "Prohibited", "Allowed below 20 mph"],
                correctIndex: 2,
                explanation: "New York has strict handheld device restrictions."
            ),
            PrepQuestion(
                prompt: "What is blocking the box?",
                options: ["Parking near hydrants", "Entering an intersection without room to clear", "Driving too slowly", "Stopping at a yellow light"],
                correctIndex: 1,
                explanation: "Blocking the box causes congestion and is prohibited."
            ),
            PrepQuestion(
                prompt: "How should speed be adjusted in work zones?",
                options: ["Increase to pass quickly", "Keep same as highway limit", "Reduce and follow posted zone limits", "Only reduce when workers visible"],
                correctIndex: 2,
                explanation: "Always obey posted work zone limits."
            )
        ],
        "FL": [
            PrepQuestion(
                prompt: "When it rains in Florida, drivers should:",
                options: ["Turn off headlights", "Use headlights", "Use hazard lights continuously", "Increase speed"],
                correctIndex: 1,
                explanation: "Headlights improve visibility and are required in low visibility conditions."
            ),
            PrepQuestion(
                prompt: "If a school bus has a stop signal out, you should:",
                options: ["Pass quickly", "Stop as required by law", "Honk and continue", "Only stop if children visible"],
                correctIndex: 1,
                explanation: "Drivers must stop for school buses with active stop signals."
            ),
            PrepQuestion(
                prompt: "Texting while driving is:",
                options: ["Safe at low speeds", "Allowed if mounted", "A dangerous distraction", "Required for navigation"],
                correctIndex: 2,
                explanation: "Texting is one of the highest-risk distractions."
            )
        ],
        "WA": [
            PrepQuestion(
                prompt: "Washington's distracted driving law generally prohibits:",
                options: ["Seatbelt use", "Handheld phone use while driving", "Using turn signals", "Driving in rain"],
                correctIndex: 1,
                explanation: "Handheld phone use is prohibited under Washington law."
            ),
            PrepQuestion(
                prompt: "What should you do near roadside emergency scenes?",
                options: ["Speed up", "Move over or slow down", "Stop in same lane", "Ignore if no cones"],
                correctIndex: 1,
                explanation: "Move over/safe slowdown helps protect responders."
            ),
            PrepQuestion(
                prompt: "In poor weather, safe driving means:",
                options: ["Following closer for visibility", "Driving faster to clear area", "Reducing speed and increasing spacing", "Using high beams in fog"],
                correctIndex: 2,
                explanation: "Lower speed and bigger gaps reduce collision risk."
            )
        ]
    ]

    private static let hardExtrasByState: [String: [PrepQuestion]] = [
        "CA": [
            PrepQuestion(
                prompt: "In dense traffic, what best reduces collision risk?",
                options: ["Frequent lane changes", "Keeping a steady safe gap", "Following closely", "Rapid acceleration"],
                correctIndex: 1,
                explanation: "A consistent safe following distance gives reaction time."
            )
        ],
        "TX": [
            PrepQuestion(
                prompt: "What is safest when visibility drops suddenly in heavy rain?",
                options: ["Keep speed to avoid hydroplaning", "Use low beams and reduce speed smoothly", "Use high beams and pass others", "Brake hard immediately"],
                correctIndex: 1,
                explanation: "Reduce speed gradually and improve visibility with low beams."
            )
        ],
        "NY": [
            PrepQuestion(
                prompt: "At a stale green light in city driving, what should you do?",
                options: ["Accelerate hard to clear quickly", "Maintain awareness and be ready to stop", "Ignore cross traffic", "Use horn continuously"],
                correctIndex: 1,
                explanation: "Defensive driving requires anticipation at intersections."
            )
        ],
        "FL": [
            PrepQuestion(
                prompt: "If roads are flooded, safest action is:",
                options: ["Drive through slowly", "Turn around and find alternate route", "Follow bigger vehicles", "Speed through to avoid stalling"],
                correctIndex: 1,
                explanation: "Flood water depth is deceptive and dangerous."
            )
        ],
        "WA": [
            PrepQuestion(
                prompt: "What improves safety most on icy roads?",
                options: ["Late hard braking", "Larger following distance and gentle inputs", "Aggressive steering", "Cruise control"],
                correctIndex: 1,
                explanation: "Smooth controls and more spacing reduce skids."
            )
        ]
    ]

    static func questions(for state: String, difficulty: QuizDifficulty) -> [PrepQuestion] {
        let base = baseQuizzesByState[state] ?? []
        switch difficulty {
        case .easy:
            return Array(base.prefix(2))
        case .medium:
            return base
        case .hard:
            return base + (hardExtrasByState[state] ?? [])
        }
    }
}
