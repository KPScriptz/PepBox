// Posts synthetic mouse and keyboard events for the UI test in CI.
// Coordinates are global screen points with the origin at the top-left.
//
//   driver screen                      -> "<width> <height>"
//   driver move X Y
//   driver click X Y | rightclick X Y
//   driver drag X1 Y1 X2 Y2            -> press, move in steps, release
//   driver jiggle X1 Y1 X2 Y2          -> press, drag to X2 Y2, shake, hold (release with "up")
//   driver up X Y
//   driver key CODE [cmd] [shift] [opt] [ctrl]
//   driver windows [owner]             -> on-screen windows with bounds

import Cocoa

let args = CommandLine.arguments

func post(_ type: CGEventType, _ point: CGPoint, _ button: CGMouseButton = .left) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)?
        .post(tap: .cghidEventTap)
}

func point(_ index: Int) -> CGPoint {
    CGPoint(x: Double(args[index])!, y: Double(args[index + 1])!)
}

func dragPath(from start: CGPoint, to end: CGPoint, steps: Int = 40) {
    for i in 1...steps {
        let t = Double(i) / Double(steps)
        post(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t))
        usleep(25_000)
    }
}

switch args.count > 1 ? args[1] : "" {
case "screen":
    let bounds = CGDisplayBounds(CGMainDisplayID())
    print(Int(bounds.width), Int(bounds.height))

case "move":
    post(.mouseMoved, point(2))

case "click":
    post(.leftMouseDown, point(2)); usleep(80_000); post(.leftMouseUp, point(2))

case "rightclick":
    post(.rightMouseDown, point(2), .right); usleep(80_000); post(.rightMouseUp, point(2), .right)

case "drag":
    let start = point(2), end = point(4)
    post(.mouseMoved, start); usleep(200_000)
    post(.leftMouseDown, start); usleep(300_000)
    dragPath(from: start, to: end)
    usleep(600_000)
    post(.leftMouseUp, end)

case "jiggle":
    let start = point(2), end = point(4)
    post(.mouseMoved, start); usleep(200_000)
    post(.leftMouseDown, start); usleep(300_000)
    dragPath(from: start, to: end, steps: 20)
    for i in 0..<16 {
        let dx: Double = i % 2 == 0 ? 60 : -60
        post(.leftMouseDragged, CGPoint(x: end.x + dx, y: end.y)); usleep(40_000)
    }
    post(.leftMouseDragged, end)

case "up":
    post(.leftMouseUp, point(2))

case "key":
    let code = CGKeyCode(Int(args[2])!)
    var flags: CGEventFlags = []
    for modifier in args.dropFirst(3) {
        switch modifier {
        case "cmd": flags.insert(.maskCommand)
        case "shift": flags.insert(.maskShift)
        case "opt": flags.insert(.maskAlternate)
        case "ctrl": flags.insert(.maskControl)
        default: break
        }
    }
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
        usleep(50_000)
    }

case "windows":
    let owner = args.count > 2 ? args[2] : nil
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for window in list {
        let name = window[kCGWindowOwnerName as String] as? String ?? "?"
        if let owner, name != owner { continue }
        let b = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
        let title = window[kCGWindowName as String] as? String ?? ""
        let layer = window[kCGWindowLayer as String] as? Int ?? 0
        print("\(name)\tlayer=\(layer)\tx=\(Int(b["X"] ?? 0)) y=\(Int(b["Y"] ?? 0)) w=\(Int(b["Width"] ?? 0)) h=\(Int(b["Height"] ?? 0))\t\(title)")
    }

default:
    FileHandle.standardError.write("unknown command\n".data(using: .utf8)!)
    exit(2)
}
