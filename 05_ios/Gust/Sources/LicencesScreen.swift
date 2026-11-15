//
//  LicencesScreen.swift
//  Gust
//
//  Licence texts, bundled and readable in-app. LGPL-3.0 obliges us to ship the
//  licence and the notices; putting them behind a Settings row is the minimum a
//  user can actually reach, rather than burying them in the source tree.
//

import SwiftUI

struct LicencesScreen: View {
    private enum Document: String, CaseIterable, Identifiable {
        case notice = "NOTICE"
        case licence = "BREEZY_LICENSE"
        case additional = "BREEZY_LICENSE_ADDITIONAL"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .notice: return "Notice"
            case .licence: return "LGPL-3.0"
            case .additional: return "Additional terms"
            }
        }
    }

    @State private var selected: Document = .notice

    var body: some View {
        VStack(spacing: 0) {
            Picker("Document", selection: $selected) {
                ForEach(Document.allCases) { document in
                    Text(document.title).tag(document)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                Text(text(for: selected))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("licence.text")
            }
        }
        .navigationTitle("Licences")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A missing bundle resource is shown as an error rather than as an empty page:
    /// silence here would look like "there are no licence obligations".
    private func text(for document: Document) -> String {
        // The Licences folder is copied as a resource directory, so the files land
        // next to each other inside the bundle.
        guard let url = Bundle.main.url(forResource: document.rawValue, withExtension: "txt")
            ?? Bundle.main.url(forResource: document.rawValue, withExtension: "txt", subdirectory: "Licences"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return "Licence document \(document.rawValue).txt is missing from the app bundle."
        }
        return contents
    }
}
