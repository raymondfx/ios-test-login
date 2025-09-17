//
//  LoyaltyPointsApp.swift
//  LoyaltyPoints
//
//  Created by Raymond Korir on 16/09/2025.
//

import SwiftUI

@main
struct LoyaltyPointsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
