import SwiftUI

// ─────────────────────────────────────────────────────────────
// ЭКРАН 2. ПОДКЛЮЧЕНИЕ ЧАСОВ (соглашение на доступ)
// Объясняем, что читаем, и по кнопке вызываем системное окно Apple.
// ─────────────────────────────────────────────────────────────

struct ConnectView: View {
    @EnvironmentObject var model: AppModel
    @State private var isConnecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: "applewatch")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Подключите Apple Watch")
                .font(.largeTitle.bold())

            Text("Приложение будет только читать данные активности из «Здоровья». Мы ничего не записываем и не меняем.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label("Шаги", systemImage: "figure.walk")
                Label("Активные калории", systemImage: "flame.fill")
                Label("Тренировки и минуты упражнений", systemImage: "stopwatch")
            }
            .font(.headline)

            Text("Сейчас Apple покажет окно разрешений — включите все пункты.")
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
                Task {
                    await model.connect()
                    isConnecting = false
                }
            } label: {
                HStack {
                    if isConnecting { ProgressView().tint(.white) }
                    Text("Подключить Apple Watch")
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
}

#Preview { ConnectView().environmentObject(AppModel()) }
