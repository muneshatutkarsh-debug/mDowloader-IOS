import SwiftUI

struct AddDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloads: DownloadManager
    @State private var urlText: String
    @State private var filename = ""
    @State private var showValidation = false

    init(initialURL: String = "") {
        _urlText = State(initialValue: initialURL)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IDMBackground()
                Form {
                    Section("Direct file URL") {
                        TextField("https://example.com/file.zip", text: $urlText, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                        Button("Paste") {
                            if let value = UIPasteboard.general.string { urlText = value }
                        }
                    }
                    Section("Optional filename") {
                        TextField("Use the server filename", text: $filename)
                    }
                    Section {
                        Text("mDownloader supports direct HTTP and HTTPS file links. Sites protected by sign-in, DRM, or streaming-only players may not expose a downloadable file URL.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") { submit() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Enter a valid HTTP or HTTPS URL", isPresented: $showValidation) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func submit() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            showValidation = true
            return
        }
        downloads.addDownload(url: url, preferredFilename: filename.isEmpty ? nil : filename)
        dismiss()
    }
}

