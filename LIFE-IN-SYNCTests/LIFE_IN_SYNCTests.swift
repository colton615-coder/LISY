//
//  LIFE_IN_SYNCTests.swift
//  LIFE-IN-SYNCTests
//
//  Created by Colton Thomas on 3/31/26.
//

import Foundation
import Testing
@testable import LIFE_IN_SYNC

struct LIFE_IN_SYNCTests {
    @Test func habitModelStoresIdentityAndTarget() async throws {
        let habit = Habit(name: "Water", targetCount: 8)

        #expect(habit.name == "Water")
        #expect(habit.targetCount == 8)
        #expect(habit.id.uuidString.isEmpty == false)
    }

    @Test func taskModelDefaultsToOpenMediumPriority() async throws {
        let task = TaskItem(title: "Call bank")

        #expect(task.isCompleted == false)
        #expect(task.priority == TaskPriority.medium.rawValue)
        #expect(task.id.uuidString.isEmpty == false)
    }

    @Test func studyEntryStoresNotes() async throws {
        let entry = StudyEntry(title: "Morning Study", passageReference: "Psalm 1", notes: "Meditate on the contrast.")

        #expect(entry.title == "Morning Study")
        #expect(entry.passageReference == "Psalm 1")
        #expect(entry.notes == "Meditate on the contrast.")
    }

    @Test func swingRecordStoresOptionalMediaAndNotes() async throws {
        let record = SwingRecord(title: "Driver session", mediaFilename: "swing.mov", notes: "Ball started left.")

        #expect(record.mediaFilename == "swing.mov")
        #expect(record.notes == "Ball started left.")
    }
}
