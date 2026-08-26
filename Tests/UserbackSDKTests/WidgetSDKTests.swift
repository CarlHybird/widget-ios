import XCTest
@testable import UserbackSDK

final class UserbackSDKTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(UserbackSDK.version(), "1.0.0")
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
