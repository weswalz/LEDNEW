//
//  SetupView.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/24/25.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

// Extension to handle platform-specific TextField modifiers
extension View {
    func numericKeyboard() -> some View {
        #if os(iOS)
        return self.keyboardType(.numberPad)
        #else
        return self
        #endif
    }
}

// Custom button style for gradient background with responsive scaling
struct GradientButtonStyle: ButtonStyle {
    // Pass the scale factor directly to the button style
    var scaleFactor: CGFloat = 1.0
    
    func makeBody(configuration: Configuration) -> some View {
        return configuration.label
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8 * scaleFactor)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SetupView: View {
    @ObservedObject var oscManager: OSCManager
    @Binding var showSetup: Bool
    
    @State private var layerNumber: String = "3"
    @State private var slotNumber: String = "1"
    @State private var isValidInput = true
    @State private var useTableNumber: Bool = true
    @State private var tableNumberLabel: String = "Table Number"
    @State private var timeoutMinutes: Double = 5.0
    @State private var selectedTab: Int = 0 // 0 for Setup, 1 for Customization
    
    @State private var forceCaps: Bool = true
    
    // Initialize with values from OSCManager
    init(oscManager: OSCManager, showSetup: Binding<Bool>) {
        self._oscManager = ObservedObject(wrappedValue: oscManager)
        self._showSetup = showSetup
        
        // Load initial values from OSCManager using getter methods
        _layerNumber = State(initialValue: String(oscManager.getDefaultLayer()))
        _slotNumber = State(initialValue: String(oscManager.getStartingClip()))
        _useTableNumber = State(initialValue: oscManager.useTableNumber)
        _tableNumberLabel = State(initialValue: oscManager.tableNumberLabel)
        _timeoutMinutes = State(initialValue: oscManager.timeoutMinutes)
        _forceCaps = State(initialValue: oscManager.forceCaps)
    }
    
    // Computed property to determine scaling factor based on device size
    var scaleFactor: CGFloat {
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        // Base scale on iPad mini width (768 points)
        if screenWidth < 768 {
            return max(screenWidth / 768, 0.7)
        } else if screenWidth > 1024 {
            // For iPad Pro, slightly larger scaling
            return min(screenWidth / 1024, 1.2)
        } else {
            return 1.0
        }
        #elseif os(macOS)
        // For macOS, scale based on screen size
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        if screenWidth < 1280 {
            return max(screenWidth / 1440, 0.7)
        } else if screenWidth > 1920 {
            return min(screenWidth / 1920, 1.1)
        } else {
            return 0.85 // Default slightly smaller for macOS
        }
        #else
        return 1.0
        #endif
    }
    
    // Computed property for responsive width constraints
    private var maxResponsiveWidth: CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width * 0.9
        #elseif os(macOS)
        return (NSScreen.main?.frame.width ?? 1440) * 0.7
        #else
        return 600
        #endif
    }
    
    var body: some View {
        ZStack(alignment: .top) {
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
            
            // Content with responsive top margin - more compact and polished
            VStack(spacing: 15 * scaleFactor) {
                // Logo and Title - Common for both tabs
                VStack(spacing: 8 * scaleFactor) {
                    Image("ck120")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45 * scaleFactor, height: 45 * scaleFactor)
                        .padding(.bottom, 2 * scaleFactor)
                    
                    Text("LED MESSENGER")
                        .font(.system(size: 24 * scaleFactor, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 5 * scaleFactor)
                
                // IP Detection Status - Common for both tabs - more polished
                HStack(spacing: 8 * scaleFactor) {
                    Circle()
                        .fill(oscManager.isConnected ? Color(hex: "10B981") : Color(hex: "EF4444"))
                        .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                    
                    if oscManager.isConnected {
                        Text("IP DETECTED: \(String(describing: oscManager.targetHost))")
                            .font(.system(size: 14 * scaleFactor, weight: .medium))
                            .foregroundColor(Color(hex: "10B981"))
                    } else {
                        Text("NO IP DETECTED")
                            .font(.system(size: 14 * scaleFactor, weight: .medium))
                            .foregroundColor(Color(hex: "EF4444"))
                    }
                }
                .padding(.vertical, 6 * scaleFactor)
                .padding(.horizontal, 15 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 6 * scaleFactor)
                        .fill(Color.black.opacity(0.3))
                )
                .frame(width: min(350 * scaleFactor, maxResponsiveWidth * 0.7))
                
                // Mobile-style tab bar
                HStack(spacing: 0) {
                    // Setup tab
                    Button(action: { selectedTab = 0 }) {
                        VStack(spacing: 4 * scaleFactor) {
                            Text("Setup")
                                .font(.system(size: 16 * scaleFactor, weight: .medium))
                                .foregroundColor(selectedTab == 0 ? .white : Color.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12 * scaleFactor)
                        .background(selectedTab == 0 ? Color(hex: "3B82F6") : Color(hex: "64748B"))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Customization tab
                    Button(action: { selectedTab = 1 }) {
                        VStack(spacing: 4 * scaleFactor) {
                            Text("Customization")
                                .font(.system(size: 16 * scaleFactor, weight: .medium))
                                .foregroundColor(selectedTab == 1 ? .white : Color.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12 * scaleFactor)
                        .background(selectedTab == 1 ? Color(hex: "3B82F6") : Color(hex: "64748B"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .cornerRadius(8 * scaleFactor)
                .padding(.horizontal, 20 * scaleFactor)
                .padding(.top, 10 * scaleFactor)
                .padding(.bottom, 15 * scaleFactor)
                
                // Tab content
                if selectedTab == 0 {
                    setupTabContent
                } else {
                    customizationTabContent
                }
                
                // Mobile-style Let's Go Button
                VStack {
                    Button(action: {
                        if let layer = Int(layerNumber), let slot = Int(slotNumber) {
                            oscManager.configureClips(
                                defaultLayer: layer,
                                startingClip: slot,
                                useTableNumber: useTableNumber,
                                tableNumberLabel: tableNumberLabel,
                                timeoutMinutes: timeoutMinutes,
                                forceCaps: forceCaps
                            )
                            showSetup = false
                        }
                    }) {
                        Text("LET'S GO!")
                            .font(.system(size: 18 * scaleFactor, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16 * scaleFactor)
                            .background(Color(hex: "3B82F6"))
                            .cornerRadius(10 * scaleFactor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isValidInput)
                    .padding(.horizontal, 20 * scaleFactor)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 30 * scaleFactor)
                .padding(.top, 20 * scaleFactor)
            }
            .padding(.top, 40 * scaleFactor) // Further reduced top margin
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
        }
    }
    
    // Setup Tab Content - more compact
    private var setupTabContent: some View {
        VStack(spacing: 15 * scaleFactor) {
            // Instructions - no grey background
            VStack(alignment: .center, spacing: 10 * scaleFactor) {
                Text("LED MESSENGER works by sending text to 5 sequential text clips in Resolume on a single layer followed by a blank clip to clear the message.")
                    .font(.system(size: 14 * scaleFactor))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 15 * scaleFactor)
                    .frame(maxWidth: 550 * scaleFactor)
                    .fixedSize(horizontal: false, vertical: true) // Force text wrapping
                
                Text("EXAMPLE: Layer 3 Slot 1 would need: 1,2,3,4,5 all text clips with 6 empty to clear the message.")
                    .font(.system(size: 14 * scaleFactor))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 15 * scaleFactor)
                    .frame(maxWidth: 550 * scaleFactor)
                
                Text("Make sure port 2269 is set in Resolume Preferences > OSC > OSC Input Port.")
                    .font(.system(size: 14 * scaleFactor, weight: .bold))
                    .foregroundColor(Color(hex: "F97316"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 15 * scaleFactor)
                    .frame(maxWidth: 550 * scaleFactor)
            }
            .padding(.vertical, 12 * scaleFactor)
            .frame(maxWidth: min(600 * scaleFactor, maxResponsiveWidth))
            
            // Starting Clip Slot - no grey background
            VStack(alignment: .center, spacing: 12 * scaleFactor) {
                Text("Starting Clip Slot:")
                    .font(.system(size: 18 * scaleFactor, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.bottom, 5 * scaleFactor)
                
                HStack(spacing: 20 * scaleFactor) {
                    Spacer()
                    
                    // Layer field
                    VStack(alignment: .center, spacing: 6 * scaleFactor) {
                        Text("Layer")
                            .font(.system(size: 16 * scaleFactor))
                            .foregroundColor(Color(hex: "94A3B8"))
                        
                        TextField("5", text: $layerNumber)
                            .numericKeyboard()
                            .font(.system(size: 20 * scaleFactor, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10 * scaleFactor)
                            .padding(.vertical, 8 * scaleFactor)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8 * scaleFactor)
                            .frame(width: 80 * scaleFactor)
                            .onChange(of: layerNumber) { validateInput() }
                    }
                    
                    // Slot field
                    VStack(alignment: .center, spacing: 6 * scaleFactor) {
                        Text("Slot")
                            .font(.system(size: 16 * scaleFactor))
                            .foregroundColor(Color(hex: "94A3B8"))
                        
                        TextField("4", text: $slotNumber)
                            .numericKeyboard()
                            .font(.system(size: 20 * scaleFactor, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10 * scaleFactor)
                            .padding(.vertical, 8 * scaleFactor)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8 * scaleFactor)
                            .frame(width: 80 * scaleFactor)
                            .onChange(of: slotNumber) { validateInput() }
                    }
                    
                    Spacer()
                }
                
                // Validation message
                if !isValidInput {
                    Text("Please enter valid numbers (1-99)")
                        .font(.system(size: 14 * scaleFactor, weight: .medium))
                        .foregroundColor(Color(hex: "EF4444"))
                        .padding(.top, 5 * scaleFactor)
                }
                
                // Instruction text
                Text("Make sure this layer is active with the visual slider all the way up to see the test message.")
                    .font(.system(size: 14 * scaleFactor))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 15 * scaleFactor)
                    .padding(.top, 10 * scaleFactor)
                    .frame(maxWidth: 450 * scaleFactor)
                    .fixedSize(horizontal: false, vertical: true) // Force text wrapping
            }
            .padding(.vertical, 12 * scaleFactor)
            .frame(maxWidth: min(600 * scaleFactor, maxResponsiveWidth))
        }
    }
    
    // Customization Tab Content - no grey backgrounds
    private var customizationTabContent: some View {
        VStack(spacing: 20 * scaleFactor) {
            Text("Customization")
                .font(.system(size: 20 * scaleFactor, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 5 * scaleFactor)
            
            // Timeout field - moved to top, independent of toggle
            VStack(alignment: .center, spacing: 8 * scaleFactor) {
                Text("Timeout (minutes):")
                    .font(.system(size: 18 * scaleFactor))
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "94A3B8"))
                
                HStack {
                    Spacer()
                    
                    TextField("5", value: $timeoutMinutes, formatter: NumberFormatter())
                        .numericKeyboard()
                        .font(.system(size: 20 * scaleFactor, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12 * scaleFactor)
                        .padding(.vertical, 8 * scaleFactor)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8 * scaleFactor)
                        .frame(width: 120 * scaleFactor)
                        .onChange(of: timeoutMinutes) {
                            // Ensure timeout is between 1 and 60 minutes
                            if timeoutMinutes < 1 {
                                timeoutMinutes = 1
                            } else if timeoutMinutes > 60 {
                                timeoutMinutes = 60
                            }
                        }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 10 * scaleFactor)
            .frame(maxWidth: min(550 * scaleFactor, maxResponsiveWidth))
            .padding(.bottom, 10 * scaleFactor)
            
            // Message Identification section
            VStack(spacing: 10 * scaleFactor) {
                Text("Message Identification")
                    .font(.system(size: 18 * scaleFactor, weight: .medium))
                    .foregroundColor(.white)
                
                Toggle("", isOn: $useTableNumber)
                    .labelsHidden()
                    .scaleEffect(1.2 * scaleFactor)
                    .frame(width: 80 * scaleFactor)
                    .padding(.vertical, 5 * scaleFactor)
            }
            .padding(.vertical, 10 * scaleFactor)
            .frame(maxWidth: 350 * scaleFactor)
            .padding(.bottom, 10 * scaleFactor)
            
            // Force Caps section
            VStack(spacing: 10 * scaleFactor) {
                Text("Force Uppercase")
                    .font(.system(size: 18 * scaleFactor, weight: .medium))
                    .foregroundColor(.white)
                
                Toggle("", isOn: $forceCaps)
                    .labelsHidden()
                    .scaleEffect(1.2 * scaleFactor)
                    .frame(width: 80 * scaleFactor)
                    .padding(.vertical, 5 * scaleFactor)
            }
            .padding(.vertical, 10 * scaleFactor)
            .frame(maxWidth: 350 * scaleFactor)
            .padding(.bottom, 10 * scaleFactor)
            
            // Label field - only shown if toggle is on
            if useTableNumber {
                VStack(alignment: .center, spacing: 10 * scaleFactor) {
                    Text("Label:")
                        .font(.system(size: 18 * scaleFactor))
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "94A3B8"))
                    
                    TextField("Table Number", text: $tableNumberLabel)
                        .font(.system(size: 20 * scaleFactor, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12 * scaleFactor)
                        .padding(.vertical, 8 * scaleFactor)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8 * scaleFactor)
                        .frame(maxWidth: 350 * scaleFactor)
                }
                .padding(.vertical, 10 * scaleFactor)
                .frame(maxWidth: min(550 * scaleFactor, maxResponsiveWidth))
            }
        }
    }
    
    private func validateInput() {
        guard let layer = Int(layerNumber), let slot = Int(slotNumber) else {
            isValidInput = false
            return
        }
        
        isValidInput = layer > 0 && layer < 100 && slot > 0 && slot < 100
    }
}

// Preview provider
struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView(oscManager: OSCManager(), showSetup: .constant(true))
            .preferredColorScheme(.dark)
    }
}