import XCTest

/// Walks the first morning end to end in the Simulator, where the mock Screen Time gateway stands in for the real one:
/// onboarding, hitting the bar too early, writing goals and a reflection, and unlocking the day.
final class DaybreakUITests: XCTestCase {
    private let reflection = "Today matters because the scope document unblocks the whole build and I have been circling it for a week. I keep opening Instagram before I have a plan so the plan comes first. If the run happens at six I will sleep better tonight and the gym stops being a source of guilt."

    @MainActor
    func testFirstMorningEndToEnd() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()

        // S1: Welcome → the mock grants access after a short delay.
        let allow = app.buttons["Allow Screen Time access"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5), "Welcome screen should offer the authorization button")
        allow.tap()

        // S2: The system picker. In the Simulator it lists little or nothing; Continue is allowed regardless.
        let continueButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Continue'")).firstMatch
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10), "App picker screen should appear after authorization")
        continueButton.tap()

        // S3: Start time.
        let start = app.buttons["Start the schedule"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // S4: Today. Before or after the default 7:00 start, one of the two buttons opens the form.
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), "Onboarding should end on Today")
        let write = app.buttons["Write today's goals"]
        let early = app.buttons["Reflect early"]
        if write.waitForExistence(timeout: 2) {
            write.tap()
        } else {
            XCTAssertTrue(early.waitForExistence(timeout: 2), "Today should offer a way into the form")
            early.tap()
        }

        // S5: Tapping Done on an empty form must not unlock; it lists what is missing.
        let done = app.buttons["Done reflecting"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.staticTexts["Write 3 goals for today."].waitForExistence(timeout: 3), "An empty form should explain the first fix")
        XCTAssertFalse(app.staticTexts["Unlocked for today"].exists)

        let goals = [
            "Finish the Daybreak PRD before lunch",
            "Run 5k at 6 PM after work",
            "Call Mom about the weekend plans",
        ]
        for (index, goal) in goals.enumerated() {
            let field = app.textFields["goal-\(index + 1)"]
            XCTAssertTrue(field.waitForExistence(timeout: 3), "Goal row \(index + 1) should exist")
            field.tap()
            field.typeText(goal)
        }

        let editor = app.textViews["reflection"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText(reflection)

        XCTAssertTrue(app.staticTexts["Clears the bar"].waitForExistence(timeout: 5), "A complete draft should clear the standard bar")
        done.tap()

        // S6: Today, cleared.
        XCTAssertTrue(app.staticTexts["Unlocked for today"].waitForExistence(timeout: 5), "Done reflecting should unlock the day")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Finish the'")).firstMatch.exists, "Today should list the approved goals")

        // The entry is in the Journal.
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1-day streak'")).firstMatch.waitForExistence(timeout: 5))
    }
}
