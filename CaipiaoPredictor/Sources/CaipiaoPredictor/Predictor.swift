import Foundation

struct LotteryPredictor: Sendable {
    func predict(game: LotteryGame, draws: [LotteryDraw], play: PlayOption, algorithm: PredictionAlgorithm) -> LotteryPrediction {
        let scores = scoreTable(game: game, draws: draws, algorithm: algorithm)
        return predict(game: game, play: play, algorithm: algorithm, scores: scores)
    }

    func predict(game: LotteryGame, play: PlayOption, algorithm: PredictionAlgorithm, scores: [NumberScore]) -> LotteryPrediction {
        var components: [String: [Int]] = [:]

        switch game.predictionKind {
        case .unorderedBalls, .mixedBalls:
            components = predictIndependentComponents(game: game, play: play, scores: scores)
        case .orderedDigits:
            components["digits"] = algorithm == .lowPopularity ? predictLowPopularityDigits(game: game, play: play, scores: scores) : predictDigits(game: game, play: play, scores: scores)
        }

        return LotteryPrediction(
            game: game,
            play: play,
            algorithm: algorithm,
            components: components,
            generatedAt: Date(),
            note: algorithm.predictionNote(for: play)
        )
    }

    private func predictIndependentComponents(game: LotteryGame, play: PlayOption, scores: [NumberScore]) -> [String: [Int]] {
        game.components.reduce(into: [String: [Int]]()) { partial, component in
            let count = play.componentPickCounts[component.key] ?? component.defaultPickCount
            let componentScores = scores
                .filter { $0.componentKey == component.key && $0.position == nil }
            let ranked: [Int]
            if componentScores.first?.componentTitle.contains("冷门") == true {
                ranked = selectLowPopularityNumbers(component: component, count: count, scores: componentScores)
            } else {
                ranked = componentScores
                    .sorted { scoreSort($0, $1) }
                    .prefix(count)
                    .map(\.number)
            }
            partial[component.key] = component.ordered ? Array(ranked) : ranked.sorted()
        }
    }

    func scoreTable(game: LotteryGame, draws: [LotteryDraw], algorithm: PredictionAlgorithm) -> [NumberScore] {
        switch game.predictionKind {
        case .unorderedBalls, .mixedBalls:
            return game.components.flatMap { component in
                scoreComponent(component, draws: draws, algorithm: algorithm)
            }
        case .orderedDigits:
            guard let component = game.components.first else {
                return []
            }
            return (0..<component.drawCount).flatMap { position in
                scorePosition(component, position: position, draws: draws, algorithm: algorithm)
            }
        }
    }

    private func predictDigits(game: LotteryGame, play: PlayOption, scores: [NumberScore]) -> [Int] {
        guard let component = game.components.first else {
            return []
        }

        if play.key == "group6" {
            var used = Set<Int>()
            var result: [Int] = []
            for position in 0..<component.drawCount {
                let ranked = scores
                    .filter { $0.position == position }
                    .sorted { scoreSort($0, $1) }
                if let chosen = ranked.first(where: { !used.contains($0.number) }) {
                    result.append(chosen.number)
                    used.insert(chosen.number)
                }
            }
            return Array(result.prefix(3))
        }

        if play.key == "group3" {
            let allScores = combinedDigitScores(scores)
            let ranked = allScores.sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            let repeated = ranked.first?.key ?? 0
            let single = ranked.dropFirst().first?.key ?? ((repeated + 1) % 10)
            return [repeated, repeated, single]
        }

        return (0..<component.drawCount).compactMap { position in
            scores
                .filter { $0.position == position }
                .sorted { scoreSort($0, $1) }
                .first?
                .number
        }
    }

    private func scoreComponent(_ component: NumberComponent, draws: [LotteryDraw], algorithm: PredictionAlgorithm) -> [NumberScore] {
        if algorithm == .lowPopularity {
            let frequency = componentFrequency(component, draws: draws)
            let gaps = componentGaps(component, draws: draws)
            let drawCount = max(1, draws.count)
            return component.candidateUniverse.map { number in
                NumberScore(
                    componentKey: component.key,
                    componentTitle: "\(component.title)·冷门",
                    position: nil,
                    number: number,
                    frequency: frequency[number, default: 0],
                    rate: Double(frequency[number, default: 0]) / Double(drawCount),
                    currentGap: gaps[number, default: 0],
                    score: lowPopularityScore(number: number, in: component)
                )
            }
        }
        if algorithm == .machineLearning {
            return scoreMachineLearnedTarget(
                componentKey: component.key,
                componentTitle: component.title,
                position: nil,
                universe: component.candidateUniverse,
                draws: draws
            ) { draw in
                Set(draw.numbers(for: component.key))
            }
        }
        if algorithm == .neuralNetwork {
            return scoreNeuralNetworkTarget(
                componentKey: component.key,
                componentTitle: component.title,
                position: nil,
                universe: component.candidateUniverse,
                draws: draws
            ) { draw in
                Set(draw.numbers(for: component.key))
            }
        }

        guard !draws.isEmpty else {
            return component.candidateUniverse.map {
                NumberScore(componentKey: component.key, componentTitle: component.title, position: nil, number: $0, frequency: 0, rate: 0, currentGap: 0, score: 0)
            }
        }

        let allFrequency = componentFrequency(component, draws: draws)
        let recent100 = componentFrequency(component, draws: Array(draws.suffix(100)))
        let recent30 = componentFrequency(component, draws: Array(draws.suffix(30)))
        let gaps = componentGaps(component, draws: draws)

        let universe = component.candidateUniverse
        let metrics = metricsForRanking(universe: universe, allFrequency: allFrequency, recent100: recent100, recent30: recent30, gaps: gaps, drawCount: draws.count)

        return universe.enumerated().map { index, number in
            let score = statisticalScore(index: index, metrics: metrics, algorithm: algorithm)
            return NumberScore(
                componentKey: component.key,
                componentTitle: component.title,
                position: nil,
                number: number,
                frequency: allFrequency[number, default: 0],
                rate: Double(allFrequency[number, default: 0]) / Double(draws.count),
                currentGap: gaps[number, default: 0],
                score: score
            )
        }
    }

    private func scorePosition(_ component: NumberComponent, position: Int, draws: [LotteryDraw], algorithm: PredictionAlgorithm) -> [NumberScore] {
        if algorithm == .lowPopularity {
            let frequency = digitFrequency(component, position: position, draws: draws)
            let gaps = digitGaps(component, position: position, draws: draws)
            let drawCount = max(1, draws.count)
            return component.candidateUniverse.map { number in
                NumberScore(
                    componentKey: component.key,
                    componentTitle: "\(component.title)第 \(position + 1) 位·冷门",
                    position: position,
                    number: number,
                    frequency: frequency[number, default: 0],
                    rate: Double(frequency[number, default: 0]) / Double(drawCount),
                    currentGap: gaps[number, default: 0],
                    score: lowPopularityDigitScore(number: number, position: position, totalPositions: component.drawCount)
                )
            }
        }
        if algorithm == .machineLearning {
            return scoreMachineLearnedTarget(
                componentKey: component.key,
                componentTitle: "\(component.title)第 \(position + 1) 位",
                position: position,
                universe: component.candidateUniverse,
                draws: draws
            ) { draw in
                let values = draw.numbers(for: component.key)
                guard values.indices.contains(position) else {
                    return []
                }
                return [values[position]]
            }
        }
        if algorithm == .neuralNetwork {
            return scoreNeuralNetworkTarget(
                componentKey: component.key,
                componentTitle: "\(component.title)第 \(position + 1) 位",
                position: position,
                universe: component.candidateUniverse,
                draws: draws
            ) { draw in
                let values = draw.numbers(for: component.key)
                guard values.indices.contains(position) else {
                    return []
                }
                return [values[position]]
            }
        }

        guard !draws.isEmpty else {
            return component.candidateUniverse.map {
                NumberScore(componentKey: component.key, componentTitle: component.title, position: position, number: $0, frequency: 0, rate: 0, currentGap: 0, score: 0)
            }
        }

        let allFrequency = digitFrequency(component, position: position, draws: draws)
        let recent100 = digitFrequency(component, position: position, draws: Array(draws.suffix(100)))
        let recent30 = digitFrequency(component, position: position, draws: Array(draws.suffix(30)))
        let gaps = digitGaps(component, position: position, draws: draws)
        let universe = component.candidateUniverse

        let metrics = metricsForRanking(universe: universe, allFrequency: allFrequency, recent100: recent100, recent30: recent30, gaps: gaps, drawCount: draws.count)

        return universe.enumerated().map { index, number in
            let score = statisticalScore(index: index, metrics: metrics, algorithm: algorithm)
            return NumberScore(
                componentKey: component.key,
                componentTitle: "\(component.title)第 \(position + 1) 位",
                position: position,
                number: number,
                frequency: allFrequency[number, default: 0],
                rate: Double(allFrequency[number, default: 0]) / Double(draws.count),
                currentGap: gaps[number, default: 0],
                score: score
            )
        }
    }

    private func metricsForRanking(
        universe: [Int],
        allFrequency: [Int: Int],
        recent100: [Int: Int],
        recent30: [Int: Int],
        gaps: [Int: Int],
        drawCount: Int
    ) -> RankingMetrics {
        let allRates = universe.map { Double(allFrequency[$0, default: 0]) / Double(max(1, drawCount)) }
        let recent100Rates = universe.map { Double(recent100[$0, default: 0]) / Double(max(1, min(100, drawCount))) }
        let recent30Rates = universe.map { Double(recent30[$0, default: 0]) / Double(max(1, min(30, drawCount))) }
        let gapValues = universe.map { Double(gaps[$0, default: 0]) }
        let freshValues = gapValues.map { -$0 }
        let momentum = zip(recent30Rates, allRates).map { $0 - $1 }

        return RankingMetrics(
            allZ: zScores(allRates),
            recent100Z: zScores(recent100Rates),
            recent30Z: zScores(recent30Rates),
            gapZ: zScores(gapValues),
            freshZ: zScores(freshValues),
            momentumZ: zScores(momentum)
        )
    }

    private func statisticalScore(index: Int, metrics: RankingMetrics, algorithm: PredictionAlgorithm) -> Double {
        switch algorithm {
        case .balancedStats:
            return 0.35 * metrics.allZ[index] + 0.25 * metrics.recent100Z[index] + 0.20 * metrics.recent30Z[index] + 0.20 * metrics.gapZ[index]
        case .hotTrend:
            return 0.15 * metrics.allZ[index] + 0.30 * metrics.recent100Z[index] + 0.40 * metrics.recent30Z[index] + 0.10 * metrics.freshZ[index] + 0.05 * metrics.momentumZ[index]
        case .coldGap:
            return 0.25 * metrics.allZ[index] + 0.20 * metrics.recent100Z[index] + 0.10 * metrics.recent30Z[index] + 0.45 * metrics.gapZ[index]
        case .machineLearning:
            return 0
        case .neuralNetwork:
            return 0
        case .lowPopularity:
            return 0
        }
    }

    private func selectLowPopularityNumbers(component: NumberComponent, count: Int, scores: [NumberScore]) -> [Int] {
        let ranked = scores.sorted { scoreSort($0, $1) }
        var selected: [Int] = []
        var candidates = ranked

        while selected.count < count, !candidates.isEmpty {
            let best = candidates.max { lhs, rhs in
                adjustedLowPopularityScore(score: lhs, selected: selected, component: component) < adjustedLowPopularityScore(score: rhs, selected: selected, component: component)
            }
            guard let best else { break }
            selected.append(best.number)
            candidates.removeAll { $0.number == best.number }
        }

        return selected
    }

    private func adjustedLowPopularityScore(score: NumberScore, selected: [Int], component: NumberComponent) -> Double {
        var value = score.score
        for chosen in selected {
            let distance = abs(score.number - chosen)
            if distance == 0 {
                value -= 10
            } else if distance == 1 {
                value -= 2.4
            } else if distance == 2 {
                value -= 1.0
            }
            if score.number % 10 == chosen % 10 {
                value -= 1.4
            }
        }

        if selected.count >= 2 {
            let all = (selected + [score.number]).sorted()
            let gaps = zip(all.dropFirst(), all).map(-)
            if Set(gaps).count <= 2 {
                value -= 1.2
            }
        }

        if component.range.upperBound > 31, score.number <= 31 {
            value -= 1.1
        }

        return value
    }

    private func lowPopularityScore(number: Int, in component: NumberComponent) -> Double {
        let lower = component.range.lowerBound
        let upper = component.range.upperBound
        let span = max(1, upper - lower)
        let normalized = Double(number - lower) / Double(span)
        var score = normalized * 1.8

        if upper > 31, number > 31 {
            score += 3.0
        } else if upper > 31, number <= 31 {
            score -= 1.2
        }

        if [6, 8, 9, 16, 18, 28, 30, 33, 66, 68, 69, 80].contains(number) {
            score -= 1.4
        }
        if number % 10 == 0 || number % 10 == 5 || number % 10 == 8 {
            score -= 0.8
        }
        if number == lower || number == upper {
            score -= 0.4
        }
        if isRepeatedDigit(number) {
            score -= 0.7
        }

        score += deterministicNoise(number: number, salt: component.key) * 0.65
        return score
    }

    private func predictLowPopularityDigits(game: LotteryGame, play: PlayOption, scores: [NumberScore]) -> [Int] {
        guard let component = game.components.first else {
            return []
        }

        let rankedDigits = combinedDigitScores(scores).sorted {
            if $0.value == $1.value {
                return $0.key < $1.key
            }
            return $0.value > $1.value
        }.map(\.key)

        if play.key == "group3" {
            let repeated = rankedDigits.first ?? 4
            let single = rankedDigits.first { $0 != repeated } ?? 7
            return [repeated, repeated, single]
        }

        if play.key == "group6" {
            return Array(rankedDigits.prefix(3))
        }

        var result: [Int] = []
        for position in 0..<component.drawCount {
            let positionScores = scores
                .filter { $0.position == position }
                .sorted { scoreSort($0, $1) }

            let chosen = positionScores.first { score in
                !wouldCreatePopularDigitPattern(candidate: score.number, at: position, result: result, total: component.drawCount)
            }?.number ?? positionScores.first?.number ?? ((position * 3 + 4) % 10)
            result.append(chosen)
        }
        return result
    }

    private func lowPopularityDigitScore(number: Int, position: Int, totalPositions: Int) -> Double {
        var score = 0.0
        if [4, 7, 2].contains(number) {
            score += 1.4
        }
        if [6, 8, 9].contains(number) {
            score -= 1.5
        }
        if number == 0 || number == 5 {
            score -= 0.5
        }
        if position == 0, number == 0 {
            score -= 1.6
        }
        if position == totalPositions - 1, [6, 8, 9, 0].contains(number) {
            score -= 0.9
        }
        score += deterministicNoise(number: number + position * 17, salt: "digits") * 0.75
        return score
    }

    private func wouldCreatePopularDigitPattern(candidate: Int, at position: Int, result: [Int], total: Int) -> Bool {
        let values = result + [candidate]
        if result.contains(candidate) {
            return true
        }
        if values.count >= 2, values.suffix(2).allSatisfy({ $0 == candidate }) {
            return true
        }
        if values.count >= 3 {
            let suffix = Array(values.suffix(3))
            if suffix[1] - suffix[0] == suffix[2] - suffix[1] {
                return true
            }
        }
        if position == total - 1, values == values.reversed() {
            return true
        }
        return false
    }

    private func deterministicNoise(number: Int, salt: String) -> Double {
        let saltValue = salt.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let value = sin(Double(number * 97 + saltValue * 31) * 12.9898) * 43758.5453
        return value - floor(value) - 0.5
    }

    private func isRepeatedDigit(_ number: Int) -> Bool {
        let text = String(number)
        guard let first = text.first, text.count > 1 else {
            return false
        }
        return text.allSatisfy { $0 == first }
    }

    private func scoreMachineLearnedTarget(
        componentKey: String,
        componentTitle: String,
        position: Int?,
        universe: [Int],
        draws: [LotteryDraw],
        targetValues: (LotteryDraw) -> Set<Int>
    ) -> [NumberScore] {
        guard !draws.isEmpty else {
            return universe.map {
                NumberScore(componentKey: componentKey, componentTitle: componentTitle, position: position, number: $0, frequency: 0, rate: 0, currentGap: 0, score: 0)
            }
        }

        let minimumHistory = min(40, max(8, draws.count / 8))
        let positiveCount = max(1, targetValues(draws.last!).count)
        let positiveWeight = max(1, min(12, Double(max(1, universe.count - positiveCount)) / Double(positiveCount)))
        var weights = Array(repeating: 0.0, count: MachineLearningState.featureCount)
        let learningRate = 0.045
        let l2 = 0.0002

        for _ in 0..<3 {
            var state = MachineLearningState(universe: universe)
            for draw in draws {
                let targets = targetValues(draw)
                if state.totalSeen >= minimumHistory {
                    for number in universe {
                        let features = state.features(for: number)
                        let expected = targets.contains(number) ? 1.0 : 0.0
                        let predicted = sigmoid(dot(weights, features))
                        let sampleWeight = expected > 0 ? positiveWeight : 1.0
                        let error = (predicted - expected) * sampleWeight
                        for index in weights.indices {
                            weights[index] -= learningRate * (error * features[index] + l2 * weights[index])
                        }
                    }
                }
                state.observe(targets)
            }
        }

        var finalState = MachineLearningState(universe: universe)
        for draw in draws {
            finalState.observe(targetValues(draw))
        }

        return universe.map { number in
            let score = sigmoid(dot(weights, finalState.features(for: number)))
            return NumberScore(
                componentKey: componentKey,
                componentTitle: componentTitle,
                position: position,
                number: number,
                frequency: finalState.allCounts[number, default: 0],
                rate: Double(finalState.allCounts[number, default: 0]) / Double(max(1, draws.count)),
                currentGap: finalState.gaps[number, default: 0],
                score: score
            )
        }
    }

    private func scoreNeuralNetworkTarget(
        componentKey: String,
        componentTitle: String,
        position: Int?,
        universe: [Int],
        draws: [LotteryDraw],
        targetValues: (LotteryDraw) -> Set<Int>
    ) -> [NumberScore] {
        guard !draws.isEmpty else {
            return universe.map {
                NumberScore(componentKey: componentKey, componentTitle: componentTitle, position: position, number: $0, frequency: 0, rate: 0, currentGap: 0, score: 0)
            }
        }

        let minimumHistory = min(50, max(10, draws.count / 8))
        let positiveCount = max(1, targetValues(draws.last!).count)
        let positiveWeight = max(1, min(12, Double(max(1, universe.count - positiveCount)) / Double(positiveCount)))
        var network = TinyNeuralNetwork(inputCount: MachineLearningState.featureCount, hiddenCount: 8)
        let learningRate = 0.032
        let l2 = 0.00015

        for _ in 0..<4 {
            var state = MachineLearningState(universe: universe)
            for draw in draws {
                let targets = targetValues(draw)
                if state.totalSeen >= minimumHistory {
                    for number in universe {
                        let features = state.features(for: number)
                        let expected = targets.contains(number) ? 1.0 : 0.0
                        let sampleWeight = expected > 0 ? positiveWeight : 1.0
                        network.train(features: features, expected: expected, sampleWeight: sampleWeight, learningRate: learningRate, l2: l2)
                    }
                }
                state.observe(targets)
            }
        }

        var finalState = MachineLearningState(universe: universe)
        for draw in draws {
            finalState.observe(targetValues(draw))
        }

        return universe.map { number in
            let score = network.predict(features: finalState.features(for: number))
            return NumberScore(
                componentKey: componentKey,
                componentTitle: componentTitle,
                position: position,
                number: number,
                frequency: finalState.allCounts[number, default: 0],
                rate: Double(finalState.allCounts[number, default: 0]) / Double(max(1, draws.count)),
                currentGap: finalState.gaps[number, default: 0],
                score: score
            )
        }
    }

    private func componentFrequency(_ component: NumberComponent, draws: [LotteryDraw]) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for draw in draws {
            let values = draw.numbers(for: component.key)
            for number in component.allowsRepeats ? values : Array(Set(values)) {
                counts[number, default: 0] += 1
            }
        }
        return counts
    }

    private func digitFrequency(_ component: NumberComponent, position: Int, draws: [LotteryDraw]) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for draw in draws {
            let values = draw.numbers(for: component.key)
            guard values.indices.contains(position) else {
                continue
            }
            counts[values[position], default: 0] += 1
        }
        return counts
    }

    private func componentGaps(_ component: NumberComponent, draws: [LotteryDraw]) -> [Int: Int] {
        var gaps: [Int: Int] = [:]
        for number in component.candidateUniverse {
            var gap = 0
            for draw in draws.reversed() {
                if draw.numbers(for: component.key).contains(number) {
                    break
                }
                gap += 1
            }
            gaps[number] = gap
        }
        return gaps
    }

    private func digitGaps(_ component: NumberComponent, position: Int, draws: [LotteryDraw]) -> [Int: Int] {
        var gaps: [Int: Int] = [:]
        for number in component.candidateUniverse {
            var gap = 0
            for draw in draws.reversed() {
                let values = draw.numbers(for: component.key)
                if values.indices.contains(position), values[position] == number {
                    break
                }
                gap += 1
            }
            gaps[number] = gap
        }
        return gaps
    }

    private func combinedDigitScores(_ scores: [NumberScore]) -> [Int: Double] {
        var totals: [Int: Double] = [:]
        var counts: [Int: Int] = [:]
        for score in scores {
            totals[score.number, default: 0] += score.score
            counts[score.number, default: 0] += 1
        }
        return totals.mapValues { value in
            value
        }
        .mapValues { value in value }
        .reduce(into: [Int: Double]()) { partial, pair in
            let count = max(1, counts[pair.key, default: 1])
            partial[pair.key] = pair.value / Double(count)
        }
    }

    private func zScores(_ values: [Double]) -> [Double] {
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

    private func scoreSort(_ lhs: NumberScore, _ rhs: NumberScore) -> Bool {
        if lhs.score == rhs.score {
            return lhs.number < rhs.number
        }
        return lhs.score > rhs.score
    }

    private func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
        zip(lhs, rhs).map(*).reduce(0, +)
    }

    private func sigmoid(_ value: Double) -> Double {
        if value < -40 {
            return 0
        }
        if value > 40 {
            return 1
        }
        return 1 / (1 + exp(-value))
    }
}

private struct RankingMetrics {
    let allZ: [Double]
    let recent100Z: [Double]
    let recent30Z: [Double]
    let gapZ: [Double]
    let freshZ: [Double]
    let momentumZ: [Double]
}

private struct MachineLearningState {
    static let featureCount = 6

    let universe: [Int]
    var totalSeen = 0
    var allCounts: [Int: Int]
    var recent30Counts: [Int: Int]
    var recent100Counts: [Int: Int]
    var gaps: [Int: Int]
    var recent30Queue: [Set<Int>] = []
    var recent100Queue: [Set<Int>] = []

    init(universe: [Int]) {
        self.universe = universe
        self.allCounts = Dictionary(uniqueKeysWithValues: universe.map { ($0, 0) })
        self.recent30Counts = Dictionary(uniqueKeysWithValues: universe.map { ($0, 0) })
        self.recent100Counts = Dictionary(uniqueKeysWithValues: universe.map { ($0, 0) })
        self.gaps = Dictionary(uniqueKeysWithValues: universe.map { ($0, 0) })
    }

    func features(for number: Int) -> [Double] {
        let allRate = Double(allCounts[number, default: 0]) / Double(max(1, totalSeen))
        let recent30Rate = Double(recent30Counts[number, default: 0]) / Double(max(1, min(30, totalSeen)))
        let recent100Rate = Double(recent100Counts[number, default: 0]) / Double(max(1, min(100, totalSeen)))
        let gapRate = Double(gaps[number, default: 0]) / Double(max(1, min(200, max(1, totalSeen))))
        let momentum = recent30Rate - allRate
        return [1, allRate, recent100Rate, recent30Rate, gapRate, momentum]
    }

    mutating func observe(_ targets: Set<Int>) {
        totalSeen += 1

        for number in universe {
            if targets.contains(number) {
                allCounts[number, default: 0] += 1
                gaps[number] = 0
            } else {
                gaps[number, default: 0] += 1
            }
        }

        MachineLearningState.append(targets, to: &recent30Queue, counts: &recent30Counts, limit: 30)
        MachineLearningState.append(targets, to: &recent100Queue, counts: &recent100Counts, limit: 100)
    }

    private static func append(_ targets: Set<Int>, to queue: inout [Set<Int>], counts: inout [Int: Int], limit: Int) {
        queue.append(targets)
        for number in targets {
            counts[number, default: 0] += 1
        }

        if queue.count > limit {
            let removed = queue.removeFirst()
            for number in removed {
                counts[number, default: 0] -= 1
            }
        }
    }
}

private struct TinyNeuralNetwork {
    var inputCount: Int
    var hiddenCount: Int
    var inputWeights: [[Double]]
    var hiddenBiases: [Double]
    var outputWeights: [Double]
    var outputBias: Double

    init(inputCount: Int, hiddenCount: Int) {
        self.inputCount = inputCount
        self.hiddenCount = hiddenCount
        self.inputWeights = (0..<hiddenCount).map { hidden in
            (0..<inputCount).map { input in
                TinyNeuralNetwork.initialWeight(seed: hidden * 31 + input * 17 + 7)
            }
        }
        self.hiddenBiases = (0..<hiddenCount).map {
            TinyNeuralNetwork.initialWeight(seed: $0 * 19 + 11) * 0.35
        }
        self.outputWeights = (0..<hiddenCount).map {
            TinyNeuralNetwork.initialWeight(seed: $0 * 23 + 13)
        }
        self.outputBias = -0.35
    }

    func predict(features: [Double]) -> Double {
        let hidden = hiddenActivations(features: features)
        return sigmoid(dot(outputWeights, hidden) + outputBias)
    }

    mutating func train(features: [Double], expected: Double, sampleWeight: Double, learningRate: Double, l2: Double) {
        let hidden = hiddenActivations(features: features)
        let predicted = sigmoid(dot(outputWeights, hidden) + outputBias)
        let outputDelta = (predicted - expected) * sampleWeight
        let previousOutputWeights = outputWeights

        for index in 0..<hiddenCount {
            outputWeights[index] -= learningRate * (outputDelta * hidden[index] + l2 * outputWeights[index])
        }
        outputBias -= learningRate * outputDelta

        for hiddenIndex in 0..<hiddenCount {
            let hiddenDelta = outputDelta * previousOutputWeights[hiddenIndex] * (1 - hidden[hiddenIndex] * hidden[hiddenIndex])
            for inputIndex in 0..<inputCount {
                inputWeights[hiddenIndex][inputIndex] -= learningRate * (hiddenDelta * features[inputIndex] + l2 * inputWeights[hiddenIndex][inputIndex])
            }
            hiddenBiases[hiddenIndex] -= learningRate * hiddenDelta
        }
    }

    private func hiddenActivations(features: [Double]) -> [Double] {
        (0..<hiddenCount).map { hiddenIndex in
            tanh(dot(inputWeights[hiddenIndex], features) + hiddenBiases[hiddenIndex])
        }
    }

    private func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
        zip(lhs, rhs).map(*).reduce(0, +)
    }

    private func sigmoid(_ value: Double) -> Double {
        if value < -40 {
            return 0
        }
        if value > 40 {
            return 1
        }
        return 1 / (1 + exp(-value))
    }

    private static func initialWeight(seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898) * 43758.5453
        return (value - floor(value) - 0.5) * 0.28
    }
}
