import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar()
                .frame(width: 276)

            Rectangle()
                .fill(AppText.border.opacity(0.62))
                .frame(width: 1)

            PredictionContent()
        }
        .frame(minWidth: 1180, minHeight: 760)
        .background(AppBackground())
        .foregroundStyle(AppText.primary)
        .tint(AppText.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showingAlgorithm) {
            AlgorithmSheet(game: viewModel.selectedGame, play: viewModel.selectedPlay, algorithm: viewModel.selectedAlgorithm)
                .frame(width: 700, height: 560)
        }
        .sheet(isPresented: $viewModel.showingScores) {
            ScoreSheet()
                .environmentObject(viewModel)
                .frame(width: 760, height: 620)
        }
        .background(WindowConfigurator())
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureIfNeeded(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureIfNeeded(window: nsView.window, coordinator: context.coordinator)
        }
    }

    private func configureIfNeeded(window: NSWindow?, coordinator: Coordinator) {
        guard let window, coordinator.configuredWindow !== window else { return }
        configure(window: window)
        coordinator.configuredWindow = window
    }

    private func configure(window: NSWindow) {
        let minimum = NSSize(width: 1180, height: 760)
        window.minSize = minimum
        window.title = "Caipiao Predictor"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true

        let frame = window.frame
        if frame.width < minimum.width || frame.height < minimum.height {
            window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y, width: 1320, height: 820), display: true, animate: false)
            window.center()
        }
    }
}

private struct AppSidebar: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    private var totalDraws: Int {
        LotteryGame.allCases.reduce(0) { partial, game in
            partial + viewModel.drawsByGame[game, default: []].count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                AppIconMark()

                VStack(spacing: 6) {
                    Text("Caipiao Predictor")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppText.primary)
                    Text("版本 0.7.0")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppText.secondary)
                }
            }
            .padding(.top, 64)
            .padding(.bottom, 38)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    SidebarGroup(title: "福利彩票", games: LotteryGame.allCases.filter { $0.family == .welfare })
                    SidebarGroup(title: "体育彩票", games: LotteryGame.allCases.filter { $0.family == .sports })
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 16)

            SidebarStatusCard(totalDraws: totalDraws)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        .background(SidebarBackground())
    }
}

private struct AppIconMark: View {
    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: "AppLogo", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.20, green: 0.52, blue: 1), Color(red: 0.05, green: 0.32, blue: 1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: AppText.accent.opacity(0.34), radius: 18, x: 0, y: 9)
    }
}

private struct SidebarGroup: View {
    let title: String
    let games: [LotteryGame]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppText.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)

            ForEach(games) { game in
                SidebarItem(game: game)
            }
        }
    }
}

private struct SidebarItem: View {
    @EnvironmentObject private var viewModel: LotteryViewModel
    let game: LotteryGame

    private var selected: Bool {
        viewModel.selectedGame == game
    }

    var body: some View {
        Button {
            viewModel.selectedGame = game
        } label: {
            HStack(spacing: 13) {
                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 22)

                Text(game.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)

                Spacer()

                Text("\(viewModel.drawsByGame[game, default: []].count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(selected ? .white.opacity(0.9) : AppText.secondary)
            }
            .padding(.horizontal, 15)
            .frame(height: 40)
            .foregroundStyle(selected ? .white : AppText.primary)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? AppText.selectedGradient : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: selected ? AppText.accent.opacity(0.28) : .clear, radius: 13, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
    }

    private var iconName: String {
        switch game.predictionKind {
        case .orderedDigits:
            return "number"
        case .mixedBalls:
            return "circle.grid.2x2"
        case .unorderedBalls:
            return "circle.grid.3x3"
        }
    }
}

private struct SidebarStatusCard: View {
    @EnvironmentObject private var viewModel: LotteryViewModel
    let totalDraws: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 11, height: 11)
                    .shadow(color: .green.opacity(0.55), radius: 6, x: 0, y: 0)

                Text("模型状态：")
                    .font(.system(size: 12, weight: .bold))
                Text("正常")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("已载入 \(LotteryGame.allCases.count) 个模型 · \(totalDraws) 条数据")
                Text("数据更新时间：\(DisplayFormat.time(viewModel.lastUpdated))")
                Text("时区 · \(TimeZone.current.identifier)")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppText.secondary)
            .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppText.panelStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppText.border, lineWidth: 1)
        )
    }
}

private struct PredictionContent: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 34
            let contentWidth = max(720, proxy.size.width - horizontalPadding * 2)
            let canUseColumns = contentWidth >= 760

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeader()

                    if canUseColumns {
                        HStack(alignment: .top, spacing: 20) {
                            OperationCard()
                                .frame(maxWidth: .infinity, minHeight: 398, alignment: .top)
                            DrawCard()
                                .frame(maxWidth: .infinity, minHeight: 398, alignment: .top)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            OperationCard()
                                .frame(maxWidth: .infinity, alignment: .top)
                            DrawCard()
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }

                    PredictionResultPanel()
                        .frame(maxWidth: .infinity)

                    PrizeCheckPanel()
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 48)
                .padding(.bottom, 34)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PageHeader: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(viewModel.selectedGame.displayName)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppText.primary)

            Text("\(viewModel.selectedGame.schedule) · 已载入 \(viewModel.draws.count) 期开奖数据")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppText.secondary)
        }
        .padding(.leading, 4)
        .padding(.bottom, 2)
    }
}

private struct GlassPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    var titleSpacing: CGFloat = 22
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: titleSpacing) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppText.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppText.secondary)
                            .lineLimit(1)
                    }
                }
            }

            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppText.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppText.border, lineWidth: 1)
        )
    }
}

private struct OperationCard: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    var body: some View {
        GlassPanel(title: "操作区", subtitle: nil, icon: "shippingbox", iconColor: AppText.accent) {
            VStack(spacing: 22) {
                HStack(spacing: 14) {
                    DashboardActionTile(title: "刷新数据", icon: "arrow.clockwise") {
                        Task { await viewModel.updateSelectedGame() }
                    }
                    .disabled(viewModel.isUpdating || viewModel.isPredicting || viewModel.isComparingAlgorithms)

                    DashboardActionTile(title: "评分榜", icon: "chart.bar.xaxis") {
                        viewModel.openScores()
                    }
                    .disabled(viewModel.draws.isEmpty || viewModel.isScoring)

                    DashboardActionTile(title: "算法说明", icon: "text.book.closed") {
                        viewModel.showingAlgorithm = true
                    }
                }

                Button {
                    viewModel.predictNextIssue()
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isPredicting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 17, weight: .bold))
                        }

                        Text(viewModel.isPredicting ? "正在预测..." : "预测下一期")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.draws.isEmpty || viewModel.isUpdating || viewModel.isPredicting || viewModel.isComparingAlgorithms)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 22), GridItem(.flexible(), spacing: 22)], alignment: .leading, spacing: 18) {
                    FormControl(title: "玩法") {
                        DropdownControl(
                            selection: $viewModel.selectedPlayKey,
                            options: viewModel.selectedGame.playOptions.map { DropdownOption(value: $0.key, title: $0.title) }
                        )
                    }

                    FormControl(title: "预测算法") {
                        AlgorithmChecklistMenu()
                        .disabled(viewModel.isPredicting || viewModel.isScoring)
                    }

                    FormControl(title: "查看期号") {
                        DropdownControl(selection: Binding(
                            get: { viewModel.selectedIssue ?? viewModel.latestDraw?.issue ?? "" },
                            set: { viewModel.selectedIssue = $0 }
                        ), options: issueOptions)
                        .disabled(viewModel.draws.isEmpty)
                    }

                    FormControl(title: "期号输入") {
                        TextField("2026160", text: Binding(
                            get: { viewModel.selectedIssue ?? "" },
                            set: { viewModel.selectedIssue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.plain)
                        .focusEffectDisabled()
                        .disabled(viewModel.draws.isEmpty)
                    }
                }
            }
        }
    }

    private var issueOptions: [DropdownOption<String>] {
        var options = viewModel.recentIssueDraws.map { DropdownOption(value: $0.issue, title: "第 \($0.issue) 期") }
        if let selectedIssue = viewModel.selectedIssue,
           !options.contains(where: { $0.value == selectedIssue }) {
            options.insert(DropdownOption(value: selectedIssue, title: "第 \(selectedIssue) 期"), at: 0)
        }
        return options
    }
}

private struct DashboardActionTile: View {
    let title: String
    let icon: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppText.accent)

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppText.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppText.tile)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppText.border.opacity(0.75), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
    }
}

private struct FormControl<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppText.secondary)

            content
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppText.border, lineWidth: 1)
                )
        }
    }
}

private struct DropdownOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }
}

private struct DropdownControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [DropdownOption<Value>]
    @Environment(\.isEnabled) private var isEnabled

    private var selectedTitle: String {
        options.first { $0.value == selection }?.title ?? options.first?.title ?? "-"
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    if option.value == selection {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppText.secondary)
            }
            .foregroundStyle(isEnabled ? AppText.primary : AppText.muted)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
    }
}

private struct AlgorithmChecklistMenu: View {
    @EnvironmentObject private var viewModel: LotteryViewModel
    @Environment(\.isEnabled) private var isEnabled

    private var title: String {
        viewModel.orderedSelectedAlgorithms.map(\.title).joined(separator: "、")
    }

    var body: some View {
        Menu {
            ForEach(PredictionAlgorithm.allCases) { algorithm in
                Button {
                    viewModel.togglePredictionAlgorithm(algorithm)
                } label: {
                    Label(algorithm.title, systemImage: viewModel.selectedAlgorithms.contains(algorithm) ? "checkmark.square.fill" : "square")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title.isEmpty ? "选择算法" : title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppText.secondary)
            }
            .foregroundStyle(isEnabled ? AppText.primary : AppText.muted)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
    }
}

private struct DrawCard: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    private var subtitle: String? {
        viewModel.selectedDraw.map { "第 \($0.issue) 期 · \($0.drawDate)" } ?? "暂无开奖数据"
    }

    var body: some View {
        GlassPanel(title: "开奖详情", subtitle: subtitle, icon: "calendar", iconColor: AppText.accent) {
            DrawSummary(draw: viewModel.selectedDraw)
        }
    }
}

private struct DrawSummary: View {
    let draw: LotteryDraw?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let draw {
                Text("开奖号码")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(AppText.primary)

                ComponentNumbersView(game: draw.game, values: draw.components, style: .drawn)

                Spacer(minLength: 4)

                HStack(spacing: 12) {
                    MetricPill(title: "销售额", value: DisplayFormat.money(draw.saleMoney), icon: "dollarsign.circle", tint: AppText.accent)
                    MetricPill(title: "奖池", value: DisplayFormat.money(draw.prizePoolMoney), icon: "trophy", tint: .yellow)
                    MetricPill(title: "星期", value: draw.week.isEmpty ? "-" : draw.week, icon: "calendar", tint: .green)
                }
            } else {
                PlaceholderBlock(title: "暂无开奖", message: "点击刷新数据获取该彩种开奖信息。", icon: "tray")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PredictionResultPanel: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    var body: some View {
        GlassPanel(title: "预测结果", subtitle: nil, icon: "sparkles", iconColor: Color(red: 0.55, green: 0.42, blue: 1.0), titleSpacing: 10) {
            PredictionSummary()
        }
        .frame(minHeight: 236, alignment: .top)
    }
}

private struct PredictionSummary: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    private var results: [AlgorithmComparisonResult] {
        if let comparison = viewModel.algorithmComparison {
            return comparison.results
        }
        if let prediction = viewModel.prediction {
            return [
                AlgorithmComparisonResult(
                    algorithm: prediction.algorithm,
                    prediction: prediction,
                    sharedTokenCount: 0,
                    uniqueTokenCount: 0
                )
            ]
        }
        return []
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 28) {
                stateContent
                    .frame(maxWidth: .infinity, minHeight: 154)
                ResultPreviewCard(consensus: viewModel.consensusPrediction)
                    .frame(maxWidth: 560)
                    .layoutPriority(1)
            }

            VStack(alignment: .leading, spacing: 18) {
                stateContent
                    .frame(maxWidth: .infinity, minHeight: 154)
                ResultPreviewCard(consensus: viewModel.consensusPrediction)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.isPredicting {
            LoadingPredictionState()
        } else if !results.isEmpty {
            AlgorithmResultsList(results: results, summary: viewModel.algorithmComparison?.summary)
        } else {
            EmptyPredictionState()
        }
    }
}

private struct AlgorithmResultsList: View {
    let results: [AlgorithmComparisonResult]
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MiniHeader(title: "下一期候选", subtitle: "\(results.count) 个算法结果", icon: "sparkles")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(results) { result in
                    AlgorithmPredictionCard(result: result)
                }
            }

            if let summary {
                Text(summary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppText.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AlgorithmPredictionCard: View {
    let result: AlgorithmComparisonResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(result.algorithm.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(AppText.primary)

                Spacer()

                if result.sharedTokenCount > 0 || result.uniqueTokenCount > 0 {
                    Text("共识 \(result.sharedTokenCount) · 差异 \(result.uniqueTokenCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppText.secondary)
                        .monospacedDigit()
                }
            }

            ComponentNumbersView(game: result.prediction.game, values: result.prediction.components, style: .prediction)
            BetCostView(cost: result.prediction.betCost)

            Text(result.prediction.note)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppText.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(AppText.tile.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppText.border.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct EmptyPredictionState: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppText.accent.opacity(0.08))
                    .frame(width: 84, height: 84)
                Circle()
                    .fill(AppText.accent.opacity(0.12))
                    .frame(width: 66, height: 66)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color(red: 0.58, green: 0.70, blue: 1.0))
            }

            Text("等待预测")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
            Text("选择玩法后点击“预测下一期”。")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppText.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct LoadingPredictionState: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("正在计算候选号码")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
            Text("模型会根据当前玩法和算法刷新评分。")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppText.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ResultPreviewCard: View {
    let consensus: ConsensusPrediction?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("综合推荐号码")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(AppText.primary)
                    if let consensus {
                        Text("基于 \(consensus.algorithms.count) 个算法共识")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppText.secondary)
                    }
                }

                if let consensus {
                    ComponentNumbersView(game: consensus.game, values: consensus.components, style: .compactPrediction)
                } else {
                    HStack(spacing: 14) {
                        ForEach(0..<10, id: \.self) { _ in
                            Circle()
                                .stroke(AppText.border, lineWidth: 1)
                                .frame(width: 27, height: 27)
                        }
                    }
                }
            }

            if let consensus {
                Divider()
                    .overlay(AppText.border.opacity(0.9))
                BetCostView(cost: consensus.betCost)
                Text("综合推荐按各算法候选的出现次数投票；票数相同则优先采用算法内排序更靠前的号码。")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppText.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppText.tile.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppText.border.opacity(0.78), lineWidth: 1)
        )
    }
}

private enum PrizeCheckState {
    case idle(String)
    case error(String)
    case result(PrizeCheckResult)
}

private struct PrizeCheckPanel: View {
    @EnvironmentObject private var viewModel: LotteryViewModel
    @State private var issueText = ""
    @State private var inputValues: [String: String] = [:]

    private var inputSpecs: [PrizeInputSpec] {
        PrizeEvaluator.inputSpecs(game: viewModel.selectedGame, play: viewModel.selectedPlay)
    }

    private var currentRules: [PrizeRule] {
        PrizeEvaluator.rules(game: viewModel.selectedGame, play: viewModel.selectedPlay)
    }

    private var normalizedIssue: String {
        issueText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedDraw: LotteryDraw? {
        viewModel.draws.first { $0.issue == normalizedIssue }
    }

    private var checkState: PrizeCheckState {
        guard !normalizedIssue.isEmpty else {
            return .idle("请输入要兑奖的期号。")
        }
        let hasAnyInput = inputSpecs.contains { !(inputValues[$0.component.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        guard hasAnyInput else {
            return .idle("输入彩票号码后自动测算中奖结果。")
        }
        guard let draw = selectedDraw else {
            return .error(PrizeInputError.missingDraw(issue: normalizedIssue).localizedDescription)
        }

        do {
            var parsed: [String: [Int]] = [:]
            for spec in inputSpecs {
                parsed[spec.component.key] = try PrizeEvaluator.parseNumbers(inputValues[spec.component.key, default: ""], spec: spec)
            }
            return .result(PrizeEvaluator.evaluate(game: viewModel.selectedGame, play: viewModel.selectedPlay, draw: draw, numbers: parsed))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    var body: some View {
        GlassPanel(title: "中奖规则与兑奖测算", subtitle: "\(viewModel.selectedGame.name) · \(viewModel.selectedPlay.title)", icon: "trophy", iconColor: .yellow, titleSpacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 22) {
                    PrizeRulesView(rules: currentRules)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    PrizeInputView(
                        issueText: $issueText,
                        inputValues: $inputValues,
                        inputSpecs: inputSpecs,
                        issueOptions: issueOptions,
                        draw: selectedDraw,
                        state: checkState,
                        hasRecommendation: viewModel.consensusPrediction != nil,
                        fillRecommended: fillRecommendedNumbers
                    )
                    .frame(maxWidth: 520, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 18) {
                    PrizeRulesView(rules: currentRules)
                    PrizeInputView(
                        issueText: $issueText,
                        inputValues: $inputValues,
                        inputSpecs: inputSpecs,
                        issueOptions: issueOptions,
                        draw: selectedDraw,
                        state: checkState,
                        hasRecommendation: viewModel.consensusPrediction != nil,
                        fillRecommended: fillRecommendedNumbers
                    )
                }
            }
        }
        .onAppear {
            resetIssueIfNeeded()
        }
        .onChange(of: viewModel.selectedGame) { _, _ in
            resetInputs()
        }
        .onChange(of: viewModel.selectedPlayKey) { _, _ in
            resetInputs()
        }
        .onChange(of: viewModel.selectedIssue) { _, _ in
            resetIssueIfNeeded()
        }
    }

    private var issueOptions: [DropdownOption<String>] {
        var options = viewModel.recentIssueDraws.map { DropdownOption(value: $0.issue, title: "第 \($0.issue) 期") }
        if !normalizedIssue.isEmpty,
           !options.contains(where: { $0.value == normalizedIssue }) {
            options.insert(DropdownOption(value: normalizedIssue, title: "第 \(normalizedIssue) 期"), at: 0)
        }
        return options
    }

    private func resetInputs() {
        issueText = viewModel.selectedIssue ?? viewModel.latestDraw?.issue ?? ""
        inputValues = [:]
    }

    private func resetIssueIfNeeded() {
        if issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issueText = viewModel.selectedIssue ?? viewModel.latestDraw?.issue ?? ""
        }
    }

    private func fillRecommendedNumbers() {
        guard let consensus = viewModel.consensusPrediction else { return }
        var nextValues: [String: String] = inputValues
        for spec in inputSpecs {
            let values = consensus.components[spec.component.key, default: []]
            let formatter = spec.component.ordered ? DisplayFormat.digit : DisplayFormat.number
            nextValues[spec.component.key] = values.prefix(spec.requiredCount).map(formatter).joined(separator: spec.component.ordered ? "" : " ")
        }
        inputValues = nextValues
    }
}

private struct PrizeRulesView: View {
    let rules: [PrizeRule]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MiniHeader(title: "中奖规则", subtitle: "\(rules.count) 个奖级/条件", icon: "list.bullet.rectangle")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 176), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(rule.title)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(AppText.primary)
                            Spacer(minLength: 8)
                            Text(rule.prize)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(rule.prize.contains("浮动") ? .yellow : AppText.accent)
                                .lineLimit(1)
                        }

                        Text(rule.condition)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppText.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                    .background(AppText.tile.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppText.border.opacity(0.72), lineWidth: 1)
                    )
                }
            }
        }
    }
}

private struct PrizeInputView: View {
    @Binding var issueText: String
    @Binding var inputValues: [String: String]
    let inputSpecs: [PrizeInputSpec]
    let issueOptions: [DropdownOption<String>]
    let draw: LotteryDraw?
    let state: PrizeCheckState
    let hasRecommendation: Bool
    let fillRecommended: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MiniHeader(title: "号码兑奖", subtitle: "按指定期号测算", icon: "checkmark.seal")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 12) {
                FormControl(title: "兑奖期号") {
                    TextField("2026160", text: $issueText)
                        .textFieldStyle(.plain)
                        .focusEffectDisabled()
                }

                FormControl(title: "最近期号") {
                    DropdownControl(selection: $issueText, options: issueOptions)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(inputSpecs) { spec in
                    PrizeNumberField(spec: spec, text: Binding(
                        get: { inputValues[spec.component.key, default: ""] },
                        set: { inputValues[spec.component.key] = $0 }
                    ))
                }
            }

            HStack(spacing: 10) {
                Button {
                    fillRecommended()
                } label: {
                    Label("填入综合推荐", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .disabled(!hasRecommendation)

                Spacer()

                Text("仅作规则测算，最终以官方开奖与中奖彩票为准。")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppText.secondary)
            }

            if let draw {
                VStack(alignment: .leading, spacing: 8) {
                    Text("第 \(draw.issue) 期开奖：\(draw.drawDate)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppText.secondary)
                    ComponentNumbersView(game: draw.game, values: draw.components, style: .compactPrediction)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            PrizeCheckResultView(state: state)
        }
        .padding(16)
        .background(AppText.tile.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppText.border.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct PrizeNumberField: View {
    let spec: PrizeInputSpec
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(spec.component.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppText.secondary)

            TextField(spec.placeholder, text: $text)
                .font(.system(size: 14, weight: .semibold, design: spec.component.ordered ? .rounded : .default))
                .monospacedDigit()
                .textFieldStyle(.plain)
                .focusEffectDisabled()
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppText.border, lineWidth: 1)
                )

            Text(spec.helper)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppText.muted)
        }
    }
}

private struct PrizeCheckResultView: View {
    let state: PrizeCheckState

    var body: some View {
        switch state {
        case .idle(let message):
            PrizeStatusBox(icon: "number.square", title: "等待输入", message: message, tint: AppText.secondary)
        case .error(let message):
            PrizeStatusBox(icon: "exclamationmark.triangle", title: "无法测算", message: message, tint: .orange)
        case .result(let result):
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.bestPrizeName)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(result.breakdown.isEmpty ? AppText.secondary : .yellow)
                        Text(result.matchSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppText.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(result.amountSummary)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppText.primary)
                        Text("测算 \(result.checkedBetCount) 注")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppText.secondary)
                    }
                }

                if result.breakdown.isEmpty {
                    Text("本次输入号码未命中奖级。")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppText.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(result.breakdown) { item in
                            HStack(spacing: 10) {
                                Text(item.prizeName)
                                    .font(.callout.weight(.bold))
                                Spacer()
                                Text("\(item.count) 注")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppText.secondary)
                                Text(item.prizeText)
                                    .font(.callout.weight(.heavy))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(AppText.panelStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppText.border.opacity(0.78), lineWidth: 1)
            )
        }
    }
}

private struct PrizeStatusBox: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppText.primary)
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppText.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppText.panelStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct BetCostView: View {
    let cost: BetCostEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                CompactMetricPill(title: "注数", value: "\(cost.betCount) 注")
                CompactMetricPill(title: "金额", value: "\(cost.amount) 元")
            }

            Text("\(cost.detail)。\(cost.note)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppText.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CompactMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppText.secondary)
            Text(value)
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppText.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ComponentNumbersView: View {
    let game: LotteryGame
    let values: [String: [Int]]
    let style: NumberToken.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(game.components) { component in
                let numbers = values[component.key, default: []]
                if !numbers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if game.components.count > 1 || style == .prediction {
                            Text(component.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppText.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: style == .compactPrediction ? 31 : 56), spacing: style == .compactPrediction ? 9 : 12)], alignment: .leading, spacing: 10) {
                            ForEach(Array(numbers.enumerated()), id: \.offset) { _, number in
                                NumberToken(number: number, component: component, style: style)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct NumberToken: View {
    enum Style: Equatable {
        case drawn
        case prediction
        case compactPrediction
    }

    let number: Int
    let component: NumberComponent
    let style: Style

    var body: some View {
        Text(component.ordered ? DisplayFormat.digit(number) : DisplayFormat.number(number))
            .font(.system(size: style == .compactPrediction ? 13 : 17, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .frame(width: tokenSize.width, height: tokenSize.height)
            .background(
                RoundedRectangle(cornerRadius: style == .compactPrediction ? 15 : 8, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: style == .compactPrediction ? 15 : 8, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }

    private var tokenSize: CGSize {
        switch style {
        case .drawn:
            return CGSize(width: 58, height: 36)
        case .prediction:
            return CGSize(width: 54, height: 36)
        case .compactPrediction:
            return CGSize(width: 30, height: 30)
        }
    }

    private var roleColor: Color {
        switch component.colorRole {
        case .red:
            return Color(red: 1.0, green: 0.34, blue: 0.36)
        case .blue:
            return Color(red: 0.24, green: 0.55, blue: 1)
        case .gold:
            return .orange
        case .neutral:
            return .secondary
        }
    }

    private var textColor: Color {
        switch style {
        case .drawn:
            return roleColor
        case .prediction, .compactPrediction:
            return .white
        }
    }

    private var fillColor: Color {
        switch style {
        case .drawn:
            return roleColor.opacity(0.22)
        case .prediction:
            return roleColor.opacity(0.9)
        case .compactPrediction:
            return roleColor.opacity(0.72)
        }
    }

    private var strokeColor: Color {
        switch style {
        case .drawn:
            return roleColor.opacity(0.78)
        case .prediction, .compactPrediction:
            return .white.opacity(0.18)
        }
    }
}

private struct MiniHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppText.accent)
                .frame(width: 28, height: 28)
                .background(AppText.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppText.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppText.secondary)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)
                .tint(tint)

            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppText.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(AppText.tile, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppText.border.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct PlaceholderBlock: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(AppText.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppText.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
    }
}

private struct ScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: LotteryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(viewModel.selectedGame.displayName) · 评分榜")
                        .font(.title2.weight(.bold))
                    Text("\(viewModel.selectedAlgorithm.title) · 按需计算，只在打开此窗口时刷新。")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppText.secondary)
                }

                Spacer()

                Button {
                    viewModel.refreshScores()
                } label: {
                    Label("刷新评分", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScoring || viewModel.draws.isEmpty)

                Button {
                    dismiss()
                } label: {
                    Label("关闭", systemImage: "xmark.circle.fill")
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ModelSummary()
                    ScoreSummary(scores: Array(viewModel.numberScores.prefix(40)), isLoading: viewModel.isScoring)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(26)
        .background(AppBackground())
    }
}

private struct AlgorithmSheet: View {
    @Environment(\.dismiss) private var dismiss
    let game: LotteryGame
    let play: PlayOption
    let algorithm: PredictionAlgorithm

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(game.displayName) · \(play.title)")
                        .font(.title2.weight(.bold))
                    Text("当前算法：\(algorithm.title)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppText.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("关闭", systemImage: "xmark.circle.fill")
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(game.algorithmDescription(for: algorithm))
                        .textSelection(.enabled)
                        .lineSpacing(4)

                    Divider()

                    Text("算法倾向")
                        .font(.headline)
                    Text(algorithm.shortSummary)
                        .foregroundStyle(AppText.secondary)

                    Text("玩法输出")
                        .font(.headline)
                    Text(play.algorithmHint)
                        .foregroundStyle(AppText.secondary)

                    Text("风险提示")
                        .font(.headline)
                    Text("机器学习和神经网络算法已经加入，但彩票数据通常接近随机，历史拟合不代表未来优势。所有模型结果都只适合作为候选参考。")
                        .foregroundStyle(AppText.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .background(AppBackground())
    }
}

private struct ModelSummary: View {
    @EnvironmentObject private var viewModel: LotteryViewModel

    var body: some View {
        GlassPanel(title: "当前算法", subtitle: viewModel.selectedAlgorithm.scoreSubtitle, icon: "function", iconColor: AppText.accent) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.selectedAlgorithm.modelLines.enumerated()), id: \.offset) { index, line in
                    if index > 0 {
                        Divider().padding(.vertical, 8)
                    }
                    ModelLine(label: line.0, value: line.1)
                }
            }

            Text(viewModel.selectedPlay.detail)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppText.secondary)

            Button {
                viewModel.showingAlgorithm = true
            } label: {
                Label("展开算法说明", systemImage: "text.book.closed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct ScoreSummary: View {
    let scores: [NumberScore]
    let isLoading: Bool

    var body: some View {
        GlassPanel(title: "评分榜", subtitle: "Top 40", icon: "chart.bar.xaxis", iconColor: AppText.accent) {
            if isLoading && scores.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在后台刷新评分...")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppText.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow {
                        HeaderText("分区")
                        HeaderText("号")
                        HeaderText("频次")
                        HeaderText("率")
                        HeaderText("分")
                    }
                    Divider().gridCellColumns(5)

                    ForEach(scores) { score in
                        GridRow {
                            Text(score.componentTitle)
                                .lineLimit(1)
                                .foregroundStyle(AppText.secondary)
                            Text(score.position == nil ? DisplayFormat.number(score.number) : DisplayFormat.digit(score.number))
                                .fontWeight(.bold)
                                .monospacedDigit()
                            Text("\(score.frequency)")
                                .monospacedDigit()
                            Text(DisplayFormat.percent(score.rate))
                                .monospacedDigit()
                            Text(String(format: "%.2f", score.score))
                                .monospacedDigit()
                        }
                        .font(.callout.weight(.semibold))
                    }
                }
            }
        }
    }
}

private struct ModelLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppText.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }
}

private struct HeaderText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppText.secondary)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppText.selectedGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(.white.opacity(configuration.isPressed ? 0.34 : 0.10), lineWidth: 1)
            )
            .shadow(color: AppText.accent.opacity(isEnabled ? 0.28 : 0), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.48)
    }
}

private struct SidebarBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.10, blue: 0.16),
                    Color(red: 0.10, green: 0.14, blue: 0.21)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [Color.white.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private enum AppText {
    static let primary = Color.white.opacity(0.94)
    static let secondary = Color.white.opacity(0.64)
    static let muted = Color.white.opacity(0.42)
    static let accent = Color(red: 0.12, green: 0.49, blue: 1.0)
    static let panel = Color(red: 0.055, green: 0.075, blue: 0.115).opacity(0.84)
    static let panelStrong = Color(red: 0.075, green: 0.10, blue: 0.155).opacity(0.9)
    static let tile = Color.white.opacity(0.055)
    static let previewBar = Color(red: 0.34, green: 0.42, blue: 0.56)
    static let border = Color(red: 0.24, green: 0.32, blue: 0.46).opacity(0.74)
    static let selectedGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.54, blue: 1.0), Color(red: 0.05, green: 0.34, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.055, blue: 0.09)
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.13),
                    Color(red: 0.045, green: 0.075, blue: 0.13),
                    Color(red: 0.035, green: 0.06, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
