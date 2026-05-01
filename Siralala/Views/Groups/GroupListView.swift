import SwiftUI

struct GroupListView: View {
    @State private var groups: [APIGroup] = []
    @State private var showCreateGroup = false
    @State private var isLoading = true
    @State private var groupToDelete: APIGroup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gruplar")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Color.dsDeep)

                    Text("Sıralamaya arkadaşlarını çağır.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.dsMuted)
                }
                .padding(.top, 8)

                // Group rows
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 40)
                } else if groups.isEmpty {
                    EmptyStateView(
                        icon: "person.3",
                        title: "Henüz grup yok",
                        description: "Arkadaşlarınla grup oluştur\nve birlikte sırala.",
                        buttonLabel: "Grup Oluştur",
                        onAction: { showCreateGroup = true }
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                            HStack(spacing: 0) {
                                NavigationLink(destination: GroupDetailView(group: group)) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name)
                                                .font(.system(size: 19, weight: .semibold))
                                                .foregroundStyle(Color.dsDeep)

                                            HStack(spacing: 6) {
                                                Text("\(group.members.count) üye")
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Color.dsMuted)
                                            }
                                        }

                                        Spacer()

                                        // Member avatar stack
                                        HStack(spacing: -10) {
                                            ForEach(Array(group.members.prefix(4).enumerated()), id: \.offset) { _, member in
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.dsSurfaceDim)
                                                        .frame(width: 30, height: 30)
                                                    Text(member.displayName.prefix(1).uppercased())
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundStyle(Color.dsDeep)
                                                }
                                                .overlay(
                                                    Circle().strokeBorder(Color.dsBg, lineWidth: 2)
                                                )
                                            }
                                            if group.members.count > 4 {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.dsSurfaceDim)
                                                        .frame(width: 30, height: 30)
                                                    Text("+\(group.members.count - 4)")
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(Color.dsMuted)
                                                }
                                                .overlay(
                                                    Circle().strokeBorder(Color.dsBg, lineWidth: 2)
                                                )
                                            }
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.dsUltraMuted)
                                    }
                                }

                                Button {
                                    groupToDelete = group
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.red.opacity(0.7))
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.dsSurfaceDim))
                                }
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 16)

                            if index < groups.count - 1 {
                                Divider().background(Color.dsHairline)
                            }
                        }
                    }
                    .padding(.top, 24)
                }

            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dsBg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.dsDeep))
                }
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView {
                Task { await loadGroups() }
            }
        }
        .task { await loadGroups() }
        .refreshable { await loadGroups() }
        .alert("Grubu silmek istediğine emin misin?", isPresented: .init(
            get: { groupToDelete != nil },
            set: { if !$0 { groupToDelete = nil } }
        )) {
            Button("Sil", role: .destructive) {
                if let group = groupToDelete {
                    Task {
                        try? await APIService.shared.deleteGroup(id: group.id.value)
                        await loadGroups()
                    }
                    groupToDelete = nil
                }
            }
            Button("Vazgeç", role: .cancel) { groupToDelete = nil }
        } message: {
            Text("Gruptaki tüm sorular ve paylaşımlar silinecek.")
        }
    }

    private func loadGroups() async {
        groups = (try? await APIService.shared.getGroups()) ?? []
        isLoading = false
    }
}
