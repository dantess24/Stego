//
//  StegoApp.swift
//  Stego
//
//  Created by Сергей Андрианов on 18.09.2026.
//

import SwiftUI
import CoreData

@main
struct StegoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
