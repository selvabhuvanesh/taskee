//
//  CelebrationView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let rotation: Double
    let speed: Double
    let size: CGFloat
    let shape: Int
}

struct CelebrationOverlay: View {
    @Binding var isActive: Bool
    var title: String = "Task Complete!"
    var subtitle: String = ""
    var rewardAmount: Double = 0

    @State private var pieces: [ConfettiPiece] = []
    @State private var animate = false
    @State private var showBanner = false

    private let colors: [Color] = [
        .yellow, .green, .blue, .pink, .orange, .purple, .cyan, .mint
    ]

    var body: some View {
        ZStack {
            if isActive {
                ForEach(pieces) { piece in
                    ConfettiShape(shape: piece.shape)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .rotationEffect(.degrees(animate ? piece.rotation + 360 : piece.rotation))
                        .offset(
                            x: piece.x,
                            y: animate ? UIScreen.main.bounds.height + 50 : -50
                        )
                        .opacity(animate ? 0 : 1)
                }

                if showBanner {
                    VStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.yellow)

                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        if rewardAmount > 0 {
                            Text("+\(Int(rewardAmount)) coins earned!")
                                .font(.headline)
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                triggerCelebration()
            }
        }
    }

    private func triggerCelebration() {
        let screenWidth = UIScreen.main.bounds.width
        pieces = (0..<40).map { _ in
            ConfettiPiece(
                color: colors.randomElement()!,
                x: CGFloat.random(in: -screenWidth/2...screenWidth/2),
                rotation: Double.random(in: 0...360),
                speed: Double.random(in: 1.5...3.0),
                size: CGFloat.random(in: 6...14),
                shape: Int.random(in: 0...2)
            )
        }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showBanner = true
        }

        withAnimation(.easeIn(duration: 2.5)) {
            animate = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showBanner = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isActive = false
            animate = false
            pieces = []
        }
    }
}

struct ConfettiShape: Shape {
    let shape: Int

    func path(in rect: CGRect) -> Path {
        switch shape {
        case 0:
            return Circle().path(in: rect)
        case 1:
            return Rectangle().path(in: rect)
        default:
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            for i in 0..<5 {
                let angle = (Double(i) * 4 * .pi / 5) - .pi / 2
                let point = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                if i == 0 { path.move(to: point) }
                else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        }
    }
}
