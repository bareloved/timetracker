// LoomTests/AppUsageBarTests.swift
import Testing
import Foundation
@testable import Loom

@Suite("AppUsageBar Logic")
struct AppUsageBarTests {

    // MARK: - Test data helpers

    private func app(_ name: String, _ seconds: TimeInterval) -> AppUsage {
        AppUsage(appName: name, duration: seconds)
    }

    // MARK: - Grouping

    @Test("Apps above 2% threshold are kept individually")
    func appsAboveThreshold() {
        let apps = [
            app("iTerm2", 1620),
            app("Brave", 660),
            app("Xcode", 480),
            app("Finder", 360),
            app("WhatsApp", 120),
        ]
        let items = AppUsageBarView.groupedItems(from: apps, totalDuration: 3240)
        #expect(items.count == 5)
        #expect(items[0].label == "iTerm2")
        #expect(items[1].label == "Brave")
    }

    @Test("Apps below 2% are grouped into Other")
    func smallAppsGrouped() {
        let apps = [
            app("iTerm2", 1620),
            app("Brave", 660),
            app("Xcode", 480),
            app("Finder", 360),
            app("Loom", 30),
            app("WhatsApp", 20),
            app("TextEdit", 10),
        ]
        let items = AppUsageBarView.groupedItems(from: apps, totalDuration: 3180)
        #expect(items.count == 5)
        #expect(items.last?.label == "Other")
        #expect(items.last?.duration == 60)
    }

    @Test("When all apps are below 2%, show all individually instead of one big Other")
    func allSmallAppsShownIndividually() {
        let apps = [
            app("App1", 10),
            app("App2", 8),
            app("App3", 6),
        ]
        let items = AppUsageBarView.groupedItems(from: apps, totalDuration: 6000)
        #expect(items.count == 3)
        #expect(items.first?.label == "App1")
        #expect(!items.contains { $0.label == "Other" })
    }

    @Test("Items are sorted by duration descending")
    func sortedByDuration() {
        let apps = [
            app("Small", 100),
            app("Big", 500),
            app("Medium", 300),
        ]
        let items = AppUsageBarView.groupedItems(from: apps, totalDuration: 900)
        #expect(items[0].label == "Big")
        #expect(items[1].label == "Medium")
        #expect(items[2].label == "Small")
    }

    // MARK: - Color assignment

    @Test("Colors cycle through palette by duration rank")
    func colorAssignment() {
        let apps = [
            app("First", 500),
            app("Second", 300),
            app("Third", 100),
        ]
        let items = AppUsageBarView.groupedItems(from: apps, totalDuration: 900)
        #expect(items[0].color == AppUsageBarView.appPalette[0])
        #expect(items[1].color == AppUsageBarView.appPalette[1])
        #expect(items[2].color == AppUsageBarView.appPalette[2])
    }

    @Test("Other segment gets the dedicated Other color")
    func otherColor() {
        let apps = [
            app("Big", 500),
            app("Tiny1", 5),
            app("Tiny2", 3),
        ]
        let items = AppUsageBarView.groupedItems(from: apps, totalDuration: 508)
        let other = items.first { $0.label == "Other" }
        #expect(other != nil)
        #expect(other?.color == AppUsageBarView.otherColor)
    }

    // MARK: - Zero duration edge case

    @Test("Zero total duration produces equal-width items with no Other grouping")
    func zeroDuration() {
        let apps = [
            app("App1", 0),
            app("App2", 0),
        ]
        let items = AppUsageBarView.groupedItems(from: apps, totalDuration: 0)
        #expect(items.count == 2)
        #expect(items[0].proportion == 0.5)
        #expect(items[1].proportion == 0.5)
    }

    // MARK: - Empty apps

    @Test("Empty app list produces no items")
    func emptyApps() {
        let items = AppUsageBarView.groupedItems(from: [], totalDuration: 100)
        #expect(items.isEmpty)
    }
}
