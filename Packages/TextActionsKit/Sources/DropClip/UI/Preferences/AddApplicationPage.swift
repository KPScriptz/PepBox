// AddApplicationPage.swift
// DropClip
//
// Picking the application an App Rule applies to, as a page reached from App Rules: the running
// and installed applications in a searchable list, or a bundle identifier typed by hand.
import SwiftUI
import AppKit
import DropClipCore

@MainActor
public struct AddApplicationPage: View {
    @ObservedObject private var router = SettingsRouter.shared

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var customBundleID = ""

    @StateObject private var scanner = InstalledAppsScanner()
    /// Droppy: the merged, sorted list, built when the scan lands rather than on every pass: it
    /// asked every running app for its activation policy and bundle URL (each a round trip to
    /// another process) and re-sorted everything for each keystroke in the search field.
    @State private var apps: [InstalledAppInfo] = []

    /// The toolbar's search inside Droppy; `nil`, the page searches in a field of its own, as
    /// upstream does.
    private let hostedQuery: String?

    public init(hostedQuery: String? = nil) {
        self.hostedQuery = hostedQuery
    }

    private func mergedApps() -> [InstalledAppInfo] {
        var map = [String: InstalledAppInfo]()

        for app in scanner.installedApps {
            map[app.bundleIdentifier] = app
        }

        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular,
               let bid = app.bundleIdentifier,
               bid != "com.dropclip.Text Actions",
               map[bid] == nil {
                let name = app.localizedName ?? bid
                let path = app.bundleURL?.path ?? ""
                map[bid] = InstalledAppInfo(name: name, bundleIdentifier: bid, path: path)
            }
        }

        return Array(map.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredApps: [InstalledAppInfo] {
        let query = (hostedQuery ?? searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query) }
    }

    private func add(_ bundleID: String) {
        RuleEngine.shared.addOrUpdateRule(AppRule(bundleIdentifiers: [bundleID]))
        router.pop()
    }

    public var body: some View {
        // PepBox: Droppy-only branch removed
        upstreamBody
        
    }

    /// Inside Droppy: sections of Droppy's Form. A bundle identifier typed by hand first, then
    /// every application as a row with its own Add button, filtered by the toolbar's search, or,
    /// with no `hostedQuery`, by a search field that heads the applications.
    private var nativeBody: some View {
        DropClipSettingsPageBody {
            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        TextField("Bundle Identifier", text: $customBundleID, prompt: Text(verbatim: "com.apple.Terminal"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                            .onSubmit { submitCustom() }
                        Button("Add Rule") { submitCustom() }
                            .disabled(customBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } label: {
                    Text("Bundle Identifier")
                }
            } footer: {
                Text("Example: com.apple.Terminal. Use * to match several apps.")
                    .foregroundStyle(.secondary)
            }

            Section {
                if hostedQuery == nil {
                    DropClipSearchRow(text: $searchText, prompt: String(localized: "Search applications..."))
                }
                if scanner.isLoading && scanner.installedApps.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading applications...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(filteredApps) { app in
                        nativeAppRow(app)
                    }
                }
            } header: {
                Text("Applications")
            } footer: {
                HStack(spacing: 8) {
                    Text("Choose an application to add a rule for it.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { router.pop() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding(.top, 6)
            }
        }
        .task {
            if scanner.installedApps.isEmpty {
                _ = await scanner.scanInstalledApps()
            }
        }
        .onReceive(scanner.$installedApps) { _ in apps = mergedApps() }
    }

    private func nativeAppRow(_ app: InstalledAppInfo) -> some View {
        LabeledContent {
            Button("Add") { add(app.bundleIdentifier) }
                .help(String(localized: "Add a rule for \(app.name)"))
        } label: {
            HStack(spacing: 10) {
                if let appIcon = app.path.isEmpty
                    ? DropClipAppLookup.icon(forBundleID: app.bundleIdentifier)
                    : DropClipAppLookup.icon(forPath: app.path, key: app.bundleIdentifier) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "app")
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                DropClipRowTitle(title: app.name, subtitle: app.bundleIdentifier)
            }
        }
    }

    private var upstreamBody: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Applications").tag(0)
                Text("Custom").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .padding(.top, 12)
            .padding(.bottom, 10)

            if selectedTab == 1 {
                customEntry
            } else {
                applicationList
            }
        }
        // Droppy: the list is rebuilt when the scan publishes, not on every pass.
        .onReceive(scanner.$installedApps) { _ in apps = mergedApps() }
    }

    private var customEntry: some View {
        SettingsEditorPage {
            VStack(alignment: .leading, spacing: 14) {
                InsetGroupCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bundle Identifier")
                            .font(.subheadline)
                        TextField("e.g. com.apple.Terminal", text: $customBundleID)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { submitCustom() }
                        Text("Example: com.apple.Terminal. Use * to match several apps.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
            }
        } footer: {
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { router.pop() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Rule") { submitCustom() }
                    .buttonStyle(.borderedProminent)
                    .disabled(customBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func submitCustom() {
        let trimmed = customBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        add(trimmed)
    }

    private var applicationList: some View {
        VStack(spacing: 0) {
            NativeSearchField(
                text: $searchText,
                placeholder: String(localized: "Search applications...")
            )
            .frame(height: 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

            Group {
                if scanner.isLoading && scanner.installedApps.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading applications...").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredApps) { app in
                        Button {
                            add(app.bundleIdentifier)
                        } label: {
                            HStack(spacing: 10) {
                                // Droppy: looked up once (`DropClipAppLookup`), not on every pass.
                                if let appIcon = app.path.isEmpty
                                    ? DropClipAppLookup.icon(forBundleID: app.bundleIdentifier)
                                    : DropClipAppLookup.icon(forPath: app.path, key: app.bundleIdentifier) {
                                    Image(nsImage: appIcon)
                                        .resizable()
                                        .frame(width: 26, height: 26)
                                } else {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 26, height: 26)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(app.bundleIdentifier)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 3)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "Add a rule for \(app.name)"))
                    }
                    .listStyle(.inset)
                    .alternatingRowBackgrounds()
                }
            }
            .task {
                if scanner.installedApps.isEmpty {
                    _ = await scanner.scanInstalledApps()
                }
            }

            Divider()

            HStack {
                Text("Choose an application to add a rule for it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { router.pop() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}
