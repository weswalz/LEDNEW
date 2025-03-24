//
//  EnhancedContentView.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/24/25.
//

import SwiftUI

struct EnhancedContentView: View {
    @StateObject private var peerConnectivity = PeerConnectivityManager()
    @State private var oscManager = OSCManager()
    @StateObject private var viewModel: EnhancedViewModel
    
    // View State
    @State private var showingNewMessageSheet = false
    @State private var messageText = ""
    @State private var tableNumber = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    init() {
        let peerConn = PeerConnectivityManager()
        let osc = OSCManager()
        let messageQueue = EnhancedMessageQueue(peerConnectivity: peerConn, oscManager: osc)
        
        // Use _StateObject to initialize properly
        _peerConnectivity = StateObject(wrappedValue: peerConn)
        // OSCManager is now @Observable, so we use @State instead of @StateObject
        self.oscManager = osc
        _viewModel = StateObject(wrappedValue: EnhancedViewModel(messageQueue: messageQueue))
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // 1) Header at top, no extra top padding
            headerView
            
            // 2) Instructions bar, 10px below header
            instructionsBar
            
            // 3) Scrollable message list, 10px below instructions
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        messageCard(message)
                    }
                }
                .padding(.horizontal, 10)
            }
            .overlay {
                if viewModel.messages.isEmpty {
                    Text("No messages in queue")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 16))
                }
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#0f172a"),
                    Color(hex: "#1e293b"),
                    Color(hex: "#0f172a")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingNewMessageSheet) {
            newMessageSheet
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        VStack(spacing: 10) {
            // Top row: title + buttons
            HStack(spacing: 10) {
                Text("LED WALL MESSENGER")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    // Reload app functionality
                }) {
                    Text("Reload App")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "EF4444"))
                        .cornerRadius(6)
                }
                
                Button(action: {
                    Task {
                        isProcessing = true
                        await viewModel.clearScreen()
                        isProcessing = false
                    }
                }) {
                    Text("Clear Screen")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "F97316"))
                        .cornerRadius(6)
                }
                .disabled(isProcessing)
                
                Button(action: {
                    showingNewMessageSheet = true
                }) {
                    Text("New Message")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "EC4899"))
                        .cornerRadius(6)
                }
                .disabled(isProcessing)
            }
            
            // Status row
            HStack(spacing: 20) {
                // Connection status
                HStack(spacing: 6) {
                    Circle()
                        .fill(peerConnectivity.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                        .frame(width: 8, height: 8)
                    
                    Text("CONNECTED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(peerConnectivity.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                }
                
                // OSC connection status
                HStack(spacing: 6) {
                    Circle()
                        .fill(oscManager.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                        .frame(width: 8, height: 8)
                    
                    Text("OSC CONNECTED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(oscManager.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                }
                
                // Resolume status
                HStack(spacing: 6) {
                    Circle()
                        .fill(peerConnectivity.resolumeFound ? Color(hex: "10B981") : Color(hex: "EF4444"))
                        .frame(width: 8, height: 8)
                    
                    Text("RESOLUME FOUND")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(peerConnectivity.resolumeFound ? Color(hex: "10B981") : Color(hex: "EF4444"))
                }
                
                Spacer()
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.3))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    private var instructionsBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("INSTRUCTIONS: Queue message → Send to LED wall")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 15)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.05))
        }
        .background(Color.black.opacity(0.2))
    }
    
    private func messageCard(_ message: EnhancedOSCMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Table \(message.tableNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Status indicator or actions based on message status
                switch message.status {
                case .queued:
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                isProcessing = true
                                await viewModel.deleteMessage(message.id)
                                isProcessing = false
                            }
                        }) {
                            Text("Delete")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "EF4444"))
                        }
                        .disabled(isProcessing)
                        
                        Button(action: {
                            // Edit message functionality
                        }) {
                            Text("Edit")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "F97316"))
                        }
                        .disabled(isProcessing)
                        
                        Button(action: {
                            Task {
                                isProcessing = true
                                await viewModel.sendMessage(message.id)
                                isProcessing = false
                            }
                        }) {
                            Text("SEND TO WALL")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: "0EA5E9"))
                                .foregroundColor(.white)
                                .cornerRadius(5)
                        }
                        .disabled(isProcessing)
                    }
                    
                case .sent:
                    Text("DISPLAYED")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "10B981"))
                    
                case .expired:
                    Text("EXPIRED")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "94A3B8"))
                }
            }
            
            Text(message.value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(messageBackgroundColor(for: message.status))
        .cornerRadius(8)
    }
    
    private func messageBackgroundColor(for status: EnhancedOSCMessage.MessageStatus) -> Color {
        switch status {
        case .queued:
            return Color(hex: "0F172A").opacity(0.7)
        case .sent:
            return Color(hex: "064E3B").opacity(0.3)
        case .expired:
            return Color(hex: "1F2937").opacity(0.5)
        }
    }
    
    private var newMessageSheet: some View {
        ZStack {
            // Dark background
            Color(hex: "0F172A")
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Header
                Text("New Message")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "3B82F6"))
                
                // Table number field
                VStack(alignment: .leading, spacing: 8) {
                    Text("TABLE NUMBER")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "94A3B8"))
                    
                    TextField("4", text: $tableNumber)
                        .font(.body)
                        .padding()
                        .background(Color(hex: "1E293B"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                
                // Message field
                VStack(alignment: .leading, spacing: 8) {
                    Text("MESSAGE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "94A3B8"))
                    
                    TextField("HAPPY BIRTHDAY!", text: $messageText)
                        .font(.body)
                        .padding()
                        .background(Color(hex: "1E293B"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Buttons
                HStack {
                    Button("Cancel") {
                        showingNewMessageSheet = false
                    }
                    .font(.headline)
                    .padding()
                    .foregroundColor(Color(hex: "94A3B8"))
                    
                    Spacer()
                    
                    Button("Queue Message") {
                        if !messageText.isEmpty && !tableNumber.isEmpty {
                            Task {
                                isProcessing = true
                                await viewModel.addMessage(value: messageText, tableNumber: tableNumber)
                                messageText = ""
                                tableNumber = ""
                                showingNewMessageSheet = false
                                isProcessing = false
                            }
                        }
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "D946EF"), Color(hex: "EC4899")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(messageText.isEmpty || tableNumber.isEmpty || isProcessing)
                }
            }
            .padding(24)
            .background(Color(hex: "0F172A"))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - ViewModel
@MainActor
final class EnhancedViewModel: ObservableObject {
    private let messageQueue: EnhancedMessageQueue
    
    @Published var messages: [EnhancedOSCMessage] = []
    
    init(messageQueue: EnhancedMessageQueue) {
        self.messageQueue = messageQueue
        
        // Keep our messages in sync with the message queue
        Task {
            for await _ in messageQueue.$messages.values {
                self.messages = messageQueue.messages
            }
        }
    }
    
    func addMessage(value: String, tableNumber: String) async {
        messageQueue.add(address: "/text", value: value, tableNumber: tableNumber)
    }
    
    func sendMessage(_ id: UUID) async {
        messageQueue.send(messageId: id)
    }
    
    func deleteMessage(_ id: UUID) async {
        messageQueue.remove(messageId: id)
    }
    
    func clearScreen() async {
        messageQueue.clearScreen()
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview Provider
struct EnhancedContentView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedContentView()
            .preferredColorScheme(.dark)
    }
}
