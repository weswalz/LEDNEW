//
//  OSCManager.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/23/25.
//

import Foundation
import Network
import SwiftUI

// Change from @Observable to ObservableObject to work with StateObject
@MainActor
final class OSCManager: ObservableObject {
    // MARK: - Properties
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "OSCManagerQueue")
    
    // Updated for Resolume Arena
    private let targetPort = NWEndpoint.Port(integerLiteral: 2269) // Updated to Resolume Arena port
    
    // Clip rotation system
    private var currentClipIndex = 0
    private var clipRotation: [Int] = []
    private var clearClip: Int = 0
    private var defaultLayer: Int = 5
    
    // Message configuration
    var useTableNumber: Bool = true
    var tableNumberLabel: String = "Table Number"
    var timeoutMinutes: Double = 5.0
    var forceCaps: Bool = true // Default to forcing caps
    
    // Getter methods for private properties
    func getDefaultLayer() -> Int {
        return defaultLayer
    }
    
    func getStartingClip() -> Int {
        return clipRotation.first ?? 1
    }
    
    // Host information
    var targetHost: NWEndpoint.Host
    
    // Connection state
    @Published var isConnected = false
    
    // MARK: - Initialization
    
    init() {
        // Default to the Resolume IP address
        self.targetHost = NWEndpoint.Host("192.168.1.246")
        
        // Load saved settings or use defaults
        loadSavedSettings()
        
        // Setup connection
        setupConnection()
    }
    
    // Load settings from UserDefaults
    private func loadSavedSettings() {
        let defaults = UserDefaults.standard
        
        // Load layer and clip settings with defaults of layer 3, slot 1
        let layer = defaults.integer(forKey: "defaultLayer")
        let startingClip = defaults.integer(forKey: "startingClip")
        let useTableNumber = defaults.bool(forKey: "useTableNumber")
        let tableNumberLabel = defaults.string(forKey: "tableNumberLabel") ?? "Table Number"
        let timeoutMinutes = defaults.double(forKey: "timeoutMinutes")
        let forceCaps = defaults.object(forKey: "forceCaps") != nil ? defaults.bool(forKey: "forceCaps") : true
        
        // Use saved values or defaults
        configureClips(
            defaultLayer: layer > 0 ? layer : 3,
            startingClip: startingClip > 0 ? startingClip : 1,
            useTableNumber: defaults.object(forKey: "useTableNumber") != nil ? useTableNumber : true,
            tableNumberLabel: defaults.object(forKey: "tableNumberLabel") != nil ? tableNumberLabel : "Table Number",
            timeoutMinutes: timeoutMinutes > 0 ? timeoutMinutes : 5.0,
            forceCaps: forceCaps
        )
    }
    
    // Save settings to UserDefaults
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(defaultLayer, forKey: "defaultLayer")
        defaults.set(clipRotation.first ?? 1, forKey: "startingClip")
        defaults.set(useTableNumber, forKey: "useTableNumber")
        defaults.set(tableNumberLabel, forKey: "tableNumberLabel")
        defaults.set(timeoutMinutes, forKey: "timeoutMinutes")
        defaults.set(forceCaps, forKey: "forceCaps")
    }
    
    /// Configure the layer and clip numbers
    func configureClips(
        defaultLayer: Int,
        startingClip: Int,
        useTableNumber: Bool = true,
        tableNumberLabel: String = "Table Number",
        timeoutMinutes: Double = 5.0,
        forceCaps: Bool = true
    ) {
        self.defaultLayer = defaultLayer
        self.useTableNumber = useTableNumber
        self.tableNumberLabel = tableNumberLabel
        self.timeoutMinutes = timeoutMinutes
        self.forceCaps = forceCaps
        
        // Generate clip rotation based on starting clip
        let startIdx = startingClip
        clipRotation = Array(startIdx...(startIdx + 4))
        clearClip = startIdx + 5
        
        // Save settings to UserDefaults
        saveSettings()
        
        print("🔄 Configured clips: Layer \(defaultLayer), Clips \(clipRotation), Clear \(clearClip)")
        print("📋 Message config: Use \(useTableNumber ? tableNumberLabel : "No Identification"), Timeout: \(Int(timeoutMinutes)) minutes, Force Caps: \(forceCaps)")
    }
    
    // MARK: - Connection Management
    
    @MainActor
    private func setupConnection() {
        connection = NWConnection(host: targetHost, port: targetPort, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            // Log state changes immediately
            switch state {
            case .ready:
                print("✅ OSC UDP connection ready to Resolume Arena")
            case .failed(let error):
                print("❌ OSC connection failed: \(error)")
            case .waiting(let error):
                print("⌛️ Waiting to reconnect: \(error)")
            default:
                break
            }
            
            // Update UI state on main actor
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch state {
                case .ready:
                    self.isConnected = true
                case .failed(_):
                    self.isConnected = false
                    // Attempt reconnection after delay
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        self.setupConnection()
                    }
                case .waiting:
                    self.isConnected = false
                default:
                    break
                }
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
        // Split the text into words
        let words = text.split(separator: " ").map(String.init)
        
        // Group words into chunks of maximum 2 words per line
        var formattedLines: [String] = []
        var currentLine: [String] = []
        
        for word in words {
            currentLine.append(word)
            
            // When we reach 2 words, add the line and reset
            if currentLine.count == 2 {
                formattedLines.append(currentLine.joined(separator: " "))
                currentLine = []
            }
        }
        
        // Add any remaining words
        if !currentLine.isEmpty {
            formattedLines.append(currentLine.joined(separator: " "))
        }
        
        // Join all lines with newlines
        return formattedLines.joined(separator: "\n")
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