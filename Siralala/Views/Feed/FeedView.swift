import SwiftUI
import SwiftData

extension Notification.Name {
    static let feedNeedsRefresh = Notification.Name("feedNeedsRefresh")
}

enum QuestionNavigation: Hashable {
    case ranking(APISharedQuestion)
    case results(APISharedQuestion)

    static func == (lhs: QuestionNavigation, rhs: QuestionNavigation) -> Bool {
        switch (lhs, rhs) {
        case (.ranking(let a), .ranking(let b)): return a.id == b.id
        case (.results(let a), .results(let b)): return a.id == b.id
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .ranking(let q): hasher.combine("ranking"); hasher.combine(q.id)
        case .results(let q): hasher.combine("results"); hasher.combine(q.id)
        }
    }
}

struct FeedView: View {
    @State private var pendingQuestions: [APISharedQuestion] = []
    @State private var navigationPath = NavigationPath()
    @State private var isLoading = true
    @State private var showGuide = false

    private var username: String {
        APIService.shared.currentUser?.displayName ?? APIService.shared.username
    }

    func popToRoot() {
        navigationPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .feedNeedsRefresh, object: nil)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        SiralalaWordmark()
                        Spacer()
                        Button { showGuide = true } label: {
                            Image(systemName: "questionmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.dsDeep)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .strokeBorder(Color.dsHairline, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Hero greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Merhaba \(username).")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.dsDeep)
                        if isLoading {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.dsSurfaceDim)
                                .frame(width: 240, height: 28)
                        } else {
                            Text("Bekleyen \(pendingQuestions.count) soru var.")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 28)

                    if isLoading {
                        VStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.dsSurfaceDim)
                                    .frame(height: 100)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else if pendingQuestions.isEmpty {
                        emptyState
                            .frame(maxWidth: 500)
                            .frame(maxWidth: .infinity)
                    } else {
                        pendingSection
                            .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .background(Color.dsBg.ignoresSafeArea())
            .refreshable { await loadQuestions() }
            .task { await loadQuestions() }
            .onReceive(NotificationCenter.default.publisher(for: .feedNeedsRefresh)) { _ in
                Task { await loadQuestions() }
            }
            .navigationDestination(for: QuestionNavigation.self) { nav in
                switch nav {
                case .ranking(let question):
                    SharedRankingContainerView(question: question, popToRoot: popToRoot)
                case .results(let question):
                    SharedResultsView(question: question, popToRoot: popToRoot)
                }
            }
            .sheet(isPresented: $showGuide) {
                GuideView()
            }
        }
    }

    private func loadQuestions() async {
        pendingQuestions = (try? await APIService.shared.getPendingQuestions()) ?? []
        isLoading = false
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "tray",
            title: "Henüz bekleyen soru yok",
            description: "Bir havuz oluştur, arkadaşlarınla\ngrup kur ve ilk soruyu gönder!"
        )
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SENİN SIRAN")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Color.dsAccent)
                .textCase(.uppercase)

            ForEach(pendingQuestions) { question in
                NavigationLink(value: QuestionNavigation.ranking(question)) {
                    PendingQuestionCard(question: question, onDismiss: {
                        Task {
                            try? await APIService.shared.dismissQuestion(id: question.id.value)
                            await loadQuestions()
                        }
                    })
                }
                .buttonStyle(.plain)
            }
        }
    }

}

// MARK: - Questions Tab (Completed)

struct QuestionsView: View {
    @State private var completedQuestions: [APISharedQuestion] = []
    @State private var navigationPath = NavigationPath()
    @State private var isLoading = true

    func popToRoot() {
        navigationPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .feedNeedsRefresh, object: nil)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sorular")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.dsDeep)
                        Text("Cevapladığın soruların sonuçları")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.dsMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.top, 40)
                    } else if completedQuestions.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "Henüz cevaplanmış soru yok",
                            description: "Ana sayfadaki soruları cevapla,\nsonuçları burada gör."
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(completedQuestions) { question in
                                NavigationLink(value: QuestionNavigation.results(question)) {
                                    CompletedQuestionCard(question: question, onDismiss: {
                                        Task {
                                            try? await APIService.shared.dismissQuestion(id: question.id.value)
                                            await loadData()
                                        }
                                    })
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .background(Color.dsBg.ignoresSafeArea())
            .refreshable { await loadData() }
            .task { await loadData() }
            .onReceive(NotificationCenter.default.publisher(for: .feedNeedsRefresh)) { _ in
                Task { await loadData() }
            }
            .navigationDestination(for: QuestionNavigation.self) { nav in
                switch nav {
                case .ranking(let question):
                    SharedRankingContainerView(question: question, popToRoot: popToRoot)
                case .results(let question):
                    SharedResultsView(question: question, popToRoot: popToRoot)
                }
            }
        }
    }

    private func loadData() async {
        completedQuestions = (try? await APIService.shared.getCompletedQuestions()) ?? []
        isLoading = false
    }
}

struct PendingQuestionCard: View {
    let question: APISharedQuestion
    var onDismiss: (() -> Void)? = nil
    @State private var showDismissAlert = false

    private var remainingAttempts: Int {
        question.maxAttempts - question.userAttemptCount
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dsDeep)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 0) {
                    Text("\(remainingAttempts) hak")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dsAccent)
                    Text(" \u{00B7} ")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsMuted)
                    Text("\(question.poolName) \u{00B7} \(question.completionCount) katılım")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsMuted)
                }
            }

            Spacer(minLength: 0)

            // Play button
            Image(systemName: "play.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.dsDeep))

            // Dismiss button
            if onDismiss != nil {
                Button {
                    showDismissAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.dsMuted)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.dsSurfaceDim))
                }
            }
        }
        .padding(14)
        .padding(.leading, 2)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.dsHairline, lineWidth: 1)
                )
        )
        .alert("Bu soruyu gizlemek istediğine emin misin?", isPresented: $showDismissAlert) {
            Button("Gizle", role: .destructive) { onDismiss?() }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Soru ana sayfandan kaldırılacak.")
        }
    }
}

struct CompletedQuestionCard: View {
    let question: APISharedQuestion
    var onDismiss: (() -> Void)? = nil
    @State private var showDismissAlert = false

    var body: some View {
        HStack(spacing: 12) {
            RankChip(number: 1, style: .accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(question.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dsDeep)
                    .lineLimit(1)
                Text("Grup kazananı: \(question.poolName) · \(question.completionCount) katılım")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsMuted)
                    .lineLimit(1)
            }

            Spacer()

            if onDismiss != nil {
                Button {
                    showDismissAlert = true
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsUltraMuted)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dsUltraMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.dsHairline, lineWidth: 1)
                )
        )
        .alert("Ana sayfadan gizle", isPresented: $showDismissAlert) {
            Button("Gizle", role: .destructive) { onDismiss?() }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Bu soru ana sayfandan kaldırılacak. Grup detayından hâlâ erişebilirsin.")
        }
    }
}

// MARK: - Guide View

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let steps: [(icon: String, title: String, desc: String)] = [
        ("square.stack", "Havuz Oluştur",
         "Sıralamak istediğin öğeleri bir havuzda topla.\nÖrneğin: Filmler, Şarkılar, Futbolcular..."),
        ("person.3.fill", "Grup Kur",
         "Arkadaş kodunu paylaşarak arkadaşlarını ekle.\nSonra bir grup oluşturup onları davet et."),
        ("paperplane.fill", "Soru Gönder",
         "Havuzundan bir soru oluştur ve grubuna gönder.\nKaç öğe sıralansın, kaç hak olsun — sen belirle."),
        ("hand.draw.fill", "Sırala",
         "Öğeler tek tek karşına gelir.\nSürükle veya dokun, slotlara yerleştir.\nYerleştirdikten sonra değiştiremezsin!"),
        ("chart.bar.fill", "Sonuçları Gör",
         "Herkes sıraladıktan sonra grup ortalamasını,\nen çekişmeli öğeyi ve uyum yüzdesini gör.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dsMuted)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.dsSurfaceDim))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Content
            let step = steps[currentStep]

            VStack(spacing: 24) {
                // Icon
                Image(systemName: step.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(Color.dsAccent)
                    .frame(width: 90, height: 90)
                    .background(
                        Circle().fill(Color.dsAccentSoft)
                    )

                // Step indicator
                Text("\(currentStep + 1)/\(steps.count)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.dsMuted)

                // Title
                Text(step.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.dsDeep)

                // Description
                Text(step.desc)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dsMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Dots
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentStep ? Color.dsDeep : Color.dsHairline)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 24)

            // Buttons
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button {
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Text("Geri")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.dsDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.dsSurfaceDim)
                            )
                    }
                }

                Button {
                    if currentStep < steps.count - 1 {
                        withAnimation { currentStep += 1 }
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(currentStep < steps.count - 1 ? "Devam" : "Anladım")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.dsDeep)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.dsBg.ignoresSafeArea())
    }
}
