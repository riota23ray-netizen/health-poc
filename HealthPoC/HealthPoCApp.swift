import SwiftUI

// ─────────────────────────────────────────────────────────────
// ТОЧКА ВХОДА И ПЕРЕКЛЮЧЕНИЕ ЭКРАНОВ
//
// Загрузка → Подключение → Данные.
// AppModel хранит, какой экран сейчас показан, и сами данные.
// ─────────────────────────────────────────────────────────────

@main
struct HealthPoCApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch model.screen {
                case .loading:   LoadingView()     // Экран 1
                case .connect:   ConnectView()     // Экран 2
                case .dashboard: DashboardView()   // Экран 3
                }
            }
            .animation(.easeInOut, value: model.screen)
            .environmentObject(model)
            .tint(.green)
            .task { await model.start() }
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen { case loading, connect, dashboard }

    @Published var screen: Screen = .loading
    @Published var data: ActivityData?
    @Published var dailyHistory: [Date: ActivityData] = [:]
    @Published var historyLoading = false
    @Published var errorText: String?
    @Published var isRefreshing = false

    /// Сегодня — Apple. В будущем здесь будет выбор провайдера.
    let provider: ActivityProvider = AppleHealthProvider()

    private let connectedKey = "watchConnected"

    /// Экран загрузки: короткая пауза, потом решаем, куда идти.
    func start() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if UserDefaults.standard.bool(forKey: connectedKey) {
            screen = .dashboard
            await refresh()
        } else {
            screen = .connect
        }
    }

    /// Кнопка «Подключить Apple Watch».
    func connect() async {
        errorText = nil
        guard provider.isAvailable else {
            errorText = "На этом устройстве нет приложения «Здоровье»."
            return
        }
        do {
            try await provider.requestAccess()
            UserDefaults.standard.set(true, forKey: connectedKey)
            screen = .dashboard
            await refresh()
        } catch {
            errorText = "Не удалось запросить доступ: \(error.localizedDescription)"
        }
    }

    /// Кнопка «Обновить» и жест «потянуть вниз».
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let todayData = try await provider.fetchToday()
            data = todayData
            dailyHistory[Calendar.current.startOfDay(for: todayData.date)] = todayData
            errorText = nil
        } catch {
            errorText = "Ошибка чтения данных: \(error.localizedDescription)"
        }
    }

    /// Загружает реальные дневные значения HealthKit за выбранный месяц.
    func loadHistory(for month: Date) async {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return }
        historyLoading = true
        defer { historyLoading = false }
        let calendar = Calendar.current
        var day = interval.start
        while day < min(interval.end, calendar.startOfDay(for: Date())) {
            let key = calendar.startOfDay(for: day)
            if dailyHistory[key] == nil {
                do {
                    let dayData = try await provider.fetch(for: key)
                    dailyHistory[key] = dayData
                } catch {
                    // Не подменяем отсутствующие данные выдуманными значениями.
                    errorText = "Не удалось загрузить историю активности: \(error.localizedDescription)"
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: key) else { break }
            day = next
        }
    }

    /// Для тестов: вернуться на экран подключения.
    func reset() {
        UserDefaults.standard.set(false, forKey: connectedKey)
        data = nil
        screen = .connect
    }
}
