//
//  LEDNEWApp.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/24/25.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
class LEDNEWAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize peer connectivity to request network permissions
        print("iOS App launched")
        return true
    }
}
#elseif os(macOS)
class LEDNEWAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize peer connectivity to request network permissions
        print("macOS App launched")
    }
}
#endif

@main
struct LEDNEWApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(LEDNEWAppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(LEDNEWAppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            EnhancedContentView()
                .preferredColorScheme(.dark)
        }
    }
}
