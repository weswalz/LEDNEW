//
//  EnhancedContentView.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/24/25.
//

import SwiftUI

struct EnhancedContentView: View {
    // Use a single instance of each manager
    @StateObject private var peerConnectivity = PeerConnectivityManager()
    // Use @StateObject for OSCManager to prevent deinitialization
    @StateObject private var oscManager = OSCManager()
    @StateObject private var viewModel: EnhancedViewModel
    
    // View State
    @State private var showingNewMessageSheet = false
    @State private var messageText = ""
    @State private var tableNumber = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var showSetup = true // Show setup screen by default
    
    // Timer for updating progress bars
    @State private var timerCounter = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init() {
        // Create StateObject instances first
        let peerConnManager = PeerConnectivityManager()
        let oscMan = OSCManager()
        
        // Store references to the StateObjects
        _peerConnectivity = StateObject(wrappedValue: peerConnManager)
        _oscManager = StateObject(wrappedValue: oscMan)
        
        // Create message queue using the SAME instances
        let messageQueue = EnhancedMessageQueue(
            peerConnectivity: peerConnManager,
            oscManager: oscMan
        )
        
        // Initialize view model with the message queue
        _viewModel = StateObject(wrappedValue: EnhancedViewModel(messageQueue: messageQueue))
    }
    
    var body: some View {
        ZStack {
            // Background gradient
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
            
            if showSetup {
                // Show setup screen
                SetupView(oscManager: oscManager, showSetup: $showSetup)
            } else {
                // Main app view
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
                            VStack {
                                Text("No messages in queue")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 18, weight: .medium))
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 40)
                            }
                        }
                    }
                }
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
                .onReceive(timer) { _ in
                    // Update the timer counter to force UI refresh for progress bars
                    timerCounter += 1
                }
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
                    // Show setup screen again
                    showSetup = true
                }) {
                    Text("Setup")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "3B82F6"))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
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
                .buttonStyle(PlainButtonStyle())
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
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
            }
            
            // Status row
            HStack(spacing: 20) {
                // Peer Connection status
                HStack(spacing: 6) {
                    Circle()
                        .fill(peerConnectivity.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                        .frame(width: 8, height: 8)
                    
                    Text("PEER CONNECTED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(peerConnectivity.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                }
                
                // OSC connection status
                HStack(spacing: 6) {
                    Circle()
                        .fill(oscManager.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                        .frame(width: 8, height: 8)
                    
                    Text("RESOLUME CONNECTED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(oscManager.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                }
                
                Spacer()
            }
        }
        .padding(10)
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
                Spacer()
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
    
    @MainActor
    private func messageCard(_ message: EnhancedOSCMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if oscManager.useTableNumber {
                    Text("\(oscManager.tableNumberLabel) \(message.tableNumber)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    // If not using table numbers, just show a generic message label
                    Text("Message")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
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
                            Text("DELETE")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: "EF4444"))
                                .foregroundColor(.white)
                                .cornerRadius(5)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(isProcessing)
                        
                        Button(action: {
                            // Edit message functionality
                        }) {
                            Text("EDIT")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: "F97316"))
                                .foregroundColor(.white)
                                .cornerRadius(5)
                        }
                        .buttonStyle(BorderlessButtonStyle())
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
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(isProcessing)
                    }
                    
                case .sent:
                    Button(action: {
                        Task {
                            isProcessing = true
                            await viewModel.cancelMessage(message.id)
                            isProcessing = false
                        }
                    }) {
                        Text("CANCEL MESSAGE")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "10B981"))
                            .foregroundColor(.white)
                            .cornerRadius(5)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(isProcessing)
                    
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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    message.status == .sent ? Color(hex: "10B981") : Color.clear,
                    lineWidth: message.status == .sent ? 1 : 0
                )
        )
        .overlay(
            // Add progress bar for sent messages
            Group {
                if message.status == .sent {
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 4) {
                            // Time remaining indicator
                            HStack {
                                Spacer()
                                
                                let elapsedTime = Date().timeIntervalSince(message.timestamp)
                                let totalTime = oscManager.timeoutMinutes * 60 // in seconds
                                let remainingTime = max(0, totalTime - elapsedTime)
                                let minutes = Int(remainingTime) / 60
                                let seconds = Int(remainingTime) % 60
                                
                                Text("\(minutes):\(String(format: "%02d", seconds)) remaining")
                                    .font(.caption2)
                                    .foregroundColor(Color(hex: "10B981"))
                                    .padding(.bottom, 2)
                            }
                            .padding(.horizontal, 16)
                            
                            // Calculate remaining time percentage
                            GeometryReader { geometry in
                                let totalWidth = geometry.size.width
                                let elapsedTime = Date().timeIntervalSince(message.timestamp)
                                let totalTime = oscManager.timeoutMinutes * 60 // in seconds
                                let remainingTime = max(0, totalTime - elapsedTime)
                                let percentage = remainingTime / totalTime
                                
                                // Progress bar
                                ZStack(alignment: .leading) {
                                    // Background
                                    Rectangle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: totalWidth, height: 4)
                                    
                                    // Progress
                                    Rectangle()
                                        .fill(Color(hex: "10B981"))
                                        .frame(width: totalWidth * CGFloat(percentage), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                    .padding(.horizontal, -16)
                }
            }
        )
    }
    
    private func messageBackgroundColor(for status: EnhancedOSCMessage.MessageStatus) -> Color {
        switch status {
        case .queued:
            return Color(hex: "0F172A").opacity(0.7)
        case .sent:
            // Green-tinted background for active messages
            return Color(hex: "10B981").opacity(0.1)
        case .expired:
            return Color(hex: "1F2937").opacity(0.5)
        }
    }
    
    @MainActor
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
                
                // Table number field (only if enabled in settings)
                if oscManager.useTableNumber {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(oscManager.tableNumberLabel.uppercased())
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#ffffff"))
                        
                        // Simple TextField with no borders
                        TextField("4", text: $tableNumber)
                            .font(.system(size: 20))
                            .padding(.vertical, 16)
                            .padding(.horizontal, 12)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(oscManager.forceCaps ? .characters : .never)
                            #endif
                            .onChange(of: tableNumber) { oldValue, newValue in
                                if oscManager.forceCaps {
                                    tableNumber = newValue.uppercased()
                                }
                            }
                            // Remove focus border
                            .buttonStyle(PlainButtonStyle())
                            .border(Color.clear)
                    }
                }
                
                // Message field
                VStack(alignment: .leading, spacing: 8) {
                    Text("MESSAGE")
                        .font(.system(size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#ffffff"))
                    
                    // Simple TextField with no borders
                    TextField("HAPPY BIRTHDAY!", text: $messageText)
                        .font(.system(size: 20))
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(4)
                        #if os(iOS)
                        .textInputAutocapitalization(oscManager.forceCaps ? .characters : .never)
                        #endif
                        .onChange(of: messageText) { oldValue, newValue in
                            if oscManager.forceCaps {
                                messageText = newValue.uppercased()
                            }
                        }
                        // Remove focus border
                        .buttonStyle(PlainButtonStyle())
                        .border(Color.clear)
                }
                
                // Buttons
                HStack {
                    Button(action: {
                        showingNewMessageSheet = false
                    }) {
                        Text("CANCEL")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "6B7280"))
                            .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        let canProceed = messageText.isEmpty ? false :
                                        (oscManager.useTableNumber ? !tableNumber.isEmpty : true)
                        
                        if canProceed {
                            Task {
                                isProcessing = true
                                await viewModel.addMessage(
                                    value: messageText,
                                    tableNumber: oscManager.useTableNumber ? tableNumber : "N/A"
                                )
                                messageText = ""
                                tableNumber = ""
                                showingNewMessageSheet = false
                                isProcessing = false
                            }
                        }
                    }) {
                        Text("QUEUE MESSAGE")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#ffffff"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "EC4899"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(messageText.isEmpty || (oscManager.useTableNumber && tableNumber.isEmpty) || isProcessing)
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
    
    func cancelMessage(_ id: UUID) async {
        messageQueue.cancelMessage(messageId: id)
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
