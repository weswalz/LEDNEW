//
//  WebSocketManager.swift
//  LEDNEW
//
//  Created by Wesley Walz on 3/23/25.
//

import Foundation

@MainActor
final class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let serverURL: URL

    @Published var isConnected: Bool = false
    @Published var receivedMessages: [String] = []

    init(serverAddress: String = "ws://localhost:8080/ws") {
        self.serverURL = URL(string: serverAddress)!
        self.session = URLSession(configuration: .default)
        connect()
    }

    func connect() {
        guard !isConnected else { return }
        print("🔌 [WebSocketManager] Connecting to \(serverURL)...")
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
        isConnected = true
        setupReceiveMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    func send(message: String) {
        let msg = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(msg) { [weak self] error in
            if let error = error {
                print("❌ [WebSocketManager] Send error: \(error)")
                Task { @MainActor [weak self] in
                    self?.isConnected = false
                }
            } else {
                print("📤 [WebSocketManager] Sent: \(message)")
            }
        }
    }

    // Public method for receiving messages with a completion handler
    func receiveMessage(completion: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        webSocketTask?.receive(completionHandler: completion)
    }

    private func setupReceiveMessage() {
        receiveMessageInternal()
    }

    private func receiveMessageInternal() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .failure(let error):
                    print("❌ [WebSocketManager] Receive error: \(error)")
                    self.isConnected = false
                case .success(let message):
                    switch message {
                    case .string(let text):
                        print("📥 [WebSocketManager] Received: \(text)")
                        self.receivedMessages.append(text)
                    default:
                        print("ℹ️ [WebSocketManager] Received non-string message")
                    }
                    self.receiveMessageInternal() // Keep listening
                }
            }
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.disconnect()
        }
    }
}
