import Charts
import SwiftUI

private enum SpendingTrendRange: String, CaseIterable, Identifiable {
    case last7Days
    case last4Weeks
    case last6Months

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days: return loc("7 Days", "7 дн.")
        case .last4Weeks: return loc("4 Weeks", "4 нед.")
        case .last6Months: return loc("6 Months", "6 мес.")
        }
    }

    var subtitle: String {
        switch self {
        case .last7Days: return loc("Daily spending for the last 7 days", "За последние 7 дней")
        case .last4Weeks: return loc("Weekly spending for the last 4 weeks", "За последние 4 недели")
        case .last6Months: return loc("Monthly spending for the last 6 months", "За последние 6 месяцев")
        }
    }
}

private struct SpendingTrendPoint: Identifiable {
    let id: String
    let label: String
    let summaryLabel: String
    let amount: Double
    let startDate: Date
    let endDate: Date
}

private struct TrendMetric: Identifiable {
    let id: String
    let title: String
    let value: String
}

struct MonthlyChartView: View {
    @AppStorage(AppPreferences.appLanguageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
    @State private var selectedRange: SpendingTrendRange = .last7Days
    @State private var selectedPointID: String?

    let expenses: [Expense]
    let baseCurrency: String

    private var chartData: [SpendingTrendPoint] {
        spendingTrendPoints(for: selectedRange, expenses: expenses, baseCurrency: baseCurrency)
    }

    private var totalAmount: Double {
        chartData.reduce(0) { $0 + $1.amount }
    }

    private var totalDayCount: Int {
        let calendar = Calendar.current
        return max(chartData.reduce(0) { partial, point in
            partial + dayCount(from: point.startDate, to: point.endDate, calendar: calendar)
        }, 1)
    }

    private var averageDailyAmount: Double {
        totalAmount / Double(totalDayCount)
    }

    private var averageWeeklyAmount: Double {
        totalAmount / 4
    }

    private var averageMonthlyAmount: Double {
        totalAmount / 6
    }

    private var metrics: [TrendMetric] {
        switch selectedRange {
        case .last7Days:
            return [
                TrendMetric(id: "average_daily", title: loc("Average Daily", "Сред. за день"), value: fmt(averageDailyAmount, currencyCode: baseCurrency)),
                TrendMetric(id: "total", title: loc("Total", "Итого"), value: fmt(totalAmount, currencyCode: baseCurrency)),
            ]
        case .last4Weeks:
            return [
                TrendMetric(id: "average_daily", title: loc("Average Daily", "Сред. за день"), value: fmt(averageDailyAmount, currencyCode: baseCurrency)),
                TrendMetric(id: "total", title: loc("Total", "Итого"), value: fmt(totalAmount, currencyCode: baseCurrency)),
                TrendMetric(id: "average_weekly", title: loc("Average Weekly", "Сред. за нед."), value: fmt(averageWeeklyAmount, currencyCode: baseCurrency)),
            ]
        case .last6Months:
            return [
                TrendMetric(id: "average_daily", title: loc("Average Daily", "Сред. за день"), value: fmt(averageDailyAmount, currencyCode: baseCurrency)),
                TrendMetric(id: "total", title: loc("Total", "Итого"), value: fmt(totalAmount, currencyCode: baseCurrency)),
                TrendMetric(id: "average_monthly", title: loc("Average Monthly", "Сред. за мес."), value: fmt(averageMonthlyAmount, currencyCode: baseCurrency)),
            ]
        }
    }

    private var lastPointID: String? {
        chartData.last?.id
    }

    private var activePoint: SpendingTrendPoint? {
        guard !chartData.isEmpty else { return nil }
        if let selectedPointID,
           let selectedPoint = chartData.first(where: { $0.id == selectedPointID }) {
            return selectedPoint
        }
        return chartData.last
    }

    private var yAxisDomain: ClosedRange<Double> {
        guard let maxValue = chartData.map(\.amount).max(), maxValue > 0 else {
            return 0...10
        }

        let paddedUpperBound = maxValue + max(maxValue * 0.18, 10)
        return 0...roundedAxisUpperBound(for: paddedUpperBound)
    }

    var body: some View {
        if !expenses.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc("Spending Trend", "Траты"))
                            .font(.headline)
                            .foregroundStyle(AppColor.text)

                        Text(selectedRange.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.muted)
                    }

                    Picker(loc("Range", "Период"), selection: $selectedRange) {
                        ForEach(SpendingTrendRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppColor.accent)
                }

                HStack(spacing: 10) {
                    ForEach(metrics) { metric in
                        TrendMetricCard(
                            title: metric.title,
                            value: metric.value
                        )
                    }
                }

                Chart(chartData) { point in
                    let isSelected = point.id == activePoint?.id

                    LineMark(
                        x: .value("Period", point.label),
                        y: .value("Amount", point.amount)
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(AppColor.accent)

                    AreaMark(
                        x: .value("Period", point.label),
                        yStart: .value("Baseline", 0),
                        yEnd: .value("Amount", point.amount)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.accent.opacity(0.22), AppColor.accent.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Period", point.label),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(AppColor.accent)
                    .symbol {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppColor.accent)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .stroke(AppColor.text.opacity(isSelected ? 0.8 : 0.48), lineWidth: isSelected ? 2.5 : 2)
                            )
                            .frame(width: isSelected ? 16 : 13, height: isSelected ? 16 : 13)
                    }

                    if isSelected {
                        RuleMark(x: .value("Selected Period", point.label))
                            .foregroundStyle(AppColor.accent.opacity(0.22))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        PointMark(
                            x: .value("Period", point.label),
                            y: .value("Amount", point.amount)
                        )
                        .foregroundStyle(.clear)
                        .annotation(position: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fmt(point.amount, currencyCode: baseCurrency))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.text)

                                Text(point.summaryLabel)
                                    .font(.caption2)
                                    .foregroundStyle(AppColor.muted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppColor.elevated, in: RoundedRectangle(cornerRadius: Radii.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                                    .stroke(AppColor.border, lineWidth: 1)
                            )
                        }
                    }
                }
                .chartYScale(domain: yAxisDomain)
                .chartPlotStyle { plot in
                    plot
                        .background(
                            RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                                .fill(AppColor.elevated.opacity(0.28))
                        )
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(AppColor.hairline)
                        AxisTick(stroke: StrokeStyle(lineWidth: 0))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(compactCurrencyLabel(for: amount))
                                    .font(.caption2)
                                    .foregroundStyle(AppColor.muted)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: chartData.map(\.label)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(AppColor.hairline.opacity(0.75))
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        updateSelectedPoint(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 12)
                                    .onChanged { value in
                                        guard isHorizontalChartDrag(value.translation) else { return }
                                        updateSelectedPoint(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        guard isHorizontalChartDrag(value.translation) else { return }
                                        updateSelectedPoint(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .frame(height: 250)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(AppColor.tertiarySurface, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                        .stroke(AppColor.border, lineWidth: 1)
                )
            }
            .padding(20)
            .cardStyle(fill: AppColor.surface, stroke: AppColor.hairline)
            .id("\(appLanguageRawValue)-\(baseCurrency)")
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: selectedRange)
            .onAppear {
                selectedPointID = lastPointID
            }
            .onChange(of: selectedRange) { _ in
                selectedPointID = lastPointID
            }
            .onChange(of: baseCurrency) { _ in
                selectedPointID = lastPointID
            }
        }
    }

    private func roundedAxisUpperBound(for value: Double) -> Double {
        guard value > 0 else { return 10 }

        let magnitude = pow(10, floor(log10(value)))
        let normalized = value / magnitude

        let step: Double
        switch normalized {
        case ..<2:
            step = 2
        case ..<5:
            step = 5
        default:
            step = 10
        }

        return ceil(value / (step * magnitude / 10)) * (step * magnitude / 10)
    }

    private func compactCurrencyLabel(for value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = appLocale()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let symbol = currencySymbol(for: baseCurrency)

        switch value {
        case 1_000_000...:
            let text = formatter.string(from: NSNumber(value: value / 1_000_000)) ?? "0"
            return "\(symbol)\(text)M"
        case 1_000...:
            let text = formatter.string(from: NSNumber(value: value / 1_000)) ?? "0"
            return "\(symbol)\(text)K"
        default:
            let text = formatter.string(from: NSNumber(value: value)) ?? "0"
            return "\(symbol)\(text)"
        }
    }

    private func updateSelectedPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        guard plotFrame.minX...plotFrame.maxX ~= location.x,
              plotFrame.minY...plotFrame.maxY ~= location.y
        else {
            return
        }

        let relativeX = location.x - plotFrame.origin.x
        let nearestPoint = chartData.compactMap { point -> (SpendingTrendPoint, CGFloat)? in
            guard let pointX = proxy.position(forX: point.label) else { return nil }
            return (point, pointX)
        }
        .min(by: { abs($0.1 - relativeX) < abs($1.1 - relativeX) })

        selectedPointID = nearestPoint?.0.id
    }

    private func isHorizontalChartDrag(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }
}

private struct TrendMetricCard: View {
    let title: String
    let value: String

    private var wrappedTitle: String {
        let parts = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return title }
        return "\(parts[0])\n\(parts[1])"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(wrappedTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)

            Spacer(minLength: 0)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColor.tertiarySurface, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

private func spendingTrendPoints(for range: SpendingTrendRange, expenses: [Expense], baseCurrency: String) -> [SpendingTrendPoint] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let totalsByDay = Dictionary(grouping: expenses.compactMap { expense -> (Date, Double)? in
        guard let date = expenseDateFormatter.date(from: expense.date) else { return nil }
        return (calendar.startOfDay(for: date), expense.displayTotal(for: baseCurrency))
    }, by: { $0.0 }).mapValues { entries in
        entries.reduce(0) { $0 + $1.1 }
    }

    switch range {
    case .last7Days:
        return (0..<7).compactMap { offset -> SpendingTrendPoint? in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            let label = dayAxisLabel(for: date)
            return SpendingTrendPoint(
                id: isoDayKey(for: date),
                label: label,
                summaryLabel: monthDaySummaryLabel(for: date),
                amount: totalsByDay[date] ?? 0,
                startDate: date,
                endDate: date
            )
        }

    case .last4Weeks:
        guard let currentWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        return (0..<4).compactMap { offset -> SpendingTrendPoint? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -(3 - offset), to: currentWeekInterval.start),
                  let displayWeekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)
            else {
                return nil
            }

            let actualWeekEnd = min(displayWeekEnd, today)
            let total = totalsByDay.reduce(0) { partial, entry in
                let date = entry.key
                return partial + (date >= weekStart && date <= actualWeekEnd ? entry.value : 0)
            }

            let label = weekAxisLabel(for: weekStart, endDate: actualWeekEnd, calendar: calendar)
            return SpendingTrendPoint(
                id: isoDayKey(for: weekStart),
                label: label,
                summaryLabel: weekSummaryLabel(for: weekStart, endDate: actualWeekEnd),
                amount: total,
                startDate: weekStart,
                endDate: actualWeekEnd
            )
        }

    case .last6Months:
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: today)
        guard let currentMonthStart = calendar.date(from: currentMonthComponents) else { return [] }

        return (0..<6).compactMap { offset -> SpendingTrendPoint? in
            guard let monthStart = calendar.date(byAdding: .month, value: -(5 - offset), to: currentMonthStart) else {
                return nil
            }

            guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
                  let displayMonthEnd = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)
            else {
                return nil
            }

            let actualMonthEnd = min(displayMonthEnd, today)
            let total = totalsByDay.reduce(0) { partial, entry in
                let date = entry.key
                return partial + (date >= monthStart && date <= actualMonthEnd ? entry.value : 0)
            }

            return SpendingTrendPoint(
                id: currentMonthKey(for: monthStart),
                label: monthAxisLabel(for: monthStart),
                summaryLabel: monthSummaryLabel(for: monthStart),
                amount: total,
                startDate: monthStart,
                endDate: actualMonthEnd
            )
        }
    }
}

private let expenseDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let isoMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM"
    return formatter
}()

private func weekdayFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter
}

private func dayNumberFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.setLocalizedDateFormatFromTemplate("d")
    return formatter
}

private func monthDayFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.setLocalizedDateFormatFromTemplate("MMM d")
    return formatter
}

private func shortMonthFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.setLocalizedDateFormatFromTemplate("MMM")
    return formatter
}

private func longMonthFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.setLocalizedDateFormatFromTemplate("MMMM y")
    return formatter
}

private let shortYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yy"
    return formatter
}()

private func isoDayKey(for date: Date) -> String {
    expenseDateFormatter.string(from: date)
}

private func currentMonthKey(for date: Date) -> String {
    isoMonthFormatter.string(from: date)
}

private func dayAxisLabel(for date: Date) -> String {
    "\(weekdayFormatter().string(from: date))\n\(dayNumberFormatter().string(from: date))"
}

private func weekAxisLabel(for date: Date, endDate: Date, calendar: Calendar) -> String {
    let startLabel = monthDayFormatter().string(from: date)
    let endLabel = calendar.isDate(date, equalTo: endDate, toGranularity: .month)
        ? dayNumberFormatter().string(from: endDate)
        : monthDayFormatter().string(from: endDate)
    return "\(startLabel)\n\(endLabel)"
}

private func monthAxisLabel(for date: Date) -> String {
    "\(shortMonthFormatter().string(from: date))\n\(shortYearFormatter.string(from: date))"
}

private func monthDaySummaryLabel(for date: Date) -> String {
    monthDayFormatter().string(from: date)
}

private func weekSummaryLabel(for date: Date, endDate: Date) -> String {
    "\(monthDayFormatter().string(from: date)) - \(monthDayFormatter().string(from: endDate))"
}

private func monthSummaryLabel(for date: Date) -> String {
    longMonthFormatter().string(from: date)
}

private func dayCount(from startDate: Date, to endDate: Date, calendar: Calendar) -> Int {
    let normalizedStart = calendar.startOfDay(for: startDate)
    let normalizedEnd = calendar.startOfDay(for: endDate)
    let days = calendar.dateComponents([.day], from: normalizedStart, to: normalizedEnd).day ?? 0
    return max(days + 1, 1)
}
