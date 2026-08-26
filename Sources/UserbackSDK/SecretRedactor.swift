import Foundation

/// Strips known secrets from log lines and URLs before they are buffered for Userback.
enum SecretRedactor {
    static let placeholder = "[redacted]"

    static func redact(_ input: String) -> String {
        var result = input
        result = replace(result, pattern: #"(?i)Bearer\s+\S+"#, template: "Bearer \(placeholder)")
        result = replace(
            result,
            pattern: #"(?i)([?&](?:token|accessToken|access_token|refreshToken|refresh_token|code|expiresIn)=)[^&\s#]*"#,
            template: "$1\(placeholder)"
        )
        result = replace(
            result,
            pattern: #"(?i)(Set-Cookie[^:]*:\s*).+"#,
            template: "$1\(placeholder)"
        )
        result = replace(
            result,
            pattern: #"(?i)(Cookie:\s*(?:accessToken|refreshToken|clarity_accessToken|clarity_refreshToken)\s*=\s*)\S+"#,
            template: "$1\(placeholder)"
        )
        result = replace(
            result,
            pattern: #"(?i)(\b(?:accessToken|refreshToken|sharedServiceToken|Service Token)\s*[=:]\s*)\S+"#,
            template: "$1\(placeholder)"
        )
        result = replace(
            result,
            pattern: #"(?i)((?:magic link token|Universal Link Token)[^:]*[=:]\s*)\S+"#,
            template: "$1\(placeholder)"
        )
        result = replace(
            result,
            pattern: #"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"#,
            template: placeholder
        )
        return result
    }

    private static func replace(_ input: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }
}
