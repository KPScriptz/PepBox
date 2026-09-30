import SwiftUI

// MARK: - Extensions Shop
// Extracted from SettingsView.swift for faster incremental builds

struct ExtensionsShopView: View {
    @State private var selectedCategory: ExtensionCategory? = nil  // nil = show all
    @State private var searchText = ""
    @Namespace private var categoryAnimation
    @State private var extensionCounts: [String: Int] = [:]
    @State private var extensionRatings: [String: AnalyticsService.ExtensionRating] = [:]
    @State private var refreshTrigger = UUID() // Force view refresh
    @AppStorage(AppPreferenceKey.disableAnalytics) private var disableAnalytics = PreferenceDefault.disableAnalytics
    
    // MARK: - Installed State Checks
    private var isAIInstalled: Bool { AIInstallManager.shared.isInstalled }
    private var isAlfredInstalled: Bool { UserDefaults.standard.bool(forKey: "alfredTracked") }
    private var isFinderInstalled: Bool { UserDefaults.standard.bool(forKey: "finderTracked") }
    private var isSpotifyInstalled: Bool { UserDefaults.standard.bool(forKey: "spotifyTracked") }
    private var isAppleMusicInstalled: Bool { !ExtensionType.appleMusic.isRemoved }
    private var isElementCaptureInstalled: Bool {
        UserDefaults.standard.data(forKey: "elementCaptureShortcut") != nil
    }
    private var isWindowSnapInstalled: Bool { !WindowSnapManager.shared.shortcuts.isEmpty }
    private var isFFmpegInstalled: Bool { FFmpegInstallManager.shared.isInstalled }
    private var isVoiceTranscribeInstalled: Bool { VoiceTranscribeManager.shared.isModelDownloaded }
    private var isTerminalNotchInstalled: Bool { TerminalNotchManager.shared.isInstalled }
    private var isNotificationHUDInstalled: Bool { UserDefaults.standard.bool(forKey: AppPreferenceKey.notificationHUDInstalled) }
    private var isCaffeineInstalled: Bool { UserDefaults.standard.bool(forKey: AppPreferenceKey.caffeineInstalled) }
    private var isMenuBarManagerInstalled: Bool { MenuBarManager.shared.isEnabled }
    private var isTodoInstalled: Bool { UserDefaults.standard.bool(forKey: AppPreferenceKey.todoInstalled) }
    private var isCameraInstalled: Bool { UserDefaults.standard.bool(forKey: AppPreferenceKey.cameraInstalled) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Featured Hero Section
                featuredSection
                
                // Extensions List (includes header, filters, and list)
                extensionsList
            }
            .padding(.top, 4)
        }
        .id(refreshTrigger)
        .onAppear {
            Task {
                guard !disableAnalytics else {
                    extensionCounts = [:]
                    extensionRatings = [:]
                    return
                }
                async let countsTask = AnalyticsService.shared.fetchExtensionCounts()
                async let ratingsTask = AnalyticsService.shared.fetchExtensionRatings()
                
                if let counts = try? await countsTask {
                    extensionCounts = counts
                }
                if let ratings = try? await ratingsTask {
                    extensionRatings = ratings
                }
            }
        }
        .onChange(of: disableAnalytics) { _, isDisabled in
            if isDisabled {
                extensionCounts = [:]
                extensionRatings = [:]
                return
            }

            Task {
                async let countsTask = AnalyticsService.shared.fetchExtensionCounts()
                async let ratingsTask = AnalyticsService.shared.fetchExtensionRatings()
                
                if let counts = try? await countsTask {
                    extensionCounts = counts
                }
                if let ratings = try? await ratingsTask {
                    extensionRatings = ratings
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extensionStateChanged)) { _ in
            refreshTrigger = UUID()
        }
    }
    
    // MARK: - Featured Hero Section
    
    private var featuredSection: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.cyan)
                    
                    Text("Featured Extensions")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AdaptiveColors.primaryTextAuto)
                }
                
                Spacer()
            }
            
            // Row 1: AI Background Removal + Voice Transcribe
            HStack(spacing: 12) {
                FeaturedExtensionCardCompact(
                    category: "",
                    title: "Background Removal",
                    subtitle: "Local AI processing",
                    iconURL: "pepbox-media://icons/ai-bg.jpg",
                    screenshotURL: "pepbox-media://images/ai-bg-screenshot.png",
                    accentColor: .cyan,
                    isInstalled: isAIInstalled
                ) {
                    AIInstallView(
                        installCount: extensionCounts["aiBackgroundRemoval"],
                        rating: extensionRatings["aiBackgroundRemoval"]
                    )
                }
                
                FeaturedExtensionCardCompact(
                    category: "",
                    title: "Voice Transcribe",
                    subtitle: "Speech to text, on your Mac",
                    iconURL: "pepbox-media://icons/voice-transcribe.jpg",
                    screenshotURL: "pepbox-media://images/voice-transcribe-screenshot.png",
                    accentColor: .cyan,
                    isInstalled: isVoiceTranscribeInstalled
                ) {
                    VoiceTranscribeInfoView(
                        installCount: extensionCounts["voiceTranscribe"],
                        rating: extensionRatings["voiceTranscribe"]
                    )
                }
            }
            
            // Full-width hero: Quickshare (NEW)
            if !ExtensionType.quickshare.isRemoved {
                FeaturedExtensionCardWide(
                    title: "PepBox Quickshare",
                    subtitle: "Share files instantly",
                    iconURL: "pepbox-media://icons/quickshare.jpg",
                    screenshotURL: "pepbox-media://images/quickshare-screenshot.png",
                    accentColor: .cyan,
                    isInstalled: !ExtensionType.quickshare.isRemoved,
                    features: ["Instant upload", "Auto-copy link", "Track expiry"]
                ) {
                    QuickshareInfoView(
                        installCount: extensionCounts["quickshare"],
                        rating: extensionRatings["quickshare"]
                    )
                }
            }
            
            // Row 2: Community extensions
            HStack(spacing: 12) {
                FeaturedExtensionCardCompact(
                    category: "COMMUNITY",
                    title: "Reminders",
                    subtitle: "Natural language tasks",
                    iconURL: "pepbox-media://icons/reminders.png",
                    iconPlaceholder: "checklist",
                    iconPlaceholderColor: .blue,
                    screenshotURL: "pepbox-media://images/reminders-screenshot.gif",
                    accentColor: .blue,
                    isInstalled: isTodoInstalled,
                    isNew: false,
                    isCommunity: false
                ) {
                    ToDoInfoView(
                        installCount: extensionCounts["todo"],
                        rating: extensionRatings["todo"]
                    )
                }
                
                FeaturedExtensionCardCompact(
                    category: "COMMUNITY",
                    title: "Notify me!",
                    subtitle: "Show notifications in your notch",
                    iconURL: "pepbox-media://icons/notification-hud.png",
                    screenshotURL: "pepbox-media://images/notification-hud-screenshot.png",
                    accentColor: .red,
                    isInstalled: isNotificationHUDInstalled,
                    isCommunity: false
                ) {
                    NotificationHUDInfoView()
                }
                
                FeaturedExtensionCardCompact(
                    category: "COMMUNITY",
                    title: "High Alert",
                    subtitle: "Keep your Mac awake",
                    iconURL: "pepbox-media://icons/high-alert.jpg",
                    screenshotURL: "pepbox-media://images/high-alert-screenshot.gif",
                    accentColor: .orange,
                    isInstalled: isCaffeineInstalled,
                    isCommunity: false
                ) {
                    CaffeineInfoView(
                        installCount: extensionCounts["caffeine"],
                        rating: extensionRatings["caffeine"]
                    )
                }
            }
        }
        .padding(PepBoxSpacing.xs) // Allow room for hover scale animation
    }
    
    // MARK: - Category Swiper
    
    private var categorySwiperHeader: some View {
        // Wraps onto a second line when the window is narrow instead of running off the edge.
        FlowLayout(spacing: 10) {
            // Filter out .all - it's now the default when no filter selected
            ForEach(ExtensionCategory.allCases.filter { $0 != .all }) { category in
                CategoryPillButton(
                    category: category,
                    isSelected: selectedCategory == category,
                    namespace: categoryAnimation
                ) {
                    withAnimation(PepBoxAnimation.state) {
                        // Double-click/toggle behavior: clicking selected category deselects it
                        if selectedCategory == category {
                            selectedCategory = nil  // Back to "all"
                        } else {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
    
    // MARK: - Extensions List
    
    private var extensionsList: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                    
                    Text("All Extensions")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AdaptiveColors.primaryTextAuto)
                    Text("\(filteredExtensions.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search extensions", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 200)
                .background(Capsule().fill(AdaptiveColors.overlayAuto(0.06)))
            }
            
            // Category filter pills
            categorySwiperHeader
            
            // Extensions list
            VStack(spacing: 0) {
                // Filter extensions based on selected category
                let extensions = filteredExtensions
                
                ForEach(Array(extensions.enumerated()), id: \.1.id) { index, ext in
                    CompactExtensionRow(
                        iconURL: ext.iconURL,
                        iconPlaceholder: ext.iconPlaceholder,
                        iconPlaceholderColor: ext.iconPlaceholderColor,
                        title: ext.title,
                        subtitle: ext.subtitle,
                        isInstalled: ext.isInstalled,
                        installCount: extensionCounts[ext.analyticsKey],
                        isCommunity: ext.isCommunity
                    ) {
                        ext.detailView()
                    }
                    
                    if index < extensions.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(AdaptiveColors.overlayAuto(0.03))
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Filtered Extensions
    
    private var filteredExtensions: [ExtensionListItem] {
        let allExtensions: [ExtensionListItem] = [
            // AI Extensions
            ExtensionListItem(
                id: "aiBackgroundRemoval",
                iconURL: "pepbox-media://icons/ai-bg.jpg",
                title: "Background Removal",
                subtitle: "Remove backgrounds instantly",
                category: .ai,
                isInstalled: isAIInstalled,
                analyticsKey: "aiBackgroundRemoval",
                extensionType: .aiBackgroundRemoval
            ) {
                AnyView(AIInstallView(
                    installCount: extensionCounts["aiBackgroundRemoval"],
                    rating: extensionRatings["aiBackgroundRemoval"]
                ))
            },
            ExtensionListItem(
                id: "voiceTranscribe",
                iconURL: "pepbox-media://icons/voice-transcribe.jpg",
                title: "Voice Transcribe",
                subtitle: "Speech to text, on your Mac",
                category: .ai,
                isInstalled: isVoiceTranscribeInstalled,
                analyticsKey: "voiceTranscribe",
                extensionType: .voiceTranscribe
            ) {
                AnyView(VoiceTranscribeInfoView(
                    installCount: extensionCounts["voiceTranscribe"],
                    rating: extensionRatings["voiceTranscribe"]
                ))
            },
            // Media Extensions
            ExtensionListItem(
                id: "ffmpegVideoCompression",
                iconURL: "pepbox-media://icons/targeted-video-size.jpg",
                title: "Video Target Size",
                subtitle: "Compress videos to size",
                category: .files,
                isInstalled: isFFmpegInstalled,
                analyticsKey: "ffmpegVideoCompression",
                extensionType: .ffmpegVideoCompression
            ) {
                AnyView(FFmpegInstallView(
                    installCount: extensionCounts["ffmpegVideoCompression"],
                    rating: extensionRatings["ffmpegVideoCompression"]
                ))
            },
            // Productivity Extensions
            ExtensionListItem(
                id: "alfred",
                iconURL: "pepbox-media://icons/alfred.png",
                title: "Alfred Workflow",
                subtitle: "Push files via keyboard",
                category: .files,
                isInstalled: isAlfredInstalled,
                analyticsKey: "alfred",
                extensionType: .alfred
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .alfred,
                    onAction: {
                        if let path = Bundle.main.path(forResource: "PepBox", ofType: "alfredworkflow") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        }
                    },
                    installCount: extensionCounts["alfred"],
                    rating: extensionRatings["alfred"]
                ))
            },
            ExtensionListItem(
                id: "elementCapture",
                iconURL: "pepbox-media://icons/element-capture.jpg",
                title: "Element Capture",
                subtitle: "Screenshot UI elements",
                category: .productivity,
                isInstalled: isElementCaptureInstalled,
                analyticsKey: "elementCapture",
                extensionType: .elementCapture
            ) {
                AnyView(ElementCaptureInfoViewWrapper(
                    installCount: extensionCounts["elementCapture"],
                    rating: extensionRatings["elementCapture"]
                ))
            },
            ExtensionListItem(
                id: "finder",
                iconURL: "pepbox-media://icons/finder.png",
                title: "Finder Services",
                subtitle: "Right-click integration",
                category: .files,
                isInstalled: isFinderInstalled,
                analyticsKey: "finder",
                extensionType: .finder
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .finder,
                    onAction: {
                        // Open System Settings → Privacy & Security → Extensions → Finder Extensions
                        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?Finder") {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    installCount: extensionCounts["finder"],
                    rating: extensionRatings["finder"]
                ))
            },
            ExtensionListItem(
                id: "spotify",
                iconURL: "pepbox-media://icons/spotify.png",
                title: "Spotify",
                subtitle: "Control music playback",
                category: .media,
                isInstalled: isSpotifyInstalled,
                analyticsKey: "spotify",
                extensionType: .spotify
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .spotify,
                    onAction: {
                        if let url = URL(string: "spotify://") {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    installCount: extensionCounts["spotify"],
                    rating: extensionRatings["spotify"]
                ))
            },
            ExtensionListItem(
                id: "appleMusic",
                iconURL: "pepbox-media://icons/apple-music.png",
                title: "Apple Music",
                subtitle: "Native music controls",
                category: .media,
                isInstalled: isAppleMusicInstalled,
                analyticsKey: "appleMusic",
                extensionType: .appleMusic
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .appleMusic,
                    onAction: {
                        // Open Apple Music app (similar to Spotify pattern)
                        if let url = URL(string: "music://") {
                            NSWorkspace.shared.open(url)
                        }
                        AppleMusicController.shared.refreshState()
                    },
                    installCount: extensionCounts["appleMusic"],
                    rating: extensionRatings["appleMusic"]
                ))
            },
            ExtensionListItem(
                id: "windowSnap",
                iconURL: "pepbox-media://icons/window-snap.jpg",
                title: "Window Snap",
                subtitle: "Snap with shortcuts",
                category: .system,
                isInstalled: isWindowSnapInstalled,
                analyticsKey: "windowSnap",
                extensionType: .windowSnap
            ) {
                AnyView(WindowSnapInfoView(
                    installCount: extensionCounts["windowSnap"],
                    rating: extensionRatings["windowSnap"]
                ))
            },
            ExtensionListItem(
                id: "terminalNotch",
                iconURL: "pepbox-media://icons/terminotch.jpg",
                title: "Termi-Notch",
                subtitle: "Quick terminal access",
                category: .productivity,
                isInstalled: isTerminalNotchInstalled,
                analyticsKey: "terminalNotch",
                extensionType: .terminalNotch
            ) {
                AnyView(TerminalNotchInfoView(
                    installCount: extensionCounts["terminalNotch"],
                    rating: extensionRatings["terminalNotch"]
                ))
            },
            ExtensionListItem(
                id: "camera",
                iconURL: "pepbox-media://icons/snap-camera-v2.png",
                title: "Notchface",
                subtitle: "Live notch camera preview",
                category: .productivity,
                isInstalled: isCameraInstalled,
                analyticsKey: "camera",
                extensionType: .camera
            ) {
                AnyView(CameraInfoView(
                    installCount: extensionCounts["camera"],
                    rating: extensionRatings["camera"]
                ))
            },
            ExtensionListItem(
                id: "quickshare",
                iconURL: "pepbox-media://icons/quickshare.jpg",
                title: "PepBox Quickshare",
                subtitle: "Share files via 0x0.st",
                category: .files,
                isInstalled: !ExtensionType.quickshare.isRemoved,
                analyticsKey: "quickshare",
                extensionType: .quickshare
            ) {
                AnyView(QuickshareInfoView(
                    installCount: extensionCounts["quickshare"],
                    rating: extensionRatings["quickshare"]
                ))
            },
            ExtensionListItem(
                id: "notificationHUD",
                iconURL: "pepbox-media://icons/notification-hud.png",
                title: "Notify me!",
                subtitle: "Show notifications in your notch",
                category: .system,
                isInstalled: isNotificationHUDInstalled,
                analyticsKey: "notificationHUD",
                extensionType: .notificationHUD,
                isCommunity: false
            ) {
                AnyView(NotificationHUDInfoView())
            },
            ExtensionListItem(
                id: "caffeine",
                iconURL: "pepbox-media://icons/high-alert.jpg",
                title: "High Alert",
                subtitle: "Keep your Mac awake",
                category: .system,
                isInstalled: isCaffeineInstalled,
                analyticsKey: "caffeine",
                extensionType: .caffeine,
                isCommunity: false
            ) {
                AnyView(CaffeineInfoView(
                    installCount: extensionCounts["caffeine"],
                    rating: extensionRatings["caffeine"]
                ))
            },
            ExtensionListItem(
                id: "pomodoro",
                iconPlaceholder: "timer",
                iconPlaceholderColor: .red,
                title: "Pomodoro",
                subtitle: "Focus timer in your notch",
                category: .productivity,
                isInstalled: NotchWidgetKind.pomodoro.isInstalled,
                analyticsKey: "pomodoro",
                extensionType: .pomodoro
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .pomodoro,
                    onAction: { NotchWidgetKind.pomodoro.install() },
                    installCount: extensionCounts["pomodoro"],
                    rating: extensionRatings["pomodoro"]
                ))
            },
            ExtensionListItem(
                id: "emojiPicker",
                iconPlaceholder: "face.smiling",
                iconPlaceholderColor: .yellow,
                title: "Emoji Picker",
                subtitle: "Emoji one click away",
                category: .productivity,
                isInstalled: NotchWidgetKind.emojiPicker.isInstalled,
                analyticsKey: "emojiPicker",
                extensionType: .emojiPicker
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .emojiPicker,
                    onAction: { NotchWidgetKind.emojiPicker.install() },
                    installCount: extensionCounts["emojiPicker"],
                    rating: extensionRatings["emojiPicker"]
                ))
            },
            ExtensionListItem(
                id: "teleprompter",
                iconPlaceholder: "text.alignleft",
                iconPlaceholderColor: .mint,
                title: "Teleprompter",
                subtitle: "Your script under the camera",
                category: .productivity,
                isInstalled: NotchWidgetKind.teleprompter.isInstalled,
                analyticsKey: "teleprompter",
                extensionType: .teleprompter
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .teleprompter,
                    onAction: { NotchWidgetKind.teleprompter.install() },
                    installCount: extensionCounts["teleprompter"],
                    rating: extensionRatings["teleprompter"]
                ))
            },
            ExtensionListItem(
                id: "meetings",
                iconPlaceholder: "video.fill",
                iconPlaceholderColor: .blue,
                title: "Meetings",
                subtitle: "Zoom, Teams and Meet controls",
                category: .productivity,
                isInstalled: NotchWidgetKind.meetings.isInstalled,
                analyticsKey: "meetings",
                extensionType: .meetings
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .meetings,
                    onAction: { NotchWidgetKind.meetings.install() },
                    installCount: extensionCounts["meetings"],
                    rating: extensionRatings["meetings"]
                ))
            },
            ExtensionListItem(
                id: "appVolume",
                iconPlaceholder: "speaker.wave.2.fill",
                iconPlaceholderColor: .green,
                title: "App Volume",
                subtitle: "Volume slider for each app",
                category: .media,
                isInstalled: NotchWidgetKind.appVolume.isInstalled,
                analyticsKey: "appVolume",
                extensionType: .appVolume
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .appVolume,
                    onAction: { NotchWidgetKind.appVolume.install() },
                    installCount: extensionCounts["appVolume"],
                    rating: extensionRatings["appVolume"]
                ))
            },
            ExtensionListItem(
                id: "obsidian",
                iconPlaceholder: "note.text",
                iconPlaceholderColor: .purple,
                title: "Obsidian",
                subtitle: "Your vault on the shelf",
                category: .productivity,
                isInstalled: NotchWidgetKind.obsidian.isInstalled,
                analyticsKey: "obsidian",
                extensionType: .obsidian
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .obsidian,
                    onAction: { NotchWidgetKind.obsidian.install() },
                    installCount: extensionCounts["obsidian"],
                    rating: extensionRatings["obsidian"]
                ))
            },
            ExtensionListItem(
                id: "systemStats",
                iconPlaceholder: "gauge.with.dots.needle.67percent",
                iconPlaceholderColor: .teal,
                title: "System Stats",
                subtitle: "CPU, GPU, memory, network and battery",
                category: .system,
                isInstalled: NotchWidgetKind.systemStats.isInstalled,
                analyticsKey: "systemStats",
                extensionType: .systemStats
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .systemStats,
                    onAction: { NotchWidgetKind.systemStats.install() },
                    installCount: extensionCounts["systemStats"],
                    rating: extensionRatings["systemStats"]
                ))
            },
            ExtensionListItem(
                id: "upNext",
                iconPlaceholder: "calendar.badge.clock",
                iconPlaceholderColor: .orange,
                title: "Up Next",
                subtitle: "Weather and your next meetings",
                category: .productivity,
                isInstalled: NotchWidgetKind.upNext.isInstalled,
                analyticsKey: "upNext",
                extensionType: .upNext
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .upNext,
                    onAction: { NotchWidgetKind.upNext.install() },
                    installCount: extensionCounts["upNext"],
                    rating: extensionRatings["upNext"]
                ))
            },
            ExtensionListItem(
                id: "shortcuts",
                iconPlaceholder: "square.2.layers.3d.fill",
                iconPlaceholderColor: .indigo,
                title: "Shortcuts",
                subtitle: "Run Apple Shortcuts from the shelf",
                category: .productivity,
                isInstalled: NotchWidgetKind.shortcuts.isInstalled,
                analyticsKey: "shortcuts",
                extensionType: .shortcuts
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .shortcuts,
                    onAction: { NotchWidgetKind.shortcuts.install() },
                    installCount: extensionCounts["shortcuts"],
                    rating: extensionRatings["shortcuts"]
                ))
            },
            ExtensionListItem(
                id: "agents",
                iconPlaceholder: "sparkle",
                iconPlaceholderColor: .orange,
                title: "Agents",
                subtitle: "Claude Code and Codex progress in the notch",
                category: .ai,
                isInstalled: NotchWidgetKind.agents.isInstalled,
                analyticsKey: "agents",
                extensionType: .agents
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .agents,
                    onAction: { NotchWidgetKind.agents.install() },
                    installCount: extensionCounts["agents"],
                    rating: extensionRatings["agents"]
                ))
            },
            ExtensionListItem(
                id: "quickNotes",
                iconPlaceholder: "note.text.badge.plus",
                iconPlaceholderColor: .yellow,
                title: "Notes",
                subtitle: "A notepad on your shelf",
                category: .productivity,
                isInstalled: NotchWidgetKind.notes.isInstalled,
                analyticsKey: "quickNotes",
                extensionType: .quickNotes
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .quickNotes,
                    onAction: { NotchWidgetKind.notes.install() },
                    installCount: extensionCounts["quickNotes"],
                    rating: extensionRatings["quickNotes"]
                ))
            },
            ExtensionListItem(
                id: "ring",
                iconPlaceholder: "circle.dashed",
                iconPlaceholderColor: .purple,
                title: "Ring",
                subtitle: "Actions in a circle at your cursor",
                category: .productivity,
                isInstalled: UtilityExtensionKind.ring.isInstalled,
                analyticsKey: "ring",
                extensionType: .ring
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .ring,
                    onAction: { UtilityExtensionKind.ring.install() },
                    installCount: extensionCounts["ring"],
                    rating: extensionRatings["ring"]
                ))
            },
            ExtensionListItem(
                id: "keySounds",
                iconPlaceholder: "keyboard",
                iconPlaceholderColor: .brown,
                title: "Key Sounds",
                subtitle: "Mechanical keyboard sounds",
                category: .media,
                isInstalled: UtilityExtensionKind.keySounds.isInstalled,
                analyticsKey: "keySounds",
                extensionType: .keySounds
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .keySounds,
                    onAction: { UtilityExtensionKind.keySounds.install() },
                    installCount: extensionCounts["keySounds"],
                    rating: extensionRatings["keySounds"]
                ))
            },
            ExtensionListItem(
                id: "quickSearch",
                iconPlaceholder: "magnifyingglass",
                iconPlaceholderColor: .teal,
                title: "Quick Search",
                subtitle: "Search bar for apps, files and math",
                category: .productivity,
                isInstalled: UtilityExtensionKind.quickSearch.isInstalled,
                analyticsKey: "quickSearch",
                extensionType: .quickSearch
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .quickSearch,
                    onAction: { UtilityExtensionKind.quickSearch.install() },
                    installCount: extensionCounts["quickSearch"],
                    rating: extensionRatings["quickSearch"]
                ))
            },
            ExtensionListItem(
                id: "textActions",
                iconPlaceholder: "text.cursor",
                iconPlaceholderColor: .cyan,
                title: "Text Actions",
                subtitle: "Action bar for selected text",
                category: .productivity,
                isInstalled: UtilityExtensionKind.textActions.isInstalled,
                analyticsKey: "textActions",
                extensionType: .textActions
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .textActions,
                    onAction: { UtilityExtensionKind.textActions.install() },
                    installCount: extensionCounts["textActions"],
                    rating: extensionRatings["textActions"]
                ))
            },
            ExtensionListItem(
                id: "smoothScroll",
                iconPlaceholder: "computermouse",
                iconPlaceholderColor: .indigo,
                title: "Smooth Scroll",
                subtitle: "Trackpad-smooth mouse wheels",
                category: .system,
                isInstalled: UtilityExtensionKind.smoothScroll.isInstalled,
                analyticsKey: "smoothScroll",
                extensionType: .smoothScroll
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .smoothScroll,
                    onAction: { UtilityExtensionKind.smoothScroll.install() },
                    installCount: extensionCounts["smoothScroll"],
                    rating: extensionRatings["smoothScroll"]
                ))
            },
            ExtensionListItem(
                id: "eyeBreaks",
                iconPlaceholder: "eye",
                iconPlaceholderColor: .green,
                title: "Eye Breaks",
                subtitle: "20-20-20 reminders in the notch",
                category: .productivity,
                isInstalled: UtilityExtensionKind.eyeBreaks.isInstalled,
                analyticsKey: "eyeBreaks",
                extensionType: .eyeBreaks
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .eyeBreaks,
                    onAction: { UtilityExtensionKind.eyeBreaks.install() },
                    installCount: extensionCounts["eyeBreaks"],
                    rating: extensionRatings["eyeBreaks"]
                ))
            },
            ExtensionListItem(
                id: "downloadsActivity",
                iconPlaceholder: "arrow.down.circle",
                iconPlaceholderColor: .blue,
                title: "Download Progress",
                subtitle: "Browser downloads beside the notch",
                category: .files,
                isInstalled: UtilityExtensionKind.downloadsActivity.isInstalled,
                analyticsKey: "downloadsActivity",
                extensionType: .downloadsActivity
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .downloadsActivity,
                    onAction: { UtilityExtensionKind.downloadsActivity.install() },
                    installCount: extensionCounts["downloadsActivity"],
                    rating: extensionRatings["downloadsActivity"]
                ))
            },
            ExtensionListItem(
                id: "localSend",
                iconPlaceholder: "paperplane.fill",
                iconPlaceholderColor: .teal,
                title: "LocalSend",
                subtitle: "AirDrop for every device, no cloud",
                category: .files,
                isInstalled: UtilityExtensionKind.localSend.isInstalled,
                analyticsKey: "localSend",
                extensionType: .localSend
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .localSend,
                    onAction: { UtilityExtensionKind.localSend.install() },
                    installCount: extensionCounts["localSend"],
                    rating: extensionRatings["localSend"]
                ))
            },
            ExtensionListItem(
                id: "snippets",
                iconPlaceholder: "text.insert",
                iconPlaceholderColor: .orange,
                title: "Snippets",
                subtitle: "Type a shortcut, get the full text",
                category: .productivity,
                isInstalled: UtilityExtensionKind.snippets.isInstalled,
                analyticsKey: "snippets",
                extensionType: .snippets
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .snippets,
                    onAction: { UtilityExtensionKind.snippets.install() },
                    installCount: extensionCounts["snippets"],
                    rating: extensionRatings["snippets"]
                ))
            },
            ExtensionListItem(
                id: "menuBarManager",
                iconURL: "pepbox-media://icons/menubarmanager.png",
                title: "Menu Bar Manager",
                subtitle: "Organize your menu bar",
                category: .system,
                isInstalled: isMenuBarManagerInstalled,
                analyticsKey: "menuBarManager",
                extensionType: .menuBarManager
            ) {
                AnyView(MenuBarManagerInfoView(
                    installCount: extensionCounts["menuBarManager"],
                    rating: extensionRatings["menuBarManager"]
                ))
            },
            ExtensionListItem(
                id: "todo",
                iconURL: "pepbox-media://icons/reminders.png",
                title: "Reminders",
                subtitle: "Natural language tasks",
                category: .productivity,
                isInstalled: isTodoInstalled,
                analyticsKey: "todo",
                extensionType: .todo,
                isCommunity: false
            ) {
                AnyView(ToDoInfoView(
                    installCount: extensionCounts["todo"],
                    rating: extensionRatings["todo"]
                ))
            },
        ]
        
        // Search narrows everything (including disabled ones) by name or description.
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            return allExtensions
                .filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
                .sorted { $0.title < $1.title }
        }
        
        // nil = show all, otherwise filter by category
        guard let category = selectedCategory else {
            return allExtensions.filter { !$0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        }
        
        switch category {
        case .all:
            return allExtensions.filter { !$0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        case .installed:
            return allExtensions.filter { $0.isInstalled && !$0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        case .disabled:
            return allExtensions.filter { $0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        default:
            return allExtensions.filter { $0.category == category && !$0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        }
    }
}

// MARK: - Extension List Item Model

private struct ExtensionListItem: Identifiable {
    let id: String
    let iconURL: String?
    let iconPlaceholder: String?
    let iconPlaceholderColor: Color?
    let title: String
    let subtitle: String
    let category: ExtensionCategory
    let isInstalled: Bool
    let analyticsKey: String
    let extensionType: ExtensionType
    var isCommunity: Bool = false
    let detailView: () -> AnyView

    init(
        id: String,
        iconURL: String? = nil,
        iconPlaceholder: String? = nil,
        iconPlaceholderColor: Color? = nil,
        title: String,
        subtitle: String,
        category: ExtensionCategory,
        isInstalled: Bool,
        analyticsKey: String,
        extensionType: ExtensionType,
        isCommunity: Bool = false,
        detailView: @escaping () -> AnyView
    ) {
        self.id = id
        self.iconURL = iconURL
        self.iconPlaceholder = iconPlaceholder
        self.iconPlaceholderColor = iconPlaceholderColor
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.isInstalled = isInstalled
        self.analyticsKey = analyticsKey
        self.extensionType = extensionType
        self.isCommunity = isCommunity
        self.detailView = detailView
    }
}

// MARK: - Featured Extension Card (Large)

struct FeaturedExtensionCard<DetailView: View>: View {
    let category: String
    let title: String
    let subtitle: String
    let iconURL: String
    let screenshotURL: String?
    let accentColor: Color
    let isInstalled: Bool
    var installCount: Int?
    let detailView: () -> DetailView
    
    @State private var showSheet = false
    @State private var isHovering = false

    private var titleColor: Color {
        AdaptiveColors.primaryTextAuto
    }

    private var subtitleColor: Color {
        AdaptiveColors.secondaryTextAuto
    }

    private var statTextColor: Color {
        AdaptiveColors.secondaryTextAuto.opacity(0.82)
    }

    private var actionTextColor: Color {
        AdaptiveColors.primaryTextAuto
    }

    private var actionBackgroundColor: Color {
        accentColor.opacity(0.24)
    }

    private var screenshotOpacity: Double {
        0.2
    }

    private var screenshotFade: LinearGradient {
        return LinearGradient(
            stops: [
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.98), location: 0.0),
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.94), location: 0.45),
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.72), location: 0.65),
                .init(color: Color.clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardBackground: LinearGradient {
        return LinearGradient(
            colors: [AdaptiveColors.panelBackgroundAuto, AdaptiveColors.overlayAuto(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack(alignment: .leading) {
                // Screenshot background on right side with fade
                if let screenshotURLString = screenshotURL,
                   let url = URL(string: screenshotURLString) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Spacer()
                            
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width * 0.6, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Color.clear
                            }
                        }
                    }
                    .opacity(screenshotOpacity)
                    
                    // Gradient fade from left to blend the screenshot
                    screenshotFade
                }
                
                // Content overlay
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Category label (only show if not empty)
                        if !category.isEmpty {
                            Text(category)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accentColor.opacity(0.9))
                                .tracking(0.5)
                        }
                        
                        // Title
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(titleColor)
                        
                        // Subtitle
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(subtitleColor)
                        
                        Spacer()
                        
                        // Setup/Manage Button
                        HStack(spacing: 12) {
                            Text(isInstalled ? "Manage" : "Set Up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(actionTextColor)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: PepBoxRadius.ms, style: .continuous)
                                        .fill(actionBackgroundColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: PepBoxRadius.ms, style: .continuous)
                                        .stroke(AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
                                )
                            
                            if let count = installCount, count > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 10))
                                    Text("\(count)")
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(statTextColor)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Icon
                    CachedAsyncImage(url: URL(string: iconURL)) { image in
                        image.pepboxExtensionIcon(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: PepBoxRadius.large)
                            .fill(AdaptiveColors.overlayAuto(0.1))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.lx, style: .continuous))
                    .pepboxCardShadow(opacity: 0.4)
                }
                .padding(PepBoxSpacing.xl)
            }
            .frame(height: 160)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.xl, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(PepBoxAnimation.hoverBouncy, value: isHovering)
        }
        .buttonStyle(PepBoxCardButtonStyle(cornerRadius: PepBoxRadius.xl))
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showSheet) {
            detailView()
        }
    }
}


// MARK: - Featured Extension Card (Wide)

struct FeaturedExtensionCardWide<DetailView: View>: View {
    let title: String
    let subtitle: String
    let iconURL: String
    let screenshotURL: String?
    let accentColor: Color
    let isInstalled: Bool
    let features: [String]
    var isNew: Bool = false
    let detailView: () -> DetailView
    
    @State private var showSheet = false
    @State private var isHovering = false

    private var titleColor: Color {
        AdaptiveColors.primaryTextAuto
    }

    private var subtitleColor: Color {
        AdaptiveColors.secondaryTextAuto
    }

    private var featureColor: Color {
        AdaptiveColors.primaryTextAuto.opacity(0.88)
    }

    private var screenshotFade: LinearGradient {
        return LinearGradient(
            stops: [
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.98), location: 0.0),
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.94), location: 0.45),
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.72), location: 0.65),
                .init(color: Color.clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardBackground: LinearGradient {
        return LinearGradient(
            colors: [AdaptiveColors.panelBackgroundAuto, AdaptiveColors.overlayAuto(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack(alignment: .leading) {
                // Screenshot background on right side with fade
                if let screenshotURLString = screenshotURL,
                   let url = URL(string: screenshotURLString) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Spacer()
                            
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width * 0.6, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Color.clear
                            }
                        }
                    }
                    .opacity(0.2)
                    
                    // Gradient fade from left
                    screenshotFade
                }
                
                // Content overlay
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Title with optional NEW badge
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(titleColor)
                            
                            if isNew {
                                Text("New")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.cyan.opacity(0.9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                            }
                        }
                        
                        // Subtitle
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(subtitleColor)
                        
                        // Feature badges
                        HStack(spacing: 8) {
                            ForEach(features, id: \.self) { feature in
                                Text(feature)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(featureColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(AdaptiveColors.overlayAuto(0.08))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Icon
                    CachedAsyncImage(url: URL(string: iconURL)) { image in
                        image.pepboxExtensionIcon(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: PepBoxRadius.large)
                            .fill(AdaptiveColors.overlayAuto(0.1))
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
                    .pepboxCardShadow(opacity: 0.4)
                }
                .padding(PepBoxSpacing.xl)
            }
            .frame(height: 120)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.lx, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.lx, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(PepBoxAnimation.hoverBouncy, value: isHovering)
        }
        .buttonStyle(PepBoxCardButtonStyle(cornerRadius: PepBoxRadius.lx))
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showSheet) {
            detailView()
        }
    }
}


// MARK: - Featured Extension Card (Compact)

struct FeaturedExtensionCardCompact<DetailView: View>: View {
    let category: String
    let title: String
    let subtitle: String
    let iconURL: String?
    var iconPlaceholder: String? = nil
    var iconPlaceholderColor: Color = .blue
    let screenshotURL: String?
    let accentColor: Color
    let isInstalled: Bool
    var isNew: Bool = false
    var isCommunity: Bool = false
    let detailView: () -> DetailView
    
    @State private var showSheet = false
    @State private var isHovering = false

    private var titleColor: Color {
        AdaptiveColors.primaryTextAuto
    }

    private var subtitleColor: Color {
        AdaptiveColors.secondaryTextAuto
    }

    private var screenshotFade: LinearGradient {
        return LinearGradient(
            stops: [
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.98), location: 0.0),
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.94), location: 0.4),
                .init(color: AdaptiveColors.panelBackgroundAuto.opacity(0.72), location: 0.65),
                .init(color: Color.clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardBackground: LinearGradient {
        return LinearGradient(
            colors: [AdaptiveColors.panelBackgroundAuto, AdaptiveColors.overlayAuto(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack(alignment: .leading) {
                // Screenshot background on right side with fade
                if let screenshotURLString = screenshotURL,
                   let url = URL(string: screenshotURLString) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Spacer()
                            
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width * 0.7, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Color.clear
                            }
                        }
                    }
                    .opacity(0.16)
                    
                    // Gradient fade from left
                    screenshotFade
                }
                
                // Content overlay
                VStack(alignment: .leading, spacing: 8) {
                    // Icon row (top right)
                    HStack {
                        Spacer()
                        
                        if let iconURL, let iconURLValue = URL(string: iconURL) {
                            CachedAsyncImage(url: iconURLValue) { image in
                                image.pepboxExtensionIcon(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(AdaptiveColors.overlayAuto(0.1))
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.ms, style: .continuous))
                            .pepboxCardShadow(opacity: 0.3)
                        } else if let iconPlaceholder {
                            Image(systemName: iconPlaceholder)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(iconPlaceholderColor)
                                .frame(width: 36, height: 36)
                                .background(iconPlaceholderColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.ms, style: .continuous))
                                .pepboxCardShadow(opacity: 0.3)
                        } else {
                            Circle()
                                .fill(AdaptiveColors.overlayAuto(0.1))
                                .frame(width: 36, height: 36)
                        }
                    }
                    
                    Spacer()
                    
                    // Title with optional badges
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(titleColor)
                            .lineLimit(1)
                        
                        if isNew {
                            Text("New")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.cyan.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.cyan.opacity(0.15)))
                        }
                    }
                    
                    // Subtitle
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
                .padding(PepBoxSpacing.mdl)
                
                // Category ribbon badge in top-left corner (only for non-community categories)
                if !category.isEmpty && category != "COMMUNITY" {
                    VStack {
                        HStack {
                            Text(category)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AdaptiveColors.primaryTextAuto)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(accentColor.opacity(0.25))
                                )
                                .pepboxCardShadow(opacity: 0.3)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(PepBoxSpacing.smd)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(PepBoxAnimation.hoverBouncy, value: isHovering)
        }
        .buttonStyle(PepBoxCardButtonStyle(cornerRadius: PepBoxRadius.large))
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showSheet) {
            detailView()
        }
    }
}

// MARK: - Compact Extension Row

struct CompactExtensionRow<DetailView: View>: View {
    let iconURL: String?
    var iconPlaceholder: String? = nil
    var iconPlaceholderColor: Color? = nil
    let title: String
    let subtitle: String
    let isInstalled: Bool
    var installCount: Int?
    var isCommunity: Bool = false
    let detailView: () -> DetailView

    @State private var showSheet = false
    @State private var isHovering = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                if let urlString = iconURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.pepboxExtensionIcon(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: PepBoxRadius.ms)
                            .fill(AdaptiveColors.overlayAuto(0.1))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.ms, style: .continuous))
                } else if let placeholder = iconPlaceholder {
                    Image(systemName: placeholder)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(iconPlaceholderColor ?? .blue)
                        .frame(width: 44, height: 44)
                        .background((iconPlaceholderColor ?? .blue).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.ms, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: PepBoxRadius.ms)
                        .fill(AdaptiveColors.overlayAuto(0.1))
                        .frame(width: 44, height: 44)
                }
                
                // Title + Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        if isCommunity {
                            HStack(spacing: 3) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 8))
                                Text("Community")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(.purple.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Setup/Manage Button
                Text(isInstalled ? "Manage" : "Set Up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AdaptiveColors.buttonBackgroundAuto)
                    )
                    .overlay(
                        Capsule()
                            .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isHovering ? AdaptiveColors.overlayAuto(0.03) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PepBoxCardButtonStyle())
        .onHover { hovering in
            withAnimation(PepBoxAnimation.hover) {
                isHovering = hovering
            }
        }
        .sheet(isPresented: $showSheet) {
            detailView()
        }
    }
}

// MARK: - Category Pill Button

struct CategoryPillButton: View {
    let category: ExtensionCategory
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.blue.opacity(isHovering ? 1.0 : 0.85))
                        .matchedGeometryEffect(id: "SelectedCategory", in: namespace)
                } else {
                    Capsule()
                        .fill(isHovering ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                }
            }
            .overlay(
                Capsule()
                    .stroke(isSelected ? AdaptiveColors.overlayAuto(0.15) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PepBoxSelectableButtonStyle(isSelected: isSelected))
        .onHover { hovering in
            withAnimation(PepBoxAnimation.hover) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Legacy Card Styles (kept for compatibility)

struct ExtensionCardStyle: ViewModifier {
    let accentColor: Color
    @State private var isHovering = false
    
    private var borderColor: Color {
        if isHovering {
            return accentColor.opacity(0.7)
        } else {
            return AdaptiveColors.overlayAuto(0.1)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .padding(PepBoxSpacing.lg)
            .background(AdaptiveColors.overlayAuto(0.05))
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(PepBoxAnimation.hoverBouncy, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func extensionCardStyle(accentColor: Color) -> some View {
        modifier(ExtensionCardStyle(accentColor: accentColor))
    }
}

struct AIExtensionCardStyle: ViewModifier {
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .padding(PepBoxSpacing.lg)
            .background(AdaptiveColors.overlayAuto(0.05))
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous)
                    .stroke(
                        isHovering
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.purple.opacity(0.8), .pink.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(AdaptiveColors.overlayAuto(0.1)),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(PepBoxAnimation.hoverBouncy, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func aiExtensionCardStyle() -> some View {
        modifier(AIExtensionCardStyle())
    }
}

// MARK: - AI Extension Icon

struct AIExtensionIcon: View {
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.15),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.2, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .purple.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .purple.opacity(0.5), radius: 2)
                        .offset(x: -2, y: 2)
                }
                Spacer()
                HStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .pink.opacity(0.5), radius: 2)
                        .offset(x: 4, y: -4)
                    Spacer()
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.227, style: .continuous))
    }
}

// MARK: - Legacy Cards (kept for compatibility)

struct AIBackgroundRemovalSettingsRow: View {
    @ObservedObject private var manager = AIInstallManager.shared
    @State private var showInstallSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                CachedAsyncImage(url: URL(string: "pepbox-media://icons/ai-bg.jpg")) { image in
                    image.pepboxExtensionIcon(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "brain.head.profile").font(.system(size: 24)).foregroundStyle(.blue)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.ms, style: .continuous))
                
                Spacer()
                
                Text("AI")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AdaptiveColors.overlayAuto(0.1)))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Background Removal")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Remove backgrounds from images using AI. Works offline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            if manager.isInstalled {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Installed")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                }
            } else {
                Text("One-click install")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 160)
        .aiExtensionCardStyle()
        .contentShape(Rectangle())
        .onTapGesture { showInstallSheet = true }
        .sheet(isPresented: $showInstallSheet) { AIInstallView() }
    }
}

@available(*, deprecated, renamed: "AIBackgroundRemovalSettingsRow")
struct BackgroundRemovalSettingsRow: View {
    var body: some View {
        AIBackgroundRemovalSettingsRow()
    }
}

// MARK: - Element Capture Info View Wrapper
// Provides the binding for currentShortcut since the view requires it

struct ElementCaptureInfoViewWrapper: View {
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @State private var currentShortcut: SavedShortcut? = {
        if let data = UserDefaults.standard.data(forKey: "elementCaptureShortcut"),
           let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            return shortcut
        }
        return nil
    }()
    
    var body: some View {
        ElementCaptureInfoView(
            currentShortcut: $currentShortcut,
            installCount: installCount,
            rating: rating
        )
    }
}

/// Lays children out left to right, wrapping to a new line when the row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
