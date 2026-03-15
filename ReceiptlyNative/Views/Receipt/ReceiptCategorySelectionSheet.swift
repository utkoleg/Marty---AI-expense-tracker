import SwiftUI

struct ReceiptCategorySelectionSheet: View {
    let selectedCategory: String
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var sortedCategoryNames: [String] {
        allCategoryNames.sorted { lhs, rhs in
            localizedCategoryName(lhs).localizedStandardCompare(localizedCategoryName(rhs)) == .orderedAscending
        }
    }

    private var filteredCategoryNames: [String] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return sortedCategoryNames }

        return sortedCategoryNames.filter { categoryName in
            let localizedName = localizedCategoryName(categoryName)
            return categoryName.localizedCaseInsensitiveContains(trimmedQuery)
                || localizedName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var otherCategoryNames: [String] {
        filteredCategoryNames.filter { $0 != selectedCategory }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredCategoryNames.isEmpty {
                    Section {
                        EmptyStateView(
                            systemName: "magnifyingglass",
                            title: loc("No categories found", "Категории не найдены"),
                            message: loc("Try a different name.", "Попробуй другое название.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section(loc("Selected", "Выбрано")) {
                        categoryRow(for: selectedCategory)
                    }

                    Section(loc("All Categories", "Все категории")) {
                        ForEach(otherCategoryNames, id: \.self) { categoryName in
                            categoryRow(for: categoryName)
                        }
                    }
                } else {
                    Section(loc("Matching Categories", "Подходящие категории")) {
                        ForEach(filteredCategoryNames, id: \.self) { categoryName in
                            categoryRow(for: categoryName)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(loc("Category", "Категория"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("Cancel", "Отмена")) { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: loc("Search categories", "Поиск категорий"))
        }
    }

    private func categoryRow(for categoryName: String) -> some View {
        let info = categoryInfo(for: categoryName)
        let isSelected = categoryName == selectedCategory

        return Button {
            onSelect(categoryName)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                CategoryIconView(info: info, size: 38, cornerRadius: 12, weight: .medium)

                Text(localizedCategoryName(categoryName))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(info.color)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}
