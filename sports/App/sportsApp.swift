//
//  sportsApp.swift
//  sports
//
//  Created by Andy Weir on 7/20/26.
//

import SwiftUI
import UserNotifications

@main
struct sportsApp: App {
    @State private var router: Router
    @State private var reviewPrompt: ReviewPrompt
    private let notificationDelegate: NotificationDelegate

    init() {
        AppGroup.migrateFollowingIfNeeded()
        // Must run after the App Group copy: it reads the suite's bare keys.
        AppGroup.migrateLeagueNamespacingIfNeeded()
        let router = Router()
        let review = ReviewPrompt()
        let delegate = NotificationDelegate(router: router, reviewPrompt: review)
        _router = State(initialValue: router)
        _reviewPrompt = State(initialValue: review)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }

    var body: some Scene {
        WindowGroup {
            RootView(router: router, reviewPrompt: reviewPrompt)
        }
    }
}
