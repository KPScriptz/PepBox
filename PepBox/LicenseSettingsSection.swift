import SwiftUI
import Darwin

struct LicenseSettingsSection: View {
    var body: some View {
        // OPEN SOURCE: Show open source info instead of license activation
        Section {
            openSourceCard
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        } header: {
            Text("License")
        } footer: {
            Text("This is an open source build. All features are free for everyone.")
        }
    }
    
    private var openSourceCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Open Source")
                    .font(.system(size: 13, weight: .semibold))
                Text("All features unlocked - Free for everyone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
