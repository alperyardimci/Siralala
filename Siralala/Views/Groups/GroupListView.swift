import SwiftUI

struct GroupListView: View {
    @State private var groups: [APIGroup] = []
    @State private var showCreateGroup = false

    var body: some View {
        List {
            if groups.isEmpty {
                Text("Henüz grup yok")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.purple.gradient)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "person.3.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.headline)
                                Text(group.members.map(\.displayName).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            try? await APIService.shared.deleteGroup(id: groups[index].id)
                        }
                        await loadGroups()
                    }
                }
            }
        }
        .navigationTitle("Gruplar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateGroup = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView {
                Task { await loadGroups() }
            }
        }
        .task { await loadGroups() }
    }

    private func loadGroups() async {
        groups = (try? await APIService.shared.getGroups()) ?? []
    }
}
