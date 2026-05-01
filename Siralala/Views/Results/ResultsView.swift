import SwiftUI
import SwiftData

struct ResultsView: View {
    let question: Question
    var popToRoot: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private var completedSessions: [RankingSession] {
        (question.sessions ?? [])
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Question header
            VStack(spacing: 4) {
                Text(question.text)
                    .font(.headline)
                    .foregroundStyle(Color.dsDeep)
                Text(question.pool?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            .padding()

            if completedSessions.isEmpty {
                Spacer()
                Text("Henüz kimse sıralama yapmamış")
                    .foregroundStyle(Color.dsMuted)
                Spacer()
            } else {
                // Tab picker for sessions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(completedSessions.enumerated()), id: \.element.id) { index, session in
                            Button {
                                withAnimation { selectedTab = index }
                            } label: {
                                Text(session.participantName)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == index ? .bold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == index ? Color.dsDeep : Color.dsSurfaceDim)
                                    )
                                    .foregroundStyle(selectedTab == index ? .white : Color.dsDeep)
                            }
                        }

                        // Average tab
                        Button {
                            withAnimation { selectedTab = completedSessions.count }
                        } label: {
                            Text("Ortalama")
                                .font(.subheadline)
                                .fontWeight(selectedTab == completedSessions.count ? .bold : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedTab == completedSessions.count ? Color.dsDeep : Color.dsSurfaceDim)
                                )
                                .foregroundStyle(selectedTab == completedSessions.count ? .white : Color.dsDeep)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                if selectedTab < completedSessions.count {
                    SessionRankingList(session: completedSessions[selectedTab])
                } else {
                    AverageRankingList(sessions: completedSessions, question: question)
                }
            }
        }
        .background(Color.dsBg.ignoresSafeArea())
        .navigationTitle("Sonuçlar")
        .navigationBarTitleDisplayMode(.inline)
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
                        .background(Color.dsDeep, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }
}

struct SessionRankingList: View {
    let session: RankingSession

    var body: some View {
        List {
            ForEach(session.sortedEntries) { entry in
                HStack(spacing: 12) {
                    RankBadge(rank: entry.rank)

                    if let item = entry.item {
                        if let data = item.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.dsAccentSoft)
                                    .frame(width: 40, height: 40)
                                Text(item.name.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(Color.dsAccent)
                            }
                        }

                        Text(item.name)
                            .font(.body)
                            .foregroundStyle(Color.dsDeep)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dsBg)
    }
}

struct AverageRankingList: View {
    let sessions: [RankingSession]
    let question: Question

    private var averageRankings: [(item: PoolItem, avgRank: Double)] {
        var rankSums: [UUID: (item: PoolItem, total: Double, count: Int)] = [:]

        for session in sessions {
            for entry in session.sortedEntries {
                guard let item = entry.item else { continue }
                if var existing = rankSums[item.id] {
                    existing.total += Double(entry.rank)
                    existing.count += 1
                    rankSums[item.id] = existing
                } else {
                    rankSums[item.id] = (item: item, total: Double(entry.rank), count: 1)
                }
            }
        }

        return rankSums.values
            .map { (item: $0.item, avgRank: $0.total / Double($0.count)) }
            .sorted { $0.avgRank < $1.avgRank }
    }

    var body: some View {
        List {
            ForEach(Array(averageRankings.enumerated()), id: \.element.item.id) { index, ranking in
                HStack(spacing: 12) {
                    RankBadge(rank: index + 1)

                    if let data = ranking.item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.dsAccentSoft)
                                .frame(width: 40, height: 40)
                            Text(ranking.item.name.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundStyle(Color.dsAccent)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text(ranking.item.name)
                            .font(.body)
                            .foregroundStyle(Color.dsDeep)
                        Text("Ort: \(ranking.avgRank, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                    }

                    Spacer()

                    // Bar showing average
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index < 3 ? Color.dsAccent : Color.dsDeep)
                        .frame(
                            width: max(4, CGFloat(1.0 - (ranking.avgRank - 1.0) / Double(question.itemCount)) * 60),
                            height: 20
                        )
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dsBg)
    }
}

struct RankBadge: View {
    let rank: Int

    private var chipStyle: RankChip.RankChipStyle {
        switch rank {
        case 1, 2, 3: return .standard
        default: return .soft
        }
    }

    var body: some View {
        RankChip(number: rank, style: chipStyle)
    }
}
