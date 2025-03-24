//
//  PeerConnectivityManager.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/24/25.
//

import Foundation
import MultipeerConnectivity

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class PeerConnectivityManager: NSObject, ObservableObject {
    // Service type must be a unique string, 1-15 characters long, valid characters: A-Z, 0-9
    private let serviceType = "ledmsg"
    
    #if os(iOS)
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    #elseif os(macOS)
    private let myPeerId = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    #endif
    
    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser
    
    private var session: MCSession
    
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isConnected: Bool = false
    @Published var receivedMessages: [String] = []
    @Published var resolumeFound: Bool = false // For status display
    
    var messageHandler: ((String) -> Void)?
    
    override init() {
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        
        serviceBrowser = MCNearbyServiceBrowser(
            peer: myPeerId,
            serviceType: serviceType
        )
        
        super.init()
        
        session.delegate = self
        serviceAdvertiser.delegate = self
        serviceBrowser.delegate = self
        
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
        
        // Check for Resolume on the network (simplified)
        checkForResolume()
    }
    
    func send(message: String) {
        guard !connectedPeers.isEmpty else {
            print("📱 [PeerConnectivityManager] No peers connected, handling locally")
            messageHandler?(message)
            return
        }
        
        do {
            try session.send(message.data(using: .utf8)!, toPeers: connectedPeers, with: .reliable)
            print("📤 [PeerConnectivityManager] Sent to \(connectedPeers.count) peers: \(message)")
        } catch {
            print("❌ [PeerConnectivityManager] Send error: \(error)")
        }
    }
    
    private func checkForResolume() {
        // Simple implementation - we'd do a more thorough check in a real app
        Task {
            // Try to connect to Resolume's typical port
            let socketAddress = "127.0.0.1"
            let port: UInt16 = 2269
            
            // Create socket address
            var socketAddr = sockaddr_in()
            socketAddr.sin_family = sa_family_t(AF_INET)
            socketAddr.sin_port = port.bigEndian
            
            #if os(iOS) || os(macOS)
            // Direct assignment without optional binding
            let addr = inet_addr(socketAddress)
            socketAddr.sin_addr = in_addr(s_addr: addr)
            
            // Create socket
            let sockfd = socket(AF_INET, SOCK_STREAM, 0)
            if sockfd != -1 {
                let sockaddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let connectResult = withUnsafePointer(to: &socketAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.connect(sockfd, $0, sockaddrLen)
                    }
                }
                
                // If connection successful, Resolume is likely running
                if connectResult == 0 {
                    await MainActor.run {
                        self.resolumeFound = true
                    }
                }
                
                // Close socket
                Darwin.close(sockfd)
            }
            #endif
        }
    }
    
    deinit {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
    }
}

// MARK: - MCSessionDelegate
extension PeerConnectivityManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.isConnected = !self.connectedPeers.isEmpty
                print("👥 [PeerConnectivityManager] Connected to: \(peerID.displayName)")
            case .connecting:
                print("👥 [PeerConnectivityManager] Connecting to: \(peerID.displayName)")
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                self.isConnected = !self.connectedPeers.isEmpty
                print("👥 [PeerConnectivityManager] Disconnected from: \(peerID.displayName)")
            @unknown default:
                print("👥 [PeerConnectivityManager] Unknown state: \(state)")
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8) else {
            print("❌ [PeerConnectivityManager] Could not decode message data")
            return
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            print("📥 [PeerConnectivityManager] Received from \(peerID.displayName): \(message)")
            self.receivedMessages.append(message)
            self.messageHandler?(message)
        }
    }
    
    // Required but unused MCSessionDelegate methods
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension PeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor [weak self] in
            guard let self = self else {
                invitationHandler(false, nil)
                return
            }
            print("📱 [PeerConnectivityManager] Received invitation from \(peerID.displayName)")
            invitationHandler(true, self.session)
        }
    }
    
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ [PeerConnectivityManager] Could not start advertising: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension PeerConnectivityManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            print("📱 [PeerConnectivityManager] Found peer: \(peerID.displayName)")
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("📱 [PeerConnectivityManager] Lost peer: \(peerID.displayName)")
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ [PeerConnectivityManager] Could not start browsing: \(error)")
    }
}
