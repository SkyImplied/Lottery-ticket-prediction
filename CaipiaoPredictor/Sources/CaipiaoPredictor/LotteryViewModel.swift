import Foundation
import SwiftUI

@MainActor
final class LotteryViewModel: ObservableObject {
    @Published var selectedGame: LotteryGame = .kl8 {
        didSet {
            selectedPlayKey = selectedGame.playOptions.first?.key ?? ""
            selectedIssue = latestDraw?.issue
            prediction = nil
            algorithmComparison = nil
            consensusPrediction = nil
            isPredicting = false
            numberScores = []
            showingScores = false
            if drawsByGame[selectedGame, default: []].isEmpty {
                statusText = "已切换到 \(selectedGame.displayName)，点击“更新当前”获取开奖数据。"
            }
        }
    }

    @Published var selectedPlayKey: String = LotteryGame.kl8.playOptions.first?.key ?? "" {
        didSet {
            guard oldValue != selectedPlayKey else { return }
            prediction = nil
            algorithmComparison = nil
            consensusPrediction = nil
            isPredicting = false
        }
    }
    @Published var selectedAlgorithm: PredictionAlgorithm = .balancedStats {
        didSet {
            guard oldValue != selectedAlgorithm else { return }
            prediction = nil
            consensusPrediction = nil
            numberScores = []
            isPredicting = false
            isScoring = false
        }
    }
    @Published var selectedAlgorithms: Set<PredictionAlgorithm> = [.balancedStats]
    @Published var selectedIssue: String?
    @Published var drawsByGame: [LotteryGame: [LotteryDraw]] = [:]
    @Published var prediction: LotteryPrediction?
    @Published var algorithmComparison: AlgorithmComparison?
    @Published var consensusPrediction: ConsensusPrediction?
    @Published var numberScores: [NumberScore] = []
    @Published var isUpdating = false
    @Published var isPredicting = false
    @Published var isComparingAlgorithms = false
    @Published var isScoring = false
    @Published var statusText = "正在载入内置数据..."
    @Published var lastUpdated: Date?
    @Published var showingAlgorithm = false
    @Published var showingScores = false

    private let service = LotteryService()
    private var scoreCache: [ScoreCacheKey: CachedScores] = [:]
    private var scoreRefreshID = UUID()
    private var predictionTaskID = UUID()
    private var comparisonTaskID = UUID()

    var draws: [LotteryDraw] {
        drawsByGame[selectedGame, default: []]
    }

    var latestDraw: LotteryDraw? {
        draws.last
    }

    var selectedDraw: LotteryDraw? {
        guard let selectedIssue else {
            return latestDraw
        }
        return draws.first { $0.issue == selectedIssue } ?? latestDraw
    }

    var selectedPlay: PlayOption {
        selectedGame.playOptions.first { $0.key == selectedPlayKey } ?? selectedGame.playOptions[0]
    }

    var recentIssueDraws: [LotteryDraw] {
        Array(draws.suffix(180).reversed())
    }

    var drawCountText: String {
        "\(draws.count) 期"
    }

    var orderedSelectedAlgorithms: [PredictionAlgorithm] {
        let selected = selectedAlgorithms.isEmpty ? [selectedAlgorithm] : Array(selectedAlgorithms)
        return PredictionAlgorithm.allCases.filter { selected.contains($0) }
    }

    var selectedAlgorithmTitle: String {
        let algorithms = orderedSelectedAlgorithms
        guard algorithms.count > 1 else {
            return algorithms.first?.title ?? selectedAlgorithm.title
        }
        return "\(algorithms.count) 个算法"
    }

    init() {
        Task {
            await loadBundledData()
        }
    }

    func loadBundledData() async {
        do {
            let bundled = try service.loadBundledDataset()
            drawsByGame = bundled.drawsByGame
            selectedIssue = latestDraw?.issue
            let loadedGames = LotteryGame.allCases.filter { !drawsByGame[$0, default: []].isEmpty }
            let totalDraws = loadedGames.reduce(0) { $0 + drawsByGame[$1, default: []].count }
            statusText = "已载入 \(loadedGames.count) 个彩种、\(totalDraws) 期内置开奖数据（预置于 \(bundledDateText(bundled.generatedAt))）。"
        } catch {
            statusText = error.localizedDescription
        }
    }

    func updateSelectedGame() async {
        await updateGames([selectedGame])
    }

    func updateAllGames() async {
        await updateGames(LotteryGame.allCases)
    }

    func updateGames(_ games: [LotteryGame]) async {
        isUpdating = true
        statusText = games.count == 1 ? "正在更新 \(games[0].displayName)..." : "正在更新全部彩种..."
        defer {
            isUpdating = false
        }

        var successCount = 0
        var failures: [String] = []
        for game in games {
            do {
                let remoteDraws = try await service.fetchDraws(for: game)
                drawsByGame[game] = remoteDraws
                clearScoreCache(for: game)
                if game == selectedGame {
                    selectedIssue = remoteDraws.last?.issue
                    prediction = nil
                    algorithmComparison = nil
                    consensusPrediction = nil
                    numberScores = []
                }
                successCount += 1
            } catch {
                failures.append("\(game.name)：\(error.localizedDescription)")
            }
        }

        lastUpdated = Date()
        if failures.isEmpty {
            statusText = games.count == 1 ? "已更新至第 \(latestDraw?.issue ?? "-") 期" : "已更新 \(successCount) 个彩种"
        } else {
            statusText = "已更新 \(successCount) 个彩种；失败 \(failures.count) 个。\(failures.prefix(2).joined(separator: "；"))"
        }
    }

    func predictNextIssue() {
        guard !draws.isEmpty else {
            statusText = "暂无开奖数据，无法预测"
            return
        }

        let game = selectedGame
        let play = selectedPlay
        let algorithms = orderedSelectedAlgorithms
        let drawsSnapshot = draws
        let requestID = UUID()
        predictionTaskID = requestID
        isPredicting = true
        consensusPrediction = nil
        statusText = "正在用 \(algorithms.count) 个算法计算 \(game.name) \(play.title) 候选号码..."

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                let predictor = LotteryPredictor()
                return algorithms.map { algorithm in
                    let scores = predictor.scoreTable(game: game, draws: drawsSnapshot, algorithm: algorithm)
                    return (
                        algorithm: algorithm,
                        prediction: predictor.predict(game: game, play: play, algorithm: algorithm, scores: scores),
                        scores: scores
                    )
                }
            }.value

            guard predictionTaskID == requestID, selectedGame == game, selectedPlayKey == play.key, orderedSelectedAlgorithms == algorithms else {
                return
            }

            let predictions = result.map(\.prediction)
            prediction = predictions.first
            algorithmComparison = Self.makeAlgorithmComparison(game: game, play: play, predictions: predictions)
            consensusPrediction = Self.makeConsensusPrediction(
                game: game,
                play: play,
                predictions: predictions,
                scoreTables: result.map(\.scores)
            )

            for item in result {
                scoreCache[ScoreCacheKey(game: game, algorithm: item.algorithm)] = CachedScores(drawCount: drawsSnapshot.count, latestIssue: drawsSnapshot.last?.issue, values: item.scores)
            }
            if let currentScores = result.first(where: { $0.algorithm == selectedAlgorithm })?.scores ?? result.first?.scores {
                numberScores = currentScores
            }
            isPredicting = false
            statusText = "已生成 \(game.name) \(play.title) 候选号码（\(algorithms.count) 个算法）"
        }
    }

    func togglePredictionAlgorithm(_ algorithm: PredictionAlgorithm) {
        if selectedAlgorithms.contains(algorithm) {
            guard selectedAlgorithms.count > 1 else { return }
            selectedAlgorithms.remove(algorithm)
        } else {
            selectedAlgorithms.insert(algorithm)
        }
        selectedAlgorithm = algorithm
        prediction = nil
        algorithmComparison = nil
        consensusPrediction = nil
        numberScores = []
        isPredicting = false
        isScoring = false
    }

    func compareAlgorithms() {
        guard !draws.isEmpty else {
            statusText = "暂无开奖数据，无法对比算法"
            return
        }

        let game = selectedGame
        let play = selectedPlay
        let drawsSnapshot = draws
        let requestID = UUID()
        comparisonTaskID = requestID
        isComparingAlgorithms = true
        statusText = "正在对比 \(game.name) \(play.title) 的全部算法..."

        Task {
            let comparison = await Task.detached(priority: .userInitiated) {
                let predictor = LotteryPredictor()
                let result = PredictionAlgorithm.allCases.map { algorithm in
                    let scores = predictor.scoreTable(game: game, draws: drawsSnapshot, algorithm: algorithm)
                    return (
                        prediction: predictor.predict(game: game, play: play, algorithm: algorithm, scores: scores),
                        scores: scores
                    )
                }
                return (
                    comparison: Self.makeAlgorithmComparison(game: game, play: play, predictions: result.map(\.prediction)),
                    consensus: Self.makeConsensusPrediction(game: game, play: play, predictions: result.map(\.prediction), scoreTables: result.map(\.scores))
                )
            }.value

            guard comparisonTaskID == requestID, selectedGame == game, selectedPlayKey == play.key else {
                return
            }

            algorithmComparison = comparison.comparison
            consensusPrediction = comparison.consensus
            isComparingAlgorithms = false
            statusText = "已完成 \(game.name) \(play.title) 算法对比"
        }
    }

    func openScores() {
        showingScores = true
        refreshScores()
    }

    func refreshScores() {
        let game = selectedGame
        let drawsSnapshot = draws
        guard !drawsSnapshot.isEmpty else {
            numberScores = []
            isScoring = false
            return
        }

        let algorithm = selectedAlgorithm
        let cacheKey = ScoreCacheKey(game: game, algorithm: algorithm)
        if let cached = scoreCache[cacheKey],
           cached.drawCount == drawsSnapshot.count,
           cached.latestIssue == drawsSnapshot.last?.issue {
            numberScores = cached.values
            isScoring = false
            return
        }

        let requestID = UUID()
        scoreRefreshID = requestID
        isScoring = true

        Task {
            let scores = await Task.detached(priority: .utility) {
                LotteryPredictor().scoreTable(game: game, draws: drawsSnapshot, algorithm: algorithm)
            }.value

            guard scoreRefreshID == requestID, selectedGame == game, selectedAlgorithm == algorithm else {
                return
            }

            numberScores = scores
            scoreCache[cacheKey] = CachedScores(drawCount: drawsSnapshot.count, latestIssue: drawsSnapshot.last?.issue, values: scores)
            isScoring = false
        }
    }

    private func clearScoreCache(for game: LotteryGame) {
        scoreCache = scoreCache.filter { $0.key.game != game }
    }

    nonisolated private static func makeAlgorithmComparison(game: LotteryGame, play: PlayOption, predictions: [LotteryPrediction]) -> AlgorithmComparison {
        let tokenSets = Dictionary(uniqueKeysWithValues: predictions.map { ($0.algorithm, comparisonTokens(for: $0)) })
        let tokenCounts = tokenSets.values.reduce(into: [String: Int]()) { counts, tokens in
            for token in tokens {
                counts[token, default: 0] += 1
            }
        }
        let commonTokens = tokenCounts.filter { $0.value >= max(2, predictions.count - 1) }.count
        let totalDistinctTokens = tokenCounts.count
        let results = predictions.map { prediction in
            let tokens = tokenSets[prediction.algorithm, default: []]
            let shared = tokens.filter { tokenCounts[$0, default: 0] > 1 }.count
            let unique = tokens.filter { tokenCounts[$0, default: 0] == 1 }.count
            return AlgorithmComparisonResult(
                algorithm: prediction.algorithm,
                prediction: prediction,
                sharedTokenCount: shared,
                uniqueTokenCount: unique
            )
        }

        let mostShared = results.max {
            if $0.sharedTokenCount == $1.sharedTokenCount {
                return $0.uniqueTokenCount > $1.uniqueTokenCount
            }
            return $0.sharedTokenCount < $1.sharedTokenCount
        }?.algorithm.title ?? "-"
        let mostUnique = results.max {
            if $0.uniqueTokenCount == $1.uniqueTokenCount {
                return $0.sharedTokenCount > $1.sharedTokenCount
            }
            return $0.uniqueTokenCount < $1.uniqueTokenCount
        }?.algorithm.title ?? "-"

        let summary: String
        if commonTokens == totalDistinctTokens, totalDistinctTokens > 0 {
            summary = "各算法结果高度一致，当前历史特征给出的候选方向接近。"
        } else if predictions.count == 1 {
            summary = "当前只勾选了 1 个算法，结果区展示该算法候选；综合推荐与该算法一致。"
        } else if commonTokens > 0 {
            summary = "存在 \(commonTokens) 个高共识候选；\(mostShared) 与其它算法更接近，\(mostUnique) 给出的差异候选最多。"
        } else {
            summary = "当前没有高共识候选，各算法对历史特征的偏好分化明显。"
        }

        return AlgorithmComparison(
            game: game,
            play: play,
            generatedAt: Date(),
            results: results,
            commonTokens: commonTokens,
            totalDistinctTokens: totalDistinctTokens,
            summary: summary,
            reasons: comparisonReasons(for: game)
        )
    }

    nonisolated private static func makeConsensusPrediction(game: LotteryGame, play: PlayOption, predictions: [LotteryPrediction], scoreTables: [[NumberScore]]) -> ConsensusPrediction? {
        guard !predictions.isEmpty else { return nil }

        var components: [String: [Int]] = [:]
        for component in game.components {
            if component.ordered {
                let count = predictions.map { $0.components[component.key, default: []].count }.max() ?? component.defaultPickCount
                components[component.key] = (0..<count).compactMap { index in
                    rankedNumbersFromScores(
                        scoreTables: scoreTables,
                        componentKey: component.key,
                        position: index
                    ).first ?? rankedNumbersFromPredictions(
                        predictions: predictions,
                        componentKey: component.key,
                        position: index,
                        ordered: true
                    ).first
                }
            } else {
                let pickCount = play.componentPickCounts[component.key] ?? component.defaultPickCount
                let ranked = rankedNumbersFromScores(
                    scoreTables: scoreTables,
                    componentKey: component.key,
                    position: nil
                )
                let fallback = rankedNumbersFromPredictions(
                        predictions: predictions,
                        componentKey: component.key,
                        position: nil,
                        ordered: false
                    )
                components[component.key] = Array((ranked.isEmpty ? fallback : ranked).prefix(pickCount)).sorted()
            }
        }

        return ConsensusPrediction(
            game: game,
            play: play,
            algorithms: predictions.map(\.algorithm),
            components: components,
            generatedAt: Date()
        )
    }

    nonisolated private static func rankedNumbersFromScores(scoreTables: [[NumberScore]], componentKey: String, position: Int?) -> [Int] {
        struct Rank {
            var normalizedScore = 0.0
            var appearances = 0
        }

        var ranks: [Int: Rank] = [:]
        for table in scoreTables {
            let componentScores = table.filter { $0.componentKey == componentKey && $0.position == position }
            let normalized = zScored(componentScores.map(\.score))
            for (index, score) in componentScores.enumerated() {
                ranks[score.number, default: Rank()].normalizedScore += normalized[index]
                ranks[score.number, default: Rank()].appearances += 1
            }
        }

        return ranks.sorted { lhs, rhs in
            let lhsAverage = lhs.value.normalizedScore / Double(max(1, lhs.value.appearances))
            let rhsAverage = rhs.value.normalizedScore / Double(max(1, rhs.value.appearances))
            if lhsAverage != rhsAverage {
                return lhsAverage > rhsAverage
            }
            return lhs.key < rhs.key
        }
        .map(\.key)
    }

    nonisolated private static func rankedNumbersFromPredictions(predictions: [LotteryPrediction], componentKey: String, position: Int?, ordered: Bool) -> [Int] {
        struct Rank {
            var votes = 0
            var rankTotal = 0
        }

        var ranks: [Int: Rank] = [:]
        for prediction in predictions {
            let values = prediction.components[componentKey, default: []]
            if ordered, let position {
                guard values.indices.contains(position) else { continue }
                ranks[values[position], default: Rank()].votes += 1
                ranks[values[position], default: Rank()].rankTotal += position
            } else {
                for (index, number) in values.enumerated() {
                    ranks[number, default: Rank()].votes += 1
                    ranks[number, default: Rank()].rankTotal += index
                }
            }
        }

        return ranks.sorted { lhs, rhs in
            if lhs.value.votes != rhs.value.votes {
                return lhs.value.votes > rhs.value.votes
            }
            if lhs.value.rankTotal != rhs.value.rankTotal {
                return lhs.value.rankTotal < rhs.value.rankTotal
            }
            return lhs.key < rhs.key
        }
        .map(\.key)
    }

    nonisolated private static func zScored(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else {
            return []
        }
        let average = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - average, 2) }.reduce(0, +) / Double(values.count)
        let sd = sqrt(variance)
        guard sd > 0 else {
            return values.map { _ in 0 }
        }
        return values.map { ($0 - average) / sd }
    }

    nonisolated private static func comparisonTokens(for prediction: LotteryPrediction) -> Set<String> {
        var tokens = Set<String>()
        for component in prediction.game.components {
            let values = prediction.components[component.key, default: []]
            if component.ordered {
                for (index, number) in values.enumerated() {
                    tokens.insert("\(component.key)-\(index)-\(number)")
                }
            } else {
                for number in values {
                    tokens.insert("\(component.key)-\(number)")
                }
            }
        }
        return tokens
    }

    nonisolated private static func comparisonReasons(for game: LotteryGame) -> [String] {
        var reasons = [
            "综合统计会兼顾长期频率、近100期、近30期和遗漏，因此结果通常比较稳。",
            "热度趋势更偏向近期活跃号码，若近30期走势和长期频率不同，它会产生明显偏移。",
            "遗漏回补提高久未出现号码权重，所以常会和热度趋势形成对照。",
            "机器学习和神经网络会即时训练历史滚动样本，可能捕捉到非线性组合，但也更容易受随机波动影响。",
            "投注金额按每注 2 元估算；复式候选会按组合注数自动放大金额。"
        ]
        if game.predictionKind == .orderedDigits {
            reasons.append("数字位彩种按位置比较，差异来自百位/十位/个位等位置模型，而不是简单号码集合。")
        } else {
            reasons.append("分区型彩种按红蓝球、前后区等分区独立比较，某一区差异大不代表全部号码都分歧。")
        }
        return reasons
    }

    private func bundledDateText(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            return value
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct ScoreCacheKey: Hashable {
    let game: LotteryGame
    let algorithm: PredictionAlgorithm
}

private struct CachedScores {
    let drawCount: Int
    let latestIssue: String?
    let values: [NumberScore]
}
