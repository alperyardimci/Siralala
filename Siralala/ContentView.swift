import SwiftUI

struct ContentView: View {
    @State private var isRegistered = !UserDefaults.standard.string(forKey: "userName").isNilOrEmpty
    @State private var selectedTab = 0
    @State private var isReady = false

    var body: some View {
        if isRegistered {
            if isReady {
                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case 0: FeedView()
                        case 1: QuestionsView()
                        case 2: PoolListView()
                        case 3: ProfileView()
                        default: FeedView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    CustomTabBar(selectedTab: $selectedTab)
                }
                .ignoresSafeArea(.keyboard)
            } else {
                // Splash while loading user data
                ZStack {
                    Color.dsBg.ignoresSafeArea()
                    VStack(spacing: 16) {
                        SiralalaWordmark()
                        ProgressView()
                            .tint(Color.dsDeep)
                    }
                }
                .task {
                    let name = APIService.shared.username
                    guard !name.isEmpty else { isReady = true; return }
                    if let existing = try? await APIService.shared.getMe() {
                        APIService.shared.currentUser = existing
                    } else {
                        _ = try? await APIService.shared.register(username: name, displayName: name)
                    }
                    isReady = true
                }
            }
        } else {
            OnboardingView(isRegistered: $isRegistered)
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack {
            tabItem(index: 0, icon: "house", label: "Anasayfa")
            tabItem(index: 1, icon: "list.clipboard", label: "Sorular")
            tabItem(index: 2, icon: "square.stack", label: "Havuzlar")
            tabItem(index: 3, icon: "person", label: "Profil")
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .padding(.horizontal, 8)
        .background(
            Color.dsBg.opacity(0.88)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.dsHairline).frame(height: 1)
                }
        )
    }

    private func tabItem(index: Int, icon: String, label: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                // Active indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(selectedTab == index ? Color.dsAccent : .clear)
                    .frame(width: 36, height: 3)

                Image(systemName: icon)
                    .font(.system(size: 19, weight: selectedTab == index ? .medium : .light))
                    .foregroundStyle(selectedTab == index ? Color.dsDeep : Color.dsUltraMuted)
                    .frame(height: 22)

                Text(label)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .foregroundStyle(selectedTab == index ? Color.dsDeep : Color.dsUltraMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingView: View {
    @Binding var isRegistered: Bool
    @State private var userName: String = ""
    @State private var isLoading = false
    @State private var setupStep = 0 // 0=idle, 1=account, 2=pools, 3=questions, 4=done

    var body: some View {
        ZStack {
            Color.dsBg.ignoresSafeArea()

            if isLoading {
                setupProgressView
            } else {
                registrationForm
            }
        }
    }

    private var registrationForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SiralalaWordmark()
                    .padding(.top, 20)

                Spacer().frame(height: 48)

                heroText
                    .padding(.trailing, 16)

                Spacer().frame(height: 20)

                Text("Öğeler tek tek gelir, yerleştirdiğinde değişmez. Öyle sıralanır ki herkesin farklı çıkar.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dsMuted)
                    .lineSpacing(4)

                Spacer().frame(height: 40)

                TextField("Kullanıcı adın", text: $userName)
                    .foregroundStyle(Color.dsDeep)
                    .submitLabel(.done)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.dsHairline, lineWidth: 1)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsSurface))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Spacer().frame(height: 16)

                Button {
                    Task { await register() }
                } label: {
                    Text("Başla")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Color.dsDeep, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(userName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)

                Spacer().frame(height: 24)

                Text("Hesap gerektirmez \u{00B7} Arkadaş koduyla katıl")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsUltraMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private var setupProgressView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated logo
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.dsAccent)
                        .frame(width: 10, height: CGFloat([16, 26, 36][i]))
                        .opacity(setupStep > i ? 1 : 0.25)
                        .animation(.easeInOut(duration: 0.5).delay(Double(i) * 0.15), value: setupStep)
                }
            }
            .frame(height: 36, alignment: .bottom)
            .padding(.bottom, 28)

            // Greeting
            (Text("Hoş geldin, ")
                .foregroundStyle(Color.dsDeep) +
            Text(userName.trimmingCharacters(in: .whitespaces))
                .foregroundStyle(Color.dsAccent))
                .font(.system(size: 24, weight: .bold))

            Text("Sana özel içerik hazırlanıyor...")
                .font(.system(size: 14))
                .foregroundStyle(Color.dsMuted)
                .padding(.top, 6)

            // Step list
            VStack(spacing: 0) {
                setupStepRow(
                    step: 1,
                    icon: "person.crop.circle.badge.checkmark",
                    title: "Hesap oluşturuldu",
                    subtitle: "Arkadaş kodun hazır"
                )
                Divider().background(Color.dsHairline)
                setupStepRow(
                    step: 2,
                    icon: "square.stack",
                    title: "Havuzlar ekleniyor",
                    subtitle: "Futbolcular, Yemekler, Filmler"
                )
                Divider().background(Color.dsHairline)
                setupStepRow(
                    step: 3,
                    icon: "text.bubble",
                    title: "Sorular hazırlanıyor",
                    subtitle: "3 soru oluşturuluyor"
                )
            }
            .padding(.top, 36)
            .padding(.horizontal, 8)
            .frame(maxWidth: 320)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.dsSurfaceDim)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.dsAccent)
                        .frame(width: geo.size.width * progressFraction, height: 4)
                        .animation(.easeInOut(duration: 0.4), value: setupStep)
                }
            }
            .frame(height: 4)
            .frame(maxWidth: 280)
            .padding(.top, 32)

            Spacer()
        }
    }

    private var progressFraction: CGFloat {
        switch setupStep {
        case 0: return 0.05
        case 1: return 0.33
        case 2: return 0.66
        case 3: return 0.9
        default: return 1.0
        }
    }

    private func setupStepRow(step: Int, icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: setupStep >= step ? "checkmark.circle.fill" : icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    setupStep > step ? .green :
                    setupStep == step ? Color.dsAccent :
                    Color.dsUltraMuted
                )
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            setupStep > step ? Color.green.opacity(0.1) :
                            setupStep == step ? Color.dsAccentSoft :
                            Color.dsSurfaceDim
                        )
                )

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        setupStep >= step ? Color.dsDeep : Color.dsUltraMuted
                    )
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsMuted)
            }

            Spacer()

            // Status
            if setupStep > step {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
            } else if setupStep == step {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.vertical, 14)
        .opacity(setupStep >= step ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.3), value: setupStep)
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text("Bir ")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.dsDeep)
                Text("liste")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.dsAccent)
                Text(".")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.dsDeep)
            }
            Text("Tek atış.")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color.dsDeep)
            Text("Arkadaşlarınla")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color.dsDeep)
            Text("kıyasla.")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color.dsDeep)
        }
    }

    private func register() async {
        let name = userName.trimmingCharacters(in: .whitespaces)
        isLoading = true
        setupStep = 0
        UserDefaults.standard.set(name, forKey: "userName")

        // Step 1: Create account
        for _ in 1...3 {
            if let _ = try? await APIService.shared.register(username: name, displayName: name) {
                withAnimation { setupStep = 1 }
                await seedDemoContent(username: name)
                break
            }
            try? await Task.sleep(for: .seconds(2))
        }

        withAnimation { setupStep = 4 }
        try? await Task.sleep(for: .milliseconds(400))
        isRegistered = true
    }

    private func seedDemoContent(username: String) async {
        let footballers = [
            "Messi", "Ronaldo", "Neymar", "Mbappé", "Haaland",
            "Salah", "De Bruyne", "Modriç", "Kroos", "Benzema",
            "Lewandowski", "Vinícius Jr.", "Bellingham", "Saka", "Foden",
            "Müller", "Kimmich", "Pedri", "Gavi", "Yamal",
            "Arda Güler", "Hakan Çalhanoğlu", "İlkay Gündoğan", "Erling Braut Haaland",
            "Bruno Fernandes", "Jude Bellingham", "Phil Foden", "Bukayo Saka",
            "Lamine Yamal", "Florian Wirtz"
        ]

        let foods = [
            "Kebap", "Lahmacun", "Pide", "Mantı", "İskender",
            "Köfte", "Baklava", "Künefe", "Sushi", "Pizza",
            "Hamburger", "Makarna", "Çiğ Köfte", "Tantuni", "Kokoreç",
            "Döner", "Kumpir", "Midye Dolma", "Mercimek Çorbası", "Menemen",
            "Börek", "Sarma", "İmam Bayıldı", "Hünkar Beğendi", "Karnıyarık",
            "Adana Kebap", "Urfa Kebap", "Ali Nazik", "Çılbır", "Simit"
        ]

        let movies = [
            "Esaretin Bedeli", "Baba", "Kara Şövalye", "Yüzüklerin Efendisi", "Forrest Gump",
            "Yıldızlararası", "Matrix", "Dövüş Kulübü", "Başlangıç", "Parazit",
            "Gladyatör", "Schindler'in Listesi", "Yeşil Yol", "Terminatör 2", "Titanik",
            "Joker", "Avengers: Endgame", "Prestij", "Whiplash", "Django",
            "Amelie", "Hayat Güzeldir", "Olağan Şüpheliler", "Braveheart", "Rocky",
            "Karayip Korsanları", "Harry Potter", "Star Wars", "Jurassic Park", "Avatar"
        ]

        struct PoolDef {
            let name: String
            let items: [String]
            let questionText: String
        }

        let pools = [
            PoolDef(name: "Efsane Futbolcular", items: footballers, questionText: "En iyi futbolcu kim?"),
            PoolDef(name: "Yemekler", items: foods, questionText: "En sevdiğin yemek hangisi?"),
            PoolDef(name: "Filmler", items: movies, questionText: "En iyi film hangisi?")
        ]

        do {
            let group = try await APIService.shared.createGroup(
                name: "Sıralala Demo",
                memberUsernames: []
            )

            // Step 2: Create pools
            withAnimation { setupStep = 2 }
            for pool in pools {
                let shareItems = pool.items.map { ShareQuestionItem(name: $0, imageData: nil) }
                try await APIService.shared.sharePool(
                    groupId: group.id.value,
                    name: pool.name,
                    items: shareItems
                )
            }

            // Step 3: Create questions
            withAnimation { setupStep = 3 }
            for pool in pools {
                let shareItems = pool.items.map { ShareQuestionItem(name: $0, imageData: nil) }
                try await APIService.shared.shareQuestion(
                    groupId: group.id.value,
                    text: pool.questionText,
                    poolName: pool.name,
                    items: shareItems,
                    itemCount: 10,
                    maxAttempts: 1
                )
            }

            NotificationCenter.default.post(name: .feedNeedsRefresh, object: nil)
        } catch {
            // Silent fail — demo content is optional
        }
    }
}

struct ProfileView: View {
    @State private var user: APIUser?
    @State private var isLoading = true
    @State private var friends: [APIFriend] = []
    @State private var groups: [APIGroup] = []

    private var displayName: String {
        user?.displayName ?? APIService.shared.username
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Mark + wordmark
                    SiralalaWordmark()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)

                    if isLoading {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 40)
                            ProgressView()
                            Text("Profil yükleniyor...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dsMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    } else {
                        // Hero
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Profil")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dsMuted)
                                .textCase(.uppercase)

                            Text(displayName)
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(Color.dsDeep)

                            Text("\(friends.count) arkadaş · \(groups.count) grup üyeliği")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.dsMuted)
                        }
                        .padding(.top, 28)

                        // Friend code card
                        if let code = user?.friendCode {
                            VStack(spacing: 10) {
                                Text("ARKADAŞ KODUN")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1.5)
                                    .foregroundStyle(Color.dsMuted)

                                HStack {
                                    Text(code)
                                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.dsDeep)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = code
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.dsDeep)
                                            .frame(width: 36, height: 36)
                                            .background(Circle().fill(Color.dsSurfaceDim))
                                    }
                                }
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.dsSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(Color.dsHairline, lineWidth: 1)
                                    )
                            )
                            .padding(.top, 24)
                        }

                        // Navigation rows
                        VStack(spacing: 0) {
                            NavigationLink(destination: FriendsView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.dsDeep)
                                    Text("Arkadaşlar")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.dsDeep)
                                    Spacer()
                                    Text("\(friends.count)")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.dsMuted)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.dsUltraMuted)
                                }
                                .padding(.vertical, 16)
                            }

                            Divider().background(Color.dsHairline)

                            NavigationLink(destination: GroupListView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.3")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.dsDeep)
                                    Text("Gruplar")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.dsDeep)
                                    Spacer()
                                    Text("\(groups.count)")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.dsMuted)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.dsUltraMuted)
                                }
                                .padding(.vertical, 16)
                            }
                        }
                        .padding(.top, 32)
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Color.dsBg.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                let name = APIService.shared.username
                guard !name.isEmpty else { isLoading = false; return }
                for _ in 1...3 {
                    if let existing = try? await APIService.shared.getMe() {
                        user = existing
                        isLoading = false
                        break
                    }
                    if let registered = try? await APIService.shared.register(username: name, displayName: name) {
                        user = registered
                        isLoading = false
                        break
                    }
                    try? await Task.sleep(for: .seconds(2))
                }
                isLoading = false
                friends = (try? await APIService.shared.getFriends()) ?? []
                groups = (try? await APIService.shared.getGroups()) ?? []
            }
        }
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
