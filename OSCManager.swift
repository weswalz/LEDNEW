//
//  OSCManager.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/23/25.
//

import Foundation
import Network
import SwiftUI

@Observable
final class OSCManager {
    // MARK: - Properties
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "OSCManagerQueue")
    
    // Updated for Resolume Arena
    private let targetHost = NWEndpoint.Host("127.0.0.1") // Or use the iPad's/machine's IP
    private let targetPort = NWEndpoint.Port(integerLiteral: 2269) // Updated to Resolume Arena port
    
    // Clip rotation system
    private var currentClipIndex = 0
    private let clipRotation = [4, 5, 6, 7, 8]
    private let clearClip = 9
    private let defaultLayer = 5
    
    // Connection state
    var isConnected = false
    
    // MARK: - Initialization
    
    init() {
        setupConnection()
    }
    
    // MARK: - Connection Management
    
    private func setupConnection() {
        connection = NWConnection(host: targetHost, port: targetPort, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                print("✅ OSC UDP connection ready to Resolume Arena")
                self.isConnected = true
            case .failed(let error):
                print("❌ OSC connection failed: \(error)")
                self.isConnected = false
                // Attempt reconnection after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.setupConnection()
                }
            case .waiting(let error):
                print("⌛️ Waiting to reconnect: \(error)")
                self.isConnected = false
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    // MARK: - OSC Message Sending
    
    /// Send a basic OSC-style address with a float/int/string payload
    func send(address: String, value: Any) {
        guard let connection = connection else { return }
        
        let oscPacket = buildOSCPacket(address: address, value: value)
        
        connection.send(content: oscPacket, completion: .contentProcessed({ error in
            if let error = error {
                print("❌ OSC send error: \(error)")
            } else {
                print("📡 Sent OSC: \(address) \(value)")
            }
        }))
    }
    
    /// Send text to Resolume using the next clip in rotation
    func sendTextToResolume(text: String) {
        let clipNumber = getNextClipNumber()
        
        // First, send the text content to the text generator
        let textAddress = "/composition/layers/\(defaultLayer)/clips/\(clipNumber)/video/source/textgenerator/text/params/lines"
        send(address: textAddress, value: text)
        
        // Then trigger the clip
        let connectAddress = "/composition/layers/\(defaultLayer)/clips/\(clipNumber)/connect"
        send(address: connectAddress, value: 1)
        
        print("🔄 Using clip \(clipNumber) in rotation")
    }
    
    /// Clear the screen by triggering the clear clip
    func clearScreen() {
        let connectAddress = "/composition/layers/\(defaultLayer)/clips/\(clearClip)/connect"
        send(address: connectAddress, value: 1)
        print("🧹 Clearing screen using clip \(clearClip)")
    }
    
    // MARK: - Helper Methods
    
    private func buildOSCPacket(address: String, value: Any) -> Data {
        var packet = Data()
        
        // OSC address
        packet.append(oscString(address))
        
        // Type tag string
        let typeTag: String
        let payload: Data
        
        switch value {
        case let int as Int:
            typeTag = ",i"
            payload = withUnsafeBytes(of: Int32(int).bigEndian) { Data($0) }
            
        case let float as Float:
            typeTag = ",f"
            payload = withUnsafeBytes(of: float.bitPattern.bigEndian) { Data($0) }
            
        case let string as String:
            typeTag = ",s"
            // Ensure proper text formatting and newline handling
            let formattedString = formatTextForResolume(string)
            payload = oscString(formattedString)
            
        default:
            typeTag = ",s"
            payload = oscString("unsupported")
        }
        
        packet.append(oscString(typeTag))
        packet.append(payload)
        
        return packet
    }
    
    /// Format text for Resolume, ensuring proper newline handling
    private func formatTextForResolume(_ text: String) -> String {
        // Preserve newlines and ensure proper formatting
        // This handles any special formatting requirements for Resolume
        return text
    }
    
    private func oscString(_ string: String) -> Data {
        var data = string.data(using: .utf8) ?? Data()
        data.append(0) // Null terminator
        
        // OSC strings must be null-terminated and padded to 4-byte boundary
        while data.count % 4 != 0 {
            data.append(0)
        }
        
        return data
    }
    
    /// Get the next clip number in the rotation sequence
    private func getNextClipNumber() -> Int {
        let clipNumber = clipRotation[currentClipIndex]
        
        // Move to the next index, wrapping around if necessary
        currentClipIndex = (currentClipIndex + 1) % clipRotation.count
        
        return clipNumber
    }
    
    deinit {
        connection?.cancel()
        print("🛑 OSCManager deinitialized")
    }
}