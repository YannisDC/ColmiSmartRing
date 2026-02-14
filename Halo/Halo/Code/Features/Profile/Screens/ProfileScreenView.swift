import SwiftUI
import SwiftData

struct ProfileScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ringSessionManager: RingSessionManager
    @State private var showDeleteAllDataConfirmation = false
    @State private var showAddRingSheet = false

    private var dataTimeZoneOptions: [String] {
        let options = [
            TimeZone.current.identifier,
            "UTC",
            "Europe/Brussels",
            "Europe/London",
            "America/New_York",
            "America/Los_Angeles",
            "Asia/Tokyo",
            "Asia/Shanghai",
            "Asia/Dubai",
            "Australia/Sydney"
        ]
        let unique = Array(Set(options)).sorted()
        if unique.contains(ringSessionManager.preferredDataTimeZoneIdentifier) {
            return unique
        }
        return (unique + [ringSessionManager.preferredDataTimeZoneIdentifier]).sorted()
    }

    private var selectedTimeZoneDisplay: String {
        let tz = ringSessionManager.preferredDataTimeZone
        let hours = tz.secondsFromGMT() / 3600
        let sign = hours >= 0 ? "+" : ""
        return "\(tz.identifier) (UTC\(sign)\(hours))"
    }

    var body: some View {
        NavigationStack {
            List {
                DeviceSectionView(ringSessionManager: ringSessionManager, showAddRingSheet: $showAddRingSheet)
                BatterySectionView(ringSessionManager: ringSessionManager)
                TrackingSettingsSectionView(ringSessionManager: ringSessionManager)
                Section("Data Timezone") {
                    Picker("Timezone", selection: $ringSessionManager.preferredDataTimeZoneIdentifier) {
                        ForEach(dataTimeZoneOptions, id: \.self) { id in
                            Text(id).tag(id)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(selectedTimeZoneDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showDeleteAllDataConfirmation = true
                    } label: {
                        Label("Delete all local data", systemImage: "trash")
                    }
                }

                Section(L10n.Profile.debugSectionTitle) {
                    NavigationLink(destination: DebugView(ringSessionManager: ringSessionManager)) {
                        Label(L10n.Debug.navTitle, systemImage: "wrench.and.screwdriver.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.Tab.profile)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddRingSheet) {
                AddRingSheetView(ringSessionManager: ringSessionManager, isPresented: $showAddRingSheet)
            }
            .onChange(of: ringSessionManager.savedRingIdentifier) { _, newId in
                if newId != nil {
                    showAddRingSheet = false
                }
            }
            .alert("Delete all local data?", isPresented: $showDeleteAllDataConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllLocalSwiftData()
                }
            } message: {
                Text("This will permanently remove all synced sleep, heart rate, activity, HRV, blood oxygen, and stress data stored on this device.")
            }
        }
    }

    private func deleteAllLocalSwiftData() {
        do {
            let deletedSleepPeriods = try deleteAll(StoredSleepPeriod.self)
            let deletedSleepDays = try deleteAll(StoredSleepDay.self)
            let deletedHeartRateLogs = try deleteAll(StoredHeartRateLog.self)
            let deletedActivity = try deleteAll(StoredActivitySample.self)
            let deletedHRV = try deleteAll(StoredHRVSample.self)
            let deletedBloodOxygen = try deleteAll(StoredBloodOxygenSample.self)
            let deletedStress = try deleteAll(StoredStressSample.self)

            debugPrint("======= SWIFTDATA SAVE: Delete All =======")
            debugPrint("deleted StoredSleepPeriod: \(deletedSleepPeriods)")
            debugPrint("deleted StoredSleepDay: \(deletedSleepDays)")
            debugPrint("deleted StoredHeartRateLog: \(deletedHeartRateLogs)")
            debugPrint("deleted StoredActivitySample: \(deletedActivity)")
            debugPrint("deleted StoredHRVSample: \(deletedHRV)")
            debugPrint("deleted StoredBloodOxygenSample: \(deletedBloodOxygen)")
            debugPrint("deleted StoredStressSample: \(deletedStress)")
            try modelContext.save()
            debugPrint("result: SUCCESS")
            debugPrint("==========================================")
        } catch {
            debugPrint("Failed to delete local SwiftData: \(error)")
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws -> Int {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
        return items.count
    }
}
