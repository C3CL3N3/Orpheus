import SwiftUI

/// Scrolls text horizontally when it overflows its container.
/// Pauses at the start, scrolls to end, snaps back, then repeats.
struct MarqueeText: View {
    let text: String
    let font: Font
    let speed: Double  // points per second

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var taskToken: UUID = UUID()

    private var overflow: CGFloat { max(0, textWidth - containerWidth + 8) }

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: -offset)
                .background(
                    GeometryReader { tg in
                        Color.clear.onAppear { textWidth = tg.size.width }
                    }
                )
                .onAppear { containerWidth = geo.size.width }
                .onChange(of: geo.size.width) { containerWidth = $0 }
        }
        .clipped()
        .onChange(of: text) {
            offset = 0
            textWidth = 0
            restartTask()
        }
        .onChange(of: textWidth) { restartTask() }
        .onChange(of: containerWidth) { restartTask() }
        .task(id: taskToken) { await scrollLoop() }
    }

    private func restartTask() {
        offset = 0
        taskToken = UUID()
    }

    private func scrollLoop() async {
        let ov = overflow
        guard ov > 0, speed > 0 else { return }

        let duration = ov / speed

        try? await Task.sleep(for: .seconds(1.5))  // initial pause

        while !Task.isCancelled {
            withAnimation(.linear(duration: duration)) { offset = ov }
            try? await Task.sleep(for: .seconds(duration + 0.4))

            withAnimation(.easeIn(duration: 0.25)) { offset = 0 }
            try? await Task.sleep(for: .seconds(2.0))
        }
    }
}
