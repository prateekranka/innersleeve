import SwiftUI

struct StageLightControl: View {
    @Environment(StageLight.self) private var stageLight: StageLight?
    @State private var dragStartPosition: CGPoint?
    @State private var axisCrossings = 0
    @State private var previousAxisSide = -1

    var body: some View {
        GeometryReader { proxy in
            let light = stageLight ?? StageLight()
            let availableWidth = max(proxy.size.width - 44, 1)
            let availableHeight = max(proxy.size.height - 44, 1)
            let point = screenPoint(
                from: light.position,
                width: availableWidth,
                height: availableHeight,
                in: proxy.size
            )

            StageLightGlyph()
                .frame(width: 44, height: 44)
                .position(point)
                .gesture(dragGesture(width: availableWidth, height: availableHeight))
                .accessibilityLabel("Studio light")
                .accessibilityAddTraits(.isButton)
        }
        .sensoryFeedback(.selection, trigger: axisCrossings)
    }

    private func dragGesture(width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard let stageLight else { return }
                if dragStartPosition == nil {
                    dragStartPosition = stageLight.position
                    previousAxisSide = stageLight.position.x < 0 ? -1 : 1
                }
                let base = dragStartPosition ?? stageLight.position
                let next = StageLightMath.clamped(position: CGPoint(
                    x: base.x + Double(value.translation.width / (width / 2)),
                    y: base.y + Double(value.translation.height / (height / 2))
                ))
                let side = next.x < 0 ? -1 : 1
                if side != previousAxisSide {
                    axisCrossings += 1
                    previousAxisSide = side
                }
                withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.82)) {
                    stageLight.position = next
                    stageLight.intensity = max(stageLight.intensity, 0.72)
                }
            }
            .onEnded { _ in
                dragStartPosition = nil
            }
    }

    private func screenPoint(
        from position: CGPoint,
        width: CGFloat,
        height: CGFloat,
        in size: CGSize
    ) -> CGPoint {
        CGPoint(
            x: size.width / 2 + width / 2 * position.x,
            y: size.height / 2 + height / 2 * position.y
        )
    }
}

private struct StageLightGlyph: View {
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(Palette.warmYellow.opacity(0.52))
                    .frame(width: 3, height: 9)
                    .offset(y: -15)
                    .rotationEffect(.degrees(Double(index) * 90))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Palette.warmYellow,
                            Palette.warmYellow.opacity(0.45),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 17
                    )
                )
                .frame(width: 34, height: 34)

            Circle()
                .fill(Palette.warmYellow)
                .frame(width: 12, height: 12)
                .shadow(color: Palette.warmYellow.opacity(0.42), radius: 10)
        }
        .contentShape(Circle())
    }
}
