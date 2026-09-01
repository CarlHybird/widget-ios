import XCTest
@testable import UserbackSDK

@MainActor
final class UserbackSDKTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(UserbackSDK.version(), "1.0.0")
    }

    func testBootstrapCarriesIdentityAndWidgetSettings() {
        UserbackSDK.shared.configure(
            accessToken: "M-token",
            widgetJSURL: "https://static.userback.io/widget/v1.js",
            userData: ["id": "42", "info": ["email": "jane@example.com"]],
            widgetSettings: ["form_settings": ["bug": ["email_field": false]]]
        )

        let bootstrap = UserbackSDK.shared.buildInjectedJS()

        XCTAssertTrue(bootstrap.contains("Userback.user_data = "))
        XCTAssertTrue(bootstrap.contains("jane@example.com"))
        XCTAssertTrue(bootstrap.contains("Userback.widget_settings = "))
        XCTAssertTrue(bootstrap.contains("\"email_field\":false"))
    }

    /// The widget warns about a missing user ID rather than ignoring an identity it cannot use,
    /// and an empty `widget_settings` would take the form settings override path for nothing.
    func testBootstrapOmitsUnusableIdentityAndEmptySettings() {
        UserbackSDK.shared.configure(
            accessToken: "M-token",
            widgetJSURL: "https://static.userback.io/widget/v1.js",
            userData: [:],
            widgetSettings: [:]
        )

        let bootstrap = UserbackSDK.shared.buildInjectedJS()

        XCTAssertFalse(bootstrap.contains("user_data"))
        XCTAssertFalse(bootstrap.contains("widget_settings"))
        XCTAssertTrue(bootstrap.contains("Userback.access_token = \"M-token\""))
    }

    func testNativeVideoListenerIsSplicedBesideScreenshotHook() {
        let source = "prefix;" + WidgetJavaScript.nativeScreenshotListener + ";suffix"
        let patched = WidgetJavaScript.withNativeVideoListener(source)

        XCTAssertNotNil(patched)
        XCTAssertTrue(patched?.contains("userback:nativeVideo") == true)
        XCTAssertTrue(patched?.contains("submitVideoCapture") == true)
        XCTAssertTrue(patched?.contains(WidgetJavaScript.nativeScreenshotListener) == true)
    }

    func testNativeVideoListenerPatchFailsWhenHookIsMissing() {
        XCTAssertNil(WidgetJavaScript.withNativeVideoListener("window.Userback = {};"))
    }

    func testAppendChunkScriptUsesRawBase64() {
        let script = WidgetJavaScript.appendChunkScript("YQ==")
        XCTAssertTrue(script.contains("push('YQ==')"))
    }

    func testAssembleScriptDispatchesNativeVideoEvent() {
        let script = WidgetJavaScript.assembleAndDispatchScript()
        XCTAssertTrue(script.contains("userback:nativeVideo"))
        XCTAssertTrue(script.contains("video/mp4"))
        XCTAssertTrue(script.contains("__ubNativeVideoBlob"))
    }

    func testRedactsBearerTokens() {
        let redacted = SecretRedactor.redact("Authorization=Bearer eyJhbGciOi.payload.sig extra")
        XCTAssertFalse(redacted.contains("eyJhbGciOi.payload.sig"))
        XCTAssertTrue(redacted.contains("Bearer [redacted]"))
    }

    func testRedactsQuerySecrets() {
        let url = "https://app.example/auth/verify?token=secret-value&keep=ok"
        let redacted = SecretRedactor.redact(url)
        XCTAssertFalse(redacted.contains("secret-value"))
        XCTAssertTrue(redacted.contains("token=[redacted]"))
        XCTAssertTrue(redacted.contains("keep=ok"))
    }

    func testRedactsAccessTokenAssignment() {
        let redacted = SecretRedactor.redact("Saved accessToken=super-secret expiry=soon")
        XCTAssertFalse(redacted.contains("super-secret"))
        XCTAssertTrue(redacted.contains("accessToken=[redacted]"))
    }

    func testRedactsCookieValues() {
        let redacted = SecretRedactor.redact("🍪 Cookie: accessToken = abc.def.ghi")
        XCTAssertFalse(redacted.contains("abc.def.ghi"))
        XCTAssertTrue(redacted.contains("[redacted]"))
    }

    func testRedactsSetCookieHeader() {
        let redacted = SecretRedactor.redact("🍪 Raw Set-Cookie header: accessToken=abc; Path=/; HttpOnly")
        XCTAssertFalse(redacted.contains("accessToken=abc"))
        XCTAssertTrue(redacted.contains("[redacted]"))
    }

    func testRedactsJWTShapedStrings() {
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0In0.signature"
        let redacted = SecretRedactor.redact("user jwt \(jwt) done")
        XCTAssertFalse(redacted.contains("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"))
        XCTAssertTrue(redacted.contains("[redacted]"))
        XCTAssertTrue(redacted.contains("done"))
    }
}
