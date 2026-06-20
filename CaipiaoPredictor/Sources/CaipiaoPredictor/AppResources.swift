import Foundation

enum AppResources {
    private static let bundleName = "CaipiaoPredictor_CaipiaoPredictor.bundle"

    private static var packagedBundle: Bundle? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName)
        ]

        return candidates
            .compactMap { $0 }
            .compactMap { Bundle(url: $0) }
            .first
    }

    static func url(forResource name: String, withExtension extensionName: String) -> URL? {
        packagedBundle?.url(forResource: name, withExtension: extensionName)
            ?? Bundle.module.url(forResource: name, withExtension: extensionName)
    }
}
