import SwiftUI

/// Detail view for a wine chosen from the global search sheet.
///
/// Shows the wine's identity and attributes (producer, region, country, colour, grape
/// varieties, description) and offers a quick action to log a tasting for it.
struct WineSearchDetailView: View {
    let wine: WineSearch
    var showsNavigationTitle = true

    @State private var showLogTasting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.largeSpacing) {
                header
                aboutSection
                logButton
            }
            .padding(Theme.spacing)
        }
        .navigationTitle(showsNavigationTitle ? wine.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogTasting) {
            LogTastingView(preselectedWine: wine)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wineglass.fill")
                .font(.largeTitle)
                .foregroundStyle(wine.color?.accentColor ?? .wineAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text(wine.name)
                    .font(.title3.weight(.bold))

                HStack(spacing: 6) {
                    if let country = wine.country, !country.isEmpty {
                        Text(WineFlag.flag(for: country))
                    }
                    if let producer = wine.producer, !producer.isEmpty {
                        Text(producer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let region = wine.region, !region.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(region)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - About (grape varieties + description)

    @ViewBuilder
    private var aboutSection: some View {
        let grapes = wine.grapeVarieties?.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = wine.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasGrapes = !(grapes ?? "").isEmpty
        let hasDescription = !(description ?? "").isEmpty

        if hasGrapes || hasDescription {
            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                if hasGrapes, let grapes {
                    Label {
                        Text(grapes)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(.wineAccent)
                    }
                }

                if hasDescription, let description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.spacing)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    // MARK: - Log Action

    @ViewBuilder
    private var logButton: some View {
        Button {
            showLogTasting = true
        } label: {
            Label("Log a Tasting", systemImage: "plus.circle")
                .font(Theme.bodyFont.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.wineAccent)
    }
}
