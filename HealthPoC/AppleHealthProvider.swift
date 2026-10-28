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
    private let standType = HKCategoryType(.appleStandHour)

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

    // ── Данные за конкретный календарный день ──────────────────
    func fetchToday() async throws -> ActivityData {
        try await fetch(for: Date())
    }

    func fetch(for date: Date) async throws -> ActivityData {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw NSError(domain: "AppleHealthProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось определить границы дня"])
        }
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])
        var result = ActivityData(date: startOfDay, deviceType: deviceName, syncedAt: Date())
        var allSources = Set<SourceInfo>()

        let steps = try await quantityMetric(stepType, unit: .count(), predicate)
        result.steps = steps.metric
        allSources.formUnion(steps.sources)

        let energy = try await quantityMetric(energyType, unit: .kilocalorie(), predicate)
        result.activeCalories = energy.metric
        allSources.formUnion(energy.sources)

        let workouts = try await workoutMetric(predicate)
        result.workoutMinutes = workouts.metric
        allSources.formUnion(workouts.sources)

        result.exerciseMinutes = try await statisticsSum(exerciseType, unit: .minute(), predicate)
        result.standHours = try await standHoursCount(predicate)
        result.sources = allSources.sorted { $0.isWatch && !$1.isWatch }
        return result
    }

    private func standHoursCount(_ predicate: NSPredicate) async throws -> Double {
        let samples = try await HKSampleQueryDescriptor(
            predicates: [.categorySample(type: standType, predicate: predicate)],
            sortDescriptors: []
        ).result(for: store)
        // Считаем только часы, когда пользователь действительно стоял/двигался.
        return Double(Set(samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.map {
            Calendar.current.component(.hour, from: $0.startDate)
        }).count)
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
