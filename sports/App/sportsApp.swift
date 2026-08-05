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
    private let notificationDelegate: NotificationDelegate

    init() {
        AppGroup.migrateFollowingIfNeeded()
        let router = Router()
        let delegate = NotificationDelegate(router: router)
        _router = State(initialValue: router)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }

    var body: some Scene {
        WindowGroup {
            RootView(router: router)
        }
    }
}
