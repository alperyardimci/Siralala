import SwiftUI
import SwiftData
import PhotosUI

struct CreatePoolView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PoolViewModel()
    @State private var pool: Pool? = nil
    @FocusState private var isNameFocused: Bool
    @State private var itemToDelete: PoolItem?

    private let inspirationChips = [
        "Filmler", "Diziler", "Şarkılar", "Futbolcular",
        "Yemekler", "Şehirler", "Kitaplar", "Oyunlar"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let pool = pool {
                    poolItemsView(pool: pool)
                } else {
                    createPoolForm
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(Color.dsDeep)
                }
                if pool != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Bitti") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var createPoolForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Label
                Text("YENİ HAVUZ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.top, 24)

                // Hero text
                (Text("Nasıl bir ")
                    .foregroundStyle(Color.dsDeep) +
                Text("sıralama")
                    .foregroundStyle(Color.dsAccent) +
                Text(" yapmak istiyorsun?")
                    .foregroundStyle(Color.dsDeep))
                    .font(.system(size: 34, weight: .bold))
                    .padding(.top, 8)

                // Subtitle
                Text("Havuz = kıyaslayacağın şeyler. Önce bir isim, sonra öğeler.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.top, 12)

                // Large borderless input
                VStack(spacing: 0) {
                    TextField("Havuz adı", text: $viewModel.poolName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.dsDeep)
                        .submitLabel(.done)
                        .padding(.vertical, 14)
                        .focused($isNameFocused)

                    Rectangle()
                        .fill(Color.dsDeep)
                        .frame(height: 2)
                }
                .padding(.top, 28)

                // Helper text
                Text("Havuz adı \u{00B7} örn. 'Filmler', 'Kahvaltı'")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsUltraMuted)
                    .padding(.top, 8)

                // Inspiration section
                Text("İLHAM")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.top, 32)

                // Suggestion chips
                FlowLayout(spacing: 8) {
                    ForEach(inspirationChips, id: \.self) { chip in
                        Button {
                            viewModel.poolName = chip
                        } label: {
                            Text(chip)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.dsDeep)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(Color.dsSurface)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color.dsHairline, lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .padding(.top, 12)

                Spacer().frame(height: 40)

                // Bottom button
                Button {
                    if let newPool = viewModel.createPool(context: context) {
                        withAnimation {
                            pool = newPool
                        }
                    }
                } label: {
                    Text("Havuzu oluştur")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsDeep))
                }
                .disabled(viewModel.poolName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(viewModel.poolName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dsBg.ignoresSafeArea())
        .onAppear { isNameFocused = true }
    }

    private func poolItemsView(pool: Pool) -> some View {
        VStack(spacing: 0) {
            List {
                Section {
                    AddItemRow(viewModel: viewModel, pool: pool)
                }

                Section {
                    ForEach(pool.items ?? []) { item in
                        ItemRow(item: item)
                    }
                    .onDelete { indexSet in
                        let items = pool.items ?? []
                        if let index = indexSet.first {
                            itemToDelete = items[index]
                        }
                    }
                } header: {
                    Text("\(pool.itemCount) öğe")
                }
            }
        }
        .alert("Öğeyi silmek istediğine emin misin?", isPresented: .init(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Sil", role: .destructive) {
                if let item = itemToDelete {
                    viewModel.deleteItem(item, from: pool, context: context)
                    itemToDelete = nil
                }
            }
            Button("Vazgeç", role: .cancel) { itemToDelete = nil }
        } message: {
            if let item = itemToDelete {
                Text("\"\(item.name)\" havuzdan silinecek.")
            }
        }
    }
}

// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

struct ItemRow: View {
    let item: PoolItem

    var body: some View {
        HStack(spacing: 12) {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dsSurfaceDim)
                        .frame(width: 44, height: 44)
                    Text(item.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(Color.dsDeep)
                }
            }
            Text(item.name)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

struct AddItemRow: View {
    @Bindable var viewModel: PoolViewModel
    let pool: Pool
    @Environment(\.modelContext) private var context
    @FocusState private var isFocused: Bool
    @State private var showPhotoPicker = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    showPhotoPicker = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.dsSurfaceDim)
                            .frame(width: 44, height: 44)

                        if let data = viewModel.selectedImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                }
                .buttonStyle(.plain)

                TextField("Öğe adı", text: $viewModel.newItemName)
                    .foregroundStyle(Color.dsDeep)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onChange(of: viewModel.newItemName) {
                        viewModel.duplicateWarning = nil
                    }
                    .onSubmit {
                        viewModel.addItem(to: pool, context: context)
                        isFocused = true
                    }

                Button {
                    viewModel.addItem(to: pool, context: context)
                    isFocused = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.dsDeep))
                }
                .disabled(viewModel.newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let warning = viewModel.duplicateWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $viewModel.selectedPhoto, matching: .images)
        .onChange(of: viewModel.selectedPhoto) {
            Task { await viewModel.loadImage() }
        }
    }
}
