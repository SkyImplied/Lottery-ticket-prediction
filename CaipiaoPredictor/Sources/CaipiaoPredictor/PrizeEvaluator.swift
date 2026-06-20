import Foundation

struct PrizeInputSpec: Identifiable, Sendable {
    var id: String { component.key }

    let component: NumberComponent
    let requiredCount: Int
    let placeholder: String
    let helper: String
}

struct PrizeRule: Identifiable, Sendable {
    var id: String { "\(title)-\(condition)" }

    let title: String
    let condition: String
    let prize: String
}

struct PrizeBreakdown: Identifiable, Sendable {
    var id: String { "\(prizeName)-\(prizeText)" }

    let prizeName: String
    let count: Int
    let prizeText: String
}

struct PrizeCheckResult: Sendable {
    let issue: String
    let draw: LotteryDraw
    let checkedBetCount: Int
    let bestPrizeName: String
    let totalFixedPrize: Double
    let hasFloatingPrize: Bool
    let matchSummary: String
    let breakdown: [PrizeBreakdown]

    var amountSummary: String {
        var parts: [String] = []
        if totalFixedPrize > 0 {
            parts.append(Self.money(totalFixedPrize))
        }
        if hasFloatingPrize {
            parts.append("含浮动奖，按当期开奖公告为准")
        }
        return parts.isEmpty ? "0 元" : parts.joined(separator: " + ")
    }

    private static func money(_ value: Double) -> String {
        if value.rounded(.down) == value {
            return "\(Int(value)) 元"
        }
        return String(format: "%.1f 元", value)
    }
}

enum PrizeInputError: LocalizedError, Sendable {
    case empty(componentTitle: String)
    case invalidToken(componentTitle: String, token: String)
    case outOfRange(componentTitle: String, number: Int, range: ClosedRange<Int>)
    case duplicate(componentTitle: String)
    case invalidCount(componentTitle: String, expected: Int, actual: Int)
    case missingDraw(issue: String)

    var errorDescription: String? {
        switch self {
        case .empty(let title):
            return "请输入\(title)号码。"
        case .invalidToken(let title, let token):
            return "\(title)包含无效号码：\(token)。"
        case .outOfRange(let title, let number, let range):
            return "\(title)号码 \(number) 超出范围（\(range.lowerBound)-\(range.upperBound)）。"
        case .duplicate(let title):
            return "\(title)不能重复。"
        case .invalidCount(let title, let expected, let actual):
            return "\(title)需要输入 \(expected) 个号码，当前为 \(actual) 个。"
        case .missingDraw(let issue):
            return "未找到第 \(issue) 期开奖数据。"
        }
    }
}

enum PrizeEvaluator {
    static func inputSpecs(game: LotteryGame, play: PlayOption) -> [PrizeInputSpec] {
        game.components.compactMap { component in
            if game == .qlc && component.key == "back" {
                return nil
            }
            let required = play.componentPickCounts[component.key] ?? component.drawCount
            return PrizeInputSpec(
                component: component,
                requiredCount: required,
                placeholder: placeholder(for: component, count: required),
                helper: helper(for: component, count: required)
            )
        }
    }

    static func rules(game: LotteryGame, play: PlayOption) -> [PrizeRule] {
        switch game {
        case .kl8:
            return kl8Rules(pickCount: kl8PickCount(play: play))
        case .ssq:
            return [
                PrizeRule(title: "一等奖", condition: "6 红 + 1 蓝", prize: "浮动奖"),
                PrizeRule(title: "二等奖", condition: "6 红", prize: "浮动奖"),
                PrizeRule(title: "三等奖", condition: "5 红 + 1 蓝", prize: "3000 元"),
                PrizeRule(title: "四等奖", condition: "5 红，或 4 红 + 1 蓝", prize: "200 元"),
                PrizeRule(title: "五等奖", condition: "4 红，或 3 红 + 1 蓝", prize: "10 元"),
                PrizeRule(title: "六等奖", condition: "中蓝球", prize: "5 元")
            ]
        case .fc3d, .pl3:
            return [
                PrizeRule(title: "直选", condition: "3 位全部命中且顺序一致", prize: "1040 元"),
                PrizeRule(title: "组三", condition: "开奖号码为两同一不同，号码相同不看顺序", prize: "346 元"),
                PrizeRule(title: "组六", condition: "开奖号码三位各不同，号码相同不看顺序", prize: "173 元")
            ]
        case .qlc:
            return [
                PrizeRule(title: "一等奖", condition: "中 7 个基本号", prize: "浮动奖"),
                PrizeRule(title: "二等奖", condition: "中 6 个基本号 + 特别号", prize: "浮动奖"),
                PrizeRule(title: "三等奖", condition: "中 6 个基本号", prize: "浮动奖"),
                PrizeRule(title: "四等奖", condition: "中 5 个基本号 + 特别号", prize: "200 元"),
                PrizeRule(title: "五等奖", condition: "中 5 个基本号", prize: "50 元"),
                PrizeRule(title: "六等奖", condition: "中 4 个基本号 + 特别号", prize: "10 元"),
                PrizeRule(title: "七等奖", condition: "中 4 个基本号", prize: "5 元")
            ]
        case .dlt:
            return [
                PrizeRule(title: "一等奖", condition: "5 前区 + 2 后区", prize: "浮动奖"),
                PrizeRule(title: "二等奖", condition: "5 前区 + 1 后区", prize: "浮动奖"),
                PrizeRule(title: "三等奖", condition: "5 前区", prize: "10000 元"),
                PrizeRule(title: "四等奖", condition: "4 前区 + 2 后区", prize: "3000 元"),
                PrizeRule(title: "五等奖", condition: "4 前区 + 1 后区", prize: "300 元"),
                PrizeRule(title: "六等奖", condition: "3 前区 + 2 后区", prize: "200 元"),
                PrizeRule(title: "七等奖", condition: "4 前区", prize: "100 元"),
                PrizeRule(title: "八等奖", condition: "3 前区 + 1 后区，或 2 前区 + 2 后区", prize: "15 元"),
                PrizeRule(title: "九等奖", condition: "3 前区，或 1 前区 + 2 后区，或 2 前区 + 1 后区，或 2 后区", prize: "5 元")
            ]
        case .pl5:
            return [
                PrizeRule(title: "一等奖", condition: "5 位全部命中且顺序一致", prize: "100000 元")
            ]
        case .qxc:
            return [
                PrizeRule(title: "一等奖", condition: "7 位全部命中且顺序一致", prize: "浮动奖"),
                PrizeRule(title: "二等奖", condition: "前 6 位命中", prize: "浮动奖"),
                PrizeRule(title: "三等奖", condition: "前 6 位任 5 位 + 第 7 位命中", prize: "3000 元"),
                PrizeRule(title: "四等奖", condition: "任 5 位命中", prize: "500 元"),
                PrizeRule(title: "五等奖", condition: "任 4 位命中", prize: "30 元"),
                PrizeRule(title: "六等奖", condition: "任 3 位命中，或第 7 位命中", prize: "5 元")
            ]
        }
    }

    static func parseNumbers(_ rawValue: String, spec: PrizeInputSpec) throws -> [Int] {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            throw PrizeInputError.empty(componentTitle: spec.component.title)
        }

        let tokens: [String]
        if spec.component.ordered,
           raw.allSatisfy(\.isNumber),
           raw.count == spec.requiredCount {
            tokens = raw.map(String.init)
        } else {
            tokens = raw
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .filter { !$0.isEmpty }
        }

        let numbers = try tokens.map { token in
            guard let number = Int(token) else {
                throw PrizeInputError.invalidToken(componentTitle: spec.component.title, token: token)
            }
            guard spec.component.range.contains(number) else {
                throw PrizeInputError.outOfRange(componentTitle: spec.component.title, number: number, range: spec.component.range)
            }
            return number
        }

        guard numbers.count == spec.requiredCount else {
            throw PrizeInputError.invalidCount(componentTitle: spec.component.title, expected: spec.requiredCount, actual: numbers.count)
        }
        if !spec.component.allowsRepeats && Set(numbers).count != numbers.count {
            throw PrizeInputError.duplicate(componentTitle: spec.component.title)
        }
        return spec.component.ordered ? numbers : numbers.sorted()
    }

    static func evaluate(game: LotteryGame, play: PlayOption, draw: LotteryDraw, numbers: [String: [Int]]) -> PrizeCheckResult {
        switch game {
        case .kl8:
            return evaluateKL8(play: play, draw: draw, numbers: numbers)
        case .ssq:
            return evaluateTwoZone(
                game: game,
                draw: draw,
                front: numbers["front", default: []],
                back: numbers["back", default: []],
                frontCount: 6,
                backCount: 1,
                scorer: ssqPrize(red:blue:)
            )
        case .dlt:
            return evaluateTwoZone(
                game: game,
                draw: draw,
                front: numbers["front", default: []],
                back: numbers["back", default: []],
                frontCount: 5,
                backCount: 2,
                scorer: dltPrize(front:back:)
            )
        case .qlc:
            return evaluateQLC(draw: draw, numbers: numbers["front", default: []])
        case .fc3d, .pl3:
            return evaluateThreeDigits(game: game, play: play, draw: draw, numbers: numbers["digits", default: []])
        case .pl5:
            return evaluatePL5(draw: draw, numbers: numbers["digits", default: []])
        case .qxc:
            return evaluateQXC(draw: draw, numbers: numbers["digits", default: []])
        }
    }

    private static func evaluateKL8(play: PlayOption, draw: LotteryDraw, numbers: [String: [Int]]) -> PrizeCheckResult {
        let selected = numbers["main", default: []]
        let drawn = Set(draw.numbers(for: "main"))
        let matchCount = selected.filter { drawn.contains($0) }.count
        let prize = kl8Prize(pickCount: kl8PickCount(play: play), matchCount: matchCount)
        return singleResult(draw: draw, checkedBetCount: 1, matchSummary: "命中 \(matchCount) 个号码", prize: prize)
    }

    private static func evaluateTwoZone(
        game: LotteryGame,
        draw: LotteryDraw,
        front: [Int],
        back: [Int],
        frontCount: Int,
        backCount: Int,
        scorer: (Int, Int) -> PrizeAward?
    ) -> PrizeCheckResult {
        let drawnFront = Set(draw.numbers(for: "front"))
        let drawnBack = Set(draw.numbers(for: "back"))
        let bets = combinations(front, choose: frontCount).flatMap { frontBet in
            combinations(back, choose: backCount).map { (frontBet, $0) }
        }
        let prizes = bets.compactMap { frontBet, backBet in
            scorer(frontBet.filter { drawnFront.contains($0) }.count, backBet.filter { drawnBack.contains($0) }.count)
        }
        let directFrontHits = front.filter { drawnFront.contains($0) }.count
        let directBackHits = back.filter { drawnBack.contains($0) }.count
        let frontTitle = game == .dlt ? "前区" : "红球"
        let backTitle = game == .dlt ? "后区" : "蓝球"
        return aggregateResult(
            draw: draw,
            checkedBetCount: bets.count,
            matchSummary: "\(frontTitle)命中 \(directFrontHits) 个，\(backTitle)命中 \(directBackHits) 个",
            prizes: prizes
        )
    }

    private static func evaluateQLC(draw: LotteryDraw, numbers: [Int]) -> PrizeCheckResult {
        let basic = Set(draw.numbers(for: "front"))
        let special = draw.numbers(for: "back").first
        let bets = combinations(numbers, choose: 7)
        let prizes = bets.compactMap { bet -> PrizeAward? in
            let basicHits = bet.filter { basic.contains($0) }.count
            let specialHit = special.map { bet.contains($0) } ?? false
            return qlcPrize(basic: basicHits, special: specialHit)
        }
        let directBasicHits = numbers.filter { basic.contains($0) }.count
        let directSpecialHit = special.map { numbers.contains($0) } ?? false
        return aggregateResult(
            draw: draw,
            checkedBetCount: bets.count,
            matchSummary: "基本号命中 \(directBasicHits) 个，特别号\(directSpecialHit ? "命中" : "未中")",
            prizes: prizes
        )
    }

    private static func evaluateThreeDigits(game: LotteryGame, play: PlayOption, draw: LotteryDraw, numbers: [Int]) -> PrizeCheckResult {
        let drawn = draw.numbers(for: "digits")
        let prize: PrizeAward?
        switch play.key {
        case "group3":
            prize = hasSameMultiset(numbers, drawn) && hasGroup3Shape(drawn) ? PrizeAward(name: "组三", fixedAmount: 346) : nil
        case "group6":
            prize = hasSameMultiset(numbers, drawn) && Set(drawn).count == 3 ? PrizeAward(name: "组六", fixedAmount: 173) : nil
        default:
            prize = numbers == drawn ? PrizeAward(name: "直选", fixedAmount: 1040) : nil
        }
        let hits = zip(numbers, drawn).filter(==).count
        return singleResult(draw: draw, checkedBetCount: 1, matchSummary: "按位命中 \(hits) 位", prize: prize)
    }

    private static func evaluatePL5(draw: LotteryDraw, numbers: [Int]) -> PrizeCheckResult {
        let drawn = draw.numbers(for: "digits")
        let prize = numbers == drawn ? PrizeAward(name: "一等奖", fixedAmount: 100_000) : nil
        let hits = zip(numbers, drawn).filter(==).count
        return singleResult(draw: draw, checkedBetCount: 1, matchSummary: "按位命中 \(hits) 位", prize: prize)
    }

    private static func evaluateQXC(draw: LotteryDraw, numbers: [Int]) -> PrizeCheckResult {
        let drawn = draw.numbers(for: "digits")
        let matches = Array(zip(numbers, drawn)).map(==)
        let totalHits = matches.filter { $0 }.count
        let firstSixHits = matches.prefix(6).filter { $0 }.count
        let finalHit = matches.indices.contains(6) ? matches[6] : false
        let prize: PrizeAward?
        if totalHits == 7 {
            prize = PrizeAward(name: "一等奖", isFloating: true)
        } else if firstSixHits == 6 {
            prize = PrizeAward(name: "二等奖", isFloating: true)
        } else if firstSixHits == 5 && finalHit {
            prize = PrizeAward(name: "三等奖", fixedAmount: 3000)
        } else if totalHits == 5 {
            prize = PrizeAward(name: "四等奖", fixedAmount: 500)
        } else if totalHits == 4 {
            prize = PrizeAward(name: "五等奖", fixedAmount: 30)
        } else if totalHits == 3 || finalHit {
            prize = PrizeAward(name: "六等奖", fixedAmount: 5)
        } else {
            prize = nil
        }
        return singleResult(draw: draw, checkedBetCount: 1, matchSummary: "按位命中 \(totalHits) 位", prize: prize)
    }

    private static func singleResult(draw: LotteryDraw, checkedBetCount: Int, matchSummary: String, prize: PrizeAward?) -> PrizeCheckResult {
        aggregateResult(draw: draw, checkedBetCount: checkedBetCount, matchSummary: matchSummary, prizes: prize.map { [$0] } ?? [])
    }

    private static func aggregateResult(draw: LotteryDraw, checkedBetCount: Int, matchSummary: String, prizes: [PrizeAward]) -> PrizeCheckResult {
        let groups = Dictionary(grouping: prizes) { $0.name }
        let breakdown = groups.map { name, values in
            let representative = values[0]
            return PrizeBreakdown(
                prizeName: name,
                count: values.count,
                prizeText: representative.prizeText
            )
        }
        .sorted { lhs, rhs in
            awardRank(lhs.prizeName) < awardRank(rhs.prizeName)
        }
        let fixedTotal = prizes.compactMap(\.fixedAmount).reduce(0, +)
        let hasFloating = prizes.contains { $0.isFloating }
        return PrizeCheckResult(
            issue: draw.issue,
            draw: draw,
            checkedBetCount: checkedBetCount,
            bestPrizeName: breakdown.first?.prizeName ?? "未中奖",
            totalFixedPrize: fixedTotal,
            hasFloatingPrize: hasFloating,
            matchSummary: matchSummary,
            breakdown: breakdown
        )
    }

    private static func ssqPrize(red: Int, blue: Int) -> PrizeAward? {
        if red == 6 && blue == 1 { return PrizeAward(name: "一等奖", isFloating: true) }
        if red == 6 { return PrizeAward(name: "二等奖", isFloating: true) }
        if red == 5 && blue == 1 { return PrizeAward(name: "三等奖", fixedAmount: 3000) }
        if red == 5 || (red == 4 && blue == 1) { return PrizeAward(name: "四等奖", fixedAmount: 200) }
        if red == 4 || (red == 3 && blue == 1) { return PrizeAward(name: "五等奖", fixedAmount: 10) }
        if blue == 1 { return PrizeAward(name: "六等奖", fixedAmount: 5) }
        return nil
    }

    private static func dltPrize(front: Int, back: Int) -> PrizeAward? {
        if front == 5 && back == 2 { return PrizeAward(name: "一等奖", isFloating: true) }
        if front == 5 && back == 1 { return PrizeAward(name: "二等奖", isFloating: true) }
        if front == 5 { return PrizeAward(name: "三等奖", fixedAmount: 10_000) }
        if front == 4 && back == 2 { return PrizeAward(name: "四等奖", fixedAmount: 3000) }
        if front == 4 && back == 1 { return PrizeAward(name: "五等奖", fixedAmount: 300) }
        if front == 3 && back == 2 { return PrizeAward(name: "六等奖", fixedAmount: 200) }
        if front == 4 { return PrizeAward(name: "七等奖", fixedAmount: 100) }
        if (front == 3 && back == 1) || (front == 2 && back == 2) { return PrizeAward(name: "八等奖", fixedAmount: 15) }
        if front == 3 || (front == 1 && back == 2) || (front == 2 && back == 1) || back == 2 { return PrizeAward(name: "九等奖", fixedAmount: 5) }
        return nil
    }

    private static func qlcPrize(basic: Int, special: Bool) -> PrizeAward? {
        if basic == 7 { return PrizeAward(name: "一等奖", isFloating: true) }
        if basic == 6 && special { return PrizeAward(name: "二等奖", isFloating: true) }
        if basic == 6 { return PrizeAward(name: "三等奖", isFloating: true) }
        if basic == 5 && special { return PrizeAward(name: "四等奖", fixedAmount: 200) }
        if basic == 5 { return PrizeAward(name: "五等奖", fixedAmount: 50) }
        if basic == 4 && special { return PrizeAward(name: "六等奖", fixedAmount: 10) }
        if basic == 4 { return PrizeAward(name: "七等奖", fixedAmount: 5) }
        return nil
    }

    private static func kl8Prize(pickCount: Int, matchCount: Int) -> PrizeAward? {
        let fixed: [Int: [Int: Double]] = [
            1: [1: 4.5],
            2: [2: 19],
            3: [3: 52, 2: 3],
            4: [4: 93, 3: 5, 2: 3],
            5: [5: 1000, 4: 21, 3: 3],
            6: [6: 2880, 5: 30, 4: 10, 3: 3],
            7: [7: 8500, 6: 288, 5: 28, 4: 4],
            8: [8: 50_000, 7: 800, 6: 88, 5: 10, 4: 3, 0: 2],
            9: [8: 2000, 7: 225, 6: 22, 5: 5, 4: 3, 0: 2],
            10: [9: 8000, 8: 720, 7: 80, 6: 5, 0: 2]
        ]
        if (pickCount == 9 && matchCount == 9) || (pickCount == 10 && matchCount == 10) {
            return PrizeAward(name: "选\(pickCount)中\(matchCount)", isFloating: true)
        }
        guard let amount = fixed[pickCount]?[matchCount] else {
            return nil
        }
        return PrizeAward(name: "选\(pickCount)中\(matchCount)", fixedAmount: amount)
    }

    private static func kl8Rules(pickCount: Int) -> [PrizeRule] {
        let rows: [(String, String)] = switch pickCount {
        case 1: [("中 1", "4.5 元")]
        case 2: [("中 2", "19 元")]
        case 3: [("中 3", "52 元"), ("中 2", "3 元")]
        case 4: [("中 4", "93 元"), ("中 3", "5 元"), ("中 2", "3 元")]
        case 5: [("中 5", "1000 元"), ("中 4", "21 元"), ("中 3", "3 元")]
        case 6: [("中 6", "2880 元"), ("中 5", "30 元"), ("中 4", "10 元"), ("中 3", "3 元")]
        case 7: [("中 7", "8500 元"), ("中 6", "288 元"), ("中 5", "28 元"), ("中 4", "4 元")]
        case 8: [("中 8", "50000 元"), ("中 7", "800 元"), ("中 6", "88 元"), ("中 5", "10 元"), ("中 4", "3 元"), ("中 0", "2 元")]
        case 9: [("中 9", "浮动奖"), ("中 8", "2000 元"), ("中 7", "225 元"), ("中 6", "22 元"), ("中 5", "5 元"), ("中 4", "3 元"), ("中 0", "2 元")]
        default: [("中 10", "浮动奖"), ("中 9", "8000 元"), ("中 8", "720 元"), ("中 7", "80 元"), ("中 6", "5 元"), ("中 0", "2 元")]
        }
        return rows.map { PrizeRule(title: "选\(pickCount)", condition: $0.0, prize: $0.1) }
    }

    private static func placeholder(for component: NumberComponent, count: Int) -> String {
        if component.ordered {
            return String(repeating: "0", count: count)
        }
        return (0..<count).map { DisplayFormat.number(component.range.lowerBound + $0) }.joined(separator: " ")
    }

    private static func helper(for component: NumberComponent, count: Int) -> String {
        let range = component.ordered ? "\(component.range.lowerBound)-\(component.range.upperBound)" : "\(DisplayFormat.number(component.range.lowerBound))-\(DisplayFormat.number(component.range.upperBound))"
        return "请输入 \(count) 个\(component.title)，范围 \(range)\(component.allowsRepeats ? "，可重复" : "，不可重复")。"
    }

    private static func combinations(_ values: [Int], choose count: Int) -> [[Int]] {
        guard count > 0 else { return [[]] }
        guard values.count >= count else { return [] }
        guard values.count != count else { return [values] }

        var result: [[Int]] = []
        var current: [Int] = []

        func visit(_ start: Int, _ remaining: Int) {
            if remaining == 0 {
                result.append(current)
                return
            }
            let lastStart = values.count - remaining
            guard start <= lastStart else { return }
            for index in start...lastStart {
                current.append(values[index])
                visit(index + 1, remaining - 1)
                current.removeLast()
            }
        }

        visit(0, count)
        return result
    }

    private static func hasSameMultiset(_ lhs: [Int], _ rhs: [Int]) -> Bool {
        lhs.sorted() == rhs.sorted()
    }

    private static func hasGroup3Shape(_ values: [Int]) -> Bool {
        Set(values).count == 2
    }

    private static func kl8PickCount(play: PlayOption) -> Int {
        Int(play.key.replacingOccurrences(of: "pick", with: "")) ?? play.componentPickCounts["main", default: 10]
    }

    private static func awardRank(_ name: String) -> Int {
        if name.contains("一等奖") || name.contains("直选") || name.contains("中10") || name.contains("中9") || name.contains("中8") { return 1 }
        if name.contains("二等奖") || name.contains("组三") || name.contains("中7") { return 2 }
        if name.contains("三等奖") || name.contains("组六") || name.contains("中6") { return 3 }
        if name.contains("四等奖") || name.contains("中5") { return 4 }
        if name.contains("五等奖") || name.contains("中4") { return 5 }
        if name.contains("六等奖") || name.contains("中3") { return 6 }
        if name.contains("七等奖") || name.contains("中2") { return 7 }
        if name.contains("八等奖") || name.contains("中1") { return 8 }
        if name.contains("九等奖") || name.contains("中0") { return 9 }
        return 99
    }
}

private struct PrizeAward: Sendable {
    let name: String
    var fixedAmount: Double?
    var isFloating = false

    var prizeText: String {
        if isFloating {
            return "浮动奖"
        }
        guard let fixedAmount else {
            return "0 元"
        }
        if fixedAmount.rounded(.down) == fixedAmount {
            return "\(Int(fixedAmount)) 元"
        }
        return String(format: "%.1f 元", fixedAmount)
    }
}
