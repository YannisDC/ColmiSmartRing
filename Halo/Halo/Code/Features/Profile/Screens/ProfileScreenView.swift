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
            try deleteAll(StoredSleepPeriod.self)
            try deleteAll(StoredSleepDay.self)
            try deleteAll(StoredHeartRateLog.self)
            try deleteAll(StoredActivitySample.self)
            try deleteAll(StoredHRVSample.self)
            try deleteAll(StoredBloodOxygenSample.self)
            try deleteAll(StoredStressSample.self)
            try modelContext.save()
        } catch {
            print("Failed to delete local SwiftData: \(error)")
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
    }
}
