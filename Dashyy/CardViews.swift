//
//  CardViews.swift
//  Dashyy
//
//  Created by Antigravity on 18/06/26.
//

import SwiftUI
import Charts

// MARK: - Premium Glassmorphic Card Wrapper

struct CardContainer<Content: View>: View {
    let title: String
    let size: CardSize
    let isConnected: Bool
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(isConnected ? Color.green : Color.red.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .shadow(color: isConnected ? .green : .red, radius: 2)
            }
            .padding(.bottom, 2)
            
            // Content
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        }
    }
}

// MARK: - Helper Extension for Dynamic Colors

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
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func named(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "purple": return .purple
        case "mint": return .mint
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .primary
        }
    }
}

// MARK: - Generic Dynamic Card Renderer

struct DynamicCardView: View {
    let card: CardConfig
    let manager: DashboardManager
    
    var body: some View {
        let data = manager.cardData[card.id] ?? [:]
        let errorMessage = data["error"] as? String
        
        CardContainer(title: card.title, size: card.size, isConnected: !data.isEmpty && errorMessage == nil) {
            if let errorMessage = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text("Connection Failed")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(card.widgets) { widget in
                        WidgetRendererView(widget: widget, context: data, manager: manager)
                    }
                }
            }
        }
    }
}

// MARK: - Widget Compiler & Dispatcher

struct WidgetRendererView: View {
    let widget: WidgetConfig
    let context: [String: Any]
    let manager: DashboardManager
    
    var body: some View {
        switch widget.type {
        case "row":
            HStack(spacing: 12) {
                if let children = widget.children {
                    ForEach(children) { child in
                        WidgetRendererView(widget: child, context: context, manager: manager)
                    }
                }
            }
            
        case "column":
            VStack(alignment: .leading, spacing: 6) {
                if let children = widget.children {
                    ForEach(children) { child in
                        WidgetRendererView(widget: child, context: context, manager: manager)
                    }
                }
            }
            
        case "divider":
            Divider()
                .background(Color.white.opacity(0.1))
            
        case "spacer":
            Spacer()
            
        case "text":
            TextView(widget: widget, context: context)
            
        case "badge":
            BadgeView(widget: widget, context: context)
            
        case "progress":
            ProgressViewWidget(widget: widget, context: context)
            
        case "button":
            ButtonView(widget: widget, context: context, manager: manager)
            
        case "chart":
            ChartView(widget: widget, context: context)
            
        case "image":
            ImageView(widget: widget, context: context)
            
        case "list":
            ListView(widget: widget, context: context, manager: manager)
            
        default:
            EmptyView()
        }
    }
}

// MARK: - 1. Text Widget

struct TextView: View {
    let widget: WidgetConfig
    let context: [String: Any]
    
    var body: some View {
        let textValue: String = {
            if let valuePath = widget.valuePath {
                if let doubleVal = JSONValueResolver.resolveDouble(path: valuePath, in: context) {
                    return String(format: "%.1f", doubleVal)
                }
                return JSONValueResolver.resolveString(path: valuePath, in: context) ?? ""
            }
            return widget.text ?? ""
        }()
        
        let fontColor: Color = {
            if let thresholds = widget.thresholds,
               let numericVal = widget.valuePath.flatMap({ JSONValueResolver.resolveDouble(path: $0, in: context) }) {
                let sorted = thresholds.sorted(by: { $0.value > $1.value })
                for threshold in sorted {
                    if numericVal >= threshold.value {
                        return Color.named(threshold.color)
                    }
                }
            }
            if let colorName = widget.color {
                return colorName.hasPrefix("#") ? Color(hex: colorName) : Color.named(colorName)
            }
            return .primary
        }()
        
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(textValue)
                .font(.system(
                    size: CGFloat(widget.size ?? 14.0),
                    weight: widget.isBold == true ? .bold : .regular,
                    design: .rounded
                ))
                .foregroundColor(fontColor)
                .lineLimit(widget.lineLimit)
            
            if let unit = widget.unit {
                Text(unit)
                    .font(.system(size: CGFloat((widget.size ?? 14.0) * 0.55), weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 2. Badge Widget

struct BadgeView: View {
    let widget: WidgetConfig
    let context: [String: Any]
    
    var body: some View {
        let value = widget.valuePath.flatMap { JSONValueResolver.resolveString(path: $0, in: context) } ?? ""
        let colorName = widget.mappings?[value] ?? widget.color ?? "secondary"
        let color = colorName.hasPrefix("#") ? Color(hex: colorName) : Color.named(colorName)
        
        HStack(spacing: 4) {
            if let icon = widget.icon {
                Image(systemName: icon)
                    .font(.system(size: 8))
            }
            Text(value.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .frame(width: 75, height: 16)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(6)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.3), lineWidth: 0.8)
        }
    }
}

// MARK: - 3. Progress Widget

struct ProgressViewWidget: View {
    let widget: WidgetConfig
    let context: [String: Any]
    
    var body: some View {
        let progress = widget.valuePath.flatMap { JSONValueResolver.resolveDouble(path: $0, in: context) } ?? 0.0
        let color = widget.color.flatMap { Color.named($0) } ?? Color.green
        
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                Capsule()
                    .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(max(0.0, min(1.0, progress))), height: 6)
            }
        }
        .frame(height: 6)
        .padding(.vertical, 2)
    }
}

// MARK: - 4. Button Widget

struct ButtonView: View {
    let widget: WidgetConfig
    let context: [String: Any]
    let manager: DashboardManager
    
    var body: some View {
        let color = widget.color.flatMap { Color.named($0) } ?? Color.indigo
        
        Button(action: {
            if let actionPath = widget.actionPath {
                let resolved = resolveActionPath(path: actionPath, context: context)
                manager.handleAction(path: resolved)
            }
        }) {
            HStack(spacing: 4) {
                if let icon = widget.icon {
                    Image(systemName: icon)
                }
                if let label = widget.text {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func resolveActionPath(path: String, context: [String: Any]) -> String {
        var resolved = path
        let regex = try? NSRegularExpression(pattern: "\\{([^\\}]+)\\}", options: [])
        let nsString = path as NSString
        let results = regex?.matches(in: path, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in results.reversed() {
            let keyRange = match.range(at: 1)
            let key = nsString.substring(with: keyRange)
            if let val = context[key] {
                let strVal = String(describing: val)
                resolved = (resolved as NSString).replacingCharacters(in: match.range, with: strVal)
            }
        }
        return resolved
    }
}

// MARK: - 5. Time Series Chart Widget

struct ChartSeriesPointWrapper: Identifiable {
    let id = UUID()
    let date: Date
    let series: String
    let value: Double
}

struct ChartView: View {
    let widget: WidgetConfig
    let context: [String: Any]
    
    var body: some View {
        let history = (widget.valuePath.flatMap { JSONValueResolver.resolve(path: $0, in: context) } as? [[String: Any]]) ?? []
        let colors = widget.colors ?? ["#3B82F6", "#10B981"]
        let yKeys = widget.yKeys ?? []
        let labels = widget.seriesLabels ?? []
        let unit = widget.unit ?? ""
        
        let seriesPoints: [ChartSeriesPointWrapper] = history.flatMap { dp -> [ChartSeriesPointWrapper] in
            let timestamp = dp["timestamp"] as? Double ?? 0.0
            let date = Date(timeIntervalSince1970: timestamp)
            return yKeys.enumerated().compactMap { index, key in
                guard let val = dp[key] as? Double else { return nil }
                let label = index < labels.count ? labels[index] : key
                return ChartSeriesPointWrapper(date: date, series: label, value: val)
            }
        }
        
        let colorForSeries: (String) -> Color = { series in
            if let index = labels.firstIndex(of: series) {
                return Color(hex: colors[index % colors.count])
            }
            return .blue
        }
        
        VStack(alignment: .leading, spacing: 8) {
            // Legend
            HStack(spacing: 16) {
                ForEach(0..<min(yKeys.count, labels.count), id: \.self) { idx in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: colors[idx % colors.count]))
                            .frame(width: 8, height: 8)
                        
                        Text(labels[idx])
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if history.isEmpty {
                Text("No historical metrics")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                Chart {
                    ForEach(seriesPoints) { point in
                        if widget.chartType == "area" {
                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("Speed", point.value)
                            )
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [
                                        colorForSeries(point.series).opacity(0.3),
                                        colorForSeries(point.series).opacity(0.01)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .position(by: .value("Series", point.series))
                        }
                        
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Speed", point.value)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartForegroundStyleScale(domain: labels) { label in
                    colorForSeries(label)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleVal = value.as(Double.self) {
                                Text("\(String(format: "%.0f", doubleVal))\(unit)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.05))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.hour().minute().second())
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 120)
            }
        }
    }
}

// MARK: - 6. Dynamic List Widget

struct IdentifiableDict: Identifiable {
    let id: String
    let dict: [String: Any]
}

struct ListView: View {
    let widget: WidgetConfig
    let context: [String: Any]
    let manager: DashboardManager
    
    var body: some View {
        let rawItems = (widget.arrayPath.flatMap { JSONValueResolver.resolve(path: $0, in: context) } as? [[String: Any]]) ?? []
        let items = rawItems.map { dict in
            let id = JSONValueResolver.resolveString(path: "id", in: dict) ?? UUID().uuidString
            return IdentifiableDict(id: id, dict: dict)
        }
        let layouts = widget.itemLayout ?? []
        
        Group {
            if items.isEmpty {
                Text("No items active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
            } else {
                if widget.direction == "horizontal" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(items) { item in
                                let itemContext = item.dict
                                VStack(alignment: .center, spacing: 6) {
                                    ForEach(layouts) { itemWidget in
                                        WidgetRendererView(widget: itemWidget, context: itemContext, manager: manager)
                                    }
                                }
                                .frame(width: 80)
                            }
                        }
                    }
                    .frame(height: 110)
                } else {
                    VStack(spacing: 12) {
                        ForEach(items) { item in
                            let itemContext = item.dict
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(layouts) { itemWidget in
                                    WidgetRendererView(widget: itemWidget, context: itemContext, manager: manager)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(10)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 7. Image / Thumbnail Widget

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let lock = NSLock()
    
    // Store completion handlers for active downloads to avoid duplicate network tasks
    private var callbacks: [URL: [(UIImage?, Bool) -> Void]] = [:]
    
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("DashyyImageCache")
    }
    
    init() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func cacheKey(for url: URL) -> String {
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let hash = url.absoluteString.utf8.reduce(5381) {
            ($0 << 5) &+ $0 &+ Int($1)
        }
        return "\(abs(hash)).\(ext)"
    }
    
    func get(url: URL) -> UIImage? {
        if let image = cache.object(forKey: url as NSURL) {
            return image
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey(for: url))
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
        
        return nil
    }
    
    func set(url: URL, data: Data, image: UIImage) {
        cache.setObject(image, forKey: url as NSURL)
        
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey(for: url))
        DispatchQueue.global(qos: .background).async {
            try? data.write(to: fileURL)
        }
    }
    
    // Deduplicates network requests and callbacks for identical image URLs
    func fetchImage(url: URL, completion: @escaping (UIImage?, Bool) -> Void) {
        lock.lock()
        
        // Check local cache
        if let cached = get(url: url) {
            lock.unlock()
            completion(cached, false)
            return
        }
        
        // If a request is already downloading this URL, append the callback
        if callbacks[url] != nil {
            callbacks[url]?.append(completion)
            lock.unlock()
            return
        }
        
        // Otherwise, register as a new download job
        callbacks[url] = [completion]
        lock.unlock()
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            var resultImage: UIImage? = nil
            var failed = false
            
            if let data = data, let loadedImage = UIImage(data: data) {
                self.set(url: url, data: data, image: loadedImage)
                resultImage = loadedImage
            } else {
                failed = true
                print("Failed to download image from \(url.absoluteString): \(error?.localizedDescription ?? "unknown error")")
            }
            
            self.lock.lock()
            let handlers = self.callbacks[url] ?? []
            self.callbacks.removeValue(forKey: url)
            self.lock.unlock()
            
            DispatchQueue.main.async {
                for handler in handlers {
                    handler(resultImage, failed)
                }
            }
        }.resume()
    }
}

struct CachedAsyncImage: View {
    let url: URL
    let fallbackIcon: String
    let size: CGFloat
    
    @State private var image: UIImage? = nil
    @State private var loadFailed = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if loadFailed {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.45))
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _, newUrl in
            loadImage(for: newUrl)
        }
    }
    
    private func loadImage(for customUrl: URL? = nil) {
        let targetUrl = customUrl ?? url
        
        // Reset state for new URL
        self.image = nil
        self.loadFailed = false
        
        ImageCache.shared.fetchImage(url: targetUrl) { loadedImage, failed in
            // Guard against cell recycle where URL changes before callback executes
            guard targetUrl == (customUrl ?? url) else { return }
            
            if let img = loadedImage {
                self.image = img
            } else if failed {
                self.loadFailed = true
            }
        }
    }
}

struct ImageView: View {
    let widget: WidgetConfig
    let context: [String: Any]
    
    var body: some View {
        let imageUrlString = widget.valuePath.flatMap { JSONValueResolver.resolveString(path: $0, in: context) }
        let fallbackIcon = widget.icon ?? "photo"
        let width = CGFloat(widget.size ?? 32.0)
        let height = CGFloat(widget.size ?? 32.0)
        
        Group {
            if let urlStr = imageUrlString, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url, fallbackIcon: fallbackIcon, size: width)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: width * 0.45))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
        .clipped()
    }
}
