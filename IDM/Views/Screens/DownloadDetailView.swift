import SwiftUI

struct DownloadDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloads: DownloadManager
    @AppStorage("downloadFolderName") private var downloadFolderName = "Downloads"
    let downloadID: UUID

    private var item: DownloadItem? { downloads.items.first { $0.id == downloadID } }

    var body: some View {
        ZStack {
            IDMBackground()
            if let item {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left").font(.title3.bold()).frame(width: 48, height: 48).glassCard(radius: 24)
                            }
                            Spacer()
                            Text("Download Details").font(.title2.bold()).foregroundStyle(Color.idmInk)
                            Spacer()
                            Color.clear.frame(width: 48, height: 48)
                        }

                        VStack(spacing: 22) {
                            HStack(spacing: 16) {
                                SymbolTile(symbol: item.kind.symbol, size: 76, filled: true)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.filename).font(.title3.bold()).foregroundStyle(Color.idmInk).lineLimit(2)
                                    Text("\(item.formattedTotal)  •  \(item.fileExtensionLabel)").foregroundStyle(Color.idmSecondary)
                                }
                                Spacer()
                            }

                            HStack {
                                Text("\(Int(item.progress * 100))%").font(.title.bold()).monospacedDigit()
                                Spacer()
                                Text(item.formattedSpeed).font(.title3).foregroundStyle(Color.idmSecondary)
                            }
                            BlueProgressView(progress: item.status == .completed ? 1 : item.progress)

                            VStack(spacing: 0) {
                                detailRow("waveform.path.ecg", "Status", item.status.title, item.status == .failed ? .red : .idmBlue)
                                Divider()
                                detailRow("arrow.down", "Downloaded", item.formattedWritten)
                                Divider()
                                detailRow("externaldrive", "Total Size", item.formattedTotal)
                                Divider()
                                detailRow("speedometer", "Speed", item.formattedSpeed)
                                Divider()
                                detailRow("clock", "Time Left", item.status == .completed ? "Complete" : item.formattedTimeRemaining)
                                Divider()
                                detailRow("folder", "Save Path", "/" + downloadFolderName)
                            }
                            .padding(.horizontal, 16)
                            .glassCard(radius: 24)
                        }
                        .padding(20)
                        .glassCard(radius: 28)

                        HStack(spacing: 14) {
                            if item.status == .completed, let localFilename = item.localFilename {
                                ShareLink(item: DownloadManager.downloadsDirectory.appendingPathComponent(localFilename)) {
                                    actionLabel("square.and.arrow.up", "Share", prominent: false)
                                }
                            } else {
                                Button { toggle(item) } label: {
                                    actionLabel(item.status == .downloading ? "pause.fill" : "play.fill", item.status == .downloading ? "Pause" : "Resume", prominent: false)
                                }
                            }
                            Button(role: .destructive) {
                                downloads.cancel(item.id)
                            } label: {
                                actionLabel("xmark", "Cancel", prominent: true)
                            }
                            .disabled(item.status == .completed || item.status == .cancelled)
                        }

                        if let error = item.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            } else {
                ContentUnavailableView("Download not found", systemImage: "questionmark.folder")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func detailRow(_ icon: String, _ label: String, _ value: String, _ valueColor: Color = .idmSecondary) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(Color.idmBlue).frame(width: 34, height: 34).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11))
            Text(label).foregroundStyle(Color.idmInk)
            Spacer()
            Text(value).foregroundStyle(valueColor).lineLimit(1)
        }
        .padding(.vertical, 13)
    }

    private func actionLabel(_ symbol: String, _ title: String, prominent: Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(prominent ? .white : Color.idmBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(prominent ? Color.idmBlue : Color.clear, in: RoundedRectangle(cornerRadius: 22))
            .glassCard(radius: 22)
    }

    private func toggle(_ item: DownloadItem) {
        if item.status == .downloading || item.status == .queued { downloads.pause(item.id) }
        else { downloads.resume(item.id) }
    }
}

