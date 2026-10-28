import SwiftUI

private enum AppPalette {
    static let pink = Color(red: 1.00, green: 0.22, blue: 0.42)
    static let green = Color(red: 0.02, green: 0.75, blue: 0.39)
    static let blue = Color(red: 0.10, green: 0.52, blue: 1.00)
    static let ink = Color(red: 0.06, green: 0.08, blue: 0.12)
    static let muted = Color(red: 0.48, green: 0.50, blue: 0.56)
    static let canvas = Color(red: 0.97, green: 0.97, blue: 0.985)
    static let aqua = Color(red: 0.02, green: 0.87, blue: 0.80)
    static let mint = Color(red: 0.35, green: 0.98, blue: 0.60)
}

struct DashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var monthOffset = 0
    @State private var showCompetition = false
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showAccount = false
    @State private var showSettings = false
    @AppStorage("profileName") private var profileName = "Алексей"
    @AppStorage("goalExerciseMinutes") private var goalExerciseMinutes = 30.0
    @AppStorage("goalActiveCalories") private var goalActiveCalories = 500.0
    @AppStorage("goalStandHours") private var goalStandHours = 12.0

    private var selectedDayData: ActivityData? {
        let key = Calendar.current.startOfDay(for: selectedDate)
        return model.dailyHistory[key] ?? (Calendar.current.isDateInToday(selectedDate) ? model.data : nil)
    }

    private var monthDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }
    private var monthTitle: String {
        monthDate.formatted(.dateTime.month(.wide).year()).capitalized
    }
    private var days: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: monthDate),
              let dayRange = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        let weekday = (calendar.component(.weekday, from: interval.start) + 5) % 7
        return Array<Date?>(repeating: nil, count: weekday) + dayRange.map { Optional(calendar.date(byAdding: .day, value: $0 - 1, to: interval.start)!) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Мои кольца")
                            .font(.system(size: 29, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                        Spacer()
                        Button { showAccount = true } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(AppPalette.ink)
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.9), in: Circle())
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppPalette.green)
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.9), in: Circle())
                        }
                        Button { Task { await model.refresh() } } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppPalette.green)
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.9), in: Circle())
                        }
                    }
                    .padding(.horizontal, 4)

                    calendarCard
                    Button { showCompetition = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.2.fill").font(.system(size: 19, weight: .bold))
                            Spacer()
                            Text("Добавить соревнование").font(.system(size: 16, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .frame(height: 54)
                        .background(LinearGradient(colors: [AppPalette.aqua, AppPalette.mint], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("Моя активность")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .padding(.top, 2)
                    Text(Calendar.current.isDateInToday(selectedDate) ? "Сегодня" : selectedDate.formatted(.dateTime.day().month(.wide)).capitalized)
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(AppPalette.muted)
                    if let data = selectedDayData {
                        todayMetricRow(icon: "figure.run", tint: AppPalette.pink, title: "Упражнения", value: data.exerciseMinutes, goal: goalExerciseMinutes, unit: "мин", detail: "\(Int(data.exerciseMinutes)) / \(Int(goalExerciseMinutes)) мин")
                        todayMetricRow(icon: "flame.fill", tint: AppPalette.green, title: "Калории", value: data.activeCalories.total, goal: goalActiveCalories, unit: "ккал", detail: "\(Int(data.activeCalories.total)) / \(Int(goalActiveCalories)) ккал")
                        todayMetricRow(icon: "figure.cooldown", tint: AppPalette.blue, title: "Разминка", value: data.standHours, goal: goalStandHours, unit: "ч", detail: "\(Int(data.standHours)) / \(Int(goalStandHours)) ч")
                        if let error = model.errorText {
                            Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal, 8)
                        }
                    } else if model.isRefreshing || model.historyLoading {
                        ProgressView("Загружаем активность…").frame(maxWidth: .infinity).padding()
                    } else if Calendar.current.startOfDay(for: selectedDate) > Calendar.current.startOfDay(for: Date()) {
                        Text("Для этого дня данных пока нет.").font(.system(size: 12)).foregroundStyle(AppPalette.muted).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Text("Нет доступных данных за выбранный день.").font(.system(size: 12)).foregroundStyle(AppPalette.muted).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(
                LinearGradient(colors: [Color.white, AppPalette.canvas, Color(red: 0.93, green: 0.99, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.refresh() }
            .navigationDestination(isPresented: $showCompetition) { CompetitorSelectionView() }
            .sheet(isPresented: $showAccount) { AccountView() }
            .sheet(isPresented: $showSettings) { GoalsSettingsView() }
            .task { await model.loadHistory(for: monthDate) }
            .onChange(of: monthOffset) { _ in
                let calendar = Calendar.current
                if monthOffset == 0 { selectedDate = calendar.startOfDay(for: Date()) }
                else { selectedDate = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate }
                Task { await model.loadHistory(for: monthDate) }
            }
        }
        .tint(AppPalette.green)
    }

    private var calendarCard: some View {
        VStack(spacing: 10) {
            HStack {
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32).background(Color.white.opacity(0.9), in: Circle()) }
                Spacer()
                Text(monthTitle).font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button { if monthOffset < 0 { monthOffset += 1 } } label: { Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32).background(Color.white.opacity(0.9), in: Circle()) }
            }
            .foregroundStyle(AppPalette.ink)
            HStack {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                    Text(day).font(.system(size: 10, weight: .medium)).foregroundStyle(AppPalette.muted).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                    if let date {
                        let day = Calendar.current.component(.day, from: date)
                        let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
                        let isToday = Calendar.current.isDateInToday(date)
                        let progress = ringProgress(for: date, isFuture: isFuture)
                        Button { selectedDate = Calendar.current.startOfDay(for: date) } label: {
                            VStack(spacing: 2) {
                                Text("\(day)").font(.system(size: 10, weight: isToday || Calendar.current.isDate(date, inSameDayAs: selectedDate) ? .bold : .medium)).foregroundStyle(isFuture ? AppPalette.muted.opacity(0.55) : AppPalette.ink)
                                ZStack(alignment: .topTrailing) {
                                    TripleRings(progress: progress, size: 27, lineWidth: 2.5, faded: isFuture || model.dailyHistory[Calendar.current.startOfDay(for: date)] == nil && !isToday)
                                        .frame(width: 29, height: 29)
                                    if !isFuture && allGoalsClosed(on: date) {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(AppPalette.green).background(.white, in: Circle()).offset(x: 2, y: -2)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .background(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? AppPalette.aqua.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
            HStack(spacing: 12) {
                legendDot(AppPalette.pink, "Упражнения")
                legendDot(AppPalette.green, "Калории")
                legendDot(AppPalette.blue, "Разминка")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .padding(13)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
    }

    private func ringProgress(for date: Date, isFuture: Bool) -> [CGFloat] {
        if isFuture { return [0, 0, 0] }
        let key = Calendar.current.startOfDay(for: date)
        let dayData = model.dailyHistory[key] ?? (Calendar.current.isDateInToday(date) ? model.data : nil)
        guard let data = dayData else { return [0, 0, 0] }
        return [min(CGFloat(data.exerciseMinutes / max(goalExerciseMinutes, 1)), 1), min(CGFloat(data.activeCalories.total / max(goalActiveCalories, 1)), 1), min(CGFloat(data.standHours / max(goalStandHours, 1)), 1)]
    }

    private func allGoalsClosed(on date: Date) -> Bool {
        let key = Calendar.current.startOfDay(for: date)
        guard let data = model.dailyHistory[key] ?? (Calendar.current.isDateInToday(date) ? model.data : nil) else { return false }
        return data.exerciseMinutes >= goalExerciseMinutes && data.activeCalories.total >= goalActiveCalories && data.standHours >= goalStandHours
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(text).font(.system(size: 10)).foregroundStyle(AppPalette.muted) }
    }

    private func todayMetricRow(icon: String, tint: Color, title: String, value: Double, goal: Double, unit: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 19, weight: .bold)).foregroundStyle(tint).frame(width: 42, height: 42).background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(AppPalette.ink)
                Text(detail).font(.system(size: 11)).foregroundStyle(AppPalette.muted)
            }
            Spacer()
            ActivityRing(progress: goal > 0 ? min(value / goal, 1) : 0, color: tint, lineWidth: 4).frame(width: 32, height: 32)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray.opacity(0.5))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct CompetitorSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = "Xiaomi Mi Band 8"
    @State private var next = false
    private let devices: [(String, String, Color, String)] = [
        ("Apple Watch", "Все модели", Color(red: 1, green: 0.91, blue: 0.94), "applewatch"),
        ("Samsung Galaxy Watch", "Все модели", Color(red: 0.88, green: 0.93, blue: 1), "watchface.applewatch.case"),
        ("Xiaomi Mi Band 8", "Все модели", Color(red: 1, green: 0.94, blue: 0.83), "XiaomiBandProduct"),
        ("Garmin", "Все модели", Color(red: 0.87, green: 0.97, blue: 0.92), "watch.analog"),
        ("Fitbit", "Все модели", Color(red: 0.92, green: 0.91, blue: 1), "figure.walk"),
        ("Huawei", "Все модели", Color(red: 1, green: 0.90, blue: 0.94), "heart.fill"),
        ("Amazfit", "Все модели", Color(red: 0.88, green: 0.94, blue: 1), "watch.analog")
    ]
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            topBar(title: "Соревнование", back: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Добавить\nсоревнование").font(.system(size: 31, weight: .heavy, design: .rounded)).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
                    Text("Выберите устройство соперника.").font(.system(size: 15)).foregroundStyle(AppPalette.muted)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(devices.enumerated()), id: \.offset) { index, device in
                            DeviceTile(name: device.0, subtitle: device.1, tint: device.2, icon: device.3, selected: selected == device.0, wide: index == 6) { selected = device.0 }
                                .gridCellColumns(index == 6 ? 2 : 1)
                        }
                    }
                    Text("Пока доступно реальное чтение данных Apple Health. Xiaomi показан в демонстрационном режиме.")
                        .font(.system(size: 11)).foregroundStyle(AppPalette.muted).padding(.horizontal, 3)
                }.padding(16)
            }
            bottomGradientButton("Продолжить") { next = true }
                .padding(.horizontal, 16).padding(.bottom, 10)
        }
        .background(LinearGradient(colors: [.white, AppPalette.canvas, Color(red: 0.91, green: 0.99, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $next) { CompetitionModeSelectionView(selectedDevice: selected) }
    }
}

private struct DeviceTile: View {
    let name: String; let subtitle: String; let tint: Color; let icon: String; let selected: Bool; var wide = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if name.contains("Xiaomi") {
                        Text("mi").font(.system(size: 13, weight: .black)).foregroundStyle(.white).frame(width: 25, height: 25).background(Color.orange, in: RoundedRectangle(cornerRadius: 7))
                    } else {
                        Image(systemName: icon == "XiaomiBandProduct" ? "watch.analog" : icon).font(.system(size: 17, weight: .bold)).foregroundStyle(name.contains("Samsung") ? Color.blue : AppPalette.ink)
                    }
                    Spacer()
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.system(size: 19, weight: .regular)).foregroundStyle(selected ? Color.orange : AppPalette.muted.opacity(0.7))
                }
                HStack(alignment: .center, spacing: 3) {
                    if name == "Apple Watch" {
                        Image("AppleWatchProduct").resizable().scaledToFit().frame(width: wide ? 95 : 74, height: 94)
                    } else if name.contains("Xiaomi") {
                        Image("XiaomiBandProduct").resizable().scaledToFit().frame(width: wide ? 115 : 88, height: 96)
                    } else {
                        Image(systemName: icon).resizable().scaledToFit().frame(width: 65, height: 68).foregroundStyle(AppPalette.ink.opacity(0.78)).padding(.horizontal, 7)
                    }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 90)
                Text(name).font(.system(size: 12, weight: .bold)).foregroundStyle(AppPalette.ink).lineLimit(2).multilineTextAlignment(.leading)
                Text(subtitle).font(.system(size: 10)).foregroundStyle(AppPalette.muted)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(tint, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Color.orange.opacity(0.8) : Color.white.opacity(0.6), lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain)
    }
}

private struct CompetitionModeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDevice: String
    @State private var mode = 0
    @State private var duration = "Месяц"
    @State private var openSummary = false
    var body: some View {
        VStack(spacing: 0) {
            topBar(title: "Соревнование", back: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Тип\nсоревнования").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(AppPalette.ink)
                    Text("Выберите, по каким правилам будем соревноваться.").font(.system(size: 17)).foregroundStyle(AppPalette.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Длительность").font(.system(size: 15, weight: .bold))
                        Picker("Длительность", selection: $duration) {
                            Text("Неделя").tag("Неделя")
                            Text("Месяц").tag("Месяц")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(13)
                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                    ModeTile(title: "Закрытые кольца\nза месяц", subtitle: "Считаем дни, в которые выполнены все три цели активности.", symbol: "rings", tint: Color(red: 1, green: 0.91, blue: 0.68), selected: mode == 0) { mode = 0 }
                    ModeTile(title: "Баллы за активность", subtitle: "Правила начисления баллов будут настроены позже.", symbol: "chart", tint: Color(red: 0.92, green: 0.89, blue: 1), selected: mode == 1) { mode = 1 }
                    ModeTile(title: "Только совпадающие\nпоказатели", subtitle: "Сравниваем только показатели, доступные у обоих участников.", symbol: "overlap", tint: Color(red: 1, green: 0.89, blue: 0.92), selected: mode == 2) { mode = 2 }
                }.padding(16)
            }
            bottomGradientButton("Продолжить") { openSummary = true }.padding(.horizontal, 16).padding(.bottom, 10)
        }
        .background(LinearGradient(colors: [.white, AppPalette.canvas, Color(red: 0.91, green: 0.99, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $openSummary) { CompetitionMonthlySummaryView(device: selectedDevice, mode: mode, duration: duration) }
    }
}

private struct ModeTile: View {
    let title: String; let subtitle: String; let symbol: String; let tint: Color; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.65)).frame(width: 76, height: 76)
                    if symbol == "rings" { TripleRings(progress: [1, 1, 1], size: 54, lineWidth: 8).frame(width: 54, height: 54) }
                    else if symbol == "chart" { Image(systemName: "chart.bar.fill").font(.system(size: 35, weight: .bold)).foregroundStyle(Color.purple) }
                    else { ZStack { Circle().fill(AppPalette.pink.opacity(0.8)).frame(width: 42, height: 42).offset(x: -12); Circle().fill(Color.purple.opacity(0.75)).frame(width: 42, height: 42).offset(x: 12) } }
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(AppPalette.ink)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.system(size: 23)).foregroundStyle(selected ? AppPalette.ink : AppPalette.muted)
            }
            .padding(14).background(tint, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? AppPalette.ink.opacity(0.65) : .clear, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}

private struct CompetitionMonthlySummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let device: String; let mode: Int; let duration: String
    @AppStorage("profileName") private var profileName = "Алексей"
    @State private var calendarPeriod = 0
    private let months = ["октябрь 2026 г.", "сентябрь 2026 г.", "август 2026 г."]
    private var demoAlexClosedDays: Int { (1...daysInDisplayedPeriod).filter { demoClosed(day: $0, seed: 2) }.count }
    private var demoOpponentClosedDays: Int { (1...daysInDisplayedPeriod).filter { demoClosed(day: $0, seed: 4) }.count }
    private var daysInDisplayedPeriod: Int { duration == "Неделя" ? 7 : 31 }
    private func demoMetricClosed(day: Int, seed: Int, metric: Int) -> Bool {
        switch metric {
        case 0: return (day * 3 + seed) % 7 != 0 && (day + seed) % 5 != 0
        case 1: return (day * 2 + seed) % 6 != 0
        default: return (day + seed * 2) % 5 != 0
        }
    }
    private func demoClosed(day: Int, seed: Int) -> Bool {
        (0..<3).allSatisfy { demoMetricClosed(day: day, seed: seed, metric: $0) }
    }
    private func demoMetricCount(seed: Int, metric: Int) -> Int {
        (1...daysInDisplayedPeriod).filter { demoMetricClosed(day: $0, seed: seed, metric: metric) }.count
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                topBar(title: "Соревнование", back: { dismiss() })
                Text(duration == "Неделя" ? "Сводка за неделю" : "Сводка за месяц").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(AppPalette.ink)
                Text(duration == "Неделя" ? "Последние 7 дней" : months[0]).font(.system(size: 14)).foregroundStyle(AppPalette.muted)
                HStack(spacing: 10) {
                    participantSummary(name: profileName.isEmpty ? "Вы" : profileName, device: "Apple Watch", avatar: "👤", score: (0..<3).map { demoMetricCount(seed: 2, metric: $0) }, progress: (0..<3).map { CGFloat(demoMetricCount(seed: 2, metric: $0)) / CGFloat(daysInDisplayedPeriod) })
                    participantSummary(name: "Марина", device: device, avatar: "🐼", score: (0..<3).map { demoMetricCount(seed: 4, metric: $0) }, progress: (0..<3).map { CGFloat(demoMetricCount(seed: 4, metric: $0)) / CGFloat(daysInDisplayedPeriod) })
                }
                HStack {
                    Text("Активность по дням").font(.system(size: 17, weight: .heavy, design: .rounded))
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(["Месяц", "Неделя", "День"].indices, id: \.self) { index in
                            Button(["Месяц", "Неделя", "День"][index]) { calendarPeriod = index }
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(calendarPeriod == index ? AppPalette.ink : AppPalette.muted)
                                .padding(.horizontal, 8).padding(.vertical, 6).background(calendarPeriod == index ? Color(red: 0.77, green: 0.98, blue: 0.88) : .clear, in: Capsule())
                        }
                    }.background(.white.opacity(0.8), in: Capsule())
                }
                HStack(spacing: 9) { miniCalendar(name: "🐱 Алексей", seed: 2); miniCalendar(name: "🐼 Марина", seed: 4) }
                VStack(spacing: 7) {
                    HStack { Image(systemName: "trophy.fill").foregroundStyle(.orange); Text("Счёт в соревновании").font(.system(size: 11, weight: .semibold)).foregroundStyle(AppPalette.muted) }
                    HStack(spacing: 12) {
                        Text("👤 \(profileName.isEmpty ? "Вы" : profileName)").font(.system(size: 11, weight: .bold))
                        Text("\(demoAlexClosedDays)").font(.system(size: 42, weight: .heavy, design: .rounded))
                        Text(":").font(.system(size: 30, weight: .medium)).foregroundStyle(AppPalette.muted)
                        Text("\(demoOpponentClosedDays)").font(.system(size: 42, weight: .heavy, design: .rounded))
                        Text("Марина 🐼").font(.system(size: 11, weight: .bold))
                    }.foregroundStyle(AppPalette.ink)
                    GeometryReader { geo in HStack(spacing: 0) { AppPalette.mint.frame(width: geo.size.width * CGFloat(demoAlexClosedDays) / CGFloat(max(demoAlexClosedDays + demoOpponentClosedDays, 1))); AppPalette.aqua.frame(width: geo.size.width * CGFloat(demoOpponentClosedDays) / CGFloat(max(demoAlexClosedDays + demoOpponentClosedDays, 1))) }.clipShape(Capsule()) }.frame(height: 7).padding(.horizontal, 20)
                }.padding(14).frame(maxWidth: .infinity).background(LinearGradient(colors: [Color(red: 0.92, green: 0.99, blue: 0.94), Color(red: 0.90, green: 0.98, blue: 0.97)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20))
                Text("Демонстрационные данные соперника. Подключение Xiaomi пока не настроено.").font(.system(size: 10)).foregroundStyle(AppPalette.muted).padding(.horizontal, 4)
            }.padding(12)
        }
        .background(LinearGradient(colors: [.white, AppPalette.canvas, Color(red: 0.91, green: 0.99, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
    private func participantSummary(name: String, device: String, avatar: String, score: [Int], progress: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) { Text(avatar).font(.system(size: 25)); VStack(alignment: .leading, spacing: 2) { Text(name).font(.system(size: 12, weight: .bold)); Text(device).font(.system(size: 8)).foregroundStyle(AppPalette.muted).lineLimit(1) } }
            ZStack { TripleRings(progress: progress, size: 96, lineWidth: 8).frame(width: 96, height: 96) }
                .frame(maxWidth: .infinity).padding(.vertical, 3)
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 5) { Circle().fill([AppPalette.pink, AppPalette.green, AppPalette.blue][i]).frame(width: 8, height: 8); Text("\(score[i]) из \(daysInDisplayedPeriod)").font(.system(size: 10, weight: .bold)); Spacer(minLength: 0) }
                Text(["Упражнения", "Калории", "Разминка"][i]).font(.system(size: 9)).foregroundStyle(AppPalette.muted).padding(.leading, 13)
            }
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }
    private func miniCalendar(name: String, seed: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(name).font(.system(size: 10, weight: .bold)); Spacer(); Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(AppPalette.muted) }
            HStack { ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { Text($0).font(.system(size: 7)).foregroundStyle(AppPalette.muted).frame(maxWidth: .infinity) } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 5) {
                ForEach(1...((duration == "Неделя") ? 7 : 35), id: \.self) { day in
                    if day <= daysInDisplayedPeriod {
                        VStack(spacing: 1) { Text("\(day)").font(.system(size: 7)).foregroundStyle(AppPalette.muted); TripleRings(progress: (0..<3).map { demoMetricClosed(day: day, seed: seed, metric: $0) ? 1 : CGFloat((day + seed + $0) % 3 + 1) / 5 }, size: 15, lineWidth: 1.5).frame(width: 15, height: 15) }
                    } else { Color.clear.frame(height: 23) }
                }
            }
        }.padding(8).frame(maxWidth: .infinity).background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 15))
    }
}


private struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = "Алексей"
    @AppStorage("profileEmail") private var profileEmail = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Профиль") {
                    TextField("Имя", text: $profileName)
                    TextField("Электронная почта (необязательно)", text: $profileEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("Профиль хранится только на этом устройстве. Регистрация и синхронизация между телефонами пока не подключены.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Аккаунт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}

private struct GoalsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("goalExerciseMinutes") private var exerciseGoal = 30.0
    @AppStorage("goalActiveCalories") private var calorieGoal = 500.0
    @AppStorage("goalStandHours") private var standGoal = 12.0
    var body: some View {
        NavigationStack {
            Form {
                Section("Цели активности") {
                    VStack(alignment: .leading) {
                        HStack { Text("Упражнения"); Spacer(); Text("\(Int(exerciseGoal)) мин").foregroundStyle(.secondary) }
                        Slider(value: $exerciseGoal, in: 5...180, step: 5)
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("Калории"); Spacer(); Text("\(Int(calorieGoal)) ккал").foregroundStyle(.secondary) }
                        Slider(value: $calorieGoal, in: 100...2000, step: 50)
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("Разминка"); Spacer(); Text("\(Int(standGoal)) ч").foregroundStyle(.secondary) }
                        Slider(value: $standGoal, in: 1...24, step: 1)
                    }
                }
                Section {
                    Text("По умолчанию используются стартовые значения приложения. HealthKit не предоставляет сторонним приложениям доступ к персональным целям колец Apple Watch, поэтому задайте свои значения здесь.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Вернуть значения по умолчанию") {
                    exerciseGoal = 30
                    calorieGoal = 500
                    standGoal = 12
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}

private struct TripleRings: View {
    let progress: [CGFloat]; var size: CGFloat = 40; var lineWidth: CGFloat = 4; var faded = false
    var body: some View {
        ZStack {
            ring(progress[0], color: AppPalette.pink, diameter: size, width: lineWidth)
            ring(progress[1], color: AppPalette.green, diameter: size * 0.72, width: lineWidth)
            ring(progress[2], color: AppPalette.blue, diameter: size * 0.44, width: lineWidth)
        }.opacity(faded ? 0.28 : 1)
    }
    private func ring(_ value: CGFloat, color: Color, diameter: CGFloat, width: CGFloat) -> some View {
        Circle().stroke(color.opacity(0.18), lineWidth: width).overlay(Circle().trim(from: 0, to: min(max(value, 0), 1)).stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round)).rotationEffect(.degrees(-90))).frame(width: diameter, height: diameter)
    }
}

private struct ActivityRing: View {
    let progress: Double; let color: Color; let lineWidth: CGFloat
    var body: some View { Circle().stroke(color.opacity(0.18), lineWidth: lineWidth).overlay(Circle().trim(from: 0, to: CGFloat(min(max(progress, 0), 1))).stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(-90))) }
}

private func topBar(title: String, back: @escaping () -> Void) -> some View {
    HStack {
        Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(AppPalette.ink).frame(width: 34, height: 34).background(.white.opacity(0.9), in: Circle()) }
        Spacer(); Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(AppPalette.ink); Spacer()
        Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(AppPalette.ink).frame(width: 34, height: 34).background(.white.opacity(0.9), in: Circle())
    }.padding(.horizontal, 16).padding(.vertical, 5)
}

private func bottomGradientButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack { Spacer(); Text(title).font(.system(size: 17, weight: .bold)); Spacer(); Image(systemName: "arrow.right").font(.system(size: 20, weight: .medium)) }
            .foregroundStyle(.black).padding(.horizontal, 22).frame(height: 58).background(LinearGradient(colors: [AppPalette.aqua, AppPalette.mint], startPoint: .leading, endPoint: .trailing), in: Capsule())
    }.buttonStyle(.plain)
}
