package com.moolash.jarpiggy.pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import java.math.BigDecimal
import java.util.Currency

class MainActivity : FlutterActivity() {
    private var facebookLogger: AppEventsLogger? = null
    private var facebookConfiguration: List<String>? = null
    private val pendingPurchases = mutableListOf<Pair<BigDecimal, Currency>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 沿用Dart既有channel名，不因Android包名变更而断开已有封装。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.example.pennyplicotcollectspin/facebook").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "initFacebook" -> {
                        val appId = call.argument<String>("app_id")?.trim().orEmpty()
                        val token = call.argument<String>("client_token")?.trim().orEmpty()
                        val name = call.argument<String>("app_name")?.trim().orEmpty()
                        require(appId.matches(Regex("^[0-9]+$")) && token.isNotEmpty() && name.isNotEmpty()) {
                            "Invalid Facebook configuration"
                        }
                        val configuration = listOf(appId, token, name)
                        if (facebookConfiguration != configuration || facebookLogger == null) {
                            FacebookSdk.setApplicationId(appId)
                            FacebookSdk.setClientToken(token)
                            FacebookSdk.setApplicationName(name)
                            @Suppress("DEPRECATION")
                            FacebookSdk.sdkInitialize(applicationContext)
                            FacebookSdk.setAutoLogAppEventsEnabled(true)
                            FacebookSdk.setAutoInitEnabled(true)
                            FacebookSdk.fullyInitialize()
                            facebookLogger = AppEventsLogger.newLogger(applicationContext, appId)
                            AppEventsLogger.activateApp(application, appId)
                            facebookConfiguration = configuration
                            pendingPurchases.forEach { (amount, currency) ->
                                facebookLogger!!.logPurchase(amount, currency)
                            }
                            pendingPurchases.clear()
                        }
                        result.success(null)
                    }
                    "logPurchase" -> {
                        val amount = call.argument<Number>("amount")?.toDouble()
                        require(amount != null && amount.isFinite() && amount >= 0) { "Invalid revenue" }
                        val currency = Currency.getInstance(call.argument<String>("currency")?.uppercase() ?: "USD")
                        val revenue = BigDecimal.valueOf(amount)
                        val logger = facebookLogger
                        // Firebase仍在获取配置时暂存，配置确定后只补报一次。
                        if (logger == null) pendingPurchases.add(revenue to currency)
                        else logger.logPurchase(revenue, currency)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("FACEBOOK_SDK_ERROR", error.message, null)
            }
        }
    }
}
