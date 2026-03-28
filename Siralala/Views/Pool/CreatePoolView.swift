import SwiftUI
import SwiftData
import PhotosUI

struct CreatePoolView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PoolViewModel()
    @State private var pool: Pool? = nil
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let pool = pool {
                    poolItemsView(pool: pool)
                } else {
                    createPoolForm
                }
            }
            .navigationTitle(pool == nil ? "Yeni Havuz" : pool!.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange.gradient)

            Text("Havuza bir isim ver")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("Örn: Futbolcular", text: $viewModel.poolName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .focused($isNameFocused)

            Button {
                if let newPool = viewModel.createPool(context: context) {
                    withAnimation {
                        pool = newPool
                    }
                }
            } label: {
                Text("Oluştur")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(viewModel.poolName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear { isNameFocused = true }
    }

    private func poolItemsView(pool: Pool) -> some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(pool.items ?? []) { item in
                        ItemRow(item: item)
                    }
                    .onDelete { indexSet in
                        let items = pool.items ?? []
                        for index in indexSet {
                            viewModel.deleteItem(items[index], from: pool, context: context)
                        }
                    }
                } header: {
                    Text("\(pool.itemCount) öğe")
                }

                Section {
                    AddItemRow(viewModel: viewModel, pool: pool)
                }
            }
        }
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
                        .fill(.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(item.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.orange)
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
        HStack(spacing: 12) {
            Button {
                showPhotoPicker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.orange.opacity(0.1))
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
                            .foregroundStyle(.orange.opacity(0.6))
                    }
                }
            }
            .buttonStyle(.plain)

            TextField("Öğe adı", text: $viewModel.newItemName)
                .focused($isFocused)
                .onSubmit {
                    viewModel.addItem(to: pool, context: context)
                    isFocused = true
                }

            Button {
                viewModel.addItem(to: pool, context: context)
                isFocused = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .disabled(viewModel.newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $viewModel.selectedPhoto, matching: .images)
        .onChange(of: viewModel.selectedPhoto) {
            Task { await viewModel.loadImage() }
        }
    }
}
