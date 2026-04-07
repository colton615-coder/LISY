//
//  LIFE_IN_SYNCUITests.swift
//  LIFE-IN-SYNCUITests
//
//  Created by Colton Thomas on 3/31/26.
//

import XCTest

final class LIFE_IN_SYNCUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testModuleMenuShowsCanonicalModules() throws {
        let app = XCUIApplication()
        app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
        app.launch()

        app.buttons["open-module-menu"].tap()

        let habitStackEntry = app.descendants(matching: .any)["module-menu-habitStack"]
        let taskProtocolEntry = app.descendants(matching: .any)["module-menu-taskProtocol"]
        let calendarEntry = app.descendants(matching: .any)["module-menu-calendar"]
        let supplyListEntry = app.descendants(matching: .any)["module-menu-supplyList"]

        XCTAssertTrue(app.navigationBars["Modules"].waitForExistence(timeout: 2))
        scrollToElementIfNeeded(supplyListEntry, in: app)

        XCTAssertTrue(habitStackEntry.waitForExistence(timeout: 2))
        XCTAssertTrue(taskProtocolEntry.exists)
        XCTAssertTrue(calendarEntry.exists)
        XCTAssertTrue(supplyListEntry.exists)
    }

    @MainActor
    func testDashboardNavigatesToCalendarFromDashboardRow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
        app.launch()

        app.buttons["dashboard-module-calendar"].tap()

        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["return-to-dashboard"].exists)
    }

    @MainActor
    func testDashboardShowsTodaySnapshotCards() throws {
        let app = XCUIApplication()
        app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
        app.launch()

        let habitsCard = app.descendants(matching: .any)["dashboard-stat-habits"]
        let tasksCard = app.descendants(matching: .any)["dashboard-stat-tasks"]
        let eventsCard = app.descendants(matching: .any)["dashboard-stat-events"]
        let itemsCard = app.descendants(matching: .any)["dashboard-stat-items"]

        scrollToElementIfNeeded(habitsCard, in: app)

        XCTAssertTrue(habitsCard.waitForExistence(timeout: 2))
        XCTAssertTrue(tasksCard.exists)
        XCTAssertTrue(eventsCard.exists)
        XCTAssertTrue(itemsCard.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
            app.launch()
        }
    }
}

private extension LIFE_IN_SYNCUITests {
    func scrollToElementIfNeeded(_ element: XCUIElement, in app: XCUIApplication, maxScrolls: Int = 6) {
        guard element.exists == false else { return }

        for _ in 0..<maxScrolls {
            app.swipeUp()

            if element.waitForExistence(timeout: 0.5) {
                return
            }
        }
    }
}
