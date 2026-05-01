import SwiftUI

struct FriendsView: View {
    @State private var friends: [APIFriend] = []
    @State private var friendCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var friendToRemove: APIFriend?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero title
                Text("Arkadaşlar")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.dsDeep)
                    .padding(.top, 8)

                // Combined card
                VStack(spacing: 0) {
                    // Top half: your code
                    if let user = APIService.shared.currentUser {
                        VStack(spacing: 8) {
                            Text("SENİN KODUN")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(Color.dsMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Text(user.friendCode)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.dsDeep)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = user.friendCode
                                    successMessage = "Kod kopyalandı!"
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.dsDeep)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.dsSurfaceDim))
                                }
                            }
                        }
                        .padding(18)

                        Divider().background(Color.dsHairline)
                    }

                    // Bottom half: add code
                    VStack(spacing: 8) {
                        Text("Kod ekle")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.dsMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            TextField("Arkadaş kodu", text: $friendCode)
                                .textInputAutocapitalization(.characters)
                                .submitLabel(.done)
                                .font(.system(size: 17, design: .monospaced))
                                .foregroundStyle(Color.dsDeep)

                            Button {
                                Task { await addFriend() }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .frame(width: 36, height: 36)
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.dsDeep))
                                }
                            }
                            .disabled(friendCode.count < 6 || isLoading)
                        }
                    }
                    .padding(18)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dsSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.dsHairline, lineWidth: 1)
                        )
                )
                .padding(.top, 24)

                // Friends section
                VStack(alignment: .leading, spacing: 0) {
                    Text("ARKADAŞLARIN (\(friends.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.dsMuted)
                        .padding(.bottom, 12)

                    if friends.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "Henüz arkadaş yok",
                            description: "Arkadaş kodunu paylaş veya\nyukarıdan kod ekle."
                        )
                        .padding(.vertical, 8)
                    } else {
                        ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                            VStack(spacing: 0) {
                                HStack(spacing: 14) {
                                    // Avatar
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
                                        friendToRemove = friend
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.dsMuted)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(Color.dsSurfaceDim))
                                    }
                                }
                                .padding(.vertical, 12)

                                if index < friends.count - 1 {
                                    Divider().background(Color.dsHairline)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 32)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dsBg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
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
        .alert("Arkadaşı silmek istediğine emin misin?", isPresented: .init(
            get: { friendToRemove != nil },
            set: { if !$0 { friendToRemove = nil } }
        )) {
            Button("Sil", role: .destructive) {
                if let friend = friendToRemove {
                    Task {
                        do {
                            try await APIService.shared.removeFriend(id: friend.id.value)
                            await loadFriends()
                        } catch {
                            errorMessage = "Arkadaş silinemedi."
                        }
                        friendToRemove = nil
                    }
                }
            }
            Button("Vazgeç", role: .cancel) { friendToRemove = nil }
        } message: {
            if let friend = friendToRemove {
                Text("\(friend.displayName) arkadaş listenden çıkarılacak.")
            }
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
