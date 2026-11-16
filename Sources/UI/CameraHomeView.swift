import SwiftUI
import AVFoundation
import UIKit

struct CameraHomeView: View {
    @EnvironmentObject var filters: FilterLibrary
    @EnvironmentObject var backend: BackendContainer
    @StateObject private var camera = CameraEngine()
    @State private var showFilterSheet = false
    @State private var showPhotobooth = false
    @State private var captured: UIImage?
    @State private var toast: String?
    var onPaywall: () -> Void

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom)
                )

            VStack {
                HStack {
                    Button { toast = "JustSend — share moments, not feeds." } label: {
                        Text("justsend").font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { onPaywall() } label: {
                        Label(backend.isPlus ? "PLUS" : "Get Plus", systemImage: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(backend.isPlus ? Theme.gold : .white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.black.opacity(0.35), in: Capsule())
                    }
                }
                .padding(.horizontal, 22).padding(.top, 12)

                Spacer()

                // Friend strips — the signature Locket home screen
                FriendStrip(onSend: { toast = "Pick a friend to send your moment" })
                    .padding(.bottom, 14)

                // Filter carousel
                FilterCarousel(selected: $camera.selectedFilter, onOpenStore: { showFilterSheet = true })
                    .padding(.bottom, 18)

                HStack(spacing: 26) {
                    Button { showPhotobooth = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2.fill").font(.title2)
                            Text("Booth").font(.caption2)
                        }.foregroundStyle(.white)
                    }
                    Spacer()
                    Button { Task { if let img = await camera.capturePhoto() { captured = img } } } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                            Circle().fill(.white.opacity(camera.isRecording ? 0.35 : 0.9))
                                .frame(width: 68, height: 68)
                            if camera.isRecording {
                                RoundedRectangle(cornerRadius: 6).fill(Theme.accent)
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                    .accessibilityLabel("Capture")
                    Spacer()
                    Button {
                        camera.isRecording ? camera.stopRecording() : camera.startRecording()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: camera.isRecording ? "stop.circle.fill" : "video.fill")
                                .font(.title2)
                            Text(camera.isRecording ? "Stop" : "\(Int(camera.maxDuration))s video")
                                .font(.caption2)
                        }.foregroundStyle(camera.isRecording ? Theme.accent : .white)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 96)
            }

            if camera.isRecording {
                ProgressView(value: camera.recordingProgress)
                    .progressViewStyle(.linear).tint(Theme.accent)
                    .padding(.horizontal, 40).padding(.bottom, 84)
            }

            if let toast {
                VStack { Spacer(); Text(toast).font(.subheadline).padding()
                        .background(.black.opacity(0.7), in: Capsule()).foregroundStyle(.white)
                        .padding(.bottom, 110) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.toast = nil } }
            }
        }
        .sheet(isPresented: $showFilterSheet) { FilterStoreView() }
        .sheet(isPresented: $showPhotobooth) { PhotoboothView(camera: camera) }
        .sheet(isPresented: Binding(get: { captured != nil }, set: { if !$0 { captured = nil } })) {
            if let captured { MomentsComposer(image: captured) }
        }
        .task { camera.isPlus = backend.isPlus; await camera.configure() }
        .onDisappear { camera.stop() }
    }
}

struct CameraPreview: UIViewRepresentable {
    let camera: CameraEngine
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        let layer = AVCaptureVideoPreviewLayer()
        layer.frame = UIScreen.main.bounds
        v.layer.addSublayer(layer)
        camera.bindPreview(layer)
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) { }
}

struct FriendStrip: View {
    var onSend: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your people").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Button(action: onSend) {
                        VStack {
                            Circle().stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                .frame(width: 58, height: 58).overlay(Image(systemName: "plus").foregroundStyle(.white))
                            Text("Add").font(.caption2).foregroundStyle(.white)
                        }
                    }
                    ForEach(BackendContainer.shared.previewFriends) { f in
                        Button(action: onSend) {
                            VStack {
                                Avatar(url: f.user?.avatarURL, name: f.user?.displayName ?? "?")
                                    .frame(width: 58, height: 58)
                                    .overlay(Circle().stroke(Theme.accent, lineWidth: 2.5))
                                Text(f.user?.firstName ?? "?").font(.caption2).foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct Avatar: View {
    let url: URL?
    let name: String
    var body: some View {
        ZStack {
            if let url, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Theme.accent.opacity(0.7), Theme.gold.opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(String(name.prefix(1))).font(.title2.weight(.bold)).foregroundStyle(.white)
            }
        }
        .clipShape(Circle())
    }
}

struct FilterCarousel: View {
    @Binding var selected: FilterDescriptor?
    @EnvironmentObject var filters: FilterLibrary
    var onOpenStore: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(filters.filters) { f in
                        Button {
                            withAnimation { selected = selected?.id == f.id ? nil : f }
                        } label: {
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.6), Theme.gold.opacity(0.6)],
                                                         startPoint: .top, endPoint: .bottom))
                                    .frame(width: 52, height: 52)
                                    .overlay(Image(systemName: "sparkles").foregroundStyle(.white))
                                    .overlay(Circle().stroke(selected?.id == f.id ? .white : .clear, lineWidth: 3))
                                Text(f.name).font(.caption2).foregroundStyle(.white)
                            }
                        }
                    }
                }.padding(.horizontal, 20)
            }
            Button(action: onOpenStore) {
                Label("Browse filters & TikTok effects", systemImage: "square.grid.2x2")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(.black.opacity(0.4), in: Capsule())
            }
        }
    }
}
