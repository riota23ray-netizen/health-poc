import SwiftUI

// ─────────────────────────────────────────────────────────────
// ЭКРАН 2. ПОДКЛЮЧЕНИЕ ЧАСОВ (соглашение на доступ)
// Объясняем, что читаем, и по кнопке вызываем системное окно Apple.
// ─────────────────────────────────────────────────────────────

struct ConnectView: View {
    @EnvironmentObject var model: AppModel
    @State private var isConnecting = false
    @State private var selectedDevice = UserDefaults.standard.string(forKey: "selectedActivityDevice") ?? "Apple Watch"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: "watchface.applewatch.case")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Выберите свои часы")
                .font(.largeTitle.bold())

            Text("Прототип читает показатели из Apple Health. Для Mi Band данные должны синхронизироваться из Mi Fitness в приложение «Здоровье».")
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                deviceRow("Apple Watch", subtitle: "Прямое чтение колец Apple Health", icon: "applewatch")
                deviceRow("Xiaomi Mi Band 8", subtitle: "Через синхронизацию с Apple Health", icon: "figure.run")
                HStack {
                    Image(systemName: "clock")
                    Text("Samsung, Garmin и другие — позже")
                    Spacer()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(12)
            }

            Text("Далее iOS покажет системный запрос доступа. Разреши чтение шагов, калорий и данных активности.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            if let error = model.errorText {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                isConnecting = true
                UserDefaults.standard.set(selectedDevice, forKey: "selectedActivityDevice")
                Task {
                    await model.connect()
                    isConnecting = false
                }
            } label: {
                HStack {
                    if isConnecting { ProgressView().tint(.white) }
                    Text("Подключить данные и продолжить")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConnecting)
        }
        .padding(24)
    }

    private func deviceRow(_ title: String, subtitle: String, icon: String) -> some View {
        Button { selectedDevice = title } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(.green).frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selectedDevice == title ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedDevice == title ? Color.green : Color.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selectedDevice == title ? Color.green : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

