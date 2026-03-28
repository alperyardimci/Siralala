import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String = ""
    @State private var friends: [APIFriend] = []
    @State private var selectedFriends: Set<Int> = []
    @State private var isCreating = false

    var onCreated: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section("Grup Adı") {
                    TextField("Örn: Futbol Grubu", text: $groupName)
                }

                Section("Arkadaşlarını Seç") {
                    if friends.isEmpty {
                        Text("Önce arkadaş ekle")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            Button {
                                if selectedFriends.contains(friend.id) {
                                    selectedFriends.remove(friend.id)
                                } else {
                                    selectedFriends.insert(friend.id)
                                }
                            } label: {
                                HStack {
                                    Text(friend.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedFriends.contains(friend.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.orange)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yeni Grup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") {
                        Task { await createGroup() }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .fontWeight(.semibold)
                }
            }
            .task {
                friends = (try? await APIService.shared.getFriends()) ?? []
            }
        }
    }

    private func createGroup() async {
        isCreating = true
        let memberUsernames = friends.filter { selectedFriends.contains($0.id) }.map(\.username)
        _ = try? await APIService.shared.createGroup(
            name: groupName.trimmingCharacters(in: .whitespaces),
            memberUsernames: memberUsernames
        )
        onCreated?()
        dismiss()
    }
}
