//
//  RingSessionManager.swift
//  Halo
//
//  Created by Yannis De Cleene on 27/01/2025.
//

import Foundation
import CoreBluetooth
import SwiftUI

/// Settings-protocol tracking toggles (READ/WRITE isEnabled) shared by HRV, Heart Rate, Blood Oxygen, Pressure.
enum RingTrackingSetting: CaseIterable {
    case hrv           // command 56
    case heartRate     // command 22
    case bloodOxygen   // command 44
    case pressure      // command 54 (Stress)

    var commandId: UInt8 {
        switch self {
        case .hrv: return 56
        case .heartRate: return 22
        case .bloodOxygen: return 44
        case .pressure: return 54
        }
    }

    /// Maps response commandId back to setting; nil if not a tracking-setting command.
    init?(commandId: UInt8) {
        switch commandId {
        case 56: self = .hrv
        case 22: self = .heartRate
        case 44: self = .bloodOxygen
        case 54: self = .pressure
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .hrv: return "HRV"
        case .heartRate: return "Heart Rate"
        case .bloodOxygen: return "Blood Oxygen"
        case .pressure: return "Pressure (Stress)"
        }
    }
}

private let savedRingIdentifierKey = "savedRingIdentifier"
private let savedRingDisplayNameKey = "savedRingDisplayName"
private let preferredDataTimeZoneIdentifierKey = "preferredDataTimeZoneIdentifier"

@Observable
class RingSessionManager: NSObject {
    var peripheralConnected = false
    /// Latest battery info reported by the ring.
    var currentBatteryInfo: BatteryInfo?
    /// True when we have a saved ring but no peripheral and are scanning for it.
    var isScanningForRing = false
    /// Peripherals found during "Add ring" scan (name starts with R02_).
    var discoveredPeripherals: [CBPeripheral] = []
    /// True when scanning for ring to add (discovery list).
    var isDiscovering = false

    /// Persisted ring identifier for reconnection; nil if no ring has been added. Stored so @Observable updates the UI when set in didConnect.
    var savedRingIdentifier: UUID? {
        didSet {
            if let id = savedRingIdentifier {
                UserDefaults.standard.set(id.uuidString, forKey: savedRingIdentifierKey)
            } else {
                UserDefaults.standard.removeObject(forKey: savedRingIdentifierKey)
                UserDefaults.standard.removeObject(forKey: savedRingDisplayNameKey)
            }
        }
    }
    /// Display name for the ring (from BLE peripheral name).
    var ringDisplayName: String? {
        didSet {
            if let n = ringDisplayName {
                UserDefaults.standard.set(n, forKey: savedRingDisplayNameKey)
            } else {
                UserDefaults.standard.removeObject(forKey: savedRingDisplayNameKey)
            }
        }
    }

    /// Time zone used when building day-based request timestamps (e.g. heart-rate history).
    var preferredDataTimeZoneIdentifier: String {
        didSet {
            UserDefaults.standard.set(preferredDataTimeZoneIdentifier, forKey: preferredDataTimeZoneIdentifierKey)
        }
    }

    var preferredDataTimeZone: TimeZone {
        TimeZone(identifier: preferredDataTimeZoneIdentifier) ?? .current
    }

    private let manager = CBCentralManager(delegate: nil, queue: nil)
    private var peripheral: CBPeripheral?

    private static let scanTimeout: TimeInterval = 15
    private var scanWorkItem: DispatchWorkItem?

    /// Interval between keepalive packets to avoid BLE idle disconnect (e.g. 45–60 s).
    private static let keepaliveInterval: TimeInterval = 45
    private var keepaliveWorkItem: DispatchWorkItem?

    private var uartRxCharacteristic: CBCharacteristic?
    private var uartTxCharacteristic: CBCharacteristic?
    private var colmiWriteCharacteristic: CBCharacteristic?
    private var colmiNotifyCharacteristic: CBCharacteristic?

    private static let ringServiceUUID = SmartRingBLE.nordicUARTServiceUUID
    private static let colmiServiceUUID = SmartRingBLE.colmiServiceUUID
    private static let colmiWriteUUID = SmartRingBLE.colmiWriteUUID
    private static let colmiNotifyUUID = SmartRingBLE.colmiNotifyUUID
    private static let uartRxCharacteristicUUID = SmartRingBLE.nordicUARTTxUUID
    private static let uartTxCharacteristicUUID = SmartRingBLE.nordicUARTRxUUID

    private static let deviceInfoServiceUUID = SmartRingBLE.deviceInfoServiceUUID
    private static let deviceHardwareUUID = SmartRingBLE.hardwareRevisionCharUUID
    private static let deviceFirmwareUUID = SmartRingBLE.firmwareRevisionCharUUID

    private static let CMD_BLINK_TWICE: UInt8 = 16 // 0x10
    private static let CMD_BATTERY: UInt8 = 3
    private static let CMD_READ_HEART_RATE: UInt8 = 21  // 0x15
    /// Heart Rate setting (Settings protocol): READ/WRITE isEnabled. ID: 22.
    private static let CMD_HEART_RATE_SETTING: UInt8 = 22
    /// Pressure/Stress setting (Settings protocol): READ/WRITE isEnabled. ID: 54.
    private static let CMD_PRESSURE: UInt8 = 54
    /// Pressure/Stress historical data request (Commands protocol, split array).
    private static let CMD_READ_PRESSURE_DATA: UInt8 = 55
    /// HRV setting (Settings protocol): READ/WRITE isEnabled. ID: 56.
    private static let CMD_HRV: UInt8 = 56
    /// HRV historical data request (Commands protocol, split array).
    private static let CMD_READ_HRV_DATA: UInt8 = 57
    /// Sports/activity historical data request (steps, calories, distance).
    private static let CMD_READ_ACTIVITY_DATA: UInt8 = 67
    /// Sleep Data (Colmi BLE API: https://colmi.puxtril.com/commands/#sleep-data) – request/response use ID 68
    private static let CMD_SLEEP_DATA: UInt8 = 68
    /// Legacy Big Data syncHistoricalSleep; some firmware may use 0xBC 0x27
    private static let CMD_SYNC_SLEEP_LEGACY: UInt8 = 188 // 0xBC

    private static let CMD_START_REAL_TIME: UInt8 = 105
    private static let CMD_STOP_REAL_TIME: UInt8 = 106
    
    
    private static let CMD_BLOOD_OXYGEN: UInt8 = 44
    

    private let hrp = HeartRateLogParser()

    private var characteristicsDiscovered = false

    var batteryStatusCallback: ((BatteryInfo) -> Void)?
    var heartRateLogCallback: ((HeartRateLog) -> Void)?
    /// Called with each raw sleep response packet (16 bytes) for debugging / future parsing
    var sleepPacketCallback: (([UInt8]) -> Void)?
    /// Called when sleep data (command 68) is received; dayOffset is the requested day (0 = today).
    var sleepDataCallback: ((SleepData) -> Void)?
    /// Called when Big Data sleep (dataId 39) is received from Colmi service.
    var bigDataSleepCallback: ((BigDataSleepData) -> Void)?
    /// Always-on callback intended for persistence layer when Big Data sleep is received.
    var bigDataSleepPersistenceCallback: ((BigDataSleepData) -> Void)?
    /// Called when Big Data blood oxygen payload (dataId 42) is received.
    var bigDataBloodOxygenPayloadCallback: (([UInt8]) -> Void)?
    /// Always-on callback intended for persistence layer when Big Data blood oxygen payload is received.
    var bigDataBloodOxygenPayloadPersistenceCallback: (([UInt8]) -> Void)?
    /// Called with each raw HRV data packet (command 57).
    var hrvDataPacketCallback: (([UInt8]) -> Void)?
    /// Always-on callback intended for persistence layer for HRV packets.
    var hrvDataPacketPersistenceCallback: (([UInt8]) -> Void)?
    /// Called with each raw pressure/stress data packet (command 55).
    var pressureDataPacketCallback: (([UInt8]) -> Void)?
    /// Always-on callback intended for persistence layer for pressure packets.
    var pressureDataPacketPersistenceCallback: (([UInt8]) -> Void)?
    /// Called with each raw activity data packet (command 67).
    var activityDataPacketCallback: (([UInt8]) -> Void)?
    /// Always-on callback intended for persistence layer for activity packets.
    var activityDataPacketPersistenceCallback: (([UInt8]) -> Void)?
    /// Always-on callback intended for persistence layer when a heart-rate log is parsed.
    var heartRateLogPersistenceCallback: ((HeartRateLog) -> Void)?
    /// Called when the ring is connected and UART characteristics are ready; use this to trigger tracking-settings reads.
    var onReadyForSettingsQuery: (() -> Void)?
    /// Single callback or continuation for any in-flight tracking setting READ; cleared after use.
    private var pendingTrackingSetting: RingTrackingSetting?
    private var pendingTrackingSettingCallback: ((Bool) -> Void)?
    private var pendingTrackingSettingContinuation: CheckedContinuation<Bool, Error>?
    /// Last requested dayOffset for sleep (0 = today); used when parsing response 68.
    private var lastSleepDayOffset: Int = 0
    /// Big Data notify buffer (variable-length responses may arrive in chunks).
    private var bigDataBuffer: [UInt8] = []
    private static let bigDataMagic: UInt8 = 188
    private static let bigDataSleepId: UInt8 = 39
    private static let bigDataBloodOxygenId: UInt8 = 42

    // MARK: - Debug log (for Debug tab)
    struct DebugLogEntry: Identifiable {
        let id = UUID()
        let date: Date
        let direction: Direction
        let bytes: [UInt8]
        enum Direction: String { case sent = "→ Sent"; case received = "← Received" }
    }
    private static let debugLogMaxEntries = 300
    var debugLog: [DebugLogEntry] = []

    override init() {
        if let s = UserDefaults.standard.string(forKey: savedRingIdentifierKey), let id = UUID(uuidString: s) {
            self.savedRingIdentifier = id
            self.ringDisplayName = UserDefaults.standard.string(forKey: savedRingDisplayNameKey)
        } else {
            self.savedRingIdentifier = nil
            self.ringDisplayName = nil
        }
        if let tz = UserDefaults.standard.string(forKey: preferredDataTimeZoneIdentifierKey),
           TimeZone(identifier: tz) != nil {
            self.preferredDataTimeZoneIdentifier = tz
        } else {
            self.preferredDataTimeZoneIdentifier = TimeZone.current.identifier
        }
        super.init()
        manager.delegate = self
    }

    // MARK: - RingSessionManager actions

    /// Start BLE discovery for Colmi ring (by name prefix R02_). Results go to discoveredPeripherals.
    func startDiscovery() {
        stopDiscovery()
        discoveredPeripherals = []
        isDiscovering = true
        if manager.state == .poweredOn {
            actuallyStartScan()
        }
    }

    func stopDiscovery() {
        guard isDiscovering else { return }
        scanWorkItem?.cancel()
        scanWorkItem = nil
        if manager.state == .poweredOn {
            manager.stopScan()
        }
        isDiscovering = false
    }

    private func actuallyStartScan() {
        guard manager.state == .poweredOn else { return }
        manager.scanForPeripherals(withServices: nil, options: nil)
        scanWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.stopDiscovery()
        }
        scanWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanTimeout, execute: item)
    }

    /// Connect to a discovered peripheral and save it as the ring (persist identifier).
    func connectAndSaveRing(peripheral p: CBPeripheral) {
        guard manager.state == .poweredOn else { return }
        if p.state == .connected || p.state == .connecting {
            return
        }
        stopDiscovery()
        p.delegate = self
        peripheral = p
        manager.connect(p, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
        ])
    }

    func removeRing() {
        stopDiscovery()
        stopScanningForRing()
        if peripheralConnected {
            disconnect()
        }
        peripheral = nil
        savedRingIdentifier = nil
        ringDisplayName = nil
    }

    /// Reconnect: connect if we have a peripheral reference, otherwise try retrieve then scan by name.
    func findRingAgain() {
        guard savedRingIdentifier != nil else { return }
        if peripheralConnected { return }
        if let peripheral {
            connect()
        } else if manager.state == .poweredOn {
            if let id = savedRingIdentifier,
               let known = manager.retrievePeripherals(withIdentifiers: [id]).first {
                peripheral = known
                known.delegate = self
                connect()
            } else {
                startScanningForRing()
            }
        }
    }

    private func startScanningForRing() {
        guard manager.state == .poweredOn, peripheral == nil, savedRingIdentifier != nil else { return }
        scanWorkItem?.cancel()
        isScanningForRing = true
        manager.scanForPeripherals(withServices: nil, options: nil)
        let item = DispatchWorkItem { [weak self] in
            self?.stopScanningForRing()
        }
        scanWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanTimeout, execute: item)
    }

    private func stopScanningForRing() {
        guard isScanningForRing else { return }
        scanWorkItem?.cancel()
        scanWorkItem = nil
        if manager.state == .poweredOn {
            manager.stopScan()
        }
        isScanningForRing = false
    }

    func connect() {
        guard manager.state == .poweredOn, let peripheral else { return }
        manager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionStartDelayKey: 1
        ])
    }

    func disconnect() {
        guard let peripheral, manager.state == .poweredOn else { return }
        manager.cancelPeripheralConnection(peripheral)
    }

    /// Append a line to the debug log (used by Debug tab). Keeps last N entries.
    func appendToDebugLog(direction: DebugLogEntry.Direction, bytes: [UInt8]) {
        let entry = DebugLogEntry(date: Date(), direction: direction, bytes: bytes)
        debugLog.append(entry)
        if debugLog.count > Self.debugLogMaxEntries {
            debugLog.removeFirst(debugLog.count - Self.debugLogMaxEntries)
        }
    }

    /// Send a raw command packet and log it. Payload is optional (up to 14 bytes). Packet is 16 bytes with checksum.
    func sendDebugCommand(command: UInt8, subData: [UInt8]? = nil) {
        do {
            let packet = try makePacket(command: command, subData: subData)
            appendToDebugLog(direction: .sent, bytes: packet)
            sendPacket(packet: packet)
        } catch {
            appendToDebugLog(direction: .sent, bytes: [command])
        }
    }

    func clearDebugLog() {
        debugLog = []
        debugLogEntryTags = [:]
    }

    /// Tags for log entries (entry id → set of tag strings). Multiple tags per entry.
    var debugLogEntryTags: [UUID: Set<String>] = [:]

    func addTag(forEntryId id: UUID, tag: String) {
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        debugLogEntryTags[id, default: []].insert(t)
    }

    func removeTag(forEntryId id: UUID, tag: String) {
        debugLogEntryTags[id]?.remove(tag)
        if debugLogEntryTags[id]?.isEmpty == true {
            debugLogEntryTags.removeValue(forKey: id)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension RingSessionManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        debugPrint("Central manager state: \(central.state)")
        switch central.state {
        case .poweredOn:
            if isDiscovering {
                actuallyStartScan()
            } else if let id = savedRingIdentifier {
                if let known = central.retrievePeripherals(withIdentifiers: [id]).first {
                    debugPrint("Found previously connected peripheral")
                    peripheral = known
                    peripheral?.delegate = self
                    connect()
                } else {
                    debugPrint("Known peripheral not found, starting scan")
                    startScanningForRing()
                }
            }
        default:
            peripheral = nil
            stopScanningForRing()
            stopDiscovery()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        if isDiscovering {
            guard name.hasPrefix(SmartRingBLE.deviceNamePrefix) else { return }
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(peripheral)
            }
            return
        }
        if isScanningForRing, peripheral.identifier == savedRingIdentifier {
            stopScanningForRing()
            self.peripheral = peripheral
            peripheral.delegate = self
            central.connect(peripheral, options: [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                CBConnectPeripheralOptionStartDelayKey: 1
            ])
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScanningForRing()
        if peripheralConnected {
            return
        }
        if savedRingIdentifier == nil {
            savedRingIdentifier = peripheral.identifier
            ringDisplayName = peripheral.name ?? "COLMI R02 Ring"
        }
        debugPrint("DEBUG: Connected to peripheral: \(peripheral)")
        peripheral.delegate = self
        debugPrint("DEBUG: Discovering services...")
        peripheral.discoverServices([
            CBUUID(string: Self.ringServiceUUID),
            CBUUID(string: Self.deviceInfoServiceUUID),
            CBUUID(string: Self.colmiServiceUUID)
        ])
        peripheralConnected = true
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        debugPrint("Disconnected from peripheral: \(peripheral)")
        peripheralConnected = false
        characteristicsDiscovered = false
        stopKeepalive()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        debugPrint("Failed to connect to peripheral: \(peripheral), error: \(error.debugDescription)")
    }
}

// MARK: - CBPeripheralDelegate
extension RingSessionManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        debugPrint("DEBUG: Services discovery callback, error: \(String(describing: error))")
        guard error == nil, let services = peripheral.services else {
            debugPrint("DEBUG: No services found or error occurred")
            return
        }
        
        debugPrint("DEBUG: Found \(services.count) services")
        for service in services {
            switch service.uuid {
            case CBUUID(string: Self.ringServiceUUID):
                debugPrint("DEBUG: Found ring service, discovering characteristics...")
                peripheral.discoverCharacteristics([
                    CBUUID(string: Self.uartRxCharacteristicUUID),
                    CBUUID(string: Self.uartTxCharacteristicUUID)
                ], for: service)
            case CBUUID(string: Self.deviceInfoServiceUUID):
                debugPrint("DEBUG: Found device info service")
            case CBUUID(string: Self.colmiServiceUUID):
                debugPrint("DEBUG: Found Colmi Big Data service, discovering characteristics...")
                peripheral.discoverCharacteristics([
                    CBUUID(string: Self.colmiWriteUUID),
                    CBUUID(string: Self.colmiNotifyUUID)
                ], for: service)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debugPrint("DEBUG: Characteristics discovery callback, error: \(String(describing: error))")
        guard error == nil, let characteristics = service.characteristics else {
            debugPrint("DEBUG: No characteristics found or error occurred")
            return
        }
        
        debugPrint("DEBUG: Found \(characteristics.count) characteristics")
        for characteristic in characteristics {
            switch characteristic.uuid {
            case CBUUID(string: Self.uartRxCharacteristicUUID):
                debugPrint("DEBUG: Found UART RX characteristic")
                self.uartRxCharacteristic = characteristic
            case CBUUID(string: Self.uartTxCharacteristicUUID):
                debugPrint("DEBUG: Found UART TX characteristic")
                self.uartTxCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case CBUUID(string: Self.colmiWriteUUID):
                debugPrint("DEBUG: Found Colmi Big Data write characteristic")
                self.colmiWriteCharacteristic = characteristic
            case CBUUID(string: Self.colmiNotifyUUID):
                debugPrint("DEBUG: Found Colmi Big Data notify characteristic")
                self.colmiNotifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                debugPrint("DEBUG: Found other characteristic: \(characteristic.uuid)")
            }
        }
        let wasReady = characteristicsDiscovered
        characteristicsDiscovered = (uartRxCharacteristic != nil && uartTxCharacteristic != nil)
        if characteristicsDiscovered && !wasReady {
            syncOnConnect()
            startKeepalive()
            DispatchQueue.main.async { [weak self] in
                self?.onReadyForSettingsQuery?()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else {
            debugPrint("Failed to read characteristic value: \(String(describing: error))")
            return
        }
        
        let packet = [UInt8](value)

        if characteristic.uuid == CBUUID(string: Self.colmiNotifyUUID) {
            appendToDebugLog(direction: .received, bytes: packet)
            processBigDataChunk(packet)
            debugPrint(packet)
            return
        }

        if characteristic.uuid == CBUUID(string: Self.uartTxCharacteristicUUID) {
            appendToDebugLog(direction: .received, bytes: packet)
        }
        
        switch packet[0] {
        case RingSessionManager.CMD_BATTERY:
            handleBatteryResponse(packet: packet)
        case RingSessionManager.CMD_READ_HEART_RATE:
            handleHeartRateLogResponse(packet: packet)
        case Counter.shared.CMD_X:
            debugPrint("🔥")
        case RingSessionManager.CMD_START_REAL_TIME:
            let readingType = RealTimeReading(rawValue: packet[1]) ?? .heartRate
            let errorCode = packet[2]
            
            if errorCode == 0 {
                let readingValue = packet[3]
                debugPrint("Real-Time Reading - Type: \(readingType), Value: \(readingValue)")
            } else {
                debugPrint("Error in reading - Type: \(readingType), Error Code: \(errorCode)")
            }
        case RingSessionManager.CMD_SLEEP_DATA:
            handleSleepDataResponse(packet: packet)
        case RingSessionManager.CMD_SYNC_SLEEP_LEGACY:
            handleSleepResponse(packet: packet)
        case RingSessionManager.CMD_READ_HRV_DATA:
            handleHRVDataResponse(packet: packet)
        case RingSessionManager.CMD_READ_PRESSURE_DATA:
            handlePressureDataResponse(packet: packet)
        case RingSessionManager.CMD_READ_ACTIVITY_DATA:
            handleActivityDataResponse(packet: packet)
        case RingSessionManager.CMD_HRV,
             RingSessionManager.CMD_HEART_RATE_SETTING,
             RingSessionManager.CMD_BLOOD_OXYGEN,
             RingSessionManager.CMD_PRESSURE:
            handleTrackingSettingResponse(packet: packet)
        default:
            // Log unhandled opcodes so we can identify sleep/other response formats
            debugPrint("Unhandled response opcode: \(packet[0]) (0x\(String(format: "%02x", packet[0]))) – full packet: \(packet)")
            break
        }
        
        if characteristic.uuid == CBUUID(string: Self.uartTxCharacteristicUUID) {
            if let value = characteristic.value {
                debugPrint("Received value: \(value) : \([UInt8](value))")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            debugPrint("Write to characteristic failed: \(error.localizedDescription)")
        } else {
            debugPrint("Write to characteristic successful")
        }
    }
}

// MARK: - BlinkTwice

extension RingSessionManager {
    func sendBlinkTwiceCommand() {
        do {
            let blinkTwicePacket = try makePacket(command: RingSessionManager.CMD_BLINK_TWICE, subData: nil)
            appendToDebugLog(direction: .sent, bytes: blinkTwicePacket)
            sendPacket(packet: blinkTwicePacket)
        } catch {
            debugPrint("Failed to create blink twice packet: \(error)")
        }
    }
}

// MARK: - Big Data (Colmi service)

extension RingSessionManager {
    static func makeBigDataRequestPacket(dataId: UInt8) -> [UInt8] {
        [
            Self.bigDataMagic,
            dataId,
            0, 0,       // dataLen = 0 (LE)
            0xFF, 0xFF  // crc16 = 0xFFFF (LE)
        ]
    }

    static func parseBigDataResponsePacket(_ packet: [UInt8]) -> (dataId: UInt8, dataLen: Int, crc16: UInt16, payload: [UInt8])? {
        let headerLen = 6
        guard packet.count >= headerLen, packet[0] == Self.bigDataMagic else { return nil }
        let dataId = packet[1]
        let dataLen = Int(packet[2]) | (Int(packet[3]) << 8)
        let crc16 = UInt16(packet[4]) | (UInt16(packet[5]) << 8)
        guard dataLen >= 0, packet.count == headerLen + dataLen else { return nil }
        let payload = Array(packet.dropFirst(headerLen))
        return (dataId: dataId, dataLen: dataLen, crc16: crc16, payload: payload)
    }

    /// Send a Big Data request on the Colmi service. Request: magic 188, dataId, dataLen=0, crc16=0xFFFF.
    func sendBigDataRequest(dataId: UInt8) {
        guard let colmiWriteCharacteristic, let peripheral else {
            debugPrint("Cannot send Big Data request. Colmi write characteristic or peripheral not ready.")
            return
        }
        let request = Self.makeBigDataRequestPacket(dataId: dataId)
        let data = Data(request)
        peripheral.writeValue(data, for: colmiWriteCharacteristic, type: .withResponse)
        appendToDebugLog(direction: .sent, bytes: request)
        debugPrint("Big Data request sent – dataId: \(dataId), command: \(request)")
    }

    private func processBigDataChunk(_ chunk: [UInt8]) {
        bigDataBuffer.append(contentsOf: chunk)
        let headerLen = 6
        while bigDataBuffer.count >= 6 {
            guard bigDataBuffer[0] == Self.bigDataMagic else {
                bigDataBuffer.removeFirst()
                continue
            }
            let dataId = bigDataBuffer[1]
            let dataLen = Int(bigDataBuffer[2]) | (Int(bigDataBuffer[3]) << 8)
            let packetLen = headerLen + dataLen
            guard dataLen >= 0, bigDataBuffer.count >= packetLen else { break }

            // CRC16 is little-endian in the Big Data header (currently informational).
            let _ = UInt16(bigDataBuffer[4]) | (UInt16(bigDataBuffer[5]) << 8)
            let payload = Array(bigDataBuffer.dropFirst(headerLen).prefix(dataLen))
            bigDataBuffer.removeFirst(packetLen)
            handleBigDataResponse(dataId: dataId, payload: payload)
        }
    }

    private func handleBigDataResponse(dataId: UInt8, payload: [UInt8]) {
        switch dataId {
        case Self.bigDataSleepId:
            if let sleepData = BigDataSleepParser.parseSleepPayload(payload) {
                debugPrint("Big Data sleep received – \(sleepData.sleepDays) day(s)")
                bigDataSleepCallback?(sleepData)
                bigDataSleepPersistenceCallback?(sleepData)
            } else {
                debugPrint("Big Data sleep parse failed – payload length: \(payload.count)")
            }
        case Self.bigDataBloodOxygenId:
            debugPrint("Big Data blood oxygen received – payload length: \(payload.count)")
            bigDataBloodOxygenPayloadCallback?(payload)
            bigDataBloodOxygenPayloadPersistenceCallback?(payload)
        default:
            debugPrint("Big Data response – dataId: \(dataId), payload length: \(payload.count)")
        }
    }
}

// MARK: - Keepalive

extension RingSessionManager {
    /// Start sending periodic keepalives (e.g. battery request) so the BLE link doesn't drop from idle timeout.
    func startKeepalive() {
        stopKeepalive()
        scheduleNextKeepalive()
    }

    func stopKeepalive() {
        keepaliveWorkItem?.cancel()
        keepaliveWorkItem = nil
    }

    private func scheduleNextKeepalive() {
        let item = DispatchWorkItem { [weak self] in
            self?.sendKeepalive()
        }
        keepaliveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.keepaliveInterval, execute: item)
    }

    private func sendKeepalive() {
        keepaliveWorkItem = nil
        guard peripheralConnected, characteristicsDiscovered else { return }
        do {
            let packet = try makePacket(command: Self.CMD_BATTERY)
            appendToDebugLog(direction: .sent, bytes: packet)
            sendPacket(packet: packet)
        } catch {
            debugPrint("Keepalive packet failed: \(error)")
        }
        scheduleNextKeepalive()
    }
}

// MARK: - Sync on connect

extension RingSessionManager {
    /// Runs when the app has connected to the ring and discovered characteristics. Requests battery, sleep (Big Data), and heart rate log with staggered delays.
    func syncOnConnect() {
        debugPrint("Sync on connect: starting…")
        getBatteryStatus { _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.syncSleep(dayOffset: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.getHeartRateLog { _ in }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.syncHRVData(dayOffset: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            self?.syncBloodOxygen(dayOffset: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.syncPressureData(dayOffset: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { [weak self] in
            self?.syncActivityData(dayOffset: 0)
        }
    }
}

// MARK: - Sleep sync

extension RingSessionManager {
    /// Request sleep data via Colmi Big Data service (dataId 39). Preferred for rings that support it.
    func syncSleep(dayOffset: Int = 0) {
        lastSleepDayOffset = dayOffset
        sendBigDataRequest(dataId: Self.bigDataSleepId)
    }

    /// Request sleep from Nordic UART Commands protocol (ID 68). Use if Big Data sleep is not supported.
    func syncSleepCommands(dayOffset: Int = 0) {
        do {
            let packet = try makePacket(command: Self.CMD_SLEEP_DATA, subData: [
                UInt8(dayOffset & 0xFF),
                15,
                0,
                95
            ])
            lastSleepDayOffset = dayOffset
            appendToDebugLog(direction: .sent, bytes: packet)
            sendPacket(packet: packet)
            debugPrint("Sleep data requested (Commands 68, dayOffset: \(dayOffset))")
        } catch {
            debugPrint("Failed to create sleep packet: \(error)")
        }
    }

    /// Legacy: request sleep via Big Data style 0xBC 0x27 on Nordic UART (use for firmware that doesn’t support command 68).
    func syncSleepLegacy() {
        do {
            let packet = try makePacket(command: Self.CMD_SYNC_SLEEP_LEGACY, subData: [0x27])
            appendToDebugLog(direction: .sent, bytes: packet)
            sendPacket(packet: packet)
            debugPrint("Sleep sync (legacy 0xBC 0x27) requested")
        } catch {
            debugPrint("Failed to create legacy sleep packet: \(error)")
        }
    }

    private func handleSleepDataResponse(packet: [UInt8]) {
        // SleepDataResponse: commandId=68, year, month, day, time, sleepQualities, unused[3], crc
        guard packet.count >= 6, packet[0] == Self.CMD_SLEEP_DATA else { return }
        let year = Int(packet[1])
        let month = Int(packet[2])
        let day = Int(packet[3])
        let time = packet[4]
        let sleepQualities = packet[5]
        let data = SleepData(
            year: year,
            month: month,
            day: day,
            time: time,
            sleepQualities: sleepQualities,
            dayOffset: lastSleepDayOffset
        )
        debugPrint("Sleep data received – date: \(year + 2000)-\(month)-\(day), time: \(time), qualities: \(sleepQualities)")
        sleepDataCallback?(data)
    }

    private func handleSleepResponse(packet: [UInt8]) {
        guard packet.count >= 2 else { return }
        let subType = packet[1]
        debugPrint("Sleep packet (legacy 0xBC) – subType: \(subType) (0x\(String(format: "%02x", subType))), full: \(packet)")
        sleepPacketCallback?(packet)
        if subType == 255 {
            debugPrint("Sleep: no data (ring returned 0xFF subtype)")
        }
    }

    /// Request HRV historical data (Commands protocol, ID 57). dayOffset uses index field.
    func syncHRVData(dayOffset: Int = 0) {
        do {
            let packet = try makePacket(command: Self.CMD_READ_HRV_DATA, subData: [UInt8(dayOffset & 0xFF)])
            appendToDebugLog(direction: .sent, bytes: packet)
            sendPacket(packet: packet)
            debugPrint("HRV data requested (Commands 57, dayOffset/index: \(dayOffset))")
        } catch {
            debugPrint("Failed to create HRV packet: \(error)")
        }
    }

    /// Request pressure/stress historical data (Commands protocol, ID 55). dayOffset uses index field.
    func syncPressureData(dayOffset: Int = 0) {
        do {
            let packet = try makePacket(command: Self.CMD_READ_PRESSURE_DATA, subData: [UInt8(dayOffset & 0xFF)])
            appendToDebugLog(direction: .sent, bytes: packet)
            sendPacket(packet: packet)
            debugPrint("Pressure data requested (Commands 55, dayOffset/index: \(dayOffset))")
        } catch {
            debugPrint("Failed to create pressure packet: \(error)")
        }
    }

    /// Request activity data (steps/calories/distance) via Sports Data (Commands protocol, ID 67).
    func syncActivityData(dayOffset: Int = 0) {
        do {
            let packet = try makePacket(command: Self.CMD_READ_ACTIVITY_DATA, subData: [
                UInt8(dayOffset & 0xFF),
                15,
                0,
                95
            ])
            appendToDebugLog(direction: .sent, bytes: packet)
            sendPacket(packet: packet)
            debugPrint("Activity data requested (Commands 67, dayOffset: \(dayOffset))")
        } catch {
            debugPrint("Failed to create activity packet: \(error)")
        }
    }

    /// Request blood oxygen historical data via Big Data (dataId 42).
    func syncBloodOxygen(dayOffset: Int = 0) {
        _ = dayOffset // dataId 42 request itself does not include dayOffset in request header.
        sendBigDataRequest(dataId: Self.bigDataBloodOxygenId)
    }

    private func handleHRVDataResponse(packet: [UInt8]) {
        guard packet.count >= 2 else { return }
        hrvDataPacketCallback?(packet)
        hrvDataPacketPersistenceCallback?(packet)
    }

    private func handlePressureDataResponse(packet: [UInt8]) {
        guard packet.count >= 2 else { return }
        pressureDataPacketCallback?(packet)
        pressureDataPacketPersistenceCallback?(packet)
    }

    private func handleActivityDataResponse(packet: [UInt8]) {
        guard packet.count >= 2 else { return }
        activityDataPacketCallback?(packet)
        activityDataPacketPersistenceCallback?(packet)
    }
    
    func sendPacket(packet: [UInt8]) {
        guard let uartRxCharacteristic, let peripheral else {
            debugPrint("Cannot send packet. Peripheral or characteristic not ready.")
            return
        }
        
        let data = Data(packet)
        peripheral.writeValue(data, for: uartRxCharacteristic, type: .withResponse)
    }
}

// MARK: - RealTime Streaming

extension RingSessionManager {
    //    CMD_REAL_TIME_HEART_RATE = 30
    //    CONTINUE_HEART_RATE_PACKET = make_packet(CMD_REAL_TIME_HEART_RATE, bytearray(b"3"))
    
    func startRealTimeStreaming(type: RealTimeReading) {
        sendRealTimeCommand(command: RingSessionManager.CMD_START_REAL_TIME, type: type, action: .start)
    }
    
    func continueRealTimeStreaming(type: RealTimeReading) {
        sendRealTimeCommand(command: RingSessionManager.CMD_START_REAL_TIME, type: type, action: .continue)
    }
    
    func stopRealTimeStreaming(type: RealTimeReading) {
        sendRealTimeCommand(command: RingSessionManager.CMD_STOP_REAL_TIME, type: type, action: nil)
    }
    
    private func sendRealTimeCommand(command: UInt8, type: RealTimeReading, action: Action?) {
        guard let uartRxCharacteristic, let peripheral else {
            debugPrint("Cannot send real-time command. Peripheral or characteristic not ready.")
            return
        }
        
        var packetData: [UInt8] = [type.rawValue]
        if let action = action {
            packetData.append(action.rawValue)
        } else {
            packetData.append(contentsOf: [0, 0])
        }
        
        do {
            let packet = try makePacket(command: command, subData: packetData)
            let data = Data(packet)
            peripheral.writeValue(data, for: uartRxCharacteristic, type: .withResponse)
        } catch {
            debugPrint("Failed to create packet: \(error)")
        }
    }
}

// MARK: - Battery Status

extension RingSessionManager {
    func getBatteryStatus(completion: @escaping (BatteryInfo) -> Void) {
        guard let uartRxCharacteristic, let peripheral else {
            debugPrint("Cannot send battery request. Peripheral or characteristic not ready.")
            return
        }
        
        do {
            let packet = try makePacket(command: RingSessionManager.CMD_BATTERY)
            let data = Data(packet)
            peripheral.writeValue(data, for: uartRxCharacteristic, type: .withResponse)
            
            // Store completion handler to call when data is received
            self.batteryStatusCallback = completion
        } catch {
            debugPrint("Failed to create battery packet: \(error)")
        }
    }
    
    private func handleBatteryResponse(packet: [UInt8]) {
        guard packet[0] == RingSessionManager.CMD_BATTERY else {
            debugPrint("Invalid battery packet received.")
            return
        }
        
        let batteryLevel = Int(packet[1])
        let charging = packet[2] != 0
        let batteryInfo = BatteryInfo(batteryLevel: batteryLevel, charging: charging)
        currentBatteryInfo = batteryInfo
        
        // Trigger stored callback with battery info
        batteryStatusCallback?(batteryInfo)
        batteryStatusCallback = nil
    }
}

// MARK: - Tracking settings (Settings protocol: HRV, Heart Rate, Blood Oxygen, Pressure)

private let settingsActionRead: UInt8 = 1
private let settingsActionWrite: UInt8 = 2

enum RingSessionTrackingError: Error {
    case notConnected
}

extension RingSessionManager {
    /// Request current enabled state for one tracking setting (Settings protocol READ).
    func getTrackingSetting(_ setting: RingTrackingSetting, completion: @escaping (Bool) -> Void) {
        pendingTrackingSetting = setting
        pendingTrackingSettingCallback = completion
        sendSettingRead(commandId: setting.commandId)
    }

    /// Read one tracking setting from the ring (async); throws if not connected or send fails.
    func readTrackingSetting(_ setting: RingTrackingSetting) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            guard uartRxCharacteristic != nil, peripheral != nil else {
                continuation.resume(throwing: RingSessionTrackingError.notConnected)
                return
            }
            pendingTrackingSetting = setting
            pendingTrackingSettingContinuation = continuation
            sendSettingRead(commandId: setting.commandId)
        }
    }

    /// Write one tracking setting to the ring (async); throws if not connected or send fails.
    func writeTrackingSetting(_ setting: RingTrackingSetting, enabled: Bool) async throws {
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            guard uartRxCharacteristic != nil, peripheral != nil else {
                continuation.resume(throwing: RingSessionTrackingError.notConnected)
                return
            }
            pendingTrackingSetting = setting
            pendingTrackingSettingContinuation = continuation
            sendSettingWrite(commandId: setting.commandId, isEnabled: enabled)
        }
    }

    private func handleTrackingSettingResponse(packet: [UInt8]) {
        guard packet.count >= 3 else { return }
        let setting = RingTrackingSetting(commandId: packet[0])
        guard let setting, setting == pendingTrackingSetting else { return }
        let isEnabled = packet[2] != 0
        if let continuation = pendingTrackingSettingContinuation {
            pendingTrackingSettingContinuation = nil
            pendingTrackingSetting = nil
            continuation.resume(returning: isEnabled)
        } else {
            pendingTrackingSettingCallback?(isEnabled)
            pendingTrackingSetting = nil
            pendingTrackingSettingCallback = nil
        }
    }

    private func sendSettingRead(commandId: UInt8) {
        guard let uartRxCharacteristic, let peripheral else {
            debugPrint("Cannot send settings request. Peripheral or characteristic not ready.")
            return
        }
        do {
            let data = [UInt8](repeating: 0, count: 13)
            let packet = try makeSettingsPacket(commandId: commandId, action: settingsActionRead, data: data)
            appendToDebugLog(direction: .sent, bytes: packet)
            peripheral.writeValue(Data(packet), for: uartRxCharacteristic, type: .withResponse)
        } catch {
            debugPrint("Failed to create settings packet: \(error)")
        }
    }

    private func sendSettingWrite(commandId: UInt8, isEnabled: Bool) {
        guard let uartRxCharacteristic, let peripheral else {
            debugPrint("Cannot send settings write. Peripheral or characteristic not ready.")
            return
        }
        do {
            var data = [UInt8](repeating: 0, count: 13)
            data[0] = isEnabled ? 1 : 0
            let packet = try makeSettingsPacket(commandId: commandId, action: settingsActionWrite, data: data)
            appendToDebugLog(direction: .sent, bytes: packet)
            peripheral.writeValue(Data(packet), for: uartRxCharacteristic, type: .withResponse)
        } catch {
            debugPrint("Failed to create settings write packet: \(error)")
        }
    }
}

// MARK: - Heart Rate Log

extension RingSessionManager {
    private func dayStartInPreferredTimeZone(for base: Date = Date(), dayOffset: Int = 0) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = preferredDataTimeZone
        let start = calendar.startOfDay(for: base)
        guard dayOffset != 0 else { return start }
        return calendar.date(byAdding: .day, value: -dayOffset, to: start)
    }

    func getHeartRateLog(completion: @escaping (HeartRateLog) -> Void) {
        guard let uartRxCharacteristic, let peripheral else {
            debugPrint("Cannot send heart rate log request. Peripheral or characteristic not ready.")
            return
        }
        
        do {
            guard let target = dayStartInPreferredTimeZone(for: Date.now, dayOffset: 0) else {
                return
            }
            let packet = try readHeartRatePacket(for: target)
            let data = Data(packet)
            peripheral.writeValue(data, for: uartRxCharacteristic, type: .withResponse)
            
            debugPrint("HRL Commmand Sent")
            
            // Store completion handler to call when data is received
            self.heartRateLogCallback = completion
        } catch {
            debugPrint("Failed to create hrl packet: \(error)")
        }
    }
    
    private func handleHeartRateLogResponse(packet: [UInt8]) {
        guard packet[0] == RingSessionManager.CMD_READ_HEART_RATE else {
            debugPrint("Invalid heart rate log packet received.")
            return
        }
        
        guard let log = hrp.parse(packet: packet) as? HeartRateLog else {
            return
        }
        heartRateLogPersistenceCallback?(log)
        heartRateLogCallback?(log)
        heartRateLogCallback = nil
    }
}

// MARK: - X

extension RingSessionManager {
    func sendXCommand() {
        do {
            let xPacket = try makePacket(command: Counter.shared.CMD_X, subData: nil)
            sendPacket(packet: xPacket)
        } catch {
            debugPrint("Failed to create blink twice packet: \(error)")
        }
    }
}
