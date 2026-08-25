import Foundation

/// Helpers for talking to `v1.js` about a native screen recording.
///
/// `Feedback` lives inside the widget IIFE, so the page cannot call
/// `submitVideoCapture` unless a listener is registered in that same scope.
/// We splice one in next to the official `userback:nativeScreenshot` listener.
enum WidgetJavaScript {
    static let nativeScreenshotListener =
        "window.addEventListener(\"userback:nativeScreenshot\",e=>{e&&e.detail&&Feedback.handleMobileSdkScreenshotMessage(e.detail)})"

    static let nativeVideoListener = """
        ,window.addEventListener("userback:nativeVideo",e=>{if(!e||!e.detail)return;var d=e.detail,blob=d.blob||window.__ubNativeVideoBlob;if(!blob)return;if(Feedback.Tools&&typeof Feedback.Tools.submitVideoCapture==="function"){Feedback.Tools.submitVideoCapture(blob,[],d.mime_type||"video/mp4")}else{Feedback.removeScreenshotData&&Feedback.removeScreenshotData();Feedback.video_blob=blob;Feedback.video_url=window.URL.createObjectURL(blob);Feedback.video_mime_type=d.mime_type||"video/mp4";Feedback.controls_step=2;Feedback.showControls&&Feedback.showControls(!0);Feedback.addScreenshotBadge&&Feedback.addScreenshotBadge();Feedback.renderAttachment&&Feedback.renderAttachment(!0)}})
        """

    /// Inserts a `userback:nativeVideo` listener beside the screenshot one.
    /// Returns nil when the widget JS no longer contains the expected hook.
    static func withNativeVideoListener(_ source: String) -> String? {
        guard source.contains(nativeScreenshotListener) else { return nil }
        return source.replacingOccurrences(of: nativeScreenshotListener, with: nativeScreenshotListener + nativeVideoListener)
    }

    static func resetChunkBufferScript() -> String {
        "window.__ubNativeVideoChunks=[];window.__ubNativeVideoBlob=null;"
    }

    static func appendChunkScript(_ base64: String) -> String {
        "window.__ubNativeVideoChunks=window.__ubNativeVideoChunks||[];window.__ubNativeVideoChunks.push('\(base64)');"
    }

    static func assembleAndDispatchScript(mimeType: String = "video/mp4") -> String {
        """
        (function() {
            var parts = window.__ubNativeVideoChunks || [];
            window.__ubNativeVideoChunks = [];
            var b64 = parts.join('');
            if (!b64.length) return 'empty';
            var binary = atob(b64);
            var bytes = new Uint8Array(binary.length);
            for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
            window.__ubNativeVideoBlob = new Blob([bytes], { type: '\(mimeType)' });
            window.dispatchEvent(new CustomEvent('userback:nativeVideo', {
                detail: { type: 'native_video', mime_type: '\(mimeType)', mobileSDK: true }
            }));
            return 'ok';
        })();
        """
    }
}
