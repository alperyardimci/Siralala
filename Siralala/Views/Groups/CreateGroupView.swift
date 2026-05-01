import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String = ""
    @State private var friends: [APIFriend] = []
    @State private var selectedFriends: Set<String> = []
    @State private var isCreating = false
    @State private var showAddFriend = false
    @State private var errorMessage: String?

    var onCreated: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Label + hero
                    Text("YENİ GRUP")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.dsMuted)
                        .padding(.top, 24)

                    Text("Bir isim ver.\nArkadaşlarını seç.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.dsDeep)
                        .padding(.top, 8)

                    // Large borderless input
                    VStack(spacing: 0) {
                        TextField("Grup adı", text: $groupName)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.dsDeep)
                            .submitLabel(.done)
                            .padding(.vertical, 14)

                        Rectangle()
                            .fill(Color.dsDeep)
                            .frame(height: 2)
                    }
                    .padding(.top, 28)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .padding(.top, 16)
                    }

                    // Friends section
                    HStack {
                        Text("ARKADAŞLAR")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.dsMuted)
                        Spacer()
                        if !selectedFriends.isEmpty {
                            Text("\(selectedFriends.count) seçili")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.dsAccent)
                        }
                    }
                    .padding(.top, 32)

                    if friends.isEmpty {
                        VStack(spacing: 12) {
                            Text("Gruba eklemek için arkadaşın olmalı")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.dsMuted)
                            Button {
                                showAddFriend = true
                            } label: {
                                Text("Arkadaş Ekle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.dsDeep, in: Capsule())
                            }
                        }
                        .padding(.top, 16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                                Button {
                                    if selectedFriends.contains(friend.id.value) {
                                        selectedFriends.remove(friend.id.value)
                                    } else {
                                        selectedFriends.insert(friend.id.value)
                                    }
                                } label: {
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

                                        Text(friend.displayName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(Color.dsDeep)

                                        Spacer()

                                        // Check circle
                                        if selectedFriends.contains(friend.id.value) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 28, height: 28)
                                                .background(Circle().fill(Color.dsDeep))
                                        } else {
                                            Circle()
                                                .strokeBorder(Color.dsHairline, lineWidth: 1.5)
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                }

                                if index < friends.count - 1 {
                                    Divider().background(Color.dsHairline)
                                }
                            }
                        }
                        .padding(.top, 12)

                        Button {
                            showAddFriend = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 15))
                                Text("Başka Arkadaş Ekle")
                                    .font(.system(size: 15))
                            }
                            .foregroundStyle(Color.dsAccent)
                            .padding(.top, 12)
                        }
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Color.dsBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(Color.dsDeep)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createGroup() }
                    } label: {
                        Text("Oluştur")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.dsDeep))
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .opacity(groupName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
            }
            .task {
                friends = (try? await APIService.shared.getFriends()) ?? []
            }
            .sheet(isPresented: $showAddFriend) {
                NavigationStack {
                    FriendsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Bitti") {
                                    showAddFriend = false
                                    Task { friends = (try? await APIService.shared.getFriends()) ?? [] }
                                }
                                .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
    }

    private func createGroup() async {
        isCreating = true
        errorMessage = nil
        let memberUsernames = friends.filter { selectedFriends.contains($0.id.value) }.map(\.username)
        do {
            _ = try await APIService.shared.createGroup(
                name: groupName.trimmingCharacters(in: .whitespaces),
                memberUsernames: memberUsernames
            )
            onCreated?()
            dismiss()
        } catch {
            errorMessage = "Grup oluşturulamadı: \(error.localizedDescription)"
            isCreating = false
        }
    }
}
