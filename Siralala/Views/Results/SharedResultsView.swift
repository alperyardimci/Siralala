import SwiftUI

struct SharedResultsView: View {
    let question: APISharedQuestion
    var popToRoot: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var rankings: [APIRanking] = []
    @State private var selectedTab = 0
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(question.text)
                    .font(.headline)
                Text("\(question.poolName) · \(question.groupName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if rankings.isEmpty {
                Spacer()
                Text("Henüz kimse sıralama yapmamış")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                // Tab picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(rankings.enumerated()), id: \.element.id) { index, ranking in
                            Button {
                                withAnimation { selectedTab = index }
                            } label: {
                                Text(ranking.participantName)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == index ? .bold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(selectedTab == index ? .orange : .gray.opacity(0.15))
                                    )
                                    .foregroundStyle(selectedTab == index ? .white : .primary)
                            }
                        }

                        // Average tab
                        Button {
                            withAnimation { selectedTab = rankings.count }
                        } label: {
                            Text("Ortalama")
                                .font(.subheadline)
                                .fontWeight(selectedTab == rankings.count ? .bold : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(selectedTab == rankings.count ? .purple : .gray.opacity(0.15))
                                )
                                .foregroundStyle(selectedTab == rankings.count ? .white : .primary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                if selectedTab < rankings.count {
                    ServerRankingList(ranking: rankings[selectedTab])
                } else {
                    ServerAverageList(rankings: rankings, itemCount: question.itemCount)
                }
            }
        }
        .navigationTitle("Sonuçlar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            rankings = (try? await APIService.shared.getRankings(questionId: question.id)) ?? []
            isLoading = false
        }
        .refreshable {
            rankings = (try? await APIService.shared.getRankings(questionId: question.id)) ?? []
        }
        .safeAreaInset(edge: .bottom) {
            if popToRoot != nil {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        popToRoot?()
                    }
                } label: {
                    Text("Ana Sayfaya Dön")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }
}

struct ServerRankingList: View {
    let ranking: APIRanking

    var body: some View {
        List {
            ForEach(ranking.entries.sorted(by: { $0.rank < $1.rank }), id: \.rank) { entry in
                HStack(spacing: 12) {
                    RankBadge(rank: entry.rank)
                    if let img = entry.uiImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(.orange.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text(entry.itemName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(entry.itemName)
                        .font(.body)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct ServerAverageList: View {
    let rankings: [APIRanking]
    let itemCount: Int

    private var averageRankings: [(name: String, avgRank: Double)] {
        var sums: [String: (total: Double, count: Int)] = [:]

        for ranking in rankings {
            for entry in ranking.entries {
                if var existing = sums[entry.itemName] {
                    existing.total += Double(entry.rank)
                    existing.count += 1
                    sums[entry.itemName] = existing
                } else {
                    sums[entry.itemName] = (total: Double(entry.rank), count: 1)
                }
            }
        }

        return sums.map { (name: $0.key, avgRank: $0.value.total / Double($0.value.count)) }
            .sorted { $0.avgRank < $1.avgRank }
    }

    var body: some View {
        List {
            ForEach(Array(averageRankings.enumerated()), id: \.element.name) { index, ranking in
                HStack(spacing: 12) {
                    RankBadge(rank: index + 1)
                    ZStack {
                        Circle()
                            .fill(.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Text(ranking.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading) {
                        Text(ranking.name)
                            .font(.body)
                        Text("Ort: \(ranking.avgRank, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.orange.gradient)
                        .frame(
                            width: max(4, CGFloat(1.0 - (ranking.avgRank - 1.0) / Double(itemCount)) * 60),
                            height: 20
                        )
                }
                .padding(.vertical, 4)
            }
        }
    }
}
