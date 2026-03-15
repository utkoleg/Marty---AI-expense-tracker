import Foundation

enum ExpenseCSVExporter {
    static func csvString(from expenses: [Expense]) -> String {
        var rows: [[String]] = [[
            loc("Date", "Дата"),
            loc("Merchant", "Магазин"),
            loc("Category", "Категория"),
            loc("Original Total", "Исходная сумма"),
            loc("Original Currency", "Исходная валюта"),
            loc("Base Total", "Сумма в базе"),
            loc("Base Currency", "Базовая валюта"),
            loc("Exchange Rate", "Курс"),
            loc("Items", "Позиции"),
        ]]

        for expense in expenses {
            let itemNames = expense.items.map(\.name).map(sanitizeCSVCell).joined(separator: "; ")
            let baseCurrency = expense.convertedCurrency ?? currentBaseCurrencyCode()
            rows.append([
                sanitizeCSVCell(expense.date),
                sanitizeCSVCell(expense.merchant),
                sanitizeCSVCell(localizedCategoryName(expense.category)),
                String(format: "%.2f", expense.total),
                sanitizeCSVCell(normalizedCurrencyCode(expense.currency)),
                String(format: "%.2f", expense.displayTotal(for: baseCurrency)),
                sanitizeCSVCell(baseCurrency),
                expense.exchangeRate.map { String(format: "%.6f", $0) } ?? "",
                itemNames,
            ])
        }

        return rows
            .map { row in
                row.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                    .joined(separator: ",")
            }
            .joined(separator: "\n")
    }

    static func writeTemporaryCSV(
        expenses: [Expense],
        directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = AppLanguage.current == .english ? "receiptly_export.csv" : "receiptly_export_ru.csv"
    ) throws -> URL {
        let outputURL = directory.appendingPathComponent(fileName)
        try csvString(from: expenses).write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }
}
