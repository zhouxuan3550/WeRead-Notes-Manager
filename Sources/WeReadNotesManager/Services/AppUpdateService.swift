import Foundation

struct AppReleaseInfo: Decodable, Equatable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body
    }

    var versionText: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

enum AppUpdateStatus: Equatable {
    case upToDate(version: String)
    case available(current: String, latest: AppReleaseInfo)
}

enum AppUpdateService {
    static let releasesURL = URL(string: "https://github.com/zhouxuan3550/WeRead-Notes-Manager/releases")!
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/zhouxuan3550/WeRead-Notes-Manager/releases/latest")!

    static var currentVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version?.isEmpty == false ? version! : "开发版"
    }

    static func checkLatestRelease() async throws -> AppUpdateStatus {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let latest = try JSONDecoder().decode(AppReleaseInfo.self, from: data)
        let current = currentVersion
        if isVersion(latest.versionText, newerThan: current) {
            return .available(current: current, latest: latest)
        }
        return .upToDate(version: current)
    }

    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = numericParts(lhs)
        let right = numericParts(rhs)
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { part in
                Int(part.prefix { $0.isNumber }) ?? 0
            }
    }
}

enum AppUpdateError: LocalizedError {
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode):
            return "检查更新失败，GitHub 返回 \(statusCode)。"
        }
    }
}
