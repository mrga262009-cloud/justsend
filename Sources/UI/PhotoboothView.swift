import SwiftUI
import UIKit

struct PhotoboothView: View {
    @ObservedObject var camera: CameraEngine
    @Environment(\.dismiss) var dismiss
    @State private var strip: UIImage?
    @State private var counting = false

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.title2).foregroundStyle(.white) }
                    Spacer()
                    Text("Photobooth").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 30)
                }
                .padding()

                if let strip {
                    Image(uiImage: strip).resizable().scaledToFit()
                        .cornerRadius(16).shadow(radius: 20).padding()
                    HStack(spacing: 16) {
                        Button { Task { await camera.saveToPhotos(strip) } } label: {
                            Label("Save", systemImage: "square.and.arrow.down").primaryButton()
                        }
                        Button { self.strip = nil } label: {
                            Label("Retake", systemImage: "arrow.counterclockwise").font(.headline)
                                .foregroundStyle(.white).padding().background(.white.opacity(0.12), in: Capsule())
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.25), lineWidth: 2)
                        VStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2").font(.system(size: 50)).foregroundStyle(.white.opacity(0.7))
                            Text("4 frames · 4 seconds").foregroundStyle(.white.opacity(0.7))
                            Text("Get ready, smile!").font(.headline).foregroundStyle(.white)
                        }
                    }
                    .frame(height: 320).padding()

                    Button {
                        counting = true
                        Task {
                            let img = await camera.capturePhotobooth()
                            await MainActor.run { strip = img; counting = false }
                        }
                    } label: {
                        Text(counting ? "Cheese… 📸" : "Start booth").primaryButton()
                    }
                    .disabled(counting)
                    .padding(.horizontal, 40)
                }
                Spacer()
            }
        }
    }
}
