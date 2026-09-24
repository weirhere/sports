import Foundation
import Testing
import UserNotifications
@testable import StatSide

// E12's second door (2026-09-24): "Pin to Lock Screen" on the kickoff
// reminder, offered only where the pin could work.

@Suite struct KickoffReminderActionsTests {
    @Test func offeredOnlyWhenTheFeatureAndTheSettingAreBothOn() {
        #expect(KickoffReminderActions.offersPin(isAvailable: true, activitiesEnabled: true))
        #expect(!KickoffReminderActions.offersPin(isAvailable: false, activitiesEnabled: true))
        #expect(!KickoffReminderActions.offersPin(isAvailable: true, activitiesEnabled: false))
    }

    @Test func theCategoryCarriesThePinOnlyWhenOffered() throws {
        let on = try #require(KickoffReminderActions.categories(offersPin: true).first)
        #expect(on.identifier == KickoffReminderActions.categoryId)
        #expect(on.actions.map(\.identifier) == [KickoffReminderActions.pinActionId])
        #expect(on.actions.first?.options.contains(.foreground) == true)

        // Without the pin the reminder is exactly what it was.
        let off = try #require(KickoffReminderActions.categories(offersPin: false).first)
        #expect(off.identifier == KickoffReminderActions.categoryId)
        #expect(off.actions.isEmpty)
    }

    @Test func aPlainTapOpensTheGameWithoutAPin() throws {
        let intent = try #require(KickoffReminderActions.intent(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: ["gameId": "401"]))
        #expect(intent.gameId == "401")
        #expect(!intent.pin)
    }

    @Test func thePinActionAsksForThePin() throws {
        let intent = try #require(KickoffReminderActions.intent(
            actionIdentifier: KickoffReminderActions.pinActionId,
            userInfo: ["gameId": "401"]))
        #expect(intent.pin)
    }

    @Test func aResponseNamingNoGameIsIgnored() {
        #expect(KickoffReminderActions.intent(actionIdentifier: KickoffReminderActions.pinActionId,
                                              userInfo: [:]) == nil)
    }
}
