import SwiftUI

/// Timeline screen showing a chronological diary of logged tastings.
///
/// Displays tasting cards grouped by date in a scrollable list with infinite scroll
/// pagination, pull-to-refresh, a loading indicator for page fetches, and an empty state
/// prompting the user to log their first wine.
struct TimelineView: View {
    @Environment(TastingService.self) private var tastingService
    @State private var viewModel: TimelineViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.tastings.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "wineglass",
                        title: "No Tastings Yet",
                        message: "Log your first wine to start your diary.",
                        actionTitle: "New Wine"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            let groups = groupedByDate(viewModel.tastings)
                            ForEach(groups) { group in
                                let groupIndex = groups.firstIndex(where: { $0.id == group.id }) ?? 0
                                TimelineDateGroup(
                                    date: group.date,
                                    tastings: group.tastings,
                                    isFirst: groupIndex == 0,
                                    isLast: groupIndex == groups.count - 1 && !viewModel.hasMorePages
                                )
                                .task {
                                    if let last = group.tastings.last {
                                        await viewModel.onTastingAppear(last)
                                    }
                                }
                            }
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                    }
                    .refreshable { await viewModel.loadInitial() }
                    .navigationDestination(for: Tasting.self) { tasting in
                        TastingDetailView(tasting: tasting, viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Timeline")
        .task {
            if viewModel == nil {
                viewModel = TimelineViewModel(tastingService: tastingService)
            }
            await viewModel?.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tastingDidChange)) { _ in
            Task { await viewModel?.loadInitial() }
        }
    }

    // MARK: - Grouping

    private struct DateGroup: Identifiable {
        let date: String
        let tastings: [Tasting]
        var id: String { date }
    }

    private func groupedByDate(_ tastings: [Tasting]) -> [DateGroup] {
        var order: [String] = []
        var map: [String: [Tasting]] = [:]

        for tasting in tastings {
            let date = tasting.tastingDate
            if map[date] == nil {
                order.append(date)
                map[date] = []
            }
            map[date]?.append(tasting)
        }

        return order.compactMap { date in
            guard let tastings = map[date] else { return nil }
            return DateGroup(date: date, tastings: tastings)
        }
    }
}

// MARK: - Timeline Date Group

/// A group of tastings on the same date, showing one date node and multiple cards.
private struct TimelineDateGroup: View {
    let date: String
    let tastings: [Tasting]
    let isFirst: Bool
    let isLast: Bool

    private static let lineWidth: CGFloat = 2
    private static let nodeSize: CGFloat = 12
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        f.locale = Locale.current
        return f
    }()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let parsed = formatter.date(from: date) {
            return Self.dateFormatter.string(from: parsed)
        }
        return date
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline spine
            VStack(spacing: 0) {
                // Line above the node
                Rectangle()
                    .fill(isFirst ? .clear : .wineAccent.opacity(0.3))
                    .frame(width: Self.lineWidth, height: 20)

                // Date node
                Circle()
                    .fill(.wineAccent)
                    .frame(width: Self.nodeSize, height: Self.nodeSize)

                // Line below the node
                Rectangle()
                    .fill(isLast ? .clear : .wineAccent.opacity(0.3))
                    .frame(width: Self.lineWidth)
            }
            .frame(width: 24)

            // Cards for this date
            VStack(alignment: .leading, spacing: 8) {
                Text(formattedDate)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.wineAccent)

                ForEach(tastings, id: \.id) { tasting in
                    NavigationLink(value: tasting) {
                        TastingCard(tasting: tasting)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView()
            .environment(TastingService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
