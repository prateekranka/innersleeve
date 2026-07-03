import SwiftUI

/// Pure math for the depth carousel — kept UI-free so it can be regression tested.
/// Implements the hero-dominant shelf geometry:
/// the selected record stays large while neighbors cluster at the edges.
struct CarouselGeometry {
    var heroClearance: Double = 178
    var clusterStep: Double = 30
    var neighborScale: Double = 0.40
    var clusterScaleDecay: Double = 0.025
    var minClusterScale: Double = 0.30
    var maxVisible: Int = 6

    struct Placement: Equatable {
        var x: Double
        var scale: Double
        var rotationDegrees: Double
        var opacity: Double
        var blur: Double
        var zIndex: Double
    }

    func placement(forOffset offset: Double) -> Placement {
        let magnitude = abs(offset)
        let sign = offset == 0 ? 0 : (offset > 0 ? 1.0 : -1.0)

        let x: Double
        let scale: Double
        let rotation: Double
        if magnitude < 1 {
            let t = easeInOut(magnitude)
            x = sign * heroClearance * t
            scale = 1.0 - (1.0 - neighborScale) * t
            rotation = -sign * 58 * t
        } else {
            let tail = magnitude - 1
            x = sign * (heroClearance + tail * clusterStep)
            scale = max(neighborScale - tail * clusterScaleDecay, minClusterScale)
            rotation = -sign * (58 + min(tail * 4, 12))
        }

        let farProgress = min(max((magnitude - 1) / Double(max(maxVisible - 1, 1)), 0), 1)
        let opacity = magnitude < 1
            ? 1.0 - 0.10 * easeInOut(magnitude)
            : 0.9 - 0.60 * farProgress
        let blur = magnitude <= 1 ? 0 : 2.5 * farProgress
        let zIndex = 10 - magnitude
        return Placement(
            x: x,
            scale: scale,
            rotationDegrees: min(max(rotation, -72), 72),
            opacity: opacity,
            blur: blur,
            zIndex: zIndex
        )
    }

    private func easeInOut(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    /// Flick-aware snap target: project the release velocity, round, clamp.
    static func snapTarget(position: Double, velocity: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let projected = position + velocity * 0.14
        return min(max(Int(projected.rounded()), 0), count - 1)
    }

    /// Soft rubber-band clamp for dragging past the ends of the shelf.
    static func rubberBand(_ position: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        let limit = Double(count - 1)
        if position < 0 { return position * 0.35 }
        if position > limit { return limit + (position - limit) * 0.35 }
        return position
    }
}

/// Draggable 3D depth carousel. Owns continuous position; publishes snapped selection.
struct DepthCarouselView<Item: Identifiable, Disc: View>: View {
    var items: [Item]
    @Binding var selection: Int
    var geometry = CarouselGeometry()
    var discDiameter: CGFloat = 300
    /// Called when the already-selected hero disc is tapped.
    var onHeroTap: ((Item) -> Void)? = nil
    @ViewBuilder var disc: (Item, Bool) -> Disc

    @State private var position: Double = 0
    @State private var dragAnchor: Double? = nil

    private var snapSpring: Animation {
        .spring(response: 0.55, dampingFraction: 0.82)
    }

    var body: some View {
        GeometryReader { proxy in
            let midX = proxy.size.width / 2
            let midY = proxy.size.height / 2

            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let offset = Double(index) - position
                    if abs(offset) <= Double(geometry.maxVisible) + 0.5 {
                        let p = geometry.placement(forOffset: offset)
                        ZStack {
                            // Soft ground shadow under near records.
                            Ellipse()
                                .fill(Palette.warmShadow.opacity(p.zIndex > 0.6 ? 0.9 : 0.3))
                                .frame(width: discDiameter * 0.72, height: discDiameter * 0.09)
                                .offset(y: discDiameter * 0.52)
                                .blur(radius: 10)
                            disc(item, index == selection)
                        }
                        .frame(width: discDiameter, height: discDiameter)
                        .rotation3DEffect(
                            .degrees(p.rotationDegrees),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.55
                        )
                        .scaleEffect(p.scale)
                        .opacity(p.opacity)
                        .blur(radius: p.blur)
                        .position(x: midX + p.x, y: midY)
                        .zIndex(p.zIndex)
                        .onTapGesture {
                            if index == selection {
                                onHeroTap?(item)
                            } else {
                                snap(to: index)
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
        .onAppear {
            position = Double(min(selection, max(items.count - 1, 0)))
        }
        .onChange(of: selection) { _, newValue in
            if Int(position.rounded()) != newValue {
                withAnimation(snapSpring) { position = Double(newValue) }
            }
        }
        .onChange(of: items.count) { _, newCount in
            let clamped = min(selection, max(newCount - 1, 0))
            if clamped != selection { selection = clamped }
            position = Double(clamped)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selection)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragAnchor == nil { dragAnchor = position }
                let anchor = dragAnchor ?? position
                let raw = anchor - Double(value.translation.width) / 170
                position = CarouselGeometry.rubberBand(raw, count: items.count)
            }
            .onEnded { value in
                dragAnchor = nil
                let flick = Double(value.predictedEndTranslation.width - value.translation.width)
                let velocity = -flick / 170
                let target = CarouselGeometry.snapTarget(
                    position: position,
                    velocity: velocity,
                    count: items.count
                )
                snap(to: target)
            }
    }

    private func snap(to index: Int) {
        withAnimation(snapSpring) { position = Double(index) }
        if selection != index { selection = index }
    }
}
