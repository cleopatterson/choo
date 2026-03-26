import SwiftUI

struct SupplyCategoryManageSheet: View {
    @Bindable var viewModel: SuppliesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.allCategoriesForManagement, id: \.self) { category in
                    HStack(spacing: 12) {
                        Text(category.emoji)
                            .font(.title3)
                            .frame(width: 32, height: 32)

                        Text(category.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.isCategoryHidden(category) ? .secondary : .primary)

                        Spacer()

                        Button {
                            viewModel.toggleCategoryVisibility(category)
                        } label: {
                            Image(systemName: viewModel.isCategoryHidden(category) ? "eye.slash" : "eye")
                                .font(.subheadline)
                                .foregroundStyle(viewModel.isCategoryHidden(category) ? .secondary : Color.chooPurple)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
                .onMove { from, to in
                    viewModel.reorderCategories(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
