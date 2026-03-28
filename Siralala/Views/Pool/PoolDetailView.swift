import SwiftUI
import SwiftData

struct PoolDetailView: View {
    let pool: Pool
    @Environment(\.modelContext) private var context
    @State private var viewModel = PoolViewModel()
    @State private var showCreateQuestion = false

    var body: some View {
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

            if pool.itemCount >= 3 {
                Section {
                    Button {
                        showCreateQuestion = true
                    } label: {
                        Label("Soru Oluştur", systemImage: "paperplane.fill")
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle(pool.name)
        .sheet(isPresented: $showCreateQuestion) {
            CreateQuestionView(pool: pool)
        }
    }
}
