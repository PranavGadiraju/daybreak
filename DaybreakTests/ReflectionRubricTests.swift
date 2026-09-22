import Testing
@testable import Daybreak

struct ReflectionRubricTests {
    /// 46 words.
    static let standardReflection = """
        Today matters because the scope document unblocks the whole build, and I have been circling it for a week. \
        I keep opening Instagram before I have a plan, so the plan comes first. If the run happens at six \
        I will sleep better tonight.
        """

    /// 92 words.
    static let strictReflection = """
        Today matters because the scope document unblocks the whole build, and I have been circling it for a week \
        without writing a single line. I keep opening Instagram before I have a plan, so the plan comes first this \
        morning. If the run happens at six I will sleep better, and the gym stops being a thing I feel guilty about \
        at midnight. The call with Mom is the one I would skip if the day gets away from me, so it goes on the list \
        with a time and not as a vague intention.
        """

    static let goodGoals = [
        "Finish the Daybreak PRD before lunch",
        "Run 5k at 6 PM after work",
        "Call Mom about the weekend plans",
    ]

    @Test func standardApprovesAGoodDraft() {
        let draft = ReflectionDraft(goalTexts: Self.goodGoals, reflection: Self.standardReflection)
        let verdict = ReflectionRubric(strictness: .standard).evaluate(draft)
        #expect(verdict.isApproved, "failed: \(verdict.failed.map(\.title))")
    }

    @Test func strictApprovesAGoodDraft() {
        let draft = ReflectionDraft(goalTexts: Self.goodGoals, reflection: Self.strictReflection)
        let verdict = ReflectionRubric(strictness: .strict).evaluate(draft, previousGoals: ["Write the essay outline tonight"])
        #expect(verdict.isApproved, "failed: \(verdict.failed.map(\.title))")
    }

    @Test(arguments: Strictness.allCases)
    func emptyDraftFails(strictness: Strictness) {
        let verdict = ReflectionRubric(strictness: strictness).evaluate(ReflectionDraft())
        #expect(!verdict.isApproved)
        #expect(verdict.failed.contains { $0.kind == .goalCount })
    }

    @Test func tooFewGoalsSaysHowManyToAdd() {
        let draft = ReflectionDraft(goalTexts: Array(Self.goodGoals.prefix(2)), reflection: Self.standardReflection)
        let verdict = ReflectionRubric(strictness: .standard).evaluate(draft)
        let check = verdict.checks.first { $0.kind == .goalCount }
        #expect(check?.passed == false)
        #expect(check?.fix == "Add 1 more goal.")
    }

    @Test func shortGoalIsFlaggedOnItsRow() {
        let draft = ReflectionDraft(goalTexts: ["Finish the Daybreak PRD before lunch", "gym", "Call Mom about the weekend plans"], reflection: Self.standardReflection)
        let verdict = ReflectionRubric(strictness: .standard).evaluate(draft)
        let check = verdict.checks.first { $0.kind == .goalDetail }
        #expect(check?.passed == false)
        #expect(check?.goalRows == [2])
        #expect(verdict.problemRows.contains(2))
        #expect(!verdict.problemRows.contains(1))
    }

    @Test func goalWithoutAnActionFails() {
        let draft = ReflectionDraft(goalTexts: ["A quiet morning with coffee and the paper", "Run 5k at 6 PM after work", "Call Mom about the weekend plans"], reflection: Self.standardReflection)
        let verdict = ReflectionRubric(strictness: .standard).evaluate(draft)
        let check = verdict.checks.first { $0.kind == .goalAction }
        #expect(check?.passed == false)
        #expect(check?.goalRows == [1])
    }

    @Test(arguments: [
        "Finish the essay draft tonight",
        "To finish the essay draft tonight",
        "I will finish the essay draft tonight",
        "The garage really needs a clean before Sunday",
    ])
    func actionVerbsAreRecognised(goal: String) {
        #expect(TextMetrics.hasActionVerb(goal))
    }

    @Test func duplicateGoalsPointAtBothRows() {
        let draft = ReflectionDraft(goalTexts: ["Run 5k at 6 PM", "Call Mom about the weekend plans", "run 5K at 6 pm."], reflection: Self.standardReflection)
        let verdict = ReflectionRubric(strictness: .standard).evaluate(draft)
        let check = verdict.checks.first { $0.kind == .goalUnique }
        #expect(check?.passed == false)
        #expect(check?.goalRows == [1, 3])
        #expect(check?.fix == "Goals 1 and 3 say the same thing.")
    }

    @Test func shortReflectionCountsTheMissingWords() {
        let draft = ReflectionDraft(goalTexts: Self.goodGoals, reflection: "Just a few words here today")
        let verdict = ReflectionRubric(strictness: .standard).evaluate(draft)
        let check = verdict.checks.first { $0.kind == .reflectionLength }
        #expect(check?.passed == false)
        #expect(check?.fix == "34 more words. What matters most today, and why?")
    }

    @Test(arguments: [
        String(repeating: "asdf ", count: 30),
        String(repeating: "blah ", count: 30),
        "qwertyuiop zxcvbnm sdfghjkl qwrtypsdfghjklzxcvbnm mnbvcxz lkjhgfdsa poiuytrewq " + String(repeating: "xyz ", count: 25),
    ])
    func keyboardMashingIsNotWriting(text: String) {
        #expect(!TextMetrics.looksLikeProse(text))
        let verdict = ReflectionRubric(strictness: .relaxed).evaluate(ReflectionDraft(goalTexts: Self.goodGoals, reflection: text))
        #expect(verdict.failed.contains { $0.kind == .reflectionReal })
    }

    @Test func strictNeedsOneMeasurableGoal() {
        let vague = ["Finish the Daybreak PRD document draft", "Call Mom about the weekend plans", "Clean the kitchen and the hallway"]
        let verdict = ReflectionRubric(strictness: .strict).evaluate(ReflectionDraft(goalTexts: vague, reflection: Self.strictReflection))
        #expect(verdict.failed.contains { $0.kind == .goalMeasurable })

        let measurable = ["Finish the Daybreak PRD before lunch", "Call Mom about the weekend plans", "Clean the kitchen and the hallway"]
        let approved = ReflectionRubric(strictness: .strict).evaluate(ReflectionDraft(goalTexts: measurable, reflection: Self.strictReflection))
        #expect(approved.isApproved, "failed: \(approved.failed.map(\.title))")
    }

    @Test func strictRejectsYesterdaysGoals() {
        let draft = ReflectionDraft(goalTexts: Self.goodGoals, reflection: Self.strictReflection)
        let same = ReflectionRubric(strictness: .strict).evaluate(draft, previousGoals: Self.goodGoals)
        #expect(same.failed.contains { $0.kind == .freshGoals })

        let partlyNew = ReflectionRubric(strictness: .strict).evaluate(draft, previousGoals: Array(Self.goodGoals.prefix(2)))
        #expect(!partlyNew.failed.contains { $0.kind == .freshGoals })
    }

    @Test func relaxedSkipsTheActionCheck() {
        let draft = ReflectionDraft(goalTexts: ["A quiet morning with coffee", "Coffee with the team"], reflection: Self.standardReflection)
        let verdict = ReflectionRubric(strictness: .relaxed).evaluate(draft)
        #expect(!verdict.checks.contains { $0.kind == .goalAction })
        #expect(verdict.isApproved, "failed: \(verdict.failed.map(\.title))")
    }

    @Test(arguments: [
        ("Run 5k at 6 PM", true),
        ("Finish the PRD before lunch", true),
        ("Read two chapters tonight", true),
        ("Call Mom", false),
        ("Clean the kitchen", false),
    ])
    func measurableGoals(goal: String, expected: Bool) {
        #expect(TextMetrics.isMeasurable(goal) == expected)
    }

    @Test func realProsePasses() {
        #expect(TextMetrics.looksLikeProse(Self.standardReflection))
        #expect(TextMetrics.looksLikeProse("Hoy importa porque el documento desbloquea todo lo demás y llevo una semana dándole vueltas."))
    }
}
