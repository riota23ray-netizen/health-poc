import Foundation
import HealthKit

// ─────────────────────────────────────────────────────────────
// ЭТАП 2–3. РАБОТА С APPLE HEALTH (HealthKit)
//
// Единственное место в приложении, которое знает про Apple.
// Здесь: запрос разрешений и чтение данных за сегодня.
// ─────────────────────────────────────────────────────────────

final class AppleHealthProvider: ActivityProvider {
    private let store = HKHealthStore()

    let deviceName = "Apple Watch"

    /// На iPad и в некоторых регионах «Здоровья» нет вообще.
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let stepType = HKQuantityType(.stepCount)
    private let energyType = HKQuantityType(.activeEnergyBurned)
    private let exerciseType = HKQuantityType(.appleExerciseTime)
    private let standType = HKQuantityType(.appleStandTime)

    // ── Этап 2: разрешения ─────────────────────────────────────
    /// Показывает системное окно Apple «Разрешить доступ к данным Здоровья».
    /// Мы только ЧИТАЕМ данные, ничего не записываем.
    func requestAccess() async throws {
        let read: Set<HKObjectType> = [
            stepType,
            energyType,
            exerciseType,
            HKObjectType.workoutType(),
            standType
        ]
        try await store.requestAuthorization(toShare: [], read: read)
    }

    // ── Этап 3: данные за сегодня ──────────────────────────────
    func fetchToday() async throws -> ActivityData {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let today = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: [])

        var result = ActivityData(date: startOfDay, deviceType: deviceName, syncedAt: now)
        var allSources = Set<SourceInfo>()

        let steps = try await quantityMetric(stepType, unit: .count(), today)
        result.steps = steps.metric
        allSources.formUnion(steps.sources)

        let energy = try await quantityMetric(energyType, unit: .kilocalorie(), today)
        result.activeCalories = energy.metric
        allSources.formUnion(energy.sources)

        let workouts = try await workoutMetric(today)
        result.workoutMinutes = workouts.metric
        allSources.formUnion(workouts.sources)

        result.exerciseMinutes = try await statisticsSum(exerciseType, unit: .minute(), today)
        result.standMinutes = try await statisticsSum(standType, unit: .minute(), today)
        result.sources = allSources.sorted { $0.isWatch && !$1.isWatch }
        return result
    }


    /// Загружает реальные значения колец за каждый день выбранного месяца.
    /// Используются агрегированные данные HealthKit, а не демонстрационные значения.
    func fetchMonth(_ date: Date) async throws -> [DailyRingData] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        var days: [DailyRingData] = []
        var cursor = interval.start
        let now = Date()
        while cursor < interval.end && cursor <= now {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            let end = min(next, now)
            let predicate = HKQuery.predicateForSamples(withStart: cursor, end: end, options: [])
            async let calories = statisticsSum(energyType, unit: .kilocalorie(), predicate)
            async let exercise = statisticsSum(exerciseType, unit: .minute(), predicate)
            async let stand = statisticsSum(standType, unit: .minute(), predicate)
            let values = try await (calories, exercise, stand)
            days.append(DailyRingData(date: cursor, activeCalories: values.0,
                                      exerciseMinutes: values.1, standMinutes: values.2))
            cursor = next
        }
        return days
    }

    // ── Вспомогательные функции ────────────────────────────────

    /// Итог «как у Apple» + разбор каждой записи по источникам.
    private func quantityMetric(_ type: HKQuantityType, unit: HKUnit, _ predicate: NSPredicate)
        async throws -> (metric: Metric, sources: Set<SourceInfo>) {

        var metric = Metric()
        // 1) Итог от Apple: тут двойной подсчёт уже убран системой.
        metric.total = try await statisticsSum(type, unit: unit, predicate)

        // 2) Сырые записи — смотрим, кто их сделал.
        let samples = try await HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: []
        ).result(for: store)

        var sources = Set<SourceInfo>()
        for sample in samples {
            let value = sample.quantity.doubleValue(for: unit)
            let info = Self.sourceInfo(of: sample)
            sources.insert(info)
            if Self.isManual(sample) {
                metric.manual += value
            } else if info.isWatch {
                metric.fromWatch += value
            }
        }
        return (metric, sources)
    }

    /// Суммарная длительность записанных тренировок (в минутах).
    private func workoutMetric(_ predicate: NSPredicate)
        async throws -> (metric: Metric, sources: Set<SourceInfo>) {

        let workouts = try await HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: []
        ).result(for: store)

        var metric = Metric()
        var sources = Set<SourceInfo>()
        for workout in workouts {
            let minutes = workout.duration / 60
            let info = Self.sourceInfo(of: workout)
            sources.insert(info)
            metric.total += minutes
            if Self.isManual(workout) {
                metric.manual += minutes
            } else if info.isWatch {
                metric.fromWatch += minutes
            }
        }
        return (metric, sources)
    }

    /// Сумма за период — так же, как считает приложение «Здоровье».
    private func statisticsSum(_ type: HKQuantityType, unit: HKUnit, _ predicate: NSPredicate) async throws -> Double {
        let stats = try await HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        ).result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    /// Запись введена человеком руками (например, «Добавить данные» в Здоровье)?
    private static func isManual(_ sample: HKSample) -> Bool {
        (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool) == true
    }

    /// Определяем, сделали ли запись часы.
    /// productType — модель устройства, где работал источник: «Watch6,1», «iPhone14,2».
    private static func sourceInfo(of sample: HKSample) -> SourceInfo {
        let product = sample.sourceRevision.productType ?? ""
        let model = sample.device?.model ?? ""
        let isWatch = product.hasPrefix("Watch") || model == "Watch"

        let device: String
        if isWatch {
            device = "Apple Watch" + (product.isEmpty ? "" : " (\(product))")
        } else if !product.isEmpty {
            device = product
        } else if !model.isEmpty {
            device = model
        } else {
            device = "устройство неизвестно"
        }
        return SourceInfo(name: sample.sourceRevision.source.name, device: device, isWatch: isWatch)
    }
}
