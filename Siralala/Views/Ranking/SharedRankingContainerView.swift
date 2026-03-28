import SwiftUI

struct SharedSlotFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

@Observable
final class SharedRankingViewModel {
    let question: APISharedQuestion
    var selectedItems: [APIQuestionItem] = []
    var currentIndex: Int = 0
    var phase: RankingPhase = .ready
    var placements: [Int: APIQuestionItem] = [:]
    var highlightedSlot: Int? = nil
    var cardOffset: CGSize = .zero
    var cardScale: CGFloat = 1.0
    var showCard: Bool = false

    var rankCount: Int { question.itemCount }

    var currentItem: APIQuestionItem? {
        guard currentIndex < selectedItems.count else { return nil }
        return selectedItems[currentIndex]
    }

    var progress: String { "\(currentIndex)/\(rankCount)" }

    init(question: APISharedQuestion) {
        self.question = question
        let count = min(question.itemCount, question.items.count)
        self.selectedItems = Array(question.items.shuffled().prefix(count))
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

    func submitToServer() async throws {
        let entries = placements.map { SubmitRankingEntry(itemId: $0.value.id, rank: $0.key) }
        try await APIService.shared.submitRanking(questionId: question.id, entries: entries)
    }
}

struct SharedRankingContainerView: View {
    let question: APISharedQuestion
    var popToRoot: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SharedRankingViewModel
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var showQuitAlert = false
    @State private var showResults = false
    @State private var didSave = false
    @State private var alreadyRanked = false

    init(question: APISharedQuestion, popToRoot: (() -> Void)? = nil) {
        self.question = question
        self.popToRoot = popToRoot
        self._viewModel = State(initialValue: SharedRankingViewModel(question: question))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(question.text)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    if viewModel.phase != .ready && viewModel.phase != .complete {
                        Text(viewModel.progress)
                            .font(.headline)
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)

                if alreadyRanked {
                    alreadyRankedView
                } else if viewModel.phase == .ready {
                    readyView
                } else if viewModel.phase == .complete {
                    completeView
                } else {
                    rankingArea
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if viewModel.phase != .complete {
                    Button("Çık") { showQuitAlert = true }
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Çıkmak istediğine emin misin?", isPresented: $showQuitAlert) {
            Button("Çık", role: .destructive) { dismiss() }
            Button("Devam Et", role: .cancel) { }
        } message: {
            Text("Sıralaman kaybolacak.")
        }
        .task {
            let rankings = (try? await APIService.shared.getRankings(questionId: question.id)) ?? []
            let me = APIService.shared.username
            if rankings.contains(where: { $0.participantName == me || $0.participantName == APIService.shared.currentUser?.displayName }) {
                alreadyRanked = true
            }
        }
        .sheet(isPresented: $showResults) {
            NavigationStack {
                SharedResultsView(question: question, popToRoot: popToRoot)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Kapat") { showResults = false }
                        }
                    }
            }
        }
    }

    private var alreadyRankedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green.gradient)
            Text("Zaten sıraladın!")
                .font(.title2)
                .fontWeight(.bold)
            Text("Bu soruyu daha önce cevapladın.")
                .foregroundStyle(.secondary)

            Button {
                showResults = true
            } label: {
                Text("Sonuçları Gör")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)

            Button {
                if let popToRoot { popToRoot() } else { dismiss() }
            } label: {
                Text("Geri Dön")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.gradient)
                Text("Hazır mısın?")
                    .font(.title)
                    .fontWeight(.bold)
                Text("\(viewModel.rankCount) öğeyi sıralayacaksın.\nHer öğe tek tek gelecek ve\nyerleştirdikten sonra değiştiremezsin!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                viewModel.startRanking()
            } label: {
                Text("Başla")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 48)
            Spacer()
        }
    }

    private var completeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.green.gradient)

                Text("Tamamlandı!")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 8) {
                    ForEach(1...viewModel.rankCount, id: \.self) { rank in
                        if let item = viewModel.placements[rank] {
                            HStack(spacing: 12) {
                                Text("#\(rank)")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                    .frame(width: 40)
                                ZStack {
                                    Circle()
                                        .fill(.orange.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Text(item.name.prefix(1).uppercased())
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)
                                }
                                Text(item.name)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 24)

                Button {
                    Task {
                        if !didSave {
                            didSave = true
                            try? await viewModel.submitToServer()
                        }
                        showResults = true
                    }
                } label: {
                    Text("Sonuçları Gör")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green.gradient, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)

                Button {
                    Task {
                        if !didSave {
                            didSave = true
                            try? await viewModel.submitToServer()
                        }
                        if let popToRoot {
                            popToRoot()
                        } else {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Ana Sayfaya Dön")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 32)
            }
            .padding(.top, 20)
        }
    }

    private var rankingArea: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(1...viewModel.rankCount, id: \.self) { rank in
                            SharedSlotView(
                                rank: rank,
                                item: viewModel.placements[rank],
                                isHighlighted: viewModel.highlightedSlot == rank,
                                isOccupied: viewModel.isSlotOccupied(rank)
                            )
                            .background(
                                GeometryReader { slotGeo in
                                    Color.clear.preference(
                                        key: SharedSlotFrameKey.self,
                                        value: [rank: slotGeo.frame(in: .named("sharedRankingArea"))]
                                    )
                                }
                            )
                            .onTapGesture {
                                if viewModel.phase == .placing && !viewModel.isSlotOccupied(rank) {
                                    viewModel.placeItem(atRank: rank)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .frame(width: geo.size.width * 0.55)

                VStack {
                    Spacer()
                    if let item = viewModel.currentItem, viewModel.showCard {
                        SharedItemCard(item: item, isDragging: viewModel.phase == .placing)
                            .offset(viewModel.cardOffset)
                            .scaleEffect(viewModel.cardScale)
                            .gesture(
                                DragGesture(coordinateSpace: .named("sharedRankingArea"))
                                    .onChanged { value in
                                        guard viewModel.phase == .placing else { return }
                                        viewModel.cardOffset = value.translation
                                        viewModel.cardScale = 0.85
                                        let cardCenter = CGPoint(
                                            x: geo.size.width * 0.725 + value.translation.width,
                                            y: geo.size.height * 0.5 + value.translation.height
                                        )
                                        viewModel.highlightedSlot = nil
                                        for (rank, frame) in slotFrames {
                                            if frame.contains(cardCenter) && !viewModel.isSlotOccupied(rank) {
                                                viewModel.highlightedSlot = rank
                                                break
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        guard viewModel.phase == .placing else { return }
                                        if let slot = viewModel.highlightedSlot {
                                            viewModel.placeItem(atRank: slot)
                                        }
                                        withAnimation(.spring(response: 0.3)) {
                                            viewModel.cardOffset = .zero
                                            viewModel.cardScale = 1.0
                                        }
                                        viewModel.highlightedSlot = nil
                                    }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.5).combined(with: .opacity),
                                removal: .scale(scale: 0.3).combined(with: .opacity)
                            ))
                    }
                    Spacer()
                    Text("Sürükle veya\nslota dokun")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
                }
                .frame(width: geo.size.width * 0.45)
            }
            .coordinateSpace(name: "sharedRankingArea")
            .onPreferenceChange(SharedSlotFrameKey.self) { frames in
                slotFrames = frames
            }
        }
    }
}

struct SharedSlotView: View {
    let rank: Int
    let item: APIQuestionItem?
    let isHighlighted: Bool
    let isOccupied: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(isOccupied ? .white : .orange)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(isOccupied ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Color.orange.opacity(0.15)))
                )

            if let item = item {
                HStack(spacing: 8) {
                    if let img = item.uiImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    }
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isHighlighted ? .orange : .gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1, dash: [6])
                    )
                    .frame(height: 32)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isHighlighted ? .orange.opacity(0.15) :
                    isOccupied ? .green.opacity(0.08) :
                    Color(.secondarySystemGroupedBackground)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHighlighted ? .orange : .clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .animation(.spring(response: 0.35), value: isOccupied)
    }
}

struct SharedItemCard: View {
    let item: APIQuestionItem
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 12) {
            if let img = item.uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.orange.gradient)
                        .frame(width: 100, height: 100)
                    Text(item.name.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(item.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(20)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(
                    color: isDragging ? .orange.opacity(0.3) : .black.opacity(0.1),
                    radius: isDragging ? 16 : 8, y: isDragging ? 8 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.orange.opacity(isDragging ? 0.5 : 0), lineWidth: 2)
        )
    }
}
