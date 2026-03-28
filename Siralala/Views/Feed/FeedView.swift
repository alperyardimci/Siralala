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
    @State private var completedQuestions: [APISharedQuestion] = []
    @State private var navigationPath = NavigationPath()
    @State private var isLoading = false

    func popToRoot() {
        navigationPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .feedNeedsRefresh, object: nil)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    if pendingQuestions.isEmpty && completedQuestions.isEmpty && !isLoading {
                        emptyState
                    } else {
                        if !pendingQuestions.isEmpty {
                            pendingSection
                        }
                        if !completedQuestions.isEmpty {
                            completedSection
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(.orange.gradient)
                        Text("Sıralala")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
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
        }
    }

    private func loadQuestions() async {
        isLoading = true
        async let p = APIService.shared.getPendingQuestions()
        async let c = APIService.shared.getCompletedQuestions()
        pendingQuestions = (try? await p) ?? []
        completedQuestions = (try? await c) ?? []
        isLoading = false
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange.gradient)

            VStack(spacing: 8) {
                Text("Henüz soru yok")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Havuzlar sekmesinden bir havuz oluştur\nve arkadaş grubuna soru gönder!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bekleyen Sorular", systemImage: "questionmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(pendingQuestions) { question in
                NavigationLink(value: QuestionNavigation.ranking(question)) {
                    PendingQuestionCard(question: question)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tamamlanan", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            ForEach(completedQuestions) { question in
                NavigationLink(value: QuestionNavigation.results(question)) {
                    CompletedQuestionCard(question: question, onDelete: {
                        Task {
                            try? await APIService.shared.deleteQuestion(id: question.id)
                            await loadQuestions()
                        }
                    })
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PendingQuestionCard: View {
    let question: APISharedQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.text)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(question.poolName) · \(question.groupName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
            }

            HStack {
                Label("\(question.itemCount) öğe", systemImage: "square.stack")
                Spacer()
                Label("\(question.completionCount) katılım", systemImage: "person.2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct CompletedQuestionCard: View {
    let question: APISharedQuestion
    var onDelete: (() -> Void)? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.text)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(question.poolName) · \(question.groupName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if onDelete != nil {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }

            HStack {
                Label("\(question.completionCount) katılım", systemImage: "person.2.fill")
                Spacer()
                Text("Sonuçları gör")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .alert("Sıralamayı Sil", isPresented: $showDeleteAlert) {
            Button("Sil", role: .destructive) { onDelete?() }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Bu sıralama ve tüm sonuçları silinecek.")
        }
    }
}
