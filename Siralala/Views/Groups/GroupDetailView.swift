import SwiftUI

struct GroupDetailView: View {
    let group: APIGroup
    @State private var questions: [APIGroupQuestion] = []
    @State private var pools: [APISharedPool] = []
    @State private var isLoading = true

    private var myUserId: Int? {
        APIService.shared.currentUser?.id
    }

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

            Section("Havuzlar (\(pools.count))") {
                if pools.isEmpty && !isLoading {
                    Text("Henüz paylaşılan havuz yok")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pools) { pool in
                        NavigationLink {
                            SharedPoolQuestionView(pool: pool, group: group)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.purple.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .foregroundStyle(.purple)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pool.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(pool.creatorName) · \(pool.itemCount) öğe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Soru Sor")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.purple)
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions(edge: .trailing) {
                            if pool.creatorId == myUserId {
                                Button(role: .destructive) {
                                    Task {
                                        try? await APIService.shared.deleteSharedPool(id: pool.id)
                                        await loadData()
                                    }
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
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
                        .swipeActions(edge: .trailing) {
                            if question.creatorId == myUserId {
                                Button(role: .destructive) {
                                    Task {
                                        try? await APIService.shared.deleteQuestion(id: question.id)
                                        await loadData()
                                    }
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        async let q = APIService.shared.getGroupQuestions(groupId: group.id)
        async let p = APIService.shared.getGroupPools(groupId: group.id)
        questions = (try? await q) ?? []
        pools = (try? await p) ?? []
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
