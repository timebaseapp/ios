import SwiftUI

/// The main Timebase window. Two views toggled via the View menu: world
/// clock rows (⌘1, default) and timeline matrix (⌘2, coming in the next
/// slice). The world clock is the window's identity — no sidebar, no tabs.
struct MainWindow: View {
    @Environment(TimebaseMacStore.self) private var store
    @SceneStorage("mac.mainView") private var rawView: String = MainViewMode.rows.rawValue

    private var mode: MainViewMode {
        get { MainViewMode(rawValue: rawView) ?? .rows }
    }

    var body: some View {
        Group {
            switch mode {
            case .rows:
                WorldClockRows()
                    .environment(store)
            case .matrix:
                MatrixComingNext()
                    .environment(store)
            }
        }
        .task { store.bootstrap() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $rawView) {
                    Text("Rows").tag(MainViewMode.rows.rawValue)
                    Text("Matrix").tag(MainViewMode.matrix.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }
}

enum MainViewMode: String {
    case rows, matrix
}

/// Placeholder for ⌘2 timeline matrix — built in the next slice. Calm and
/// honest about what's coming rather than hiding the unimplemented view.
struct MatrixComingNext: View {
    @Environment(TimebaseMacStore.self) private var store

    @State private var tick = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let hour = ClockMath.fractionalHour(in: store.homeTimeZone, date: tick)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark)
        let fg = Palette.foreground(forHour: hour, scheme: .dark)

        ZStack {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Timeline matrix")
                    .font(Brand.serif(28))
                Text("Cities as rows, hours as columns, working-hours overlap at a glance — coming in the next slice.")
                    .font(Brand.mono(11))
                    .opacity(0.65)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .foregroundStyle(fg)
            .padding(40)
        }
        .onReceive(timer) { tick = $0 }
    }
}
