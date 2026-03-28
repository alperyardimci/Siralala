import SwiftUI

struct FriendsView: View {
    @State private var friends: [APIFriend] = []
    @State private var friendCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        List {
            Section {
                if let user = APIService.shared.currentUser {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Senin Arkadaş Kodun")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(user.friendCode)
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospaced()
                            Spacer()
                            Button {
                                UIPasteboard.general.string = user.friendCode
                                successMessage = "Kod kopyalandı!"
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Arkadaş Ekle") {
                HStack {
                    TextField("Arkadaş kodu", text: $friendCode)
                        .textInputAutocapitalization(.characters)
                        .monospaced()
                    Button {
                        Task { await addFriend() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(.orange)
                        }
                    }
                    .disabled(friendCode.count < 6 || isLoading)
                }
            }

            Section("Arkadaşların (\(friends.count))") {
                if friends.isEmpty {
                    Text("Henüz arkadaş yok")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(friends) { friend in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.orange.gradient)
                                    .frame(width: 36, height: 36)
                                Text(friend.displayName.prefix(1).uppercased())
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            Text(friend.displayName)
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                try? await APIService.shared.removeFriend(id: friends[index].id)
                            }
                            await loadFriends()
                        }
                    }
                }
            }
        }
        .navigationTitle("Arkadaşlar")
        .task { await loadFriends() }
        .alert("Hata", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Tamam") { }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Başarılı", isPresented: .init(get: { successMessage != nil }, set: { if !$0 { successMessage = nil } })) {
            Button("Tamam") { }
        } message: {
            Text(successMessage ?? "")
        }
    }

    private func loadFriends() async {
        friends = (try? await APIService.shared.getFriends()) ?? []
    }

    private func addFriend() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let friend = try await APIService.shared.addFriend(code: friendCode.trimmingCharacters(in: .whitespaces))
            friendCode = ""
            successMessage = "\(friend.displayName) arkadaş olarak eklendi!"
            await loadFriends()
        } catch {
            errorMessage = "Arkadaş bulunamadı. Kodu kontrol et."
        }
    }
}
