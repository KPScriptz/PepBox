import SwiftUI

struct LicenseActivationView: View {
    let onRequestQuit: () -> Void
    let onActivationCompleted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("Open Source")
                .font(.system(size: 24, weight: .bold))
            
            Text("PepBox is now open source and free for everyone!")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                onActivationCompleted()
            } label: {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(PepBoxAccentButtonStyle(color: .green, size: .small))
        }
        .padding(40)
        .frame(width: 320)
        .onAppear {
            // Auto-continue after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onActivationCompleted()
            }
        }
    }
}
