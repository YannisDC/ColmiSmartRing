import SwiftUI

struct MetricsScreenView: View {
    @Bindable var ringSessionManager: RingSessionManager

    var body: some View {
        ReadingsGraphsView(ringSessionManager: ringSessionManager, includeActivitySection: false)
    }
}
