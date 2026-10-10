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
            data = try await provider.fetchToday()
            errorText = nil
        } catch {
            errorText = "Ошибка чтения данных: \(error.localizedDescription)"
        }
    }

    /// Для тестов: вернуться на экран подключения.
    func reset() {
        UserDefaults.standard.set(false, forKey: connectedKey)
        data = nil
        screen = .connect
    }
}
