import SwiftUI
import SwiftData

struct SlotFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct RankingContainerView: View {
    let question: Question
    var popToRoot: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RankingViewModel
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var showQuitAlert = false
    @State private var showResults = false
    @State private var didSave = false

    init(question: Question, popToRoot: (() -> Void)? = nil) {
        self.question = question
        self.popToRoot = popToRoot
        self._viewModel = State(initialValue: RankingViewModel(question: question))
    }

    private var userName: String {
        UserDefaults.standard.string(forKey: "userName") ?? "Ben"
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal)
                    .padding(.top, 8)

                if viewModel.phase == .ready {
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
                    Button("Çık") {
                        showQuitAlert = true
                    }
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
        .sheet(isPresented: $showResults) {
            NavigationStack {
                ResultsView(question: question, popToRoot: popToRoot)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Kapat") {
                                showResults = false
                            }
                        }
                    }
            }
        }
    }

    private var headerView: some View {
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
        .padding(.bottom, 8)
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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 70))
                .foregroundStyle(.green.gradient)

            Text("Tamamlandı!")
                .font(.title)
                .fontWeight(.bold)

            Text("Sıralaman kaydedildi")
                .foregroundStyle(.secondary)

            // Show final ranking
            VStack(spacing: 8) {
                ForEach(1...viewModel.rankCount, id: \.self) { rank in
                    if let item = viewModel.placements[rank] {
                        HStack(spacing: 12) {
                            Text("#\(rank)")
                                .font(.headline)
                                .foregroundStyle(.orange)
                                .frame(width: 40)

                            if let data = item.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
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
                if !didSave {
                    viewModel.saveRanking(context: context, participantName: userName)
                    viewModel.generateMockRankings(context: context, count: 2)
                    didSave = true
                }
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
                if let popToRoot {
                    popToRoot()
                } else {
                    dismiss()
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

            Spacer()
        }
    }

    private var rankingArea: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Slots on the left
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(1...viewModel.rankCount, id: \.self) { rank in
                            RankingSlotView(
                                rank: rank,
                                item: viewModel.placements[rank],
                                isHighlighted: viewModel.highlightedSlot == rank,
                                isOccupied: viewModel.isSlotOccupied(rank)
                            )
                            .background(
                                GeometryReader { slotGeo in
                                    Color.clear
                                        .preference(
                                            key: SlotFramePreferenceKey.self,
                                            value: [rank: slotGeo.frame(in: .named("rankingArea"))]
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

                // Current item card on the right
                VStack {
                    Spacer()
                    if let item = viewModel.currentItem, viewModel.showCard {
                        ItemRevealCard(
                            item: item,
                            isDragging: viewModel.phase == .placing
                        )
                        .offset(viewModel.cardOffset)
                        .scaleEffect(viewModel.cardScale)
                        .gesture(
                            DragGesture(coordinateSpace: .named("rankingArea"))
                                .onChanged { value in
                                    guard viewModel.phase == .placing else { return }
                                    viewModel.cardOffset = value.translation
                                    viewModel.cardScale = 0.85

                                    // Hit test slots
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
            .coordinateSpace(name: "rankingArea")
            .onPreferenceChange(SlotFramePreferenceKey.self) { frames in
                slotFrames = frames
            }
        }
    }
}
