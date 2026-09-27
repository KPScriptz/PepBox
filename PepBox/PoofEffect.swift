//
//  PoofEffect.swift
//  PepBox
//
//  Created by Jordy Spruit on 03/01/2026.
//

import SwiftUI

/// A satisfying "poof" particle animation for when files are converted in-place
struct PoofEffect: View {
    var onComplete: () -> Void
    
    @State private var particles: [PoofParticle] = []
    @State private var centerScale: CGFloat = 1.0
    @State private var centerOpacity: Double = 1.0
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkOpacity: Double = 0.0
    @State private var hasTriggered = false
    
    private let particleCount = 12
    
    var body: some View {
        ZStack {
            // Center flash - sized to match file icon (44x44)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.8), .white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 22
                    )
                )
                .frame(width: 44, height: 44)
                .scaleEffect(centerScale)
                .opacity(centerOpacity)
            
            // Success checkmark - sized to match shield icon (22pt)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.green)
                .scaleEffect(checkmarkScale)
                .opacity(checkmarkOpacity)
                .shadow(color: .green.opacity(0.5), radius: 6, x: 0, y: 2)
            
            // Floating particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.offset.width, y: particle.offset.height)
                    .opacity(particle.opacity)
                    .blur(radius: particle.blur)
            }
        }
        .onAppear {
            if !hasTriggered {
                hasTriggered = true
                triggerPoof()
            }
        }
    }
    
    private func triggerPoof() {
        // Generate particles in a ring
        particles = (0..<particleCount).map { index in
            let angle = Double(index) * (360.0 / Double(particleCount)) * .pi / 180
            return PoofParticle(
                id: UUID(),
                angle: angle,
                offset: .zero,
                size: CGFloat.random(in: 4...8),
                opacity: 1.0,
                blur: 0,
                color: [Color.white, Color.blue.opacity(0.6), Color.cyan.opacity(0.5)].randomElement()!
            )
        }
        
        // Center flash animation
        withAnimation(PepBoxAnimation.easeOut) {
            centerScale = 1.5
            centerOpacity = 1.0
        }
        
        // Particles burst outward - reduced distance to fit 44x44 area
        withAnimation(PepBoxAnimation.stateEmphasis) {
            for i in particles.indices {
                let distance = CGFloat.random(in: 18...32)
                particles[i].offset = CGSize(
                    width: cos(particles[i].angle) * distance,
                    height: sin(particles[i].angle) * distance
                )
            }
        }
        
        // Checkmark pops in with bounce
        withAnimation(PepBoxAnimation.onboardingBounce.delay(0.1)) {
            checkmarkScale = 1.2
            checkmarkOpacity = 1.0
        }
        
        // Checkmark settles to normal size
        withAnimation(PepBoxAnimation.hover.delay(0.25)) {
            checkmarkScale = 1.0
        }
        
        // Fade out particles and center
        withAnimation(PepBoxAnimation.viewChange.delay(0.15)) {
            centerScale = 0.5
            centerOpacity = 0
            for i in particles.indices {
                particles[i].opacity = 0
                particles[i].blur = 2
            }
        }
        
        // Fade out checkmark
        withAnimation(.easeOut(duration: 0.2).delay(0.5)) {
            checkmarkOpacity = 0
            checkmarkScale = 0.8
        }
        
        // Complete animation - call onComplete which will set isPoofing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            onComplete()
        }
    }
}

private struct PoofParticle: Identifiable {
    let id: UUID
    let angle: Double
    var offset: CGSize
    var size: CGFloat
    var opacity: Double
    var blur: CGFloat
    var color: Color
}

/// A view modifier that overlays a poof effect and triggers replacement
struct PoofModifier: ViewModifier {
    @Binding var isPoofing: Bool
    var onPoof: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .scaleEffect(isPoofing ? 0.8 : 1.0)
                .opacity(isPoofing ? 0.3 : 1.0)
                .animation(PepBoxAnimation.hover, value: isPoofing)
            
            if isPoofing {
                PoofEffect {
                    // First do the replacement
                    onPoof()
                    // Then stop the animation
                    isPoofing = false
                }
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func poofEffect(isPoofing: Binding<Bool>, onPoof: @escaping () -> Void) -> some View {
        modifier(PoofModifier(isPoofing: isPoofing, onPoof: onPoof))
    }
}
