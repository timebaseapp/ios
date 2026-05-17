import SwiftUI

/// A vertical fluted-glass overlay rendered directly via Canvas. Each rib is
/// a smooth cylindrical highlight→shadow gradient. Tile width is fixed (so
/// the glass feels physical), screen width determines how many ribs show.
struct FlutedGlassLayer: View {
    var ribWidth: CGFloat = 60

    var body: some View {
        Canvas { context, size in
            let count = Int(ceil(size.width / ribWidth)) + 1
            for i in 0 ..< count {
                let x = CGFloat(i) * ribWidth
                let rect = CGRect(x: x, y: 0, width: ribWidth, height: size.height)
                // Sine-like highlight: bright at 25% of rib, mid at 50%,
                // shadow at 75%, mid again at 0% and 100% (wraparound).
                let g = Gradient(stops: [
                    .init(color: .clear,                  location: 0.00),
                    .init(color: .white.opacity(0.32),    location: 0.22),
                    .init(color: .clear,                  location: 0.50),
                    .init(color: .black.opacity(0.20),    location: 0.78),
                    .init(color: .clear,                  location: 1.00),
                ])
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        g,
                        startPoint: CGPoint(x: x, y: 0),
                        endPoint: CGPoint(x: x + ribWidth, y: 0)
                    )
                )
            }
        }
        .blendMode(.softLight)
    }
}
