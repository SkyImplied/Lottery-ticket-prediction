import Foundation

enum LotteryFamily: String, CaseIterable, Identifiable, Sendable {
    case welfare = "福彩"
    case sports = "体彩"

    var id: String { rawValue }
}

enum PredictionKind: String, Sendable {
    case unorderedBalls
    case mixedBalls
    case orderedDigits
}

enum PredictionAlgorithm: String, CaseIterable, Identifiable, Hashable, Sendable {
    case balancedStats
    case hotTrend
    case coldGap
    case machineLearning
    case neuralNetwork
    case lowPopularity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balancedStats:
            return "综合统计"
        case .hotTrend:
            return "热度趋势"
        case .coldGap:
            return "遗漏回补"
        case .machineLearning:
            return "机器学习"
        case .neuralNetwork:
            return "神经网络"
        case .lowPopularity:
            return "冷门组合"
        }
    }

    var shortSummary: String {
        switch self {
        case .balancedStats:
            return "兼顾长期频率、近期走势和当前遗漏。"
        case .hotTrend:
            return "更偏向近30期、近100期内活跃且间隔较短的号码。"
        case .coldGap:
            return "提高当前遗漏权重，用于观察较久未出的号码。"
        case .machineLearning:
            return "用历史开奖滚动构造训练样本，输出下一期概率评分。"
        case .neuralNetwork:
            return "训练小型前馈神经网络，学习频率、遗漏和动量的非线性组合。"
        case .lowPopularity:
            return "避开常见投注偏好，尽量生成少人同买的组合。"
        }
    }

    var scoreSubtitle: String {
        switch self {
        case .balancedStats:
            return "长期 + 近期 + 遗漏"
        case .hotTrend:
            return "近期热度优先"
        case .coldGap:
            return "遗漏回补优先"
        case .machineLearning:
            return "逻辑回归概率"
        case .neuralNetwork:
            return "前馈网络概率"
        case .lowPopularity:
            return "反热门投注偏好"
        }
    }

    var modelLines: [(String, String)] {
        switch self {
        case .balancedStats:
            return [("全历史", "35%"), ("近100期", "25%"), ("近30期", "20%"), ("当前遗漏", "20%")]
        case .hotTrend:
            return [("全历史", "15%"), ("近100期", "30%"), ("近30期", "40%"), ("连贯/动量", "15%")]
        case .coldGap:
            return [("全历史", "25%"), ("近100期", "20%"), ("近30期", "10%"), ("当前遗漏", "45%")]
        case .machineLearning:
            return [("模型", "逻辑回归"), ("特征", "频率/遗漏/动量"), ("训练", "滚动样本"), ("输出", "命中概率")]
        case .neuralNetwork:
            return [("模型", "单隐藏层网络"), ("隐藏单元", "8"), ("特征", "频率/遗漏/动量"), ("输出", "命中概率")]
        case .lowPopularity:
            return [("目标", "少人同买"), ("避开", "生日/顺子/同尾"), ("偏好", "分散不规整"), ("概率", "不提升命中率")]
        }
    }

    func predictionNote(for play: PlayOption) -> String {
        "\(title)：\(shortSummary) \(play.algorithmHint)"
    }
}

struct NumberComponent: Identifiable, Hashable, Sendable {
    var id: String { key }

    let key: String
    let title: String
    let range: ClosedRange<Int>
    let drawCount: Int
    let defaultPickCount: Int
    let colorRole: ComponentColor
    let ordered: Bool
    let allowsRepeats: Bool

    var candidateUniverse: [Int] {
        Array(range)
    }
}

enum ComponentColor: String, Hashable, Sendable {
    case red
    case blue
    case gold
    case neutral
}

struct PlayOption: Identifiable, Hashable, Sendable {
    var id: String { key }

    let key: String
    let title: String
    let componentPickCounts: [String: Int]
    let detail: String
    let prizeSummary: String
    let algorithmHint: String
}

enum LotteryGame: String, CaseIterable, Identifiable, Sendable {
    case kl8
    case ssq
    case fc3d
    case qlc
    case dlt
    case pl3
    case pl5
    case qxc

    var id: String { rawValue }

    var name: String {
        switch self {
        case .kl8: return "快乐8"
        case .ssq: return "双色球"
        case .fc3d: return "福彩3D"
        case .qlc: return "七乐彩"
        case .dlt: return "超级大乐透"
        case .pl3: return "排列3"
        case .pl5: return "排列5"
        case .qxc: return "七星彩"
        }
    }

    var displayName: String {
        "\(family.rawValue)·\(name)"
    }

    var family: LotteryFamily {
        switch self {
        case .kl8, .ssq, .fc3d, .qlc:
            return .welfare
        case .dlt, .pl3, .pl5, .qxc:
            return .sports
        }
    }

    var lotteryId: String {
        switch self {
        case .ssq: return "1"
        case .fc3d: return "2"
        case .qlc: return "3"
        case .kl8: return "6"
        case .dlt: return "281"
        case .qxc: return "287"
        case .pl3: return "283"
        case .pl5: return "284"
        }
    }

    var issueCount: Int {
        switch self {
        case .kl8:
            return 3000
        case .fc3d, .pl3, .pl5:
            return 2500
        default:
            return 1500
        }
    }

    var schedule: String {
        switch self {
        case .kl8:
            return "每日开奖"
        case .ssq:
            return "每周二、四、日开奖"
        case .fc3d, .pl3, .pl5:
            return "每日开奖"
        case .qlc:
            return "每周一、三、五开奖"
        case .dlt:
            return "每周一、三、六开奖"
        case .qxc:
            return "每周二、五、日开奖"
        }
    }

    var predictionKind: PredictionKind {
        switch self {
        case .fc3d, .pl3, .pl5, .qxc:
            return .orderedDigits
        case .ssq, .qlc, .dlt:
            return .mixedBalls
        case .kl8:
            return .unorderedBalls
        }
    }

    var components: [NumberComponent] {
        switch self {
        case .kl8:
            return [
                NumberComponent(key: "main", title: "号码", range: 1...80, drawCount: 20, defaultPickCount: 10, colorRole: .red, ordered: false, allowsRepeats: false)
            ]
        case .ssq:
            return [
                NumberComponent(key: "front", title: "红球", range: 1...33, drawCount: 6, defaultPickCount: 6, colorRole: .red, ordered: false, allowsRepeats: false),
                NumberComponent(key: "back", title: "蓝球", range: 1...16, drawCount: 1, defaultPickCount: 1, colorRole: .blue, ordered: false, allowsRepeats: false)
            ]
        case .fc3d, .pl3:
            return [
                NumberComponent(key: "digits", title: "三位", range: 0...9, drawCount: 3, defaultPickCount: 3, colorRole: .gold, ordered: true, allowsRepeats: true)
            ]
        case .qlc:
            return [
                NumberComponent(key: "front", title: "基本号", range: 1...30, drawCount: 7, defaultPickCount: 7, colorRole: .red, ordered: false, allowsRepeats: false),
                NumberComponent(key: "back", title: "特别号", range: 1...30, drawCount: 1, defaultPickCount: 1, colorRole: .blue, ordered: false, allowsRepeats: false)
            ]
        case .dlt:
            return [
                NumberComponent(key: "front", title: "前区", range: 1...35, drawCount: 5, defaultPickCount: 5, colorRole: .red, ordered: false, allowsRepeats: false),
                NumberComponent(key: "back", title: "后区", range: 1...12, drawCount: 2, defaultPickCount: 2, colorRole: .blue, ordered: false, allowsRepeats: false)
            ]
        case .pl5:
            return [
                NumberComponent(key: "digits", title: "五位", range: 0...9, drawCount: 5, defaultPickCount: 5, colorRole: .gold, ordered: true, allowsRepeats: true)
            ]
        case .qxc:
            return [
                NumberComponent(key: "digits", title: "七位", range: 0...9, drawCount: 7, defaultPickCount: 7, colorRole: .gold, ordered: true, allowsRepeats: true)
            ]
        }
    }

    var playOptions: [PlayOption] {
        switch self {
        case .kl8:
            return (1...10).map { count in
                PlayOption(
                    key: "pick\(count)",
                    title: "选\(Self.cn(count))",
                    componentPickCounts: ["main": count],
                    detail: kl8Detail(count),
                    prizeSummary: kl8Prize(count),
                    algorithmHint: "从 1-80 的模型评分中取前 \(count) 个候选，按号码升序展示。"
                )
            }
        case .ssq:
            return [
                PlayOption(key: "single", title: "标准投注", componentPickCounts: ["front": 6, "back": 1], detail: "6 个红球 + 1 个蓝球", prizeSummary: "一等奖需 6 红 + 蓝；二等奖需 6 红。", algorithmHint: "红球和蓝球分区独立评分，分别取 6 个红球与 1 个蓝球。"),
                PlayOption(key: "red_extra", title: "红球复式参考", componentPickCounts: ["front": 9, "back": 1], detail: "9 个红球候选 + 1 个蓝球", prizeSummary: "用于查看红球候选池，不等同于单注。", algorithmHint: "红球扩大到前 9 个评分号码，蓝球仍取 1 个。")
            ]
        case .fc3d:
            return Self.digitThreePlays(prefix: "福彩3D")
        case .qlc:
            return [
                PlayOption(key: "single", title: "标准投注", componentPickCounts: ["front": 7, "back": 1], detail: "7 个基本号 + 1 个特别号参考", prizeSummary: "一等奖中 7 个基本号；特别号影响部分奖级。", algorithmHint: "基本号按 1-30 评分取 7 个，特别号单独评分取 1 个。"),
                PlayOption(key: "front_extra", title: "基本号复式参考", componentPickCounts: ["front": 10, "back": 1], detail: "10 个基本号候选 + 1 个特别号", prizeSummary: "用于查看扩展候选池，不等同于单注。", algorithmHint: "基本号扩大到前 10 个评分号码。")
            ]
        case .dlt:
            return [
                PlayOption(key: "single", title: "基本投注", componentPickCounts: ["front": 5, "back": 2], detail: "5 个前区 + 2 个后区", prizeSummary: "一等奖需 5 前区 + 2 后区。", algorithmHint: "前区和后区分区独立评分，分别取 5 个与 2 个。"),
                PlayOption(key: "add", title: "追加投注参考", componentPickCounts: ["front": 5, "back": 2], detail: "号码同基本投注，奖金规则含追加", prizeSummary: "追加只影响部分奖级奖金，不改变开奖号码。", algorithmHint: "追加投注不改变号码模型，只改变投注奖金规则。"),
                PlayOption(key: "front_extra", title: "前区复式参考", componentPickCounts: ["front": 8, "back": 3], detail: "8 个前区候选 + 3 个后区候选", prizeSummary: "用于查看扩展候选池，不等同于单注。", algorithmHint: "前区和后区分别扩大候选池。")
            ]
        case .pl3:
            return Self.digitThreePlays(prefix: "排列3")
        case .pl5:
            return [
                PlayOption(key: "direct", title: "直选", componentPickCounts: ["digits": 5], detail: "按万千百十个顺序预测 5 位数字", prizeSummary: "5 位全部命中且顺序一致。", algorithmHint: "按位置分别统计 0-9 的频率、近期频率和遗漏，生成 5 位候选。")
            ]
        case .qxc:
            return [
                PlayOption(key: "direct", title: "直选", componentPickCounts: ["digits": 7], detail: "按开奖顺序预测 7 位数字", prizeSummary: "各奖级按命中位数和位置判定。", algorithmHint: "按位置分别统计 0-9 的频率、近期频率和遗漏，生成 7 位候选。")
            ]
        }
    }

    func algorithmDescription(for algorithm: PredictionAlgorithm) -> String {
        let scoring: String
        switch algorithm {
        case .balancedStats:
            scoring = """
            2. 对每个号码分区单独计算：全历史出现频率、近100期频率、近30期频率、当前遗漏期数。
            3. 将四类特征标准化为 z-score。
            4. 综合分数 = 0.35×全历史 + 0.25×近100期 + 0.20×近30期 + 0.20×遗漏。
            """
        case .hotTrend:
            scoring = """
            2. 对每个号码分区单独计算：全历史出现频率、近100期频率、近30期频率、当前遗漏期数。
            3. 将频率、近期活跃度标准化为 z-score。
            4. 综合分数 = 0.15×全历史 + 0.30×近100期 + 0.40×近30期 + 0.10×近期连贯 + 0.05×近期动量。
            """
        case .coldGap:
            scoring = """
            2. 对每个号码分区单独计算：全历史出现频率、近100期频率、近30期频率、当前遗漏期数。
            3. 将四类特征标准化为 z-score。
            4. 综合分数 = 0.25×全历史 + 0.20×近100期 + 0.10×近30期 + 0.45×遗漏。
            """
        case .machineLearning:
            scoring = """
            2. 用每一期之前的历史数据生成训练样本：长期频率、近100期频率、近30期频率、遗漏比例和近期动量。
            3. 对每个分区训练轻量逻辑回归模型，按时间顺序滚动学习“下一期是否出现”。
            4. 用训练后的模型对当前候选号码输出概率评分，再按玩法取最高候选。
            """
        case .neuralNetwork:
            scoring = """
            2. 用每一期之前的历史数据生成训练样本：长期频率、近100期频率、近30期频率、遗漏比例和近期动量。
            3. 对每个分区训练单隐藏层前馈神经网络，按时间顺序滚动学习“下一期是否出现”。
            4. 用训练后的网络对当前候选号码输出概率评分，再按玩法取最高候选。
            """
        case .lowPopularity:
            scoring = """
            2. 不尝试提高开奖号码命中概率，而是估计投注人群的常见偏好。
            3. 降低生日号、纪念日号、吉利号、顺子、同尾、整齐间隔和对称图案的权重。
            4. 对每个号码分区独立生成更分散、更不规整的候选池，减少与大众票面撞车的概率。
            """
        }

        switch predictionKind {
        case .unorderedBalls, .mixedBalls:
            return """
            1. 每次更新后重新读取该彩种所有历史开奖。
            \(scoring)
            5. 按玩法需要，从对应分区取评分最高的号码。冷门组合算法只影响“是否容易与他人同号”，不改变开奖命中概率。

            彩票设计目标是随机，任何算法都只能作为候选观察工具，不能保证中奖。
            """
        case .orderedDigits:
            return """
            1. 每次更新后重新读取该彩种所有历史开奖。
            2. 对每个位置分别建模，例如百位、十位、个位各自统计 0-9。
            \(scoring)
            5. 按玩法输出直选顺序号；组三/组六会在候选数字中约束重复结构。冷门组合算法会额外避开重复、顺子、豹子和对称等热门形态。

            数字型彩票同样不适合声称可稳定预测；机器学习结果也需要结合滚动回测和随机基线审视。
            """
        }
    }

    private static func digitThreePlays(prefix: String) -> [PlayOption] {
        [
            PlayOption(key: "direct", title: "直选", componentPickCounts: ["digits": 3], detail: "按百十个顺序预测 3 位数字", prizeSummary: "3 位全部命中且顺序一致。", algorithmHint: "按位置分别评分，输出百位、十位、个位。"),
            PlayOption(key: "group3", title: "组三", componentPickCounts: ["digits": 3], detail: "3 位中有 2 位相同", prizeSummary: "命中两个相同数字与一个不同数字，不看顺序。", algorithmHint: "先按位置评分取候选，再约束为 AAB 结构。"),
            PlayOption(key: "group6", title: "组六", componentPickCounts: ["digits": 3], detail: "3 位数字各不相同", prizeSummary: "命中 3 个不同数字，不看顺序。", algorithmHint: "取综合评分最高且互不相同的 3 个数字。")
        ]
    }

    private static func cn(_ value: Int) -> String {
        ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][value - 1]
    }

    private func kl8Detail(_ count: Int) -> String {
        switch count {
        case 1: return "命中 1 个号码中奖"
        case 2: return "命中 2 个号码中奖"
        case 3: return "命中 2-3 个号码中奖"
        case 4: return "命中 2-4 个号码中奖"
        case 5: return "命中 3-5 个号码中奖"
        case 6: return "命中 3-6 个号码中奖"
        case 7: return "命中 4-7 个号码中奖"
        case 8: return "命中 0 或 4-8 个号码中奖"
        case 9: return "命中 0 或 4-9 个号码中奖，最高奖浮动"
        default: return "命中 0 或 5-10 个号码中奖，最高奖浮动"
        }
    }

    private func kl8Prize(_ count: Int) -> String {
        switch count {
        case 1: return "中1：4.5元"
        case 2: return "中2：19元"
        case 3: return "中3：52元；中2：3元"
        case 4: return "中4：93元；中3：5元；中2：3元"
        case 5: return "中5：1000元；中4：21元；中3：3元"
        case 6: return "中6：2880元；中5：30元；中4：10元；中3：3元"
        case 7: return "中7：8500元；中6：288元；中5：28元；中4：4元"
        case 8: return "中8：50000元；中7：800元；中6：88元；中5：10元；中4：3元；中0：2元"
        case 9: return "中9：浮动（25万封顶）；中8：2000元；中7：225元；中6：22元；中5：5元；中4：3元；中0：2元"
        default: return "中10：浮动（500万封顶）；中9：8000元；中8：720元；中7：80元；中6：5元；中0：2元"
        }
    }
}

struct LotteryDraw: Identifiable, Hashable, Sendable {
    var id: String { issue }

    let game: LotteryGame
    let issue: String
    let drawDate: String
    let week: String
    let components: [String: [Int]]
    let saleMoney: Double?
    let prizePoolMoney: Double?
    let source: String

    func numbers(for key: String) -> [Int] {
        components[key, default: []]
    }
}

struct LotteryPrediction: Sendable {
    let game: LotteryGame
    let play: PlayOption
    let algorithm: PredictionAlgorithm
    let components: [String: [Int]]
    let generatedAt: Date
    let note: String

    var betCost: BetCostEstimate {
        BetCostEstimate(game: game, play: play, components: components)
    }
}

struct ConsensusPrediction: Sendable {
    let game: LotteryGame
    let play: PlayOption
    let algorithms: [PredictionAlgorithm]
    let components: [String: [Int]]
    let generatedAt: Date

    var betCost: BetCostEstimate {
        BetCostEstimate(game: game, play: play, components: components)
    }
}

struct BetCostEstimate: Sendable {
    let unitPrice = 2
    let betCount: Int
    let amount: Int
    let detail: String
    let note: String

    init(game: LotteryGame, play: PlayOption, components: [String: [Int]]) {
        let betCount = Self.betCount(game: game, play: play, components: components)
        self.betCount = betCount
        self.amount = betCount * unitPrice
        self.detail = "\(betCount) 注 × \(unitPrice) 元/注 = \(betCount * unitPrice) 元"
        self.note = Self.note(game: game, play: play, components: components, betCount: betCount)
    }

    private static func betCount(game: LotteryGame, play: PlayOption, components: [String: [Int]]) -> Int {
        switch game.predictionKind {
        case .unorderedBalls:
            guard let component = game.components.first else { return 0 }
            let selected = components[component.key, default: []].count
            let required = play.componentPickCounts[component.key] ?? component.defaultPickCount
            return max(1, combination(selected, required))
        case .mixedBalls:
            return game.components.reduce(1) { total, component in
                let selected = components[component.key, default: []].count
                let required = component.drawCount
                return total * max(1, combination(selected, required))
            }
        case .orderedDigits:
            return 1
        }
    }

    private static func note(game: LotteryGame, play: PlayOption, components: [String: [Int]], betCount: Int) -> String {
        if play.key == "add", game == .dlt {
            return "追加投注通常仍按每注 2 元基础号码估算；若按追加规则投注，请以实际出票金额为准。"
        }
        if betCount > 1 {
            return "当前候选包含复式组合，金额按组合注数估算。"
        }
        return "当前候选按单注估算。"
    }

    private static func combination(_ n: Int, _ k: Int) -> Int {
        guard n >= k, k >= 0 else { return 0 }
        guard k > 0 else { return 1 }
        let r = min(k, n - k)
        if r == 0 { return 1 }
        return (1...r).reduce(1) { partial, index in
            partial * (n - r + index) / index
        }
    }
}

struct AlgorithmComparison: Sendable {
    let game: LotteryGame
    let play: PlayOption
    let generatedAt: Date
    let results: [AlgorithmComparisonResult]
    let commonTokens: Int
    let totalDistinctTokens: Int
    let summary: String
    let reasons: [String]
}

struct AlgorithmComparisonResult: Identifiable, Sendable {
    var id: PredictionAlgorithm { algorithm }

    let algorithm: PredictionAlgorithm
    let prediction: LotteryPrediction
    let sharedTokenCount: Int
    let uniqueTokenCount: Int
}

struct NumberScore: Identifiable, Sendable {
    var id: String { "\(componentKey)-\(position ?? -1)-\(number)" }

    let componentKey: String
    let componentTitle: String
    let position: Int?
    let number: Int
    let frequency: Int
    let rate: Double
    let currentGap: Int
    let score: Double
}
