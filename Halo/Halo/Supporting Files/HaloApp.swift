//
//  HaloApp.swift
//  Halo
//
//  Created by Yannis De Cleene on 20/01/2025.
//

import SwiftUI
import SwiftData

@main
struct HaloApp: App {
    @State private var ringSessionManager = RingSessionManager()
    @State private var ringDataPersistenceCoordinator: RingDataPersistenceCoordinator?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StoredSleepDay.self,
            StoredSleepPeriod.self,
            StoredHeartRateLog.self,
            StoredActivitySample.self,
            StoredHRVSample.self,
            StoredBloodOxygenSample.self,
            StoredStressSample.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeScreenView(ringSessionManager: ringSessionManager)
                    .tabItem { Label(L10n.Tab.home, systemImage: "house.fill") }
                ActivityScreenView()
                    .tabItem { Label(L10n.Tab.activity, systemImage: "figure.walk") }
                MetricsScreenView(ringSessionManager: ringSessionManager)
                    .tabItem { Label(L10n.Tab.metrics, systemImage: "heart.text.square.fill") }
                ProfileScreenView(ringSessionManager: ringSessionManager)
                    .tabItem { Label(L10n.Tab.profile, systemImage: "person.crop.circle.fill") }
            }
            .onAppear {
                if ringDataPersistenceCoordinator == nil {
                    let coordinator = RingDataPersistenceCoordinator(
                        modelContext: sharedModelContainer.mainContext,
                        ringSessionManager: ringSessionManager
                    )
                    coordinator.start()
                    ringDataPersistenceCoordinator = coordinator
                    debugPrint("[AutoPersist] RingDataPersistenceCoordinator started")
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
