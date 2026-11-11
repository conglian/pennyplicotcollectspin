package com.pennyp.licote.spins

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Games 页面使用独立 WebView，真实绑定本地 WKSHuhs 监听加载过程。 */
internal class PCH5WebViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val url = (args as? Map<*, *>)?.get("url") as? String
        require(!url.isNullOrBlank() && Uri.parse(url).scheme in listOf("http", "https")) {
            "A valid HTTP(S) H5 URL is required"
        }
        return PCH5PlatformWebView(context, url)
    }
}

@SuppressLint("SetJavaScriptEnabled")
private class PCH5PlatformWebView(context: Context, url: String) : PlatformView {
    private val webView = WebView(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        )
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        webViewClient = WKSHuhs()
        webChromeClient = WebChromeClient()
        loadUrl(url)
    }
    private var disposed = false

    override fun getView(): View = webView

    override fun dispose() {
        if (disposed) return
        disposed = true
        // 只销毁当前网页，不调用会移除整个宿主视图的 SDK clear。
        webView.stopLoading()
        webView.webViewClient = WebViewClient()
        webView.webChromeClient = null
        (webView.parent as? ViewGroup)?.removeView(webView)
        webView.destroy()
    }
}
