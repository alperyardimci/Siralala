import SwiftUI

struct ContentView: View {
    @State private var isRegistered = !UserDefaults.standard.string(forKey: "userName").isNilOrEmpty

    var body: some View {
        if isRegistered {
            TabView {
                FeedView()
                    .tabItem {
                        Label("Anasayfa", systemImage: "house.fill")
                    }

                PoolListView()
                    .tabItem {
                        Label("Havuzlar", systemImage: "square.stack.3d.up.fill")
                    }

                ProfileView()
                    .tabItem {
                        Label("Profil", systemImage: "person.fill")
                    }
            }
            .tabViewStyle(.tabBarOnly)
            .tint(.orange)
            .task {
                let name = APIService.shared.username
                guard !name.isEmpty, APIService.shared.currentUser == nil else { return }
                if let existing = try? await APIService.shared.getMe() {
                    APIService.shared.currentUser = existing
                } else {
                    _ = try? await APIService.shared.register(username: name, displayName: name)
                }
            }
        } else {
            OnboardingView(isRegistered: $isRegistered)
        }
    }
}

struct OnboardingView: View {
    @Binding var isRegistered: Bool
    @State private var userName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 70))
                .foregroundStyle(.orange.gradient)

            Text("Sıralala")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Rastgele sıralama ile arkadaşlarını şaşırt!")
                .foregroundStyle(.secondary)

            TextField("Kullanıcı adın", text: $userName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await register() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Başla")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
            .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 48)
    }

    private func register() async {
        isLoading = true
        errorMessage = nil
        let name = userName.trimmingCharacters(in: .whitespaces)

        // Retry up to 3 times with delay
        for attempt in 1...3 {
            do {
                _ = try await APIService.shared.register(username: name, displayName: name)
                UserDefaults.standard.set(name, forKey: "userName")
                await MainActor.run {
                    isRegistered = true
                }
                isLoading = false
                return
            } catch {
                if attempt < 3 {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        errorMessage = "Bağlantı kurulamadı. İnternet bağlantınızı kontrol edip tekrar deneyin."
        isLoading = false
    }
}

struct ProfileView: View {
    @State private var user: APIUser?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.orange.gradient)
                                .frame(width: 70, height: 70)
                            Text((user?.displayName ?? "?").prefix(1).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user?.displayName ?? "")
                                .font(.title3)
                                .fontWeight(.semibold)
                            if let code = user?.friendCode {
                                HStack(spacing: 4) {
                                    Text("Kod: \(code)")
                                        .font(.caption)
                                        .monospaced()
                                        .foregroundStyle(.secondary)
                                    Button {
                                        UIPasteboard.general.string = code
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    NavigationLink(destination: FriendsView()) {
                        Label("Arkadaşlar", systemImage: "person.2.fill")
                    }
                    NavigationLink(destination: GroupListView()) {
                        Label("Gruplar", systemImage: "person.3.fill")
                    }
                }
            }
            .navigationTitle("Profil")
            .task {
                let name = APIService.shared.username
                guard !name.isEmpty else { return }
                if let existing = try? await APIService.shared.getMe() {
                    user = existing
                } else {
                    user = try? await APIService.shared.register(username: name, displayName: name)
                }
            }
        }
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
