//
//  SmartRingBLE.swift
//  Halo
//

import Foundation

/// Reference: device info and service/characteristic UUIDs for the Colmi R02 ring.
enum SmartRingBLE {
    // MARK: - Device info (scanner)
    static let deviceNamePrefix = "R02_"
    static let manufacturerName = "Bluex"
    static let modelNumber = "BX-BLE-5.0"
    static let hardwareRevision = "R02_V3.0"
    static let firmwareRevisionPrefix = "R02_3.00"

    // MARK: - Nordic UART (primary – used by app)
    /// Service: Nordic UART Service (NUS) – command/response channel.
    static let nordicUARTServiceUUID = "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E"
    /// Characteristic: Write / Write without Response → send commands to ring.
    static let nordicUARTTxUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    /// Characteristic: Notify → receive data from ring.
    static let nordicUARTRxUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    // MARK: - Colmi Big Data service (newer protocol)
    /// Service: Big Data – variable-length requests/responses (sleep, SpO2, etc.).
    static let colmiServiceUUID = "DE5BF728-D711-4E47-AF26-65E3012A5DC7"
    /// Write characteristic – send BigDataRequest (magic 188, dataId, dataLen=0, crc16=0xFFFF).
    static let colmiWriteUUID = "DE5BF72A-D711-4E47-AF26-65E3012A5DC7"
    /// Notify characteristic – receive BigDataResponse (variable length).
    static let colmiNotifyUUID = "DE5BF729-D711-4E47-AF26-65E3012A5DC7"

    // MARK: - Standard device info (GATT 0x180A)
    static let deviceInfoServiceUUID = "0000180A-0000-1000-8000-00805F9B34FB"
    static let hardwareRevisionCharUUID = "00002A27-0000-1000-8000-00805F9B34FB"
    static let firmwareRevisionCharUUID = "00002A26-0000-1000-8000-00805F9B34FB"
}
