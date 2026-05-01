# Siralala

Arkadaşlarınla sıralama yapabileceğin iOS uygulaması. Havuzlar oluştur, gruplara soru gönder, öğeleri tek tek sırala ve sonuçları karşılaştır.

## Özellikler

- **Havuz Yönetimi** — Sıralamak istediğin öğeleri havuzlarda topla (Filmler, Yemekler, Futbolcular vb.)
- **Grup Sistemi** — Arkadaş koduyla arkadaş ekle, gruplar oluştur, sonradan üye davet et
- **Soru Oluşturma** — Havuzdan soru oluştur, birden fazla gruba gönder, öğe sayısını ve katılım hakkını belirle
- **Sıralama Mekaniği** — Öğeler tek tek gelir, sürükle veya dokun, yerleştirdikten sonra değiştiremezsin
- **Sonuç Analizi** — Grup ortalaması, uyum yüzdesi, en çekişmeli öğe, katılımcı bazlı sonuçlar
- **Çoklu Katılım** — Aynı soruya birden fazla cevaplama hakkı verilebilir (1-10 arası)

## Teknik Yapı

- **iOS** — SwiftUI, SwiftData, iOS 17+
- **Backend** — Node.js (Express) + Firebase Firestore
- **Hosting** — Vercel (serverless)
- **Mimari** — Singleton APIService, observable state, 30s in-memory cache

## Proje Yapısı

```
Siralala/
├── ContentView.swift          # Tab bar, onboarding, profil
├── SiralalaApp.swift          # App entry point, SwiftData container
├── Services/
│   ├── APIService.swift       # Singleton API client + cache
│   └── APIModels.swift        # Codable modeller (FlexID, APIUser, vb.)
├── ViewModels/
│   ├── PoolViewModel.swift    # Havuz CRUD
│   └── RankingViewModel.swift # Lokal sıralama state
├── Views/
│   ├── Feed/FeedView.swift    # Ana sayfa, sorular tab, soru kartları, rehber
│   ├── Pool/                  # Havuz listesi, detay, oluşturma
│   ├── Groups/                # Grup listesi, detay, oluşturma, paylaşılan havuz sorusu
│   ├── Friends/               # Arkadaş yönetimi
│   ├── Question/              # Soru oluşturma
│   ├── Ranking/               # Sıralama ekranı (drag & drop + tap)
│   └── Results/               # Sonuç görüntüleme (lokal + sunucu)
├── Utilities/
│   ├── DesignTokens.swift     # Renk paleti, reusable component'lar
│   └── MockData.swift         # Demo seed (deprecated, sunucu tarafına taşındı)
└── Models/                    # SwiftData modelleri (Pool, PoolItem, Question, vb.)

firebase/functions/api/
└── index.js                   # Express API (users, friends, groups, pools, questions, rankings)
```

## Kurulum

### iOS
1. Xcode 16+ gerekli
2. `Siralala.xcodeproj` aç
3. Simulator veya cihazda çalıştır

### Backend
```bash
cd firebase
npm install
npx vercel dev    # lokal geliştirme
npx vercel --prod # production deploy
```

## Tasarım Sistemi

| Token | Değer | Kullanım |
|-------|-------|----------|
| `dsBg` | #FBF8F3 | Arka plan |
| `dsSurface` | #FFFFFF | Kart yüzeyi |
| `dsDeep` | #1A1613 | Ana metin |
| `dsMuted` | opacity 0.55 | İkincil metin |
| `dsAccent` | #E8824A | Vurgu (turuncu) |
| `dsHairline` | opacity 0.08 | Kenarlık |

Tüm kartlar **16px border-radius**, tutarlı padding ve design token renkleri kullanır.
