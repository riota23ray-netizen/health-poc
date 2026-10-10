import SwiftUI

// ─────────────────────────────────────────────────────────────
// ЭКРАН 1. ЗАГРУЗКА
// Просто логотип и индикатор, пока приложение решает, куда идти.
// ─────────────────────────────────────────────────────────────

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.green.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 72))
                Text("Health PoC")
                    .font(.largeTitle.bold())
                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
            .foregroundStyle(.white)
        }
    }
}

