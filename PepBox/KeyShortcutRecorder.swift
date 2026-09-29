import SwiftUI
import Carbon


struct KeyShortcutRecorder: View {
    @Binding var shortcut: SavedShortcut?
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Shortcut display
            Text(shortcut?.description ?? "None")
                .font(.system(size: 12, weight: .medium))
                .frame(minWidth: 80, alignment: .center)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(AdaptiveColors.buttonBackgroundAuto)
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous)
                        .stroke(isRecording ? Color.blue : AdaptiveColors.subtleBorderAuto, lineWidth: isRecording ? 2 : 1)
                )
            
            // Record button
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "Press Keys..." : "Record Shortcut")
                    .lineLimit(1)
                    .frame(width: 120)
            }
            .buttonStyle(PepBoxAccentButtonStyle(color: isRecording ? .red : .blue, size: .small))
        }
        .onDisappear {
            stopRecording() // Cleanup
        }
    }
    
    func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore modifier keys pressed alone (including Caps Lock)
            // 54-55: Right/Left Command, 56: Left Shift, 57: Caps Lock
            // 58: Left Option, 59: Left Control, 60: Right Shift
            // 61: Right Option, 62: Right Control
            if event.keyCode == 54 || event.keyCode == 55 || event.keyCode == 56 || 
               event.keyCode == 57 || event.keyCode == 58 || event.keyCode == 59 || 
               event.keyCode == 60 || event.keyCode == 61 || event.keyCode == 62 {
                return nil
            }
            
            // Capture
            DispatchQueue.main.async {
                let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
                self.shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: flags.rawValue)
                self.stopRecording()
            }
            return nil // Swallow event
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

