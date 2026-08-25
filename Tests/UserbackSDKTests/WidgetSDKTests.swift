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
}
