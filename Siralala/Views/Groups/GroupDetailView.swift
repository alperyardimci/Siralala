import SwiftUI

struct GroupDetailView: View {
    @State var group: APIGroup
    @State private var questions: [APIGroupQuestion] = []
    @State private var pools: [APISharedPool] = []
    @State private var isLoading = true
    @State private var loadError = false
    @State private var showAddMember = false
    @State private var friends: [APIFriend] = []
    @State private var isAddingMember = false

    private var myUserId: FlexID? {
        APIService.shared.currentUser?.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                VStack(alignment: .leading, spacing: 12) {
                    Text(group.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.dsDeep)

                    // Overlapping member avatars + count + add button
                    HStack(spacing: 8) {
                        HStack(spacing: -10) {
                            ForEach(Array(group.members.prefix(5).enumerated()), id: \.offset) { _, member in
                                ZStack {
                                    Circle()
                                        .fill(Color.dsSurfaceDim)
                                        .frame(width: 32, height: 32)
                                    Text(member.displayName.prefix(1).uppercased())
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.dsDeep)
                                }
                                .overlay(
                                    Circle().strokeBorder(Color.dsBg, lineWidth: 2)
                                )
                            }
                        }

                        Text("\(group.members.count) üye")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dsMuted)

                        Spacer()

                        Button {
                            showAddMember = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Ekle")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color.dsAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.dsAccentSoft)
                            )
                        }
                    }
                }
                .padding(.top, 8)

                // Active questions section
                VStack(alignment: .leading, spacing: 12) {
                    Text("AKTIF SORULAR")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.dsMuted)

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else if loadError {
                        VStack(spacing: 10) {
                            Text("Veriler yüklenemedi.")
                                .font(.system(size: 15))
                                .foregroundStyle(.red)
                            Button {
                                isLoading = true
                                Task { await loadData() }
                            } label: {
                                Label("Tekrar Dene", systemImage: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.dsAccent)
                            }
                        }
                        .padding(.vertical, 20)
                    } else if questions.isEmpty {
                        EmptyStateView(
                            icon: "text.bubble",
                            title: "Henüz soru yok",
                            description: "Bu gruba bir havuzdan\nsoru gönder."
                        )
                    } else {
                        ForEach(questions) { question in
                            NavigationLink {
                                if question.userRanked {
                                    SharedResultsView(question: question.asSharedQuestion)
                                } else {
                                    SharedRankingContainerView(question: question.asSharedQuestion)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(question.text)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(Color.dsDeep)
                                            .multilineTextAlignment(.leading)

                                        HStack(spacing: 6) {
                                            Text(question.poolName)
                                                .font(.system(size: 13))
                                            Text("\u{00B7}")
                                            Text("\(question.completionCount) katılım")
                                                .font(.system(size: 13))
                                        }
                                        .foregroundStyle(Color.dsMuted)
                                    }

                                    Spacer()

                                    if !question.userRanked {
                                        Text("Sırala")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(Color.dsDeep))
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.dsAccent)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.dsSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(Color.dsHairline, lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
                .padding(.top, 28)

                // Pools section
                VStack(alignment: .leading, spacing: 12) {
                    Text("HAVUZLAR")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.dsMuted)

                    if pools.isEmpty && !isLoading {
                        EmptyStateView(
                            icon: "square.stack",
                            title: "Henüz havuz yok",
                            description: "Bu grupla bir havuz paylaş."
                        )
                    } else {
                        ForEach(pools) { pool in
                            NavigationLink {
                                SharedPoolQuestionView(pool: pool, group: group)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pool.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(Color.dsDeep)

                                        Text("\(pool.itemCount) öğe · \(pool.creatorName)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.dsMuted)
                                    }

                                    Spacer()

                                    Text("Soru sor")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.dsAccent)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.dsUltraMuted)
                                }
                                .padding(.vertical, 14)
                            }

                            if pool.id != pools.last?.id {
                                Divider().background(Color.dsHairline)
                            }
                        }
                    }
                }
                .padding(.top, 28)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dsBg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .refreshable { await loadData() }
        .sheet(isPresented: $showAddMember) {
            AddGroupMemberSheet(
                group: group,
                existingMembers: group.members,
                onAdded: { newMember in
                    group.members.append(newMember)
                }
            )
        }
    }

    private func loadData() async {
        loadError = false
        do {
            async let q = APIService.shared.getGroupQuestions(groupId: group.id.value)
            async let p = APIService.shared.getGroupPools(groupId: group.id.value)
            questions = try await q
            pools = try await p
        } catch {
            loadError = true
        }
        isLoading = false
    }
}

struct AddGroupMemberSheet: View {
    let group: APIGroup
    let existingMembers: [APIFriend]
    var onAdded: ((APIFriend) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [APIFriend] = []
    @State private var isLoading = true
    @State private var isAdding: String?
    @State private var errorMessage: String?
    @State private var addedIds: Set<String> = []

    private var availableFriends: [APIFriend] {
        let memberIds = Set(existingMembers.map(\.id.value))
        return friends.filter { !memberIds.contains($0.id.value) && !addedIds.contains($0.id.value) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.top, 40)
                } else if availableFriends.isEmpty {
                    VStack(spacing: 12) {
                        Text("Eklenecek arkadaş kalmadı")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.dsMuted)
                        Text("Tüm arkadaşların zaten bu grupta.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsUltraMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(availableFriends.enumerated()), id: \.element.id) { index, friend in
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.dsSurfaceDim)
                                            .frame(width: 40, height: 40)
                                        Text(friend.displayName.prefix(1).uppercased())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.dsDeep)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.displayName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(Color.dsDeep)
                                        Text(friend.username)
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundStyle(Color.dsMuted)
                                    }

                                    Spacer()

                                    Button {
                                        Task { await addMember(friend) }
                                    } label: {
                                        if isAdding == friend.id.value {
                                            ProgressView()
                                                .frame(width: 60, height: 32)
                                        } else {
                                            Text("Ekle")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.dsDeep, in: Capsule())
                                        }
                                    }
                                    .disabled(isAdding != nil)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)

                                if index < availableFriends.count - 1 {
                                    Divider().padding(.leading, 78)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                Spacer()
            }
            .background(Color.dsBg.ignoresSafeArea())
            .navigationTitle("Üye Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                friends = (try? await APIService.shared.getFriends()) ?? []
                isLoading = false
            }
        }
    }

    private func addMember(_ friend: APIFriend) async {
        isAdding = friend.id.value
        errorMessage = nil
        do {
            try await APIService.shared.addGroupMember(groupId: group.id.value, memberUsername: friend.username)
            addedIds.insert(friend.id.value)
            onAdded?(friend)
        } catch {
            errorMessage = "\(friend.displayName) eklenemedi."
        }
        isAdding = nil
    }
}

struct GroupQuestionRow: View {
    let question: APIGroupQuestion

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.dsDeep)
                HStack(spacing: 6) {
                    Text(question.poolName)
                    Text("\u{00B7}")
                    Text("\(question.completionCount) katılım")
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.dsMuted)
            }

            Spacer()

            if !question.userRanked {
                Text("Sırala")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.dsDeep))
            }
        }
        .padding(.vertical, 2)
    }
}
