//
//  ContentView.swift
//  Dashyy
//
//  Created by Aditya Madhyastha on 17/06/26.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = DashboardManager()
    @State private var showingConfigEditor = false
    @State private var configText = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingSettings = false
    @Environment(\.scenePhase) private var scenePhase
    
    private var backgroundColors: [Color] {
        if let hexColors = manager.config?.theme?.backgroundColors, !hexColors.isEmpty {
            return hexColors.map { Color(hex: $0) }
        }
        return [
            Color(hex: "#0A0E17"),
            Color(hex: "#121829"),
            Color(hex: "#1A102F")
        ]
    }
    
    private var accentColor: Color {
        if let hexAccent = manager.config?.theme?.accentColor {
            return Color(hex: hexAccent)
        }
        return .indigo
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Dynamic Layout Render
                        if let config = manager.config {
                            ForEach(config.sections) { section in
                                sectionView(section)
                            }
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(accentColor)
                                Text("Loading configuration...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(manager.config?.title ?? "Dashyy")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    let isLive = manager.isWebSocketConnected
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isLive ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        
                        Text(isLive ? "LIVE" : "DISCONNECTED")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(isLive ? .green : .orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((isLive ? Color.green : Color.orange).opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke((isLive ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                    )
                    .fixedSize(horizontal: true, vertical: true)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            prepareConfigEditor()
                            showingConfigEditor = true
                        }) {
                            Label("Edit Layout", systemImage: "square.stack.3d.up.fill")
                                .foregroundColor(accentColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingConfigEditor) {
                configEditorSheet
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(manager: manager)
            }
            .task {
                manager.connect()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    print("App returned to active foreground - reconnecting...")
                    manager.reconnect()
                }
            }
        }
    }
    
    // MARK: - Section View Generator
    
    @ViewBuilder
    private func sectionView(_ section: DashboardSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Title
            Text(section.title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            // Grid Builder based on Column Budget
            VStack(spacing: 16) {
                let cardConfigs = section.cardIds.compactMap { manager.config?.cards[$0] }
                let rows = makeRows(cards: cardConfigs, totalColumns: section.columns)
                ForEach(0..<rows.count, id: \.self) { rowIndex in
                    let rowItems = rows[rowIndex]
                    HStack(spacing: 16) {
                        ForEach(rowItems, id: \.0.id) { card, span in
                            cardView(card)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Card Router
    
    @ViewBuilder
    private func cardView(_ card: CardConfig) -> some View {
        DynamicCardView(card: card, manager: manager)
    }
    
    // MARK: - Dynamic Layout Grid Algorithm
    
    private func makeRows(cards: [CardConfig], totalColumns: Int) -> [[(CardConfig, Int)]] {
        var rows: [[(CardConfig, Int)]] = []
        var currentRow: [(CardConfig, Int)] = []
        var currentRowSpan = 0
        
        for card in cards {
            let span: Int
            switch (card.size, totalColumns) {
            case (_, 1):
                span = 1
            case (.small, _):
                span = 1
            case (.medium, _):
                span = min(2, totalColumns)
            case (.large, _):
                span = totalColumns
            }
            
            // If current card exceeds the grid width limit, push the active row
            if currentRowSpan + span > totalColumns {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    currentRowSpan = 0
                }
            }
            
            currentRow.append((card, span))
            currentRowSpan += span
            
            if currentRowSpan >= totalColumns {
                rows.append(currentRow)
                currentRow = []
                currentRowSpan = 0
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    // MARK: - Config JSON Editor Sheet
    
    private func prepareConfigEditor() {
        if let config = manager.config {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(config),
               let jsonString = String(data: data, encoding: .utf8) {
                configText = jsonString
            }
        }
    }
    
    private var configEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Modify dashboard JSON configuration to see real-time UI alterations. Adding/removing items or changing grid layouts updates dynamically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.white.opacity(0.02))
                
                TextEditor(text: $configText)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(8)
                    .background(Color(hex: "#0E111A"))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
            }
            .navigationTitle("Layout JSON Editor")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Invalid JSON"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showingConfigEditor = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNewConfig()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func saveNewConfig() {
        guard let data = configText.data(using: .utf8) else {
            alertMessage = "Unable to parse text as data."
            showingAlert = true
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(DashboardConfig.self, from: data)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                manager.config = decoded
            }
            showingConfigEditor = false
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

#Preview {
    ContentView()
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let manager: DashboardManager
    @State private var serverAddressText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Server Configuration")) {
                    TextField("Server Address (host:port)", text: $serverAddressText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Text("Enter the address of your Python backend server. Use 'localhost:8000' for local simulator testing, or your Mac's LAN IP (e.g. '192.168.1.15:8000') for device testing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Connection Info")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(manager.isWebSocketConnected ? "Live Connected" : "Disconnected (Simulated)")
                            .foregroundColor(manager.isWebSocketConnected ? .green : .orange)
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                serverAddressText = manager.serverAddress
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        manager.serverAddress = serverAddressText
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

