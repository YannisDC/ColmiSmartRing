import SwiftUI
import SwiftData

/// Backward-compatible wrapper that now maps to the Home screen.
struct ContentView: View {
    @Bindable var ringSessionManager: RingSessionManager

    var body: some View {
        HomeScreenView(ringSessionManager: ringSessionManager)
    }
}

#Preview {
    ContentView(ringSessionManager: RingSessionManager())
        .modelContainer(for: [StoredSleepDay.self, StoredSleepPeriod.self, StoredHeartRateLog.self], inMemory: true)
}
