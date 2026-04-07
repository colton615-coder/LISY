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

        XCTAssertTrue(app.navigationBars["Modules"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["module-menu-habitStack"].exists)
        XCTAssertTrue(app.buttons["module-menu-taskProtocol"].exists)
        XCTAssertTrue(app.buttons["module-menu-calendar"].exists)
        XCTAssertTrue(app.buttons["module-menu-supplyList"].exists)
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

        XCTAssertTrue(app.staticTexts["Habits"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Tasks"].exists)
        XCTAssertTrue(app.staticTexts["Events"].exists)
        XCTAssertTrue(app.staticTexts["Items"].exists)
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
