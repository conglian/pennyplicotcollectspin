package com.pennyp.licote.spins

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** Flutter 显式请求时调用原生 create，宿主 Activity 正常卸载时调用原生 clear。 */
class Penyplicotcollectspinsh5Plugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var createdActivity: Activity? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "penyplicotcollectspinsh5")
        channel.setMethodCallHandler(this)
        pageLogChannel = channel
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "penyplicotcollectspinsh5/webview", PCH5WebViewFactory()
        )
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "create" -> {
                val current = activity
                if (current == null || current.isFinishing || current.isDestroyed) {
                    result.error("H5_NO_ACTIVITY", "An active Android Activity is required", null)
                    return
                }
                if (createdActivity === current) {
                    result.success(null)
                    return
                }
                try {
                    Log.i(TAG, "[H5] create invoked")
                    Penyplicotcollectspinsh5Class.create(current)
                    createdActivity = current
                    // Java 内部仍保留原有异常处理，此日志仅表示入口调用已返回。
                    Log.i(TAG, "[H5] create returned")
                    result.success(null)
                } catch (error: Exception) {
                    reportCreateFailure(error, result)
                } catch (error: LinkageError) {
                    reportCreateFailure(error, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun reportCreateFailure(error: Throwable, result: Result) {
        Log.e(TAG, "[H5] create failed (${error.javaClass.simpleName})")
        result.error("H5_CREATE_FAILED", "Native H5 create failed", null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        val previous = activity
        // 先释放引用，后续 engine detach 或重复回调不会再次清理同一宿主。
        detachActivity()
        if (previous == null) return
        try {
            Log.i(TAG, "[H5] clear invoked")
            Penyplicotcollectspinsh5Class.clear(previous)
            Log.i(TAG, "[H5] clear returned")
        } catch (error: Throwable) {
            // JNI 或视图清理异常不能打断宿主的退出流程。
            Log.e(TAG, "[H5] clear failed (${error.javaClass.simpleName})")
        }
    }

    private fun detachActivity() {
        activity = null
        createdActivity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (pageLogChannel === channel) pageLogChannel = null
        channel.setMethodCallHandler(null)
        detachActivity()
    }

    companion object {
        private const val TAG = "PennyPilotH5"
        private val mainHandler = Handler(Looper.getMainLooper())
        @Volatile private var pageLogChannel: MethodChannel? = null

        /** WebView 回调转到 Flutter；引擎卸载后丢弃旧消息，不持有 Activity。 */
        @JvmStatic
        fun forwardPageLog(event: String, url: String?) {
            if (url.isNullOrBlank()) return
            val target = pageLogChannel ?: return
            mainHandler.post {
                if (pageLogChannel !== target) return@post
                try {
                    target.invokeMethod("onPageLog", mapOf("event" to event, "url" to url))
                } catch (error: RuntimeException) {
                    Log.w(TAG, "[H5] page log forwarding failed (${error.javaClass.simpleName})")
                }
            }
        }
    }
}
