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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let data = model.data {
                        MetricCard(icon: "figure.walk", title: "Шаги", unit: "", metric: data.steps)
                        MetricCard(icon: "flame.fill", title: "Активные калории", unit: "ккал", metric: data.activeCalories)
                        MetricCard(icon: "stopwatch", title: "Тренировки", unit: "мин", metric: data.workoutMinutes)

                        InfoRow(title: "Минуты упражнений (кольцо)", value: "\(format(data.exerciseMinutes)) мин")

                        SourcesCard(sources: data.sources)

                        if data.steps.total == 0 && data.activeCalories.total == 0 {
                            Text("Везде 0? Проверьте разрешения: «Здоровье» → значок профиля → Приложения (раздел «Конфиденциальность») → Health PoC → включить всё.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }

                        Text("Обновлено: \(data.syncedAt.formatted(date: .omitted, time: .standard))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if model.isRefreshing {
                        ProgressView("Читаем данные…").padding(.top, 40)
                    }

                    if let error = model.errorText {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }

                    Button("Сбросить подключение (для теста)", role: .destructive) {
                        model.reset()
                    }
                    .font(.footnote)
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Сегодня")
            .refreshable { await model.refresh() }
            .toolbar {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
            }
        }
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
                        .foregroundStyle(source.isWatch ? .green : .secondary)
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
