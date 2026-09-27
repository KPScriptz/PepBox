import Combine
import Foundation
import Security

@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    /// Maximum number of simultaneous device activations allowed per license key.
    private static let maxDeviceActivations = 1

    @Published private(set) var requiresLicenseEnforcement: Bool
    @Published private(set) var isActivated: Bool
    @Published private(set) var isChecking: Bool = false
    @Published private(set) var statusMessage: String
    @Published private(set) var licensedEmail: String
    @Published private(set) var licenseKeyHint: String
    @Published private(set) var activatedDeviceName: String
    @Published private(set) var lastVerifiedAt: Date?

    var purchaseURL: URL? { configuration.purchaseURL }

    private let defaults: UserDefaults
    private let session: URLSession
    private let keychainStore: GumroadLicenseKeychainStore
    private let configuration: Configuration
    private var didBootstrap = false

    private init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        self.keychainStore = GumroadLicenseKeychainStore()

        let loadedConfiguration = Self.loadConfiguration()
        self.configuration = loadedConfiguration

        // OPEN SOURCE: Disable license enforcement - all users get free access
        self.requiresLicenseEnforcement = false
        self.isActivated = true
        self.statusMessage = "Open Source - Free for everyone"
        self.licensedEmail = "opensource@pepbox.app"
        self.licenseKeyHint = "****FREE"
        self.activatedDeviceName = Self.currentDeviceName()
        self.lastVerifiedAt = Date()
    }

    func bootstrap() {
        // OPEN SOURCE: License enforcement disabled, no bootstrap needed
        didBootstrap = true
    }

    @discardableResult
    func activate(licenseKey: String, email: String?) async -> Bool {
        // OPEN SOURCE: License activation not required, always return true
        return true
    }

    func revalidateStoredLicense() async {
        // OPEN SOURCE: License revalidation not required
    }

    func deactivateLocally() {
        // OPEN SOURCE: Deactivation not applicable for open source version
    }

    func deactivateCurrentDevice() async {
        // OPEN SOURCE: Device deactivation not applicable for open source version
    }

    private func restoreStoredState() {
        licensedEmail = defaults.string(forKey: AppPreferenceKey.gumroadLicenseEmail) ?? ""
        licenseKeyHint = defaults.string(forKey: AppPreferenceKey.gumroadLicenseKeyHint) ?? ""
        activatedDeviceName = defaults.string(forKey: AppPreferenceKey.gumroadLicenseDeviceName) ?? ""

        if defaults.object(forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt) != nil {
            let seconds = defaults.double(forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt)
            if seconds > 0 {
                lastVerifiedAt = Date(timeIntervalSince1970: seconds)
            }
        }

        let hasStoredKey = keychainStore.fetchLicenseKey()?.nonEmpty != nil
        let hasStoredActivationFlag = defaults.object(forKey: AppPreferenceKey.gumroadLicenseActive) != nil
        let storedActiveFlag = defaults.bool(forKey: AppPreferenceKey.gumroadLicenseActive)

        isActivated = hasStoredKey && (storedActiveFlag || !hasStoredActivationFlag)
        if isActivated && activatedDeviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activatedDeviceName = Self.currentDeviceName()
            defaults.set(activatedDeviceName, forKey: AppPreferenceKey.gumroadLicenseDeviceName)
        }
        if isActivated {
            statusMessage = hasStoredActivationFlag ? "License active." : "Saved license found. Verifying..."
        } else {
            statusMessage = "License not activated."
        }
    }

    private func setActivatedState(
        isActive: Bool,
        email: String,
        keyHint: String,
        deviceName: String,
        verifiedAt: Date?,
        message: String,
        clearKeychain: Bool = false,
        notify: Bool = true
    ) {
        let previousState = isActivated

        if clearKeychain {
            keychainStore.deleteLicenseKey()
        }

        isActivated = isActive
        licensedEmail = email
        licenseKeyHint = keyHint
        activatedDeviceName = isActive ? (deviceName.nonEmpty ?? Self.currentDeviceName()) : ""
        lastVerifiedAt = verifiedAt
        statusMessage = message

        defaults.set(isActive, forKey: AppPreferenceKey.gumroadLicenseActive)
        defaults.set(email, forKey: AppPreferenceKey.gumroadLicenseEmail)
        defaults.set(keyHint, forKey: AppPreferenceKey.gumroadLicenseKeyHint)
        defaults.set(activatedDeviceName, forKey: AppPreferenceKey.gumroadLicenseDeviceName)

        if let verifiedAt {
            defaults.set(verifiedAt.timeIntervalSince1970, forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt)
        } else {
            defaults.removeObject(forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt)
        }

        if notify, previousState != isActivated {
            NotificationCenter.default.post(name: .licenseStateDidChange, object: isActivated)
        }
    }

    private func verifyLicense(
        licenseKey: String,
        incrementUsesCount: Bool,
        decrementUsesCount: Bool = false
    ) async throws -> GumroadVerifyResponse {
        guard configuration.isConfigured else {
            throw LicenseVerificationError.missingProductIdentifier
        }

        guard let url = URL(string: "https://api.gumroad.com/v2/licenses/verify") else {
            throw LicenseVerificationError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "license_key", value: licenseKey),
            URLQueryItem(name: "increment_uses_count", value: incrementUsesCount ? "true" : "false")
        ]

        if decrementUsesCount {
            queryItems.append(URLQueryItem(name: "decrement_uses_count", value: "true"))
        }

        if let productID = configuration.productID {
            queryItems.append(URLQueryItem(name: "product_id", value: productID))
        } else if let productPermalink = configuration.productPermalink {
            queryItems.append(URLQueryItem(name: "product_permalink", value: productPermalink))
        }

        var components = URLComponents()
        components.queryItems = queryItems
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LicenseVerificationError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseVerificationError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let decoded = try? decoder.decode(GumroadVerifyResponse.self, from: data) {
            if httpResponse.statusCode >= 500 {
                throw LicenseVerificationError.server(decoded.message?.nonEmpty ?? "Gumroad is temporarily unavailable.")
            }
            return decoded
        }

        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = payload["message"] as? String {
            throw LicenseVerificationError.server(message)
        }

        let fallbackMessage = String(data: data, encoding: .utf8)?.nonEmpty ?? "Unexpected response from Gumroad."
        throw LicenseVerificationError.server(fallbackMessage)
    }

    private static func loadConfiguration() -> Configuration {
        let info = Bundle.main.infoDictionary ?? [:]

        let productID = normalizedConfigValue(info["GumroadProductID"] as? String)
        let productPermalink = normalizedConfigValue(info["GumroadProductPermalink"] as? String)

        let rawPurchaseURL = normalizedConfigValue(info["GumroadPurchaseURL"] as? String)
        let purchaseURL = rawPurchaseURL.flatMap(URL.init(string:))

        return Configuration(productID: productID, productPermalink: productPermalink, purchaseURL: purchaseURL)
    }

    private static func normalizedConfigValue(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let placeholderValues: Set<String> = [
            "YOUR_GUMROAD_PRODUCT_ID",
            "YOUR_GUMROAD_PRODUCT_PERMALINK",
            "YOUR_GUMROAD_PURCHASE_URL"
        ]

        if placeholderValues.contains(trimmed) {
            return nil
        }

        return trimmed
    }

    private static func keyHint(for key: String) -> String {
        let suffix = String(key.suffix(4))
        return suffix.isEmpty ? "****" : "****\(suffix)"
    }

    private static func currentDeviceName() -> String {
        if let localized = Host.current().localizedName?.nonEmpty {
            return localized
        }
        if let host = ProcessInfo.processInfo.hostName.nonEmpty {
            return host
        }
        return "This Mac"
    }
}

private extension LicenseManager {
    struct Configuration {
        let productID: String?
        let productPermalink: String?
        let purchaseURL: URL?

        var isConfigured: Bool {
            productID != nil || productPermalink != nil
        }
    }

    struct GumroadVerifyResponse: Decodable {
        let success: Bool
        let message: String?
        let purchase: Purchase?

        var isValidPurchase: Bool {
            guard success else { return false }
            guard purchase?.refunded != true,
                  purchase?.disputed != true,
                  purchase?.chargebacked != true else {
                return false
            }
            guard purchase?.subscriptionEndedAt?.nonEmpty == nil else {
                return false
            }
            return true
        }

        struct Purchase: Decodable {
            let email: String?
            let uses: Int?
            let refunded: Bool?
            let disputed: Bool?
            let chargebacked: Bool?
            let subscriptionEndedAt: String?
        }
    }

    enum LicenseVerificationError: LocalizedError {
        case missingProductIdentifier
        case invalidRequest
        case invalidResponse
        case network(String)
        case server(String)

        var errorDescription: String? {
            switch self {
            case .missingProductIdentifier:
                return "Gumroad product identifier is missing. Set GumroadProductID in Info.plist."
            case .invalidRequest:
                return "License verification request could not be created."
            case .invalidResponse:
                return "Received an invalid response from Gumroad."
            case .network(let message):
                return message
            case .server(let message):
                return message
            }
        }
    }
}

private struct GumroadLicenseKeychainStore {
    private let service = "com.pivotxp.pepbox.gumroad-license"
    private let account = "license_key"

    func storeLicenseKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    func fetchLicenseKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    func deleteLicenseKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
