import Foundation

enum LotteryServiceError: LocalizedError {
    case invalidResponse
    case serverMessage(String)
    case missingBundledData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "开奖接口返回内容无法解析"
        case .serverMessage(let message):
            return message
        case .missingBundledData:
            return "未找到内置开奖数据"
        }
    }
}

struct LotteryService {
    private let endpoint = URL(string: "https://jc.zhcw.com/port/client_json.php")!

    func fetchDraws(for game: LotteryGame) async throws -> [LotteryDraw] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "transactionType", value: "10001001"),
            URLQueryItem(name: "lotteryId", value: game.lotteryId),
            URLQueryItem(name: "issueCount", value: "\(game.issueCount)"),
            URLQueryItem(name: "startIssue", value: ""),
            URLQueryItem(name: "endIssue", value: ""),
            URLQueryItem(name: "startDate", value: ""),
            URLQueryItem(name: "endDate", value: ""),
            URLQueryItem(name: "type", value: "0"),
            URLQueryItem(name: "pageNum", value: "1"),
            URLQueryItem(name: "pageSize", value: "\(game.issueCount)"),
            URLQueryItem(name: "tt", value: "\(Date().timeIntervalSince1970)"),
            URLQueryItem(name: "callback", value: "lottery_callback")
        ]

        guard let url = components.url else {
            throw LotteryServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("https://www.zhcw.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let text = String(data: data, encoding: .utf8) ?? ""
        let jsonData = try extractJSONPData(from: text)
        let response = try JSONDecoder().decode(ZHCWResponse.self, from: jsonData)

        if let code = response.resCode, code != "000000" {
            throw LotteryServiceError.serverMessage(response.message ?? "接口返回错误：\(code)")
        }

        return response.data.compactMap { item in
            makeDraw(from: item, game: game)
        }
        .sorted { $0.issue < $1.issue }
    }

    func loadBundledDataset() throws -> BundledLotteryDataset {
        guard let url = Bundle.module.url(forResource: "bundled_draws", withExtension: "json") else {
            throw LotteryServiceError.missingBundledData
        }
        let data = try Data(contentsOf: url)
        let bundled = try JSONDecoder().decode(BundledLotteryFile.self, from: data)
        var drawsByGame: [LotteryGame: [LotteryDraw]] = [:]

        for game in LotteryGame.allCases {
            let rows = bundled.games[game.rawValue, default: []]
            drawsByGame[game] = rows.map { row in
                LotteryDraw(
                    game: game,
                    issue: row.issue,
                    drawDate: row.drawDate,
                    week: row.week,
                    components: row.components,
                    saleMoney: row.saleMoney,
                    prizePoolMoney: row.prizePoolMoney,
                    source: row.source
                )
            }
            .sorted { issueSortKey($0.issue) < issueSortKey($1.issue) }
        }

        return BundledLotteryDataset(generatedAt: bundled.generatedAt, source: bundled.source, drawsByGame: drawsByGame)
    }

    private func makeDraw(from item: ZHCWDraw, game: LotteryGame) -> LotteryDraw? {
        let front = parseNumbers(item.frontWinningNum)
        let back = parseNumbers(item.backWinningNum)
        var componentValues: [String: [Int]] = [:]

        switch game {
        case .kl8:
            guard front.count >= 20 else { return nil }
            componentValues["main"] = Array(front.prefix(20)).sorted()
        case .ssq:
            guard front.count >= 6, back.count >= 1 else { return nil }
            componentValues["front"] = Array(front.prefix(6)).sorted()
            componentValues["back"] = Array(back.prefix(1)).sorted()
        case .fc3d, .pl3:
            let digits = parseDigits(item.frontWinningNum, expectedCount: 3)
            guard digits.count == 3 else { return nil }
            componentValues["digits"] = digits
        case .qlc:
            guard front.count >= 7 else { return nil }
            componentValues["front"] = Array(front.prefix(7)).sorted()
            if let special = back.first {
                componentValues["back"] = [special]
            } else if front.count >= 8 {
                componentValues["back"] = [front[7]]
            } else {
                componentValues["back"] = []
            }
        case .dlt:
            guard front.count >= 5, back.count >= 2 else { return nil }
            componentValues["front"] = Array(front.prefix(5)).sorted()
            componentValues["back"] = Array(back.prefix(2)).sorted()
        case .pl5:
            let digits = parseDigits(item.frontWinningNum, expectedCount: 5)
            guard digits.count == 5 else { return nil }
            componentValues["digits"] = digits
        case .qxc:
            let merged = [item.frontWinningNum, item.backWinningNum]
                .filter { !$0.isEmpty && $0 != "-1" }
                .joined(separator: " ")
            let digits = parseDigits(merged, expectedCount: 7)
            guard digits.count == 7 else { return nil }
            componentValues["digits"] = digits
        }

        return LotteryDraw(
            game: game,
            issue: item.issue,
            drawDate: item.openTime,
            week: item.week,
            components: componentValues,
            saleMoney: Double(item.saleMoney),
            prizePoolMoney: Double(item.prizePoolMoney),
            source: "zhcw_jsonp"
        )
    }

    private func extractJSONPData(from text: String) throws -> Data {
        guard let start = text.firstIndex(of: "("), let end = text.lastIndex(of: ")"), start < end else {
            throw LotteryServiceError.invalidResponse
        }
        let json = text[text.index(after: start)..<end]
        guard let data = String(json).data(using: .utf8) else {
            throw LotteryServiceError.invalidResponse
        }
        return data
    }

    private func parseNumbers(_ value: String) -> [Int] {
        value
            .split(separator: " ")
            .compactMap { Int($0) }
            .filter { $0 >= 0 }
    }

    private func parseDigits(_ value: String, expectedCount: Int) -> [Int] {
        let spaced = value
            .split(separator: " ")
            .compactMap { Int($0) }
        if spaced.count == expectedCount, spaced.allSatisfy({ (0...9).contains($0) }) {
            return spaced
        }

        let digits = value.compactMap { char -> Int? in
            guard let scalar = char.unicodeScalars.first, CharacterSet.decimalDigits.contains(scalar) else {
                return nil
            }
            return Int(String(char))
        }
        return Array(digits.prefix(expectedCount))
    }

    private func issueSortKey(_ issue: String) -> (Int, String) {
        let digits = issue.filter(\.isNumber)
        return (Int(digits) ?? 0, issue)
    }
}

struct BundledLotteryDataset: Sendable {
    let generatedAt: String
    let source: String
    let drawsByGame: [LotteryGame: [LotteryDraw]]
}

private struct BundledLotteryFile: Decodable {
    let generatedAt: String
    let source: String
    let games: [String: [BundledLotteryDraw]]
}

private struct BundledLotteryDraw: Decodable {
    let issue: String
    let drawDate: String
    let week: String
    let components: [String: [Int]]
    let saleMoney: Double?
    let prizePoolMoney: Double?
    let source: String
}

private struct ZHCWResponse: Decodable {
    let resCode: String?
    let message: String?
    let data: [ZHCWDraw]
}

private struct ZHCWDraw: Decodable {
    let issue: String
    let openTime: String
    let frontWinningNum: String
    let backWinningNum: String
    let saleMoney: String
    let prizePoolMoney: String
    let week: String
}
