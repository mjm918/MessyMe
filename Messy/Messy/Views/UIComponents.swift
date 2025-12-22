//
//  UIComponents.swift
//  Messy
//
//  Reusable Apple-style UI components with modern animations
//

import SwiftUI

// MARK: - Design System Colors

extension Color {
    static let messyBrand = Color.orange
    
    // Semantic colors
    static let messySecondary = Color.primary.opacity(0.6)
    static let messyBackground = Color(nsColor: .windowBackgroundColor)
}

extension ShapeStyle where Self == Color {
    static var messyBrand: Color { .messyBrand }
}

// MARK: - Typography

struct MessyFontModifier: ViewModifier {
    enum Style {
        case largeTitle
        case title
        case headline
        case body
        case caption
    }
    
    let style: Style
    
    func body(content: Content) -> some View {
        switch style {
        case .largeTitle:
            content.font(.system(size: 24, weight: .bold, design: .rounded))
        case .title:
            content.font(.system(size: 20, weight: .semibold, design: .rounded))
        case .headline:
            content.font(.system(size: 16, weight: .semibold, design: .default))
        case .body:
            content.font(.system(size: 14, weight: .regular, design: .default))
        case .caption:
            content.font(.system(size: 12, weight: .medium, design: .default))
        }
    }
}

extension View {
    func messyFont(_ style: MessyFontModifier.Style) -> some View {
        modifier(MessyFontModifier(style: style))
    }
}

// MARK: - Glass Morphic Card

struct GlassMorphicCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var opacity: CGFloat
    
    init(cornerRadius: CGFloat = 16, opacity: CGFloat = 0.6, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(opacity)
                    
                    // Subtle tint of brand color
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.messyBrand.opacity(0.03))
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .white.opacity(0.05),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    let colors: [Color]
    
    init(colors: [Color] = [.black, .gray.opacity(0.5), .black]) {
        self.colors = colors
    }
    
    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Bouncy Button Style

struct BouncyButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    var duration: Double = 1.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.2),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerEffect(duration: duration))
    }
}

// MARK: - Floating Particles (Subtle)

struct FloatingParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
}

struct FloatingParticlesView: View {
    @State private var particles: [FloatingParticle] = []
    let particleCount: Int
    let color: Color
    
    init(count: Int = 15, color: Color = .messyBrand) {
        self.particleCount = count
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 2)
                }
            }
            .onAppear {
                initializeParticles(in: geometry.size)
                animateParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func initializeParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            FloatingParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 2...5),
                opacity: Double.random(in: 0.05...0.2),
                speed: Double.random(in: 10...20)
            )
        }
    }
    
    private func animateParticles(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in particles.indices {
                withAnimation(.linear(duration: 0.05)) {
                    particles[i].y -= CGFloat(particles[i].speed * 0.05)
                    particles[i].x += CGFloat.random(in: -0.2...0.2)
                    
                    if particles[i].y < -10 {
                        particles[i].y = size.height + 10
                        particles[i].x = CGFloat.random(in: 0...size.width)
                    }
                }
            }
        }
    }
}

// MARK: - Glow Effect

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.3), radius: radius / 2)
            .shadow(color: color.opacity(0.1), radius: radius)
    }
}

extension View {
    func glow(color: Color = .messyBrand, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Staggered Animation Container

struct StaggeredAnimation<Content: View>: View {
    let index: Int
    let content: Content
    let baseDelay: Double
    
    @State private var appeared = false
    
    init(index: Int, baseDelay: Double = 0.04, @ViewBuilder content: () -> Content) {
        self.index = index
        self.baseDelay = baseDelay
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * baseDelay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Parallax Card

struct ParallaxCard<Content: View>: View {
    let content: Content
    @State private var offset: CGSize = .zero
    @State private var isHovered = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .rotation3DEffect(
                .degrees(isHovered ? Double(offset.width / 40) : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .rotation3DEffect(
                .degrees(isHovered ? Double(-offset.height / 40) : 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hovering
                    if !hovering {
                        offset = .zero
                    }
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    offset = CGSize(
                        width: location.x - 100,
                        height: location.y - 50
                    )
                case .ended:
                    offset = .zero
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GlassMorphicCard {
            Text("Glass Card")
                .messyFont(.headline)
                .padding()
        }
        
        Text("Shimmer Effect")
            .messyFont(.title)
            .shimmer()
        
        Button("Bouncy Button") {}
            .buttonStyle(BouncyButtonStyle())
    }
    .padding()
    .frame(width: 300, height: 400)
    .background(Color.gray.opacity(0.3))
}
