package com.nproject.nproject

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var latestIntent: Intent? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        latestIntent = intent
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        latestIntent = intent

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "nproject/share"
        ).setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
                val text = call.argument<String>("text").orEmpty()
                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(sendIntent, "Nproject 공유"))
                result.success(null)
            } else if (call.method == "getInitialListingId") {
                result.success(extractListingId(latestIntent?.data))
            } else {
                result.notImplemented()
            }
        }
    }

    private fun extractListingId(uri: Uri?): String? {
        if (uri == null) return null
        if (uri.scheme == "nproject" && uri.host == "listing") {
            return uri.pathSegments.firstOrNull()
        }
        return null
    }
}
