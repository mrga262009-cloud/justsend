import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var backend: BackendContainer
    @State private var filter: String = "all"
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    HStack {
                        Text("History").font(.system(size: 30, weight: .black, design: .rounded))
                        Spacer()
                        Menu {
                            Button("All") { filter = "all" }
                            Button("Photos") { filter = "image" }
                            Button("Videos") { filter = "video" }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title2).foregroundStyle(Theme.ink)
                        }
                    }
                    .padding(.horizontal, 20)

                    let items = backend.moments.isEmpty ? BackendContainer.sampleMoments : backend.moments
                    ForEach(items.filter { filter == "all" || $0.kind.rawValue == filter }) { m in
                        MomentCard(moment: m)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Theme.surface)
            .task { await backend.refresh() }
        }
    }
}

struct MomentCard: View {
    let moment: Moment
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Avatar(url: nil, name: BackendContainer.previewFriends.first(where: { $0.uid == moment.ownerUID })?.user?.firstName ?? "?")
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading) {
                    Text(BackendContainer.previewFriends.first(where: { $0.uid == moment.ownerUID })?.user?.displayName ?? "Friend")
                        .font(.subheadline.weight(.semibold))
                    Text(moment.date, style: .relative).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                if moment.kind == .video {
                    Label("\(Int(moment.durationSeconds ?? 0))s", systemImage: "video.fill")
                        .font(.caption).foregroundStyle(Theme.accent)
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(LinearGradient(
                    colors: [Theme.accent.opacity(0.15), Theme.gold.opacity(0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                if let caption = moment.caption {
                    Text(caption).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                        .padding().multilineTextAlignment(.center)
                }
            }
            .frame(height: 220)
            HStack(spacing: 18) {
                Label("\(moment.reactions.count)", systemImage: "heart")
                Label("\(moment.viewCount)", systemImage: "eye")
                Spacer()
                Button { } label: { Image(systemName: "ellipsis") }
            }
            .font(.subheadline).foregroundStyle(Theme.muted)
        }
        .padding(14)
        .glassCard()
        .padding(.horizontal, 18)
    }
}
