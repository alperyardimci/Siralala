import SwiftUI
import SwiftData

enum RankingPhase: Equatable {
    case ready
    case revealing
    case placing
    case placed
    case complete
}

@Observable
final class RankingViewModel {
    var question: Question
    var selectedItems: [PoolItem] = []
    var currentIndex: Int = 0
    var phase: RankingPhase = .ready
    var placements: [Int: PoolItem] = [:]
    var highlightedSlot: Int? = nil
    var cardOffset: CGSize = .zero
    var cardScale: CGFloat = 1.0
    var showCard: Bool = false

    var rankCount: Int {
        question.itemCount
    }

    var currentItem: PoolItem? {
        guard currentIndex < selectedItems.count else { return nil }
        return selectedItems[currentIndex]
    }

    var progress: String {
        "\(currentIndex)/\(rankCount)"
    }

    var isLastItem: Bool {
        currentIndex >= selectedItems.count - 1
    }

    init(question: Question) {
        self.question = question
        let allItems = question.pool?.items ?? []
        let count = min(question.itemCount, allItems.count)
        self.selectedItems = Array(allItems.shuffled().prefix(count))
    }

    func startRanking() {
        phase = .revealing
        showCard = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.showCard = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.phase = .placing
        }
    }

    func placeItem(atRank rank: Int) {
        guard let item = currentItem, placements[rank] == nil else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            placements[rank] = item
            phase = .placed
            showCard = false
        }

        highlightedSlot = nil
        cardOffset = .zero

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.advanceToNext()
        }
    }

    func advanceToNext() {
        currentIndex += 1
        if currentIndex >= selectedItems.count {
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = .complete
            }
        } else {
            phase = .revealing
            showCard = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.showCard = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.phase = .placing
            }
        }
    }

    func isSlotOccupied(_ rank: Int) -> Bool {
        placements[rank] != nil
    }

    func saveRanking(context: ModelContext, participantName: String) {
        let itemIDs = selectedItems.map { $0.id }
        let session = RankingSession(
            participantName: participantName,
            question: question,
            selectedItemIDs: itemIDs
        )
        context.insert(session)

        for (rank, item) in placements {
            let entry = RankingEntry(rank: rank, item: item)
            entry.session = session
            context.insert(entry)
        }

        session.completedAt = Date()
        question.sessions?.append(session)

        try? context.save()
    }

    func generateMockRankings(context: ModelContext, count: Int = 3) {
        let names = ["Ahmet", "Mehmet", "Ayşe", "Fatma", "Ali", "Zeynep"]
        let mockNames = Array(names.shuffled().prefix(count))

        for name in mockNames {
            let shuffled = selectedItems.shuffled()
            let itemIDs = shuffled.map { $0.id }
            let session = RankingSession(
                participantName: name,
                question: question,
                selectedItemIDs: itemIDs
            )
            context.insert(session)

            for (index, item) in shuffled.enumerated() {
                let entry = RankingEntry(rank: index + 1, item: item)
                entry.session = session
                context.insert(entry)
            }

            session.completedAt = Date()
            question.sessions?.append(session)
        }

        try? context.save()
    }
}
