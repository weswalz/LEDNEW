//
//  EnhancedMessageQueue.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/24/25.
//

import Foundation
import Combine

// Enhanced message model with additional metadata
struct EnhancedOSCMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let address: String
    let value: String
    let tableNumber: String
    let timestamp: Date
    var status: MessageStatus
    
    enum MessageStatus: String, Codable {
        case queued
        case sent
        case expired
    }
    
    init?(address: String, value: String, tableNumber: String) {
        guard address.starts(with: "/") else { return nil }
        self.id = UUID()
        self.address = address
        self.value = value
        self.tableNumber = tableNumber
        self.timestamp = Date()
        self.status = .queued
    }
    
    // Helper property to display in the UI
    func displayText(useTableNumber: Bool, tableNumberLabel: String) -> String {
        if useTableNumber {
            return "\(tableNumberLabel) \(tableNumber): \(value)"
        } else {
            return value
        }
    }
}

@MainActor
final class EnhancedMessageQueue: ObservableObject {
    @Published var messages: [EnhancedOSCMessage] = []
    private var peerConnectivity: PeerConnectivityManager
    private var oscManager: OSCManager
    
    // For auto-expiration
    private var expirationTimers: [UUID: Timer] = [:]
    private var expirationTime: TimeInterval {
        return oscManager.timeoutMinutes * 60 // Convert minutes to seconds
    }
    
    init(peerConnectivity: PeerConnectivityManager, oscManager: OSCManager) {
        self.peerConnectivity = peerConnectivity
        self.oscManager = oscManager
        
        // Set up peer connectivity message handler
        peerConnectivity.messageHandler = { [weak self] jsonString in
            self?.handleIncomingMessage(jsonString)
        }
    }
    
    // Add a new message to the queue
    func add(address: String, value: String, tableNumber: String, broadcast: Bool = true) {
        guard let message = EnhancedOSCMessage(address: address, value: value, tableNumber: tableNumber) else {
            print("❌ [EnhancedMessageQueue] Invalid message format")
            return
        }
        
        messages.append(message)
        
        // Set up auto-expiration timer
        startExpirationTimer(for: message)
        
        // Broadcast to peers if needed
        if broadcast {
            broadcastMessage(action: "add", message: message)
        }
    }
    
    // Send a message to Resolume
    func send(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            print("❌ [EnhancedMessageQueue] Message not found for sending")
            return
        }
        
        var updatedMessage = messages[index]
        updatedMessage.status = .sent
        messages[index] = updatedMessage
        
        // Send to Resolume using OSCManager's rotation system
        oscManager.sendTextToResolume(text: updatedMessage.value)
        
        // Broadcast status change to peers
        broadcastMessage(action: "update", message: updatedMessage)
    }
    
    // Remove a message from the queue
    func remove(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        let message = messages[index]
        
        // Cancel expiration timer
        if let timer = expirationTimers[messageId] {
            timer.invalidate()
            expirationTimers[messageId] = nil
        }
        
        messages.remove(at: index)
        
        // Broadcast removal to peers
        broadcastMessage(action: "remove", message: message)
    }
    
    // Clear the LED wall
    func clearScreen() {
        // Use the OSCManager's clearScreen method
        oscManager.clearScreen()
        
        // Update status of all sent messages
        for index in messages.indices {
            if messages[index].status == .sent {
                var updatedMessage = messages[index]
                updatedMessage.status = .expired
                messages[index] = updatedMessage
                
                // Broadcast status change
                broadcastMessage(action: "update", message: updatedMessage)
            }
        }
    }
    
    // Cancel a sent message and return it to queue
    func cancelMessage(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            print("❌ [EnhancedMessageQueue] Message not found for cancellation")
            return
        }
        
        var updatedMessage = messages[index]
        
        // Only cancel if message is currently sent
        if updatedMessage.status == .sent {
            // Clear the screen
            oscManager.clearScreen()
            
            // Update status back to queued
            updatedMessage.status = .queued
            messages[index] = updatedMessage
            
            // Cancel the expiration timer
            if let timer = expirationTimers[messageId] {
                timer.invalidate()
                expirationTimers[messageId] = nil
            }
            
            // Broadcast status change to peers
            broadcastMessage(action: "update", message: updatedMessage)
            
            print("🔄 [EnhancedMessageQueue] Message cancelled and returned to queue")
        }
    }
    
    // Start auto-expiration timer for a message
    private func startExpirationTimer(for message: EnhancedOSCMessage) {
        let timer = Timer.scheduledTimer(withTimeInterval: expirationTime, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    if self.messages[index].status == .sent {
                        // Clear the LED wall for this specific message
                        self.clearScreen()
                    }
                    
                    var updatedMessage = self.messages[index]
                    updatedMessage.status = .expired
                    self.messages[index] = updatedMessage
                    
                    // Broadcast expiration
                    self.broadcastMessage(action: "update", message: updatedMessage)
                }
            }
        }
        
        expirationTimers[message.id] = timer
    }
    
    // Handle messages coming from peers
    private func handleIncomingMessage(_ jsonString: String) {
        do {
            guard let data = jsonString.data(using: .utf8) else { return }
            
            let decoder = JSONDecoder()
            let messageAction = try decoder.decode(MessageAction.self, from: data)
            
            switch messageAction.action {
            case "add":
                if let messageData = messageAction.message {
                    // Add without broadcasting to avoid loops
                    if !messages.contains(where: { $0.id == messageData.id }) {
                        messages.append(messageData)
                        startExpirationTimer(for: messageData)
                    }
                }
                
            case "update":
                if let messageData = messageAction.message,
                   let index = messages.firstIndex(where: { $0.id == messageData.id }) {
                    messages[index] = messageData
                }
                
            case "remove":
                if let messageData = messageAction.message {
                    messages.removeAll { $0.id == messageData.id }
                    if let timer = expirationTimers[messageData.id] {
                        timer.invalidate()
                        expirationTimers[messageData.id] = nil
                    }
                }
                
            default:
                print("⚠️ [EnhancedMessageQueue] Unknown action: \(messageAction.action)")
            }
            
        } catch {
            print("❌ [EnhancedMessageQueue] Error decoding message: \(error)")
        }
    }
    
    // Broadcast a message action to all peers
    private func broadcastMessage(action: String, message: EnhancedOSCMessage) {
        do {
            let messageAction = MessageAction(action: action, message: message)
            let encoder = JSONEncoder()
            let data = try encoder.encode(messageAction)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    peerConnectivity.send(message: jsonString)
                }
            }
        } catch {
            print("❌ [EnhancedMessageQueue] Error encoding message: \(error)")
        }
    }
    
    // Helper struct for peer-to-peer communication
    private struct MessageAction: Codable {
        let action: String
        let message: EnhancedOSCMessage?
    }
}
