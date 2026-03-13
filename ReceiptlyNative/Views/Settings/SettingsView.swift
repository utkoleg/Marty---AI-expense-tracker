import SwiftUI

struct SettingsView: View {
    let expenses: [Expense]
    let stats: Stats
    var onClearAll: () -> Void

    @State private var showClearConfirm = false
    @State private var apiKey = APIKeyStore.apiKey
    @State private var showKeySaved = false
    @State private var exportURL: URL? = nil
    @State private var showShare = false

    private var totalItems: Int { expenses.reduce(0) { $0 + $1.items.count } }
    private var avgPerReceipt: String {
        expenses.isEmpty ? "—" : fmt(stats.totalSpent / Double(expenses.count))
    }

    private let summaryRows: [(String, String)] = []   // built dynamically

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary stats
                VStack(spacing: 0) {
                    ForEach([
                        ("Total Receipts", "\(expenses.count)"),
                        ("Total Items",    "\(totalItems)"),
                        ("Total Spent",    fmt(stats.totalSpent)),
                        ("Categories",    "\(stats.usedCats.count)"),
                        ("Avg per Receipt", expenses.isEmpty ? "—" : fmt(stats.totalSpent / Double(expenses.count))),
                    ], id: \.0) { label, value in
                        HStack {
                            Text(label).font(.system(size: 15)).foregroundColor(AppColor.muted)
                            Spacer()
                            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(AppColor.text)
                        }
                        .padding(16)
                        if label != "Avg per Receipt" {
                            Divider().background(AppColor.border)
                        }
                    }
                }
                .cardStyle()

                // Actions
                VStack(spacing: 0) {
                    Button {
                        exportCSV()
                    } label: {
                        HStack(spacing: 10) {
                            Text("📤")
                            Text("Export to CSV")
                            Spacer()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(expenses.isEmpty ? AppColor.muted : AppColor.accent)
                        .padding(16)
                    }
                    .disabled(expenses.isEmpty)
                    .opacity(expenses.isEmpty ? 0.5 : 1)

                    Divider().background(AppColor.border)

                    Button {
                        showClearConfirm = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("🗑")
                            Text("Clear All Expenses")
                            Spacer()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(expenses.isEmpty ? AppColor.muted : AppColor.danger)
                        .padding(16)
                    }
                    .disabled(expenses.isEmpty)
                    .opacity(expenses.isEmpty ? 0.5 : 1)
                }
                .cardStyle()

                // API Key configuration
                VStack(alignment: .leading, spacing: 10) {
                    Text("Anthropic API Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColor.muted)
                        .textCase(.uppercase)
                        .kerning(0.4)
                    SecureField("sk-ant-api03-…", text: $apiKey)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppColor.text)
                        .padding(12)
                        .background(AppColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button {
                        APIKeyStore.apiKey = apiKey
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        showKeySaved = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            showKeySaved = false
                        }
                    } label: {
                        Text(showKeySaved ? "✓ Saved" : "Save Key")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(11)
                            .background(showKeySaved ? AppColor.success : AppColor.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Radii.md))
                    }
                }
                .padding(16)
                .cardStyle()

                // About
                VStack(alignment: .leading, spacing: 0) {
                    Text("""
                        **Marty** uses Claude AI to scan and categorize your expenses automatically.

                        50 categories · Line-item extraction · Monthly charts · CSV export

                        All data is stored locally on your device.
                        """)
                        .font(.system(size: 13))
                        .foregroundColor(AppColor.muted)
                        .lineSpacing(4)
                }
                .padding(16)
                .cardStyle()
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .background(Color.clear)
        .confirmationDialog("Clear all expenses?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) { onClearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showShare) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
    }

    private func exportCSV() {
        let csv = ExpenseStore_csvHelper(expenses: expenses, stats: stats)
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("receiptly_export.csv")
        try? csv.write(to: tmpURL, atomically: true, encoding: .utf8)
        exportURL = tmpURL
        showShare = true
    }
}

private func ExpenseStore_csvHelper(expenses: [Expense], stats: Stats) -> String {
    var rows: [[String]] = [["Date", "Merchant", "Category", "Total", "Items"]]
    for e in expenses {
        let itemNames = e.items.map(\.name).joined(separator: "; ")
        rows.append([e.date, e.merchant, e.category, String(format: "%.2f", e.total), itemNames])
    }
    return rows
        .map { $0.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") }
        .joined(separator: "\n")
}

// MARK: - UIKit share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
