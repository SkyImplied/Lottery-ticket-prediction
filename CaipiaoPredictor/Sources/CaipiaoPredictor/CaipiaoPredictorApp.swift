import SwiftUI

@main
struct CaipiaoPredictorApp: App {
    @StateObject private var viewModel = LotteryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1320, height: 840)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("更新当前彩种") {
                    Task {
                        await viewModel.updateSelectedGame()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("更新全部彩种") {
                    Task {
                        await viewModel.updateAllGames()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
