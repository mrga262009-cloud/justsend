import SwiftUI
import UniformTypeIdentifiers

struct FilterStoreView: View {
    @EnvironmentObject var filters: FilterLibrary
    @Environment(\.dismiss) var dismiss
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Filter Studio").font(.system(size: 28, weight: .black, design: .rounded))
                    Text("Beauty looks, TikTok effects and community filters — all in one place.")
                        .foregroundStyle(Theme.muted).font(.subheadline)

                    HStack(spacing: 10) {
                        Button { showImporter = true } label: {
                            Label("Import catalogue", systemImage: "square.and.arrow.down")
                                .font(.subheadline.weight(.semibold)).padding(12)
                                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        }
                        Label("Rust core: \(RustBridge.version())", systemImage: "cpu")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(filters.filtered) { f in
                            FilterTile(filter: f)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .background(Theme.surface)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .searchable(text: $filters.searchText, prompt: "Search effects")
            .sheet(isPresented: $showImporter) {
                DocumentPicker { url in
                    Task { try? await filters.importCatalog(from: url) }
                }
            }
        }
    }
}

struct FilterTile: View {
    @EnvironmentObject var filters: FilterLibrary
    let filter: FilterDescriptor
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(
                    colors: [Theme.accent.opacity(0.25), Theme.gold.opacity(0.4)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "sparkles").font(.title).foregroundStyle(.white)
                VStack {
                    HStack {
                        if filter.source == .tiktok {
                            Text("TIKTOK").font(.system(size: 8, weight: .black)).foregroundStyle(.white)
                                .padding(4).background(.black.opacity(0.55), in: Capsule())
                        }
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Button { filters.toggleFavorite(filter) } label: {
                            Image(systemName: filter.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(filter.isFavorite ? Theme.accent : .white)
                        }
                    }
                }.padding(8)
            }
            .frame(height: 120)
            Text(filter.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(filter.source.rawValue.capitalized).font(.caption2).foregroundStyle(Theme.muted)
        }
        .padding(10).glassCard()
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let u = urls.first { onPick(u) }
        }
    }
}
