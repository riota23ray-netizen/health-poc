import SwiftUI

// ─────────────────────────────────────────────────────────────
// ЭКРАН 3. ДАННЫЕ ЗА СЕГОДНЯ
// Для каждой метрики три цифры:
//   • «Всего»          — должно совпасть с приложением «Здоровье»
//   • «С часов»        — то, что пойдёт в соревнование
//   • «Вручную»        — введено руками, в зачёт не идёт
// Ниже — список источников: кто именно записал данные.
// ─────────────────────────────────────────────────────────────

struct DashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var showingCompetition = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthCalendar
                    Button {
                        showingCompetition = true
                    } label: {
                        Label("Добавить соревнование", systemImage: "person.2.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)

                    if let data = model.data {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Активность сегодня").font(.title3.bold())
                            MetricCard(icon: "figure.walk", title: "Шаги", unit: "", metric: data.steps)
                            MetricCard(icon: "flame.fill", title: "Активные калории", unit: "ккал", metric: data.activeCalories)
                            MetricCard(icon: "stopwatch", title: "Тренировки", unit: "мин", metric: data.workoutMinutes)
                            InfoRow(title: "Минуты упражнений", value: "\(format(data.exerciseMinutes)) мин")
                            SourcesCard(sources: data.sources)
                            Text("Обновлено: \(data.syncedAt.formatted(date: .omitted, time: .standard))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else if model.isRefreshing {
                        ProgressView("Читаем данные…").padding(.top, 20)
                    }
                    if let error = model.errorText {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    Button("Сбросить подключение (для теста)", role: .destructive) { model.reset() }
                        .font(.footnote).padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Мои кольца")
            .refreshable { await model.refresh() }
            .toolbar {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
            }
            .sheet(isPresented: $showingCompetition) { CompetitionDemoView() }
        }
    }

    private var monthCalendar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { Task { await model.changeMonth(by: -1) } } label: {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(model.selectedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                    if model.isLoadingMonth { ProgressView().controlSize(.mini) }
                }
                Spacer()
                Button { Task { await model.changeMonth(by: 1) } } label: {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
                .disabled(Calendar.current.isDate(model.selectedMonth, equalTo: Date(), toGranularity: .month))
            }
            HStack {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                    Text(day).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            let dates = calendarDates()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 10) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let key = Calendar.current.startOfDay(for: date)
                        let dayData = model.monthData[key]
                        VStack(spacing: 4) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption2).foregroundStyle(.primary)
                            RingTripleView(data: dayData, date: date)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
            HStack(spacing: 12) {
                LegendDot(color: .pink, title: "Упражнения")
                LegendDot(color: .green, title: "Калории")
                LegendDot(color: .red, title: "Стояние")
            }
            .font(.caption2)
            Text("Кольца за прошлые дни загружаются из Apple Health. Будущие дни серые.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func calendarDates() -> [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: model.selectedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: model.selectedMonth) else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start) // Sunday = 1
        let mondayFirstOffset = (weekday + 5) % 7
        return Array(repeating: nil, count: mondayFirstOffset) + dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start).map { Optional($0) }
        }
    }
}

private struct RingTripleView: View {
    let data: DailyRingData?
    let date: Date
    private let size: CGFloat = 27
    var body: some View {
        ZStack {
            ring(color: .pink, progress: data.map { min($0.exerciseMinutes / 30, 1) } ?? 0, inset: 0)
            ring(color: .green, progress: data.map { min($0.activeCalories / 500, 1) } ?? 0, inset: 4)
            ring(color: .red, progress: data.map { min($0.standMinutes / 720, 1) } ?? 0, inset: 8)
        }
        .frame(width: size, height: size)
        .opacity(data == nil ? 0.25 : 1)
        .accessibilityLabel(accessibilityText)
    }
    private func ring(color: Color, progress: Double, inset: CGFloat) -> some View {
        Circle().stroke(color.opacity(data == nil ? 0.22 : 0.18), lineWidth: 2.2)
            .overlay {
                Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(inset)
    }
    private var accessibilityText: String {
        guard let data else { return "\(date.formatted(date: .abbreviated, time: .omitted)): данные не загружены" }
        return "\(date.formatted(date: .abbreviated, time: .omitted)): упражнения \(Int(data.exerciseMinutes)) минут, калории \(Int(data.activeCalories)), стояние \(Int(data.standMinutes / 60)) часов"
    }
}

private struct LegendDot: View {
    let color: Color
    let title: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).foregroundStyle(.secondary)
        }
    }
}

private struct CompetitionDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode = 0
    @State private var selectedDevice = "Xiaomi Mi Band 8"
    private let modes = ["Закрытые кольца за месяц", "Баллы за активность", "Совпадающие показатели"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Добавить соревнование").font(.title2.bold())
                    Text("Устройство соперника").font(.headline)
                    ForEach(["Apple Watch", "Samsung Galaxy Watch", "Xiaomi Mi Band 8", "Garmin", "Другие часы"], id: \.self) { device in
                        Button { selectedDevice = device } label: {
                            HStack {
                                Image(systemName: selectedDevice == device ? "largecircle.fill.circle" : "circle")
                                Text(device)
                                Spacer()
                                if device != "Xiaomi Mi Band 8" { Text("Скоро").font(.caption).foregroundStyle(.secondary) }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
                    Text("Тип соревнования").font(.headline)
                    ForEach(modes.indices, id: \.self) { index in
                        Button { selectedMode = index } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(modes[index]).font(.subheadline.bold())
                                    Spacer()
                                    if selectedMode == index { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                }
                                Text(modeDescription(index)).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain).foregroundStyle(.primary)
                    }
                    Button("Показать демонстрацию") { selectedMode = max(selectedMode, 0) }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    comparisonPreview
                    Text("Демонстрационные данные. Реальное подключение соперника и синхронизация между телефонами пока не реализованы.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Соревнование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
    private func modeDescription(_ index: Int) -> String {
        switch index {
        case 0: return "Считаем дни, в которые выполнены все три цели активности."
        case 1: return "Баллы за активность — правила начисления будут настроены позже."
        default: return "Сравниваем только метрики, доступные у обоих участников."
        }
    }
    private var comparisonPreview: some View {
        VStack(spacing: 14) {
            Text("Сравнение за месяц").font(.headline)
            HStack(alignment: .top, spacing: 12) {
                participant(title: "Вы · Apple Watch", colors: [.pink, .green, .red], metrics: ["Упражнения", "Калории", "Стояние"])
                participant(title: "Соперник · Xiaomi", colors: [.pink, .green, .red], metrics: ["Разминка", "Калории", "Шаги"])
            }
            HStack(spacing: 14) {
                Text("1").font(.system(size: 42, weight: .bold, design: .rounded))
                Text(":").font(.largeTitle).foregroundStyle(.secondary)
                Text("2").font(.system(size: 42, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.green)
            Text("Закрытые дни · демонстрационный счёт").font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
    private func participant(title: String, colors: [Color], metrics: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.bold())
            ForEach(metrics.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    Circle().fill(colors[i]).frame(width: 8, height: 8)
                    Text(metrics[i]).font(.caption)
                }
            }
            Text("Кольца").font(.caption2).foregroundStyle(.secondary)
            RingTripleView(data: DailyRingData(date: Date(), activeCalories: 350, exerciseMinutes: 22, standMinutes: 480), date: Date())
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// ── Карточка метрики ───────────────────────────────────────────
private struct MetricCard: View {
    let icon: String
    let title: String
    let unit: String
    let metric: Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.green)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(metric.total)).font(.system(size: 40, weight: .bold, design: .rounded))
                Text(unit).foregroundStyle(.secondary)
            }

            HStack {
                Pill(text: "⌚ С часов: \(format(metric.fromWatch))", color: .green)
                Pill(text: "✍️ Вручную: \(format(metric.manual))", color: metric.manual > 0 ? .orange : .gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).bold()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// ── Кто записал данные ─────────────────────────────────────────
private struct SourcesCard: View {
    let sources: [SourceInfo]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Источники данных").font(.headline)
            if sources.isEmpty {
                Text("Записей за сегодня нет").foregroundStyle(.secondary)
            }
            ForEach(sources) { source in
                HStack {
                    Image(systemName: source.isWatch ? "applewatch" : "iphone")
                        .foregroundStyle(source.isWatch ? Color.green : Color.secondary)
                    VStack(alignment: .leading) {
                        Text(source.name)
                        Text(source.device).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 12431.6 → «12 432»
private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0)))
}
