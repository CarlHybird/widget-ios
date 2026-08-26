import Foundation

/// Strips known secrets from log lines and URLs before they are buffered for Userback.
enum SecretRedactor {
    static let placeholder = "[redacted]"

    private struct Rule {
        let regex: NSRegularExpression
        let template: String
    }

    /// `redact` runs on every captured stdout line. Compiling these per call made the
    /// pipe reader fall behind the app's logging, which back-pressures `print` itself.
    private static let rules: [Rule] = {
        let specs: [(pattern: String, template: String)] = [
            (#"(?i)Bearer\s+\S+"#, "Bearer \(placeholder)"),
            (#"(?i)([?&](?:token|accessToken|access_token|refreshToken|refresh_token|code|expiresIn)=)[^&\s#]*"#, "$1\(placeholder)"),
            (#"(?i)(Set-Cookie[^:]*:\s*).+"#, "$1\(placeholder)"),
            (#"(?i)(Cookie:\s*(?:accessToken|refreshToken|clarity_accessToken|clarity_refreshToken)\s*=\s*)\S+"#, "$1\(placeholder)"),
            (#"(?i)(\b(?:accessToken|refreshToken|sharedServiceToken|Service Token)\s*[=:]\s*)\S+"#, "$1\(placeholder)"),
            (#"(?i)((?:magic link token|Universal Link Token)[^:]*[=:]\s*)\S+"#, "$1\(placeholder)"),
            (#"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"#, placeholder),
        ]

        return specs.compactMap { spec in
            guard let regex = try? NSRegularExpression(pattern: spec.pattern) else { return nil }
            return Rule(regex: regex, template: spec.template)
        }
    }()

    /// Every pattern above requires one of these substrings, so a line without any of
    /// them cannot match and skips all seven scans. Most log lines take this path.
    private static let triggers = ["bearer", "token", "cookie", "eyj", "code=", "expiresin"]

    static func redact(_ input: String) -> String {
        let lowered = input.lowercased()
        guard triggers.contains(where: { lowered.contains($0) }) else { return input }

        var result = input
        for rule in rules {
            let range = NSRange(result.startIndex..., in: result)
            result = rule.regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: rule.template
            )
        }
        return result
    }
}
