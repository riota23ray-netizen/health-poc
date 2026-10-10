import Foundation

// ─────────────────────────────────────────────────────────────
// ЭТАП 0. ОБЩАЯ МОДЕЛЬ ДАННЫХ (п. 5 и п. 14 ТЗ)
//
// Этот файл не знает ни про Apple, ни про Samsung.
// Любые часы в будущем должны превращаться вот в эту структуру.
// ─────────────────────────────────────────────────────────────

/// Одна метрика (шаги, калории, тренировки), разложенная по источникам.
struct Metric {
    /// Итог «как в приложении Здоровье»: Apple сама убирает двойной подсчёт,
    /// если человек ходил одновременно с телефоном и часами.
    var total: Double = 0
    /// Только записи, которые сделали сами часы.
    var fromWatch: Double = 0
    /// Введено вручную — в соревновании такое учитываться не должно.
    var manual: Double = 0
}

/// Откуда пришла запись: название источника и устройство.
struct SourceInfo: Identifiable, Hashable {
    var id: String { name + "|" + device }
    let name: String
    let device: String
    let isWatch: Bool
}

/// Универсальные данные активности за день.
struct ActivityData {
    var date: Date
    var deviceType: String
    var steps = Metric()
    var activeCalories = Metric()
    var workoutMinutes = Metric()
    /// «Минуты упражнений» из колец Apple — для сравнения с тренировками.
    var exerciseMinutes: Double = 0
    var sources: [SourceInfo] = []
    var syncedAt: Date
}

/// Интерфейс «поставщика активности». Сегодня он один — Apple Health.
/// Завтра рядом появится SamsungHealthProvider с тем же набором функций,
/// а остальное приложение даже не заметит разницы.
protocol ActivityProvider {
    var deviceName: String { get }
    var isAvailable: Bool { get }
    func requestAccess() async throws
    func fetchToday() async throws -> ActivityData
}
