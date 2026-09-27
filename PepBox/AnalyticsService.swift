//
//  AnalyticsService.swift
//  PepBox
//
//  Created by Jordy Spruit on 04/01/2026.
//

import Foundation
import SwiftUI

/// Usage statistics and extension ratings.
/// PepBox has no analytics backend (the upstream Supabase project belongs to Droppy),
/// so nothing is sent over the network: counts and ratings come back empty and the
/// UI hides them. Only the local "extension installed" flag is kept.
final class AnalyticsService: Sendable {
    static let shared = AnalyticsService()

    var isDisabled: Bool { true }

    private init() {}

    func logAppLaunch() {}

    func fetchDownloadCount() async throws -> Int {
        throw URLError(.unsupportedURL)
    }

    // MARK: - Extension Tracking

    /// Sets a local flag so cards and filters can show the installed state
    func trackExtensionActivation(extensionId: String) {
        UserDefaults.standard.set(true, forKey: "\(extensionId)Tracked")
    }

    func fetchExtensionCounts() async throws -> [String: Int] { [:] }

    // MARK: - Extension Ratings

    struct ExtensionRating {
        let averageRating: Double
        let ratingCount: Int
    }

    func submitExtensionRating(extensionId: String, rating: Int, feedback: String?) async throws {}

    func fetchExtensionRatings() async throws -> [String: ExtensionRating] { [:] }

    func fetchExtensionReviews(extensionId: String) async throws -> [ExtensionReview] { [] }
}

// MARK: - Extension Review Model

struct ExtensionReview: Identifiable {
    let id: String
    let rating: Int
    let feedback: String?
    let createdAt: Date
}
