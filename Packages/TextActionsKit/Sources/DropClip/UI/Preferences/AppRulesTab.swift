// AppRulesTab.swift
// DropClip
//
// Renders the application rules preferences tab for managing app exclusion rules and application-specific settings.
// Styled with inset SettingsCards.

import SwiftUI
import AppKit
import DropClipCore

@MainActor
public struct AppRulesTab: View {
    @ObservedObject private var ruleEngine = RuleEngine.shared

    public init() {}

    public var body: some View {
        // Droppy: a page of Droppy's native Settings inside Droppy.
        DropClipSettingsPageBody(spacing: 14) {
                SettingsCard("Application Rules") {
                    if ruleEngine.userRules.isEmpty {
                        ContentUnavailableView {
                            Label("No App Rules Configured", systemImage: "shield")
                        } description: {
                            Text("Text Actions works in all applications by default. Add an application to configure per-app rules or exclusions.")
                                .multilineTextAlignment(.center)
                        } actions: {
                            Button("Add Application") { SettingsRouter.shared.push(.addApplication) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(Array(ruleEngine.userRules.enumerated()), id: \.element.id) { index, rule in
                            if index > 0 {
                                SettingsDivider(insetLeading: 56)
                            }
                            AppRuleRowView(rule: rule) { updatedRule in
                                RuleEngine.shared.addOrUpdateRule(updatedRule)
                            } onDelete: {
                                RuleEngine.shared.removeRule(id: rule.id)
                            }
                            // Droppy: the native Form pads its rows itself.
                            .padding(.horizontal, DropClipHost.isInsideDroppy ? 0 : 16)
                            .padding(.vertical, DropClipHost.isInsideDroppy ? 0 : 6)
                        }
                    }
                }

                // Droppy: a note under the cards is the Form's footer inside Droppy.
                // PepBox: Droppy-only branch removed
                Text("Configure per-app trigger and paste behavior.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                
        }
    }
}

@MainActor
private struct AppRuleRowView: View {
    let rule: AppRule
    let onUpdate: (AppRule) -> Void
    let onDelete: () -> Void

    private var bundleID: String {
        rule.bundleIdentifiers.first ?? String(localized: "Unknown App")
    }

    private var isDisabled: Bool {
        rule.disabled == true
    }

    private var isHotkeyOnly: Bool {
        rule.hotkeyOnly == true
    }

    private var isPasteDenied: Bool {
        rule.denyPaste == true
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // App Icon
            // Droppy: looked up once (`DropClipAppLookup`), not on every pass of every row.
            if let appIcon = DropClipAppLookup.icon(forBundleID: bundleID) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .opacity(isDisabled ? 0.5 : 1.0)
            } else {
                Image(systemName: bundleID.contains("*") ? "asterisk.circle" : "app.dashed")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .opacity(isDisabled ? 0.5 : 1.0)
            }

            // App Title & Bundle ID
            VStack(alignment: .leading, spacing: 2) {
                if let appName = DropClipAppLookup.name(forBundleID: bundleID) {
                    Text(appName)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                    Text(bundleID)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(bundleID)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                }
            }

            Spacer()

            // Disable Toggle
            Toggle("", isOn: Binding(
                get: { !isDisabled },
                set: { isEnabled in
                    let updated = AppRule(
                        bundleIdentifiers: rule.bundleIdentifiers,
                        disabled: isEnabled ? nil : true,
                        hotkeyOnly: rule.hotkeyOnly,
                        useMenuCopy: rule.useMenuCopy,
                        denyPaste: rule.denyPaste,
                        retrievalMode: rule.retrievalMode,
                        gate: rule.gate
                    )
                    onUpdate(updated)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            // Droppy: the size of every other switch on the page.
            .dropClipFormSwitchSize(upstream: .regular)
            .accessibilityLabel(isDisabled ? String(localized: "Enable in this app") : String(localized: "Disable in this app"))

            // Three-Dots (...) Actions Menu
            Menu {
                Button {
                    let updated = AppRule(
                        bundleIdentifiers: rule.bundleIdentifiers,
                        disabled: rule.disabled,
                        hotkeyOnly: isHotkeyOnly ? nil : true,
                        useMenuCopy: rule.useMenuCopy,
                        denyPaste: rule.denyPaste,
                        retrievalMode: rule.retrievalMode,
                        gate: rule.gate
                    )
                    onUpdate(updated)
                } label: {
                    if isHotkeyOnly {
                        Label("Hotkey Only", systemImage: "checkmark")
                    } else {
                        Text("Hotkey Only")
                    }
                }

                Button {
                    let updated = AppRule(
                        bundleIdentifiers: rule.bundleIdentifiers,
                        disabled: rule.disabled,
                        hotkeyOnly: rule.hotkeyOnly,
                        useMenuCopy: rule.useMenuCopy,
                        denyPaste: isPasteDenied ? nil : true,
                        retrievalMode: rule.retrievalMode,
                        gate: rule.gate
                    )
                    onUpdate(updated)
                } label: {
                    if isPasteDenied {
                        Label("Copy Result Only", systemImage: "checkmark")
                    } else {
                        Text("Copy Result Only")
                    }
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("Remove Rule", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More Actions")
            .accessibilityLabel("More Actions")
        }
        .padding(.vertical, 4)
    }
}
