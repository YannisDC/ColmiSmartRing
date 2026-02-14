//
//  Packet.swift
//  Halo
//
//  Created by Yannis De Cleene on 25/01/2025.
//

import Foundation

func makePacket(command: UInt8, subData: [UInt8]? = nil) throws -> [UInt8] {
    // Ensure the command is between 0 and 255
    guard command <= 255 else {
        throw PacketError.invalidCommand
    }

    // Initialize a 16-byte packet filled with zeros
    var packet = [UInt8](repeating: 0, count: 16)
    packet[0] = command

    // Validate and copy subData into the packet if provided
    if let subData = subData {
        guard subData.count <= 14 else {
            throw PacketError.invalidSubDataLength
        }
        for (index, byte) in subData.enumerated() {
            packet[index + 1] = byte
        }
    }

    // Calculate and set the checksum (last byte of the packet)
    packet[15] = checksum(packet: packet)

    return packet
}

func checksum(packet: [UInt8]) -> UInt8 {
    // Use `UInt` to safely handle summation without overflow
    let sum = packet.reduce(0) { (result, byte) in
        result + UInt(byte)
    }
    return UInt8(sum % 255)
}

/// Settings/Commands protocol: 16-byte packet with [commandId, action, data[13], crc].
/// CRC = (commandId + sum of the 13 data bytes) & 0xFF.
func makeSettingsPacket(commandId: UInt8, action: UInt8, data: [UInt8]) throws -> [UInt8] {
    guard data.count == 13 else {
        throw PacketError.invalidSubDataLength
    }
    var packet = [UInt8](repeating: 0, count: 16)
    packet[0] = commandId
    packet[1] = action
    for (i, b) in data.enumerated() {
        packet[2 + i] = b
    }
    var sum = UInt(commandId)
    for i in 2..<15 { sum += UInt(packet[i]) }
    packet[15] = UInt8(sum & 0xFF)
    return packet
}

// Custom errors for validation
enum PacketError: Error {
    case invalidCommand
    case invalidSubDataLength
}
