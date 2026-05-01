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
        let entries = placements.map { SubmitRankingEntry(itemId: $0.value.id.value, rank: $0.key) }
        try await APIService.shared.submitRanking(questionId: question.id.value, entries: entries)
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
    @State private var submitError: String?

    init(question: APISharedQuestion, popToRoot: (() -> Void)? = nil) {
        self.question = question
        self.popToRoot = popToRoot
        self._viewModel = State(initialValue: SharedRankingViewModel(question: question))
    }

    private var progressFraction: CGFloat {
        guard viewModel.rankCount > 0 else { return 0 }
        return CGFloat(viewModel.currentIndex) / CGFloat(viewModel.rankCount)
    }

    var body: some View {
        ZStack {
            Color.dsBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        showQuitAlert = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Çık")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.dsDeep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.dsSurfaceDim)
                                .overlay(Capsule().strokeBorder(Color.dsHairline, lineWidth: 1))
                        )
                    }
                    Spacer()

                    if viewModel.phase != .ready && viewModel.phase != .complete {
                        Text("\(viewModel.currentIndex + 1) / \(viewModel.rankCount)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.dsDeep)
                            .contentTransition(.numericText())
                    }

                    if question.maxAttempts > 1 {
                        Spacer()
                        Text("\(question.userAttemptCount + (didSave ? 1 : 0))/\(question.maxAttempts) hak")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dsAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.dsAccentSoft))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)

                // Progress bar
                if viewModel.phase != .ready {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.dsSurfaceDim)
                                .frame(height: 3)
                            Rectangle()
                                .fill(Color.dsAccent)
                                .frame(width: geo.size.width * progressFraction, height: 3)
                                .animation(.easeInOut(duration: 0.3), value: progressFraction)
                        }
                    }
                    .frame(height: 3)
                }

                // Question header
                VStack(alignment: .leading, spacing: 6) {
                    Text("SORU · \(question.groupName.uppercased())")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.dsMuted)
                    Text(question.text)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.dsDeep)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if alreadyRanked {
                    alreadyRankedView
                        .frame(maxWidth: 500)
                } else if viewModel.phase == .ready {
                    readyView
                        .frame(maxWidth: 500)
                } else if viewModel.phase == .complete {
                    completeView
                        .frame(maxWidth: 600)
                } else {
                    rankingArea
                        .frame(maxWidth: 900)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Çıkmak istediğine emin misin?", isPresented: $showQuitAlert) {
            Button("Çık", role: .destructive) { dismiss() }
            Button("Devam Et", role: .cancel) { }
        } message: {
            Text("Sıralaman kaybolacak.")
        }
        .task {
            if question.userAttemptCount >= question.maxAttempts {
                alreadyRanked = true
            } else {
                // Double-check from server
                let rankings = (try? await APIService.shared.getRankings(questionId: question.id.value)) ?? []
                let me = APIService.shared.username
                let myCount = rankings.filter { $0.participantName == me || $0.participantName == APIService.shared.currentUser?.displayName }.count
                if myCount >= question.maxAttempts {
                    alreadyRanked = true
                }
            }
        }
        .onChange(of: submitError) {
            if submitError != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    submitError = nil
                }
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

    private func submitAndThen(_ action: @escaping () -> Void) async {
        if !didSave {
            do {
                try await viewModel.submitToServer()
                didSave = true
                action()
            } catch {
                submitError = "Gönderilemedi, tekrar dene."
            }
        } else {
            action()
        }
    }

    private var alreadyRankedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.dsAccent)
            Text("Zaten sıraladın!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.dsDeep)
            Text(question.maxAttempts > 1
                 ? "Bu soruyu \(question.userAttemptCount)/\(question.maxAttempts) kez cevapladın."
                 : "Bu soruyu daha önce cevapladın.")
                .foregroundStyle(Color.dsMuted)

            Button {
                showResults = true
            } label: {
                Text("Sonuçları Gör")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dsDeep, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)

            Button {
                if let popToRoot { popToRoot() } else { dismiss() }
            } label: {
                Text("Geri Dön")
                    .font(.system(size: 17, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dsSurfaceDim, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.dsDeep)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                SiralalaMarkView(size: 60, color: .dsAccent)

                Text("Hazır mısın?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.dsDeep)
                Text("\(viewModel.rankCount) öğeyi sıralayacaksın.\nHer öğe tek tek gelecek ve\nyerleştirdikten sonra değiştiremezsin!")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .multilineTextAlignment(.center)

                if question.maxAttempts > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(question.maxAttempts - question.userAttemptCount) cevaplama hakkın kaldı")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.dsAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color.dsAccentSoft)
                    )
                }
            }
            Button {
                viewModel.startRanking()
            } label: {
                Text("Başla")
                    .font(.system(size: 19, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dsDeep, in: RoundedRectangle(cornerRadius: 16))
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
                    .foregroundStyle(Color.dsAccent)

                Text("Tamamlandı!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.dsDeep)

                VStack(spacing: 8) {
                    ForEach(1...viewModel.rankCount, id: \.self) { rank in
                        if let item = viewModel.placements[rank] {
                            HStack(spacing: 12) {
                                RankChip(number: rank, style: rank <= 3 ? .accent : .soft)
                                if let img = item.uiImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.dsAccentSoft)
                                            .frame(width: 36, height: 36)
                                        Text(item.name.prefix(1).uppercased())
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.dsAccent)
                                    }
                                }
                                Text(item.name)
                                    .font(.body)
                                    .foregroundStyle(Color.dsDeep)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 24)

                if let submitError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                        Text(submitError)
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                }

                Button {
                    Task { await submitAndThen { showResults = true } }
                } label: {
                    Text("Sonuçları Gör")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.dsDeep, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)

                Button {
                    Task {
                        await submitAndThen {
                            if let popToRoot {
                                popToRoot()
                            } else {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    Text("Ana Sayfaya Dön")
                        .font(.system(size: 17, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.dsSurfaceDim, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color.dsDeep)
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
                        ZStack {
                            // Ghost cards behind
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.dsSurfaceDim.opacity(0.5))
                                .frame(width: 140, height: 180)
                                .rotationEffect(.degrees(6))
                                .offset(x: 8, y: 4)
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.dsSurfaceDim.opacity(0.3))
                                .frame(width: 140, height: 180)
                                .rotationEffect(.degrees(-4))
                                .offset(x: -6, y: 6)

                            SharedItemCard(item: item, isDragging: viewModel.phase == .placing)
                                .rotationEffect(.degrees(-2))
                        }
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

                    // Bottom floating card label
                    if let item = viewModel.currentItem, viewModel.showCard {
                        VStack(spacing: 8) {
                            Text("ŞU ANKİ ÖĞE")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(Color.dsMuted)
                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.dsDeep)
                        }
                        .padding(.bottom, 16)
                    } else {
                        Text("Sürükle veya\nslota dokun")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 20)
                    }
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
            RankChip(number: rank, style: isOccupied ? .accent : .soft)

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
                        .foregroundStyle(Color.dsDeep)
                        .lineLimit(1)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                if isHighlighted {
                    Text("BURAYA BIRAK")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.dsAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 32)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsUltraMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 32)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isHighlighted ? Color.dsAccentSoft :
                    isOccupied ? Color.dsSurface :
                    Color.dsSurface
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHighlighted ? Color.dsAccent :
                    Color.dsHairline,
                    style: isHighlighted ? StrokeStyle(lineWidth: 2, dash: [6]) : StrokeStyle(lineWidth: 1),
                    antialiased: true
                )
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
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.dsDeep)
                        .frame(width: 80, height: 80)
                    Text(item.name.prefix(1).uppercased())
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(item.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.dsDeep)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(18)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dsSurface)
                .shadow(
                    color: isDragging ? Color.dsAccent.opacity(0.25) : Color.black.opacity(0.08),
                    radius: isDragging ? 16 : 8, y: isDragging ? 8 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.dsHairline, lineWidth: 1)
        )
    }
}
