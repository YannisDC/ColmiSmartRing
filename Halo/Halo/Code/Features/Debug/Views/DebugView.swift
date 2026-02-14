//
//  DebugView.swift
//  Halo
//
//  Debug feature: send raw commands, sync sleep variants, response log with tags.
//

import SwiftUI

enum DebugByteFormat: String, CaseIterable {
    case hex = "Hex"
    case decimal = "Decimal"
}

struct DebugView: View {
    @Bindable var ringSessionManager: RingSessionManager
    @State private var commandText = "43"
    @State private var payloadHex = ""
    @AppStorage("debugByteFormat") private var byteFormat: DebugByteFormat = .hex

    private var commandValue: UInt8? {
        guard let n = Int(commandText.trimmingCharacters(in: .whitespaces)), n >= 0, n <= 255 else { return nil }
        return UInt8(n)
    }

    private var payloadBytes: [UInt8]? {
        let s = payloadHex.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
        guard s.count.isMultiple(of: 2), !s.isEmpty else {
            if payloadHex.isEmpty { return [] }
            return nil
        }
        var bytes: [UInt8] = []
        var index = s.startIndex
        while index < s.endIndex {
            let next = s.index(index, offsetBy: 2, limitedBy: s.endIndex) ?? s.endIndex
            guard let b = UInt8(s[index..<next], radix: 16) else { return nil }
            bytes.append(b)
            index = next
        }
        return bytes
    }

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.Debug.sendCommandSection) {
                    HStack {
                        Text(L10n.Debug.commandLabel)
                        TextField(L10n.Debug.commandPlaceholder, text: $commandText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L10n.Debug.payloadLabel)
                        TextField(L10n.Debug.payloadPlaceholder, text: $payloadHex)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                    }
                    Button {
                        sendCommand()
                    } label: {
                        Label(L10n.Debug.sendButton, systemImage: "arrow.up.circle.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.semibold))
                    }
                    .disabled(commandValue == nil || (payloadHex.isEmpty == false && payloadBytes == nil) || !ringSessionManager.peripheralConnected)
                }

                Section(L10n.Debug.sleepSection) {
                    Button {
                        ringSessionManager.syncSleep()
                    } label: {
                        Label(L10n.Debug.syncSleepBigData, systemImage: "bed.double.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!ringSessionManager.peripheralConnected)
                    Button {
                        ringSessionManager.syncSleepCommands(dayOffset: 0)
                    } label: {
                        Label(L10n.Debug.syncSleepToday, systemImage: "bed.double.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!ringSessionManager.peripheralConnected)
                    Button {
                        ringSessionManager.syncSleepCommands(dayOffset: 1)
                    } label: {
                        Label(L10n.Debug.syncSleepYesterday, systemImage: "bed.double.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!ringSessionManager.peripheralConnected)
                    Button {
                        ringSessionManager.syncSleepLegacy()
                    } label: {
                        Label(L10n.Debug.syncSleepLegacy, systemImage: "bed.double")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!ringSessionManager.peripheralConnected)
                }

                Section {
                    Picker(L10n.Debug.showBytesAs, selection: $byteFormat) {
                        Text(L10n.Debug.byteFormatHex).tag(DebugByteFormat.hex)
                        Text(L10n.Debug.byteFormatDecimal).tag(DebugByteFormat.decimal)
                    }
                    .pickerStyle(.segmented)
                    Button(role: .destructive) {
                        ringSessionManager.clearDebugLog()
                    } label: {
                        Label(L10n.Debug.clearLog, systemImage: "trash")
                    }
                } header: {
                    Text(L10n.Debug.logHeader)
                } footer: {
                    Text(L10n.Debug.logFooter(ringSessionManager.debugLog.count))
                }

                Section(L10n.Debug.responseLogSection) {
                    if ringSessionManager.debugLog.isEmpty {
                        Text(L10n.Debug.noEntriesYet)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(ringSessionManager.debugLog.reversed()) { entry in
                            DebugLogEntryRow(
                                entry: entry,
                                manager: ringSessionManager,
                                byteFormat: byteFormat,
                                bytesFormatted: bytesFormatted(entry.bytes)
                            )
                        }
                    }
                }
            }
            .navigationTitle(L10n.Debug.navTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sendCommand() {
        guard let cmd = commandValue else { return }
        if payloadHex.isEmpty {
            ringSessionManager.sendDebugCommand(command: cmd, subData: nil)
        } else if let payload = payloadBytes {
            ringSessionManager.sendDebugCommand(command: cmd, subData: payload)
        }
    }

    private func bytesFormatted(_ bytes: [UInt8]) -> String {
        switch byteFormat {
        case .hex:
            return bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        case .decimal:
            return bytes.map { String($0) }.joined(separator: " ")
        }
    }
}

// MARK: - Log entry row with tags
private struct DebugLogEntryRow: View {
    let entry: RingSessionManager.DebugLogEntry
    @Bindable var manager: RingSessionManager
    let byteFormat: DebugByteFormat
    let bytesFormatted: String

    @State private var newTagText = ""
    @FocusState private var isTagFieldFocused: Bool

    private var tags: [String] {
        (manager.debugLogEntryTags[entry.id] ?? []).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.direction.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(entry.direction == .sent ? .blue : .green)
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(bytesFormatted)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)

            if !tags.isEmpty || isTagFieldFocused || !newTagText.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagPill(text: tag) {
                            manager.removeTag(forEntryId: entry.id, tag: tag)
                        }
                    }
                    HStack(spacing: 4) {
                        TextField(L10n.Debug.addTagPlaceholder, text: $newTagText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .focused($isTagFieldFocused)
                            .onSubmit {
                                if !newTagText.isEmpty {
                                    manager.addTag(forEntryId: entry.id, tag: newTagText)
                                    newTagText = ""
                                }
                            }
                        if !newTagText.isEmpty {
                            Button {
                                manager.addTag(forEntryId: entry.id, tag: newTagText)
                                newTagText = ""
                            } label: { Image(systemName: "plus.circle.fill") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } else {
                Button {
                    isTagFieldFocused = true
                } label: {
                    Label(L10n.Debug.addTag, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tag pill
private struct TagPill: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption2)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.2))
        .clipShape(Capsule())
    }
}

// MARK: - Flow layout for tags
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

#Preview {
    DebugView(ringSessionManager: RingSessionManager())
}
