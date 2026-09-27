//
//  ContentView.swift
//  PepBox
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

/// Main content view - redirects to ShelfView
/// This file is kept for Xcode template compatibility
struct ContentView: View {
    var body: some View {
        ShelfView(state: PepBoxState.shared)
    }
}

#Preview {
    ContentView()
        .frame(width: 320, height: 280)
}
