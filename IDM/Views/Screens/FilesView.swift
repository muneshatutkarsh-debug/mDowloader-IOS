import QuickLook
import SwiftUI
import UIKit

private struct FileCategory: Identifiable {
    let id: String
    let title: String
    let kind: DownloadKind?
}

struct FilesView: View {
    @EnvironmentObject private var library: FileLibrary
    @EnvironmentObject private var theme: ThemeManager
    @State private var search = ""

    private let categories = [
        FileCategory(id: "all", title: "All Files", kind: nil),
        FileCategory(id: "documents", title: "Documents", kind: .document),
        FileCategory(id: "videos", title: "Videos", kind: .video),
        FileCategory(id: "music", title: "Music", kind: .audio),
        FileCategory(id: "images", title: "Images", kind: .image),
        FileCategory(id: "archives", title: "Archives", kind: .archive)
    ]

    private var visibleCategories: [FileCategory] {
        guard !search.isEmpty else { return categories }
        return categories.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ZStack {
            IDMBackground()
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    PageTitle(title: "Files")
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.body).foregroundStyle(Color.idmSecondary)
                        TextField("Search files", text: $search)
                    }
                    .padding(.horizontal, 16).frame(height: 50).glassCard(radius: 25)

                    ForEach(visibleCategories) { category in
                        NavigationLink {
                            FileListView(title: category.title, kind: category.kind)
                        } label: {
                            HStack(spacing: 14) {
                                SymbolTile(symbol: "folder.fill", size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.title).font(.body.weight(.semibold)).foregroundStyle(Color.idmInk)
                                    Text("\(library.files(for: category.kind).count) files").font(.footnote).foregroundStyle(Color.idmSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.idmSecondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12).glassCard(radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 125)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { library.refresh() }
    }
}

private struct FileListView: View {
    @EnvironmentObject private var library: FileLibrary
    let title: String
    let kind: DownloadKind?
    @State private var search = ""
    @State private var previewURL: URL?
    @State private var sharedFile: StoredFile?

    private var files: [StoredFile] {
        let values = library.files(for: kind)
        return search.isEmpty ? values : values.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            ForEach(files) { file in
                HStack(spacing: 14) {
                    Button { previewURL = file.url } label: {
                        HStack(spacing: 14) {
                            EmojiTile(emoji: file.kind.emoji, size: 42)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name).foregroundStyle(Color.idmInk).lineLimit(2)
                                Text(file.formattedSize).font(.caption).foregroundStyle(Color.idmSecondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    Button { sharedFile = file } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.idmBlue)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", systemImage: "trash", role: .destructive) { library.delete(file) }
                }
            }
        }
        .searchable(text: $search, prompt: "Search \(title.lowercased())")
        .overlay { if files.isEmpty { ContentUnavailableView("No \(title)", systemImage: "folder") } }
        .navigationTitle(title)
        .quickLookPreview($previewURL)
        .sheet(item: $sharedFile) { file in
            ActivityShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .onAppear { library.refresh() }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
