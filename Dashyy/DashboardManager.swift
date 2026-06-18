//
//  DashboardManager.swift
//  Dashyy
//
//  Created by Antigravity on 17/06/26.
//

import Foundation
import Combine
import SwiftUI

@Observable
final class DashboardManager {
    var config: DashboardConfig?
    var isWebSocketConnected = false
    
    // Live data cache, maps Card ID to dynamic data dictionary [String: Any]
    var cardData: [String: [String: Any]] = [:]
    
    // Server Host Address stored in UserDefaults
    var serverAddress: String {
        get {
            UserDefaults.standard.string(forKey: "server_address")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "localhost:8000"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: "server_address")
            reconnect()
        }
    }
    
    private var chartHistoryLengths: [String: Int] = [:]
    private var webSocketTask: URLSessionWebSocketTask?
    private var connectionTask: Task<Void, Never>?
    
    init() {
        // No side-effects in init to prevent SwiftUI reconstruction loops
    }
    
    deinit {
        connectionTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    // MARK: - Connections Management
    
    func reconnect() {
        print("Reconnecting to: \(serverAddress)")
        connectionTask?.cancel()
        connectionTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isWebSocketConnected = false
        connect()
    }
    
    func connect() {
        connectionTask?.cancel()
        
        connectionTask = Task {
            await fetchDashboard()
            guard !Task.isCancelled else { return }
            connectWebSocket()
        }
    }
    
    // MARK: - HTTP Fetch Layout Configuration
    
    func fetchDashboard() async {
        guard !Task.isCancelled else { return }
        guard let url = URL(string: "http://\(serverAddress)/api/dashboard") else {
            print("Invalid API Base URL: http://\(serverAddress)/api/dashboard")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to fetch dashboard: invalid response status code. Retrying in 3s...")
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await fetchDashboard()
                return
            }
            
            let decoded = try JSONDecoder().decode(DashboardConfig.self, from: data)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    self.config = decoded
                }
                print("Successfully loaded layout configuration from server.")
            }
        } catch {
            guard !Task.isCancelled else { return }
            print("HTTP Fetch failed: \(error.localizedDescription). Retrying in 3s...")
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await fetchDashboard()
            } catch {
                // Task was cancelled during sleep
            }
        }
    }
    
    // MARK: - WebSockets Real-time Metric Stream
    
    func connectWebSocket() {
        guard !Task.isCancelled else { return }
        guard let url = URL(string: "ws://\(serverAddress)/ws") else { return }
        
        print("Connecting to WebSocket at: \(url)")
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        
        // Listen for incoming metrics packet
        receiveWebSocketMessage()
    }
    
    private func receiveWebSocketMessage() {
        guard let task = webSocketTask else { return }
        
        task.receive { [weak self] result in
            guard let self = self else { return }
            
            // Verify that the task wasn't cancelled or replaced
            guard self.webSocketTask === task else { return }
            
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    if !self.isWebSocketConnected {
                        self.isWebSocketConnected = true
                    }
                }
                
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.handleWebSocketMessage(data: data)
                    }
                case .data(let data):
                    self.handleWebSocketMessage(data: data)
                @unknown default:
                    break
                }
                
                // Continue receiving next messages
                self.receiveWebSocketMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isWebSocketConnected = false
                    
                    // Verify that the task wasn't replaced before updating/reconnecting
                    guard self.webSocketTask === task else { return }
                    self.webSocketTask = nil
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    private func handleWebSocketMessage(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let cardDataDict = json["cardData"] as? [String: [String: Any]] {
                DispatchQueue.main.async {
                    for (cardId, payload) in cardDataDict {
                        self.cardData[cardId] = payload
                    }
                }
            }
        } catch {
            print("Failed to decode WebSocket payload: \(error.localizedDescription)")
        }
    }
    
    private func scheduleReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if !self.isWebSocketConnected && self.webSocketTask == nil {
                print("Attempting to reconnect WebSocket...")
                self.connectWebSocket()
            }
        }
    }
    
    // MARK: - Dynamic SDUI Actions Dispatcher
    
    func handleAction(path: String) {
        guard let url = URL(string: path) else { return }
        
        let cardId = url.host ?? url.path.components(separatedBy: "/").first ?? ""
        let action = url.path.components(separatedBy: "/").last ?? ""
        let queryItems = URLComponents(string: path)?.queryItems
        let itemId = queryItems?.first(where: { $0.name == "id" })?.value ?? ""
        
        // Live Server Dispatch
        var components = URLComponents(string: "http://\(serverAddress)/api/actions/\(cardId)/\(action)")
        if !itemId.isEmpty {
            components?.queryItems = [URLQueryItem(name: "id", value: itemId)]
        }
        
        guard let actionURL = components?.url else { return }
        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to dispatch action: \(error.localizedDescription)")
            } else {
                print("Action successfully dispatched to server: \(cardId)/\(action)")
            }
        }.resume()
    }
}
