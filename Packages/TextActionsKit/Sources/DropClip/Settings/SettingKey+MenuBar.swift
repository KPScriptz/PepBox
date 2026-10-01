// SettingKey+MenuBar.swift
// DropClip
//
// Defines the AppKit presentation preference for the menu bar status item.
import DropClipCore

extension SettingKey where Value == Bool {
    static var showMenuBarIcon: SettingKey<Bool> {
        SettingKey<Bool>("showMenuBarIcon", defaultValue: true)
    }
}
