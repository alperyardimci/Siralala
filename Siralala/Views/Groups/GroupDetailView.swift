import SwiftUI

struct GroupDetailView: View {
    let group: APIGroup
    @State private var questions: [APIGroupQuestion] = []
    @State private var isLoading = true

    var body: some View {
        List {
            Section("Üyeler (\(group.members.count))") {
                ForEach(group.members) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.orange.gradient)
                                .frame(width: 32, height: 32)
                            Text(member.displayName.prefix(1).uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        Text(member.displayName)
                            .font(.subheadline)
                    }
                }
            }

            Section("Sorular (\(questions.count))") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if questions.isEmpty {
                    Text("Bu grupta henüz soru yok")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(questions) { question in
                        NavigationLink {
                            if question.userRanked {
                                SharedResultsView(question: question.asSharedQuestion)
                            } else {
                                SharedRankingContainerView(question: question.asSharedQuestion)
                            }
                        } label: {
                            GroupQuestionRow(question: question)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadQuestions() }
        .refreshable { await loadQuestions() }
    }

    private func loadQuestions() async {
        questions = (try? await APIService.shared.getGroupQuestions(groupId: group.id)) ?? []
        isLoading = false
    }
}

struct GroupQuestionRow: View {
    let question: APIGroupQuestion

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(question.userRanked ? .green.opacity(0.15) : .orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: question.userRanked ? "checkmark.circle.fill" : "questionmark.circle")
                    .foregroundStyle(question.userRanked ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(question.poolName)
                    Text("·")
                    Text("\(question.completionCount) katılım")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !question.userRanked {
                Text("Sırala")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
