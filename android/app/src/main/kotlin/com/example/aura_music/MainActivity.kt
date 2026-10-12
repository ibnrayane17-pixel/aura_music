package com.example.aura_music

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteAudio" -> {
                        val ids = (call.argument<List<Any>>("ids") ?: emptyList())
                            .mapNotNull { (it as? Number)?.toLong() }
                        deleteAudio(ids, result)
                    }
                    "notificationsEnabled" -> {
                        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                        result.success(manager.areNotificationsEnabled())
                    }
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(true)
                    }
                    "notificationInfo" -> result.success(notificationInfo())
                    else -> result.notImplemented()
                }
            }
    }

    // ---------------------------------------------------------------------
    // Notification diagnosis (shown by the debug button in the app)
    // ---------------------------------------------------------------------
    private fun notificationInfo(): HashMap<String, Any> {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val info = HashMap<String, Any>()

        info["sdk"] = Build.VERSION.SDK_INT
        info["release"] = Build.VERSION.RELEASE ?: ""
        info["device"] = "${Build.MANUFACTURER} ${Build.MODEL}"
        info["enabled"] = manager.areNotificationsEnabled()
        info["permission"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        val channels = ArrayList<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            for (channel in manager.notificationChannels) {
                channels.add("${channel.id} (importance ${channel.importance})")
            }
        }
        info["channels"] = channels

        val active = ArrayList<String>()
        for (n in manager.activeNotifications) {
            val channelId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                n.notification.channelId ?: "-"
            } else {
                "-"
            }
            active.add("id ${n.id} / channel $channelId")
        }
        info["active"] = active

        @Suppress("DEPRECATION")
        val running = (getSystemService(ACTIVITY_SERVICE) as ActivityManager)
            .getRunningServices(100)
            .any { it.service.className.contains("AudioService") }
        info["serviceRunning"] = running

        return info
    }

    // ---------------------------------------------------------------------
    // Notifications (Android 13+ needs a runtime permission)
    // ---------------------------------------------------------------------
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == NOTIFICATION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    // ---------------------------------------------------------------------
    // Delete audio files
    // ---------------------------------------------------------------------
    private fun deleteAudio(ids: List<Long>, result: MethodChannel.Result) {
        if (ids.isEmpty()) {
            result.success(true)
            return
        }
        if (pendingDeleteResult != null) {
            result.error("busy", "Another delete request is running.", null)
            return
        }

        val uris = ids.map {
            ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, it)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+: the system asks the user to confirm the deletion.
                val sender = MediaStore.createDeleteRequest(contentResolver, uris).intentSender
                pendingDeleteResult = result
                startIntentSenderForResult(sender, DELETE_REQUEST_CODE, null, 0, 0, 0)
            } else {
                // Android 10 and older: direct delete (may be refused by the system).
                var deleted = 0
                for (uri in uris) {
                    deleted += contentResolver.delete(uri, null, null)
                }
                result.success(deleted > 0)
            }
        } catch (e: Exception) {
            pendingDeleteResult = null
            result.error("delete_failed", e.message, null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == DELETE_REQUEST_CODE) {
            pendingDeleteResult?.success(resultCode == Activity.RESULT_OK)
            pendingDeleteResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val CHANNEL = "com.auramusic/files"
        private const val DELETE_REQUEST_CODE = 4711
        private const val NOTIFICATION_REQUEST_CODE = 4712
    }
}