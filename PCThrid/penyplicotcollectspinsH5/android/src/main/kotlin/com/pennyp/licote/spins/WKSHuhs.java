package com.pennyp.licote.spins;

import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.util.Log;
import androidx.annotation.Keep;


@Keep
public class WKSHuhs extends WebViewClient {

    @Override
    @Keep
    public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
        super.onPageStarted(view, url, favicon);
    }

    @Override
    @Keep
    public void onPageFinished(WebView view, String url) {
        super.onPageFinished(view, url);
    }
}
