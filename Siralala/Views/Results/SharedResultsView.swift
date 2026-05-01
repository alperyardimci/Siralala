import SwiftUI

struct SharedResultsView: View {
    let question: APISharedQuestion
    var popToRoot: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var rankings: [APIRanking] = []
    @State private var selectedTab = 0
    @State private var isLoading = true

    // selectedTab == rankings.count means "Ortalama"
    private var isAverageSelected: Bool { selectedTab == rankings.count }

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

    // Simple consensus: how much participants agree (inverse of std dev, normalized)
    private var consensusPercent: Int {
        guard rankings.count >= 2 else { return 100 }
        var totalVariance: Double = 0
        var count: Double = 0
        var itemRanks: [String: [Double]] = [:]
        for ranking in rankings {
            for entry in ranking.entries {
                itemRanks[entry.itemName, default: []].append(Double(entry.rank))
            }
        }
        for (_, ranks) in itemRanks {
            let mean = ranks.reduce(0, +) / Double(ranks.count)
            let variance = ranks.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(ranks.count)
            totalVariance += variance
            count += 1
        }
        guard count > 0 else { return 100 }
        let avgVariance = totalVariance / count
        let maxVariance = Double(question.itemCount * question.itemCount) / 4.0
        let consensus = max(0, 1.0 - avgVariance / maxVariance)
        return Int(consensus * 100)
    }

    private var mostDisputedItem: String {
        var itemRanks: [String: [Double]] = [:]
        for ranking in rankings {
            for entry in ranking.entries {
                itemRanks[entry.itemName, default: []].append(Double(entry.rank))
            }
        }
        var maxVariance: Double = 0
        var disputed = "—"
        for (name, ranks) in itemRanks {
            let mean = ranks.reduce(0, +) / Double(ranks.count)
            let variance = ranks.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(ranks.count)
            if variance > maxVariance {
                maxVariance = variance
                disputed = name
            }
        }
        return disputed
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("SONUÇLAR · \(question.poolName.uppercased())")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.dsMuted)
                Text(question.text)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.dsDeep)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if rankings.isEmpty {
                Spacer()
                Text("Henüz kimse sıralama yapmamış")
                    .foregroundStyle(Color.dsMuted)
                Spacer()
            } else {
                // Stats strip
                HStack(spacing: 8) {
                    StatBox(label: "KATILIM", value: "\(rankings.count)", dark: false)
                    StatBox(label: "UYUM", value: "%\(consensusPercent)", dark: false)
                    StatBox(label: "ÇEKİŞMELİ", value: mostDisputedItem, dark: true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Tab chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Average tab first
                        Button {
                            withAnimation { selectedTab = rankings.count }
                        } label: {
                            Text("Ortalama")
                                .font(.system(size: 14, weight: isAverageSelected ? .semibold : .regular))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(isAverageSelected ? Color.dsDeep : Color.clear)
                                )
                                .foregroundStyle(isAverageSelected ? .white : Color.dsDeep)
                                .overlay(
                                    Capsule().strokeBorder(isAverageSelected ? Color.clear : Color.dsHairline, lineWidth: 1)
                                )
                        }

                        ForEach(Array(rankings.enumerated()), id: \.element.id) { index, ranking in
                            Button {
                                withAnimation { selectedTab = index }
                            } label: {
                                Text(ranking.participantName)
                                    .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(selectedTab == index ? Color.dsDeep : Color.clear)
                                    )
                                    .foregroundStyle(selectedTab == index ? .white : Color.dsDeep)
                                    .overlay(
                                        Capsule().strokeBorder(selectedTab == index ? Color.clear : Color.dsHairline, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)

                if selectedTab < rankings.count {
                    ServerRankingList(ranking: rankings[selectedTab])
                } else {
                    ServerAverageList(rankings: rankings, itemCount: question.itemCount)
                }
            }
        }
        .background(Color.dsBg.ignoresSafeArea())
        .navigationTitle("Sonuçlar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            rankings = (try? await APIService.shared.getRankings(questionId: question.id.value)) ?? []
            // Default to average tab
            selectedTab = rankings.count
            isLoading = false
        }
        .refreshable {
            rankings = (try? await APIService.shared.getRankings(questionId: question.id.value)) ?? []
        }
        .safeAreaInset(edge: .bottom) {
            if popToRoot != nil {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        popToRoot?()
                    }
                } label: {
                    Text("Ana sayfaya dön")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.dsDeep, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Stats Box

private struct StatBox: View {
    let label: String
    let value: String
    let dark: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(dark ? .white.opacity(0.7) : Color.dsMuted)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(dark ? .white : Color.dsDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dark ? Color.dsDeep : Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(dark ? Color.clear : Color.dsHairline, lineWidth: 1)
                )
        )
    }
}

// MARK: - Ranking lists

struct ServerRankingList: View {
    let ranking: APIRanking

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(ranking.entries.sorted(by: { $0.rank < $1.rank }), id: \.rank) { entry in
                    HStack(spacing: 12) {
                        RankChip(number: entry.rank, style: entry.rank <= 3 ? .standard : .soft)
                        if let img = entry.uiImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                        }
                        Text(entry.itemName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dsDeep)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    Divider()
                        .background(Color.dsHairline)
                        .padding(.horizontal, 20)
                }
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
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(averageRankings.enumerated()), id: \.element.name) { index, ranking in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            RankChip(number: index + 1, style: index < 3 ? .standard : .soft)
                            Text(ranking.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.dsDeep)
                            Spacer()
                            Text("ort \(ranking.avgRank, specifier: "%.1f")")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color.dsMuted)
                        }

                        // Bar
                        GeometryReader { geo in
                            let maxWidth = geo.size.width
                            let barWidth = max(4, CGFloat(1.0 - (ranking.avgRank - 1.0) / Double(max(1, itemCount - 1))) * maxWidth)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(index < 3 ? Color.dsAccent : Color.dsDeep)
                                .frame(width: barWidth, height: 6)
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    Divider()
                        .background(Color.dsHairline)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
}
