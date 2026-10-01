//
//  KeyboardShortcuts.swift
//  DropClip, inside Droppy
//
//  The part of Sindre Sorhus's KeyboardShortcuts package DropClip uses,
//  re-implemented on its API. KeyboardShortcuts is Copyright (c) Sindre Sorhus
//  and MIT licensed (Assets/Legal/KeyboardShortcuts-LICENSE.txt);
//  declared here because a droplet links DroppyKit and nothing else
//  (the port from OpenClip (PROVENANCE.md) drops the import).
//

import AppKit
import Carbon.HIToolbox
import DropClipCore

/// Droppy: DropClip's global shortcuts, on Carbon hot keys the way the package registers them.
///
/// Storage is the package's own, so DropClip's settings export (`SettingsCatalog+App`) and an
/// import from OpenClip read the same values: `KeyboardShortcuts_<name>` holds the chord
/// as JSON (`{"carbonKeyCode":8,"carbonModifiers":2304}`), or `false` for one the user cleared,
/// in DropClip's own defaults domain. A name with no stored value has its initial chord.
///
/// Every chord is set on Droppy's Shortcuts page (`DropClipShortcutEntries`), where Droppy's
/// recorder turns `isEnabled` off while it records so a chord being typed does not fire.
@MainActor
public enum KeyboardShortcuts {
    // MARK: Types

    /// A shortcut's identity.
    public struct Name: Hashable, Sendable, RawRepresentable {
        public let rawValue: String
        /// The chord a name has until the user sets or clears it.
        public let initialShortcut: Shortcut?

        public init(_ name: String, initial: Shortcut? = nil) {
            rawValue = name
            initialShortcut = initial
        }

        public init?(rawValue: String) {
            self.init(rawValue)
        }

        public static func == (lhs: Name, rhs: Name) -> Bool { lhs.rawValue == rhs.rawValue }
        public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }
    }

    /// A key, by its virtual key code.
    public struct Key: Hashable, Sendable, RawRepresentable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let c = Key(rawValue: kVK_ANSI_C)
        public static let one = Key(rawValue: kVK_ANSI_1)
        public static let two = Key(rawValue: kVK_ANSI_2)
        public static let three = Key(rawValue: kVK_ANSI_3)
        public static let four = Key(rawValue: kVK_ANSI_4)
        public static let five = Key(rawValue: kVK_ANSI_5)
        public static let six = Key(rawValue: kVK_ANSI_6)
        public static let seven = Key(rawValue: kVK_ANSI_7)
        public static let eight = Key(rawValue: kVK_ANSI_8)
        public static let nine = Key(rawValue: kVK_ANSI_9)
    }

    /// A chord: one key and its modifiers.
    public struct Shortcut: Hashable, Codable, Sendable, CustomStringConvertible {
        public let carbonKeyCode: Int
        public let carbonModifiers: Int

        public init(carbonKeyCode: Int, carbonModifiers: Int = 0) {
            self.carbonKeyCode = carbonKeyCode
            self.carbonModifiers = carbonModifiers
        }

        public init(_ key: Key, modifiers: NSEvent.ModifierFlags = []) {
            self.init(carbonKeyCode: key.rawValue, carbonModifiers: Self.carbonModifiers(from: modifiers))
        }

        /// The chord a key-down event is, or nil for an event that is not a key.
        public init?(event: NSEvent) {
            guard event.type == .keyDown || event.type == .keyUp else { return nil }
            self.init(
                carbonKeyCode: Int(event.keyCode),
                carbonModifiers: Self.carbonModifiers(from: event.modifierFlags))
        }

        public var key: Key? { Key(rawValue: carbonKeyCode) }

        public var modifiers: NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            if carbonModifiers & controlKey != 0 { flags.insert(.control) }
            if carbonModifiers & optionKey != 0 { flags.insert(.option) }
            if carbonModifiers & shiftKey != 0 { flags.insert(.shift) }
            if carbonModifiers & cmdKey != 0 { flags.insert(.command) }
            return flags
        }

        public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
            var carbon = 0
            let flags = flags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) { carbon |= cmdKey }
            if flags.contains(.option) { carbon |= optionKey }
            if flags.contains(.control) { carbon |= controlKey }
            if flags.contains(.shift) { carbon |= shiftKey }
            return carbon
        }

        /// The chord as the menu bar writes it: ⌃⌥⇧⌘ then the key.
        public var description: String {
            var text = ""
            let flags = modifiers
            if flags.contains(.control) { text += "⌃" }
            if flags.contains(.option) { text += "⌥" }
            if flags.contains(.shift) { text += "⇧" }
            if flags.contains(.command) { text += "⌘" }
            return text + KeyboardShortcuts.keyName(for: carbonKeyCode)
        }
    }

    // MARK: Storage

    private static var defaults: UserDefaults { .dropclip }

    private static func storageKey(_ name: Name) -> String { "KeyboardShortcuts_\(name.rawValue)" }

    public static func getShortcut(for name: Name) -> Shortcut? {
        let value = defaults.object(forKey: storageKey(name))
        if value == nil { return name.initialShortcut }
        guard let string = value as? String, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    public static func setShortcut(_ shortcut: Shortcut?, for name: Name) {
        if let shortcut,
           let data = try? JSONEncoder().encode(shortcut),
           let string = String(data: data, encoding: .utf8)
        {
            defaults.set(string, forKey: storageKey(name))
        } else {
            defaults.set(false, forKey: storageKey(name))
        }
        refresh(name)
        NotificationCenter.default.post(name: .dropClipShortcutsDidChange, object: name.rawValue)
    }

    /// Back to the name's initial chord.
    public static func reset(_ names: Name...) {
        for name in names {
            defaults.removeObject(forKey: storageKey(name))
            refresh(name)
        }
        NotificationCenter.default.post(name: .dropClipShortcutsDidChange, object: nil)
    }

    // MARK: Handlers

    private static var keyDownHandlers: [Name: [() -> Void]] = [:]
    private static var keyUpHandlers: [Name: [() -> Void]] = [:]
    private static var disabledNames: Set<Name> = []

    public static func onKeyDown(for name: Name, action: @escaping () -> Void) {
        keyDownHandlers[name, default: []].append(action)
        refresh(name)
    }

    public static func onKeyUp(for name: Name, action: @escaping () -> Void) {
        keyUpHandlers[name, default: []].append(action)
        refresh(name)
    }

    /// Takes the chords back from the rest of the system.
    public static func enable(_ names: [Name]) {
        for name in names {
            disabledNames.remove(name)
            refresh(name)
        }
    }

    /// Hands the chords to the rest of the system until `enable`.
    public static func disable(_ names: [Name]) {
        for name in names {
            disabledNames.insert(name)
            refresh(name)
        }
    }

    /// Every chord at once: off while a recorder is recording, and while the droplet is off.
    public static var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            for name in Set(keyDownHandlers.keys).union(keyUpHandlers.keys) { refresh(name) }
        }
    }

    /// Every name a handler was installed for, for Droppy's Shortcuts page.
    public static var handledNames: Set<Name> { Set(keyDownHandlers.keys).union(keyUpHandlers.keys) }

    /// The chord a name holds right now, when another name already holds it.
    public static func owner(of shortcut: Shortcut, excluding name: Name) -> Name? {
        handledNames.first { $0 != name && getShortcut(for: $0) == shortcut }
    }

    // MARK: Carbon

    private nonisolated static let signature: OSType = 0x4F43_4C50  // "OCLP"
    private static var registrations: [Name: (ref: EventHotKeyRef, id: UInt32)] = [:]
    private static var namesByID: [UInt32: Name] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerRef: EventHandlerRef?

    private static func refresh(_ name: Name) {
        unregister(name)
        guard isEnabled, !disabledNames.contains(name),
              keyDownHandlers[name] != nil || keyUpHandlers[name] != nil,
              let shortcut = getShortcut(for: name)
        else { return }
        installHandlerIfNeeded()
        let id = nextID
        nextID &+= 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.carbonKeyCode), UInt32(shortcut.carbonModifiers),
            EventHotKeyID(signature: signature, id: id), GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else { return }
        registrations[name] = (ref, id)
        namesByID[id] = name
    }

    private static func unregister(_ name: Name) {
        guard let registration = registrations.removeValue(forKey: name) else { return }
        UnregisterEventHotKey(registration.ref)
        namesByID[registration.id] = nil
    }

    /// Unregisters every chord, for the droplet switching off. Handlers stay; `isEnabled`
    /// brings the chords back.
    public static func suspendAll() {
        isEnabled = false
    }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                // Droppy registers hot keys of its own on the same target: anything not ours
                // passes on untouched.
                guard status == noErr, hotKeyID.signature == KeyboardShortcuts.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                let id = hotKeyID.id
                return DroppyMainThread.enter {
                    KeyboardShortcuts.dispatch(id: id, pressed: pressed) ? noErr : OSStatus(eventNotHandledErr)
                }
            },
            types.count, &types, nil, &handlerRef)
    }

    private static func dispatch(id: UInt32, pressed: Bool) -> Bool {
        guard let name = namesByID[id] else { return false }
        let handlers = (pressed ? keyDownHandlers[name] : keyUpHandlers[name]) ?? []
        for handler in handlers { handler() }
        return true
    }

    // MARK: Key names

    nonisolated fileprivate static func keyName(for keyCode: Int) -> String {
        if let special = specialKeyNames[keyCode] { return special }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "?" }
        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutData.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }

    private nonisolated static let specialKeyNames: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑",
        kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]
}

extension Notification.Name {
    /// Droppy: a chord changed, so Droppy's Shortcuts page and the link rows redraw.
    public static let dropClipShortcutsDidChange = Notification.Name("com.pivotxp.PepBox.textactions.shortcutsDidChange")
}
