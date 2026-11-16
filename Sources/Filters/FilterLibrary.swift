import Foundation
import SwiftUI
import CoreImage

@MainActor
final class FilterLibrary: ObservableObject {
    static let shared = FilterLibrary()

    @Published private(set) var filters: [FilterDescriptor] = []
    @Published private(set) var isLoading = false
    @Published var searchText = ""
    @Published private(set) var lastError: String?

    private let fileManager = FileManager.default
    private var catalogURL: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("filter_catalog.json")
    }

    var filtered: [FilterDescriptor] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return filters }
        return filters.filter {
            $0.name.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) } ||
            ($0.authorName?.lowercased().contains(q) ?? false)
        }
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        // 1. bundled seed catalogue
        var all = Self.bundledFilters()
        // 2. persisted catalogue from the crawler
        if let data = try? Data(contentsOf: catalogURL),
           let json = String(data: data, encoding: .utf8) {
            let normalized = RustBridge.normalizeCatalog(json)
            if let parsed = try? JSONDecoder().decode([FilterDescriptor].self, from: Data(normalized.utf8)) {
                all = merge(all, parsed)
            }
            lastError = RustBridge.validateCatalog(json)
        }
        filters = all.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func importCatalog(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        guard let json = String(data: data, encoding: .utf8) else { throw APIError.decoding("not utf8") }
        if let err = RustBridge.validateCatalog(json) { throw APIError.body(err) }
        let normalized = RustBridge.normalizeCatalog(json)
        try Data(normalized.utf8).write(to: catalogURL)
        await bootstrap()
    }

    func toggleFavorite(_ filter: FilterDescriptor) {
        guard let i = filters.firstIndex(where: { $0.id == filter.id }) else { return }
        filters[i].isFavorite.toggle()
    }

    private func merge(_ a: [FilterDescriptor], _ b: [FilterDescriptor]) -> [FilterDescriptor] {
        var map: [String: FilterDescriptor] = [:]
        for f in a + b {
            let key = f.id
            map[key] = f
        }
        return Array(map.values)
    }

    static func bundledFilters() -> [FilterDescriptor] {
        let beauty = FilterDescriptor(
            id: "native-glow", name: "Glow", source: .bundled, authorName: "JustSend",
            intensity: 0.7, tags: ["beauty", "tiktok", "portrait"])
        let clean = FilterDescriptor(
            id: "native-clean", name: "Clean Girl", source: .bundled, authorName: "JustSend",
            intensity: 0.6, tags: ["beauty", "natural"])
        let film = FilterDescriptor(
            id: "native-film", name: "35mm Film", source: .bundled, authorName: "JustSend",
            intensity: 0.8, tags: ["film", "vintage"])
        let vivid = FilterDescriptor(
            id: "native-vivid", name: "Vivid", source: .bundled, authorName: "JustSend",
            intensity: 0.9, tags: ["color", "vibrant"])
        let noir = FilterDescriptor(
            id: "native-noir", name: "Noir", source: .bundled, authorName: "JustSend",
            intensity: 1.0, tags: ["bw", "cinematic"])
        return [beauty, clean, film, vivid, noir]
    }
}

// MARK: - Core Image rendering

enum FilterRenderer {
    static func apply(_ filter: FilterDescriptor?, to image: CIImage, intensity: Double) -> CIImage {
        guard let filter else { return image }
        var out = image
        switch filter.id {
        case "native-glow":
            let blur = out.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 8.0])
            out = out.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image,
                                                                       kCIInputImageKey: blur])
            out = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.08,
                                                                     kCIInputBrightnessKey: 0.02])
        case "native-clean":
            out = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.92,
                                                                     kCIInputContrastKey: 1.06,
                                                                     kCIInputBrightnessKey: 0.03])
        case "native-film":
            out = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.82,
                                                                     kCIInputContrastKey: 1.12])
            out = out.applyingFilter("CIVignette", parameters: [kCIInputRadiusKey: 1.6, kCIInputIntensityKey: 0.35])
        case "native-vivid":
            out = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.35,
                                                                     kCIInputContrastKey: 1.1])
        case "native-noir":
            out = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0,
                                                                     kCIInputContrastKey: 1.25])
        default:
            out = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.0 + intensity * 0.2])
        }
        return out
    }
}
