import Foundation
import NaturalLanguage

/// One goal line in the form. Has an identity so rows can be added and removed without confusing SwiftUI.
nonisolated struct GoalLine: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

/// What the user has written so far.
nonisolated struct ReflectionDraft: Codable, Equatable, Sendable {
    var goals: [GoalLine]
    var reflection: String

    init(goals: [GoalLine] = [GoalLine(), GoalLine(), GoalLine()], reflection: String = "") {
        self.goals = goals
        self.reflection = reflection
    }

    init(goalTexts: [String], reflection: String) {
        self.init(goals: goalTexts.map { GoalLine(text: $0) }, reflection: reflection)
    }

    /// Every row, trimmed, empties included, so indices match the rows on screen.
    var trimmedGoals: [String] {
        goals.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Only the rows with something in them.
    var filledGoals: [String] {
        trimmedGoals.filter { !$0.isEmpty }
    }

    var isEmpty: Bool {
        filledGoals.isEmpty && reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The numbers behind each strictness level.
nonisolated struct RubricThresholds: Equatable, Sendable {
    var minGoals: Int
    var maxGoals: Int = 5
    var minWordsPerGoal: Int
    var requiresActionVerb: Bool
    var requiresMeasurableGoal: Bool
    var minReflectionWords: Int
    var requiresFreshGoals: Bool

    static let relaxed = RubricThresholds(
        minGoals: 2, minWordsPerGoal: 3, requiresActionVerb: false, requiresMeasurableGoal: false,
        minReflectionWords: 25, requiresFreshGoals: false)
    static let standard = RubricThresholds(
        minGoals: 3, minWordsPerGoal: 4, requiresActionVerb: true, requiresMeasurableGoal: false,
        minReflectionWords: 40, requiresFreshGoals: false)
    static let strict = RubricThresholds(
        minGoals: 3, minWordsPerGoal: 5, requiresActionVerb: true, requiresMeasurableGoal: true,
        minReflectionWords: 80, requiresFreshGoals: true)
}

nonisolated extension RubricThresholds {
    init(for strictness: Strictness) {
        self = switch strictness {
        case .relaxed: .relaxed
        case .standard: .standard
        case .strict: .strict
        }
    }
}

/// One line of the checklist.
nonisolated struct RubricCheck: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case goalCount, goalDetail, goalAction, goalMeasurable, goalUnique, reflectionLength, reflectionReal, freshGoals
    }

    let kind: Kind
    let title: String
    let passed: Bool
    /// What to do about it, shown only when the check fails.
    let fix: String?
    /// 1-based goal rows this failure points at, so the form can mark them.
    let goalRows: [Int]

    var id: Kind { kind }
}

nonisolated struct RubricVerdict: Equatable, Sendable {
    let checks: [RubricCheck]

    var isApproved: Bool { checks.allSatisfy(\.passed) }
    var failed: [RubricCheck] { checks.filter { !$0.passed } }
    var problemRows: Set<Int> { Set(failed.flatMap(\.goalRows)) }
}

/// The bar. Deterministic, offline, and fast enough to run on every keystroke.
nonisolated struct ReflectionRubric: Sendable {
    let thresholds: RubricThresholds

    init(strictness: Strictness) {
        thresholds = RubricThresholds(for: strictness)
    }

    init(thresholds: RubricThresholds) {
        self.thresholds = thresholds
    }

    func evaluate(_ draft: ReflectionDraft, previousGoals: [String] = []) -> RubricVerdict {
        let t = thresholds
        let filled = draft.trimmedGoals.enumerated().filter { !$0.element.isEmpty }
        var checks: [RubricCheck] = []

        // Enough goals
        let count = filled.count
        let missing = t.minGoals - count
        checks.append(RubricCheck(
            kind: .goalCount,
            title: "At least \(t.minGoals) goals",
            passed: missing <= 0,
            fix: missing <= 0 ? nil : (count == 0
                ? "Write \(t.minGoals) goals for today."
                : "Add \(missing) more \(missing == 1 ? "goal" : "goals")."),
            goalRows: []))

        // Each goal is specific
        let short = filled.filter { TextMetrics.wordCount($0.element) < t.minWordsPerGoal }.map { $0.offset + 1 }
        checks.append(RubricCheck(
            kind: .goalDetail,
            title: "Each goal is specific (\(t.minWordsPerGoal)+ words)",
            passed: short.isEmpty,
            fix: short.isEmpty ? nil : "\(TextMetrics.goalSubject(short)) too short. Say what done looks like.",
            goalRows: short))

        // Goals start with an action
        if t.requiresActionVerb {
            let passive = filled.filter { !TextMetrics.hasActionVerb($0.element) }.map { $0.offset + 1 }
            checks.append(RubricCheck(
                kind: .goalAction,
                title: "Goals start with an action",
                passed: passive.isEmpty,
                fix: passive.isEmpty ? nil : "Start \(TextMetrics.goalNames(passive)) with what you'll do: Send…, Finish…, Call…",
                goalRows: passive))
        }

        // One goal is measurable
        if t.requiresMeasurableGoal {
            let measurable = filled.contains { TextMetrics.isMeasurable($0.element) }
            checks.append(RubricCheck(
                kind: .goalMeasurable,
                title: "One goal has a number or a time",
                passed: measurable,
                fix: measurable ? nil : "Give one goal a number or a time.",
                goalRows: []))
        }

        // No repeated goals
        var seen: [String: Int] = [:]
        var duplicateRows: [Int] = []
        for (offset, goal) in filled {
            let key = TextMetrics.normalized(goal)
            if let firstRow = seen[key] {
                if !duplicateRows.contains(firstRow) { duplicateRows.append(firstRow) }
                duplicateRows.append(offset + 1)
            } else {
                seen[key] = offset + 1
            }
        }
        checks.append(RubricCheck(
            kind: .goalUnique,
            title: "No repeated goals",
            passed: duplicateRows.isEmpty,
            fix: duplicateRows.isEmpty ? nil : "\(TextMetrics.goalNames(duplicateRows).capitalizedFirst) say the same thing.",
            goalRows: duplicateRows))

        // Reflection length
        let words = TextMetrics.wordCount(draft.reflection)
        let wordsMissing = t.minReflectionWords - words
        checks.append(RubricCheck(
            kind: .reflectionLength,
            title: "Reflection of \(t.minReflectionWords)+ words",
            passed: wordsMissing <= 0,
            fix: wordsMissing <= 0 ? nil : (words == 0
                ? "Write a few sentences about why today matters."
                : "\(wordsMissing) more \(wordsMissing == 1 ? "word" : "words"). What matters most today, and why?"),
            goalRows: []))

        // Reads like real writing
        let real = words > 0 && TextMetrics.looksLikeProse(draft.reflection)
        checks.append(RubricCheck(
            kind: .reflectionReal,
            title: "Reads like real writing",
            passed: real,
            fix: (real || words == 0) ? nil : "This doesn't read like sentences yet.",
            goalRows: []))

        // Different from yesterday
        if t.requiresFreshGoals, !previousGoals.isEmpty {
            let previous = Set(previousGoals.map(TextMetrics.normalized))
            let allOld = !filled.isEmpty && filled.allSatisfy { previous.contains(TextMetrics.normalized($0.element)) }
            checks.append(RubricCheck(
                kind: .freshGoals,
                title: "Different from yesterday",
                passed: !allOld,
                fix: allOld ? "These match yesterday's goals. What's new today?" : nil,
                goalRows: []))
        }

        return RubricVerdict(checks: checks)
    }
}

/// The string measurements the rubric is built on. Pure functions, no state.
nonisolated enum TextMetrics {
    static func words(_ text: String) -> [String] {
        text.split { $0.isWhitespace || $0.isNewline }.map(String.init)
    }

    static func wordCount(_ text: String) -> Int {
        words(text).count
    }

    /// Lowercased letters, digits and single spaces only, for comparing goals.
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Goals a person actually writes start with one of these far more often than a tagger expects.
    static let actionVerbs: Set<String> = [
        "finish", "send", "write", "call", "email", "text", "read", "run", "walk", "lift", "go", "book", "plan",
        "review", "ship", "fix", "draft", "clean", "cook", "study", "practice", "practise", "meet", "prepare", "make",
        "build", "start", "complete", "submit", "pay", "buy", "schedule", "outline", "edit", "publish", "record",
        "file", "apply", "research", "learn", "organize", "organise", "update", "reply", "answer", "ask", "visit",
        "train", "stretch", "meditate", "journal", "sleep", "wake", "drink", "eat", "cut", "stop", "reach", "message",
        "deliver", "design", "code", "test", "deploy", "refactor", "debug", "measure", "track", "reflect", "decide",
        "choose", "pick", "sort", "tidy", "fold", "wash", "water", "take", "bring", "drop", "get", "set", "put", "do",
        "try", "check", "confirm", "cancel", "renew", "order", "return", "print", "sign", "open", "close", "launch",
        "push", "pull", "merge", "commit", "grade", "mark", "teach", "tutor", "coach", "help", "support", "listen",
        "watch", "play", "swim", "bike", "cycle", "hike", "row", "ride", "climb", "jog", "sprint", "move", "clear",
        "block", "reserve", "invite", "host", "attend", "join", "leave", "arrive", "sell", "pitch", "present", "demo",
        "rehearse", "memorize", "memorise", "revise", "translate", "transcribe", "summarize", "summarise",
        "brainstorm", "sketch", "paint", "draw", "photograph", "shoot", "film", "bake", "brew", "prep", "sweep",
        "vacuum", "mop", "iron", "shop", "stock", "fill", "empty", "charge", "install", "upgrade", "migrate", "backup",
        "export", "import", "download", "upload", "share", "post", "announce", "celebrate", "thank", "forgive",
        "apologize", "apologise", "spend", "save", "invest", "budget", "donate", "give", "volunteer", "mentor", "hire",
        "interview", "negotiate", "wrap", "pack", "unpack", "respond", "follow", "compile", "compare", "assemble",
        "arrange", "define", "describe", "explain", "explore", "gather", "implement", "improve", "increase", "reduce",
        "remove", "replace", "rewrite", "rework", "solve", "verify", "validate", "walkthrough", "wire", "call",
    ]

    /// True when the goal names an action: the first word (or the word after "to" / "I will") is a known verb,
    /// or the part-of-speech tagger finds any verb in the line.
    static func hasActionVerb(_ goal: String) -> Bool {
        let tokens = words(normalized(goal))
        guard let first = tokens.first else { return false }
        if actionVerbs.contains(first) { return true }
        if first == "to", tokens.count > 1, actionVerbs.contains(tokens[1]) { return true }
        if first == "i", tokens.count > 2, ["will", "want", "need"].contains(tokens[1]), actionVerbs.contains(tokens[2]) { return true }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = goal
        var found = false
        tagger.enumerateTags(in: goal.startIndex..<goal.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if tag == .verb {
                found = true
                return false
            }
            return true
        }
        return found
    }

    static let measurableWords: Set<String> = [
        "by", "before", "until", "noon", "midnight", "tonight", "morning", "afternoon", "evening", "lunch", "dinner",
        "breakfast", "deadline", "once", "twice", "thrice", "half", "hour", "hours", "minute", "minutes", "min",
        "km", "miles", "mile", "pages", "page", "reps", "sets", "laps", "chapters", "chapter",
    ]

    /// A number, a time, or a deadline word.
    static func isMeasurable(_ goal: String) -> Bool {
        if goal.contains(where: \.isNumber) { return true }
        return !Set(words(normalized(goal))).isDisjoint(with: measurableWords)
    }

    /// Rejects keyboard mashing and repeated filler without needing a language model:
    /// no absurdly long tokens, a vowel share in the range real Latin-script prose occupies, and enough distinct words.
    static func looksLikeProse(_ text: String) -> Bool {
        let tokens = words(normalized(text))
        guard !tokens.isEmpty else { return false }
        if tokens.contains(where: { $0.count > 30 }) { return false }

        let letters = tokens.joined().filter(\.isLetter)
        guard letters.count >= 3 else { return false }

        let asciiLetters = letters.filter(\.isASCII)
        if Double(asciiLetters.count) / Double(letters.count) >= 0.7 {
            let vowels = asciiLetters.filter { "aeiouy".contains($0) }.count
            let ratio = Double(vowels) / Double(asciiLetters.count)
            guard (0.2...0.65).contains(ratio) else { return false }
        }

        if tokens.count >= 8 {
            let distinct = Double(Set(tokens).count) / Double(tokens.count)
            guard distinct >= 0.4 else { return false }
        }
        return true
    }

    /// "Goal 2 is" / "Goals 1 and 3 are"
    static func goalSubject(_ rows: [Int]) -> String {
        rows.count == 1 ? "Goal \(rows[0]) is" : "Goals \(joined(rows)) are"
    }

    /// "goal 2" / "goals 1 and 3"
    static func goalNames(_ rows: [Int]) -> String {
        rows.count == 1 ? "goal \(rows[0])" : "goals \(joined(rows))"
    }

    private static func joined(_ rows: [Int]) -> String {
        let sorted = rows.sorted()
        guard let last = sorted.last, sorted.count > 1 else { return sorted.map(String.init).joined() }
        return sorted.dropLast().map(String.init).joined(separator: ", ") + " and \(last)"
    }
}

nonisolated extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
