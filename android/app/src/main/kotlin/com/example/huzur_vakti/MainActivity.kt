package com.example.huzur_vakti

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.huzur_vakti.alarm.AlarmReceiver
import com.example.huzur_vakti.dnd.PrayerDndScheduler
import com.example.huzur_vakti.widgets.WidgetUpdateReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val dndChannelName = "huzur_vakti/dnd"
	private val permissionsChannelName = "huzur_vakti/permissions"
	private val widgetsChannelName = "huzur_vakti/widgets"
	private val alarmChannelName = "huzur_vakti/alarms"
	private val NOTIFICATION_PERMISSION_CODE = 1001

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		// Vibration Handler
		VibrationHandler.setup(flutterEngine, this)

		// Widget Channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetsChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"scheduleWidgetUpdates" -> {
						WidgetUpdateReceiver.scheduleWidgetUpdates(this)
						result.success(true)
					}
					"cancelWidgetUpdates" -> {
						WidgetUpdateReceiver.cancelWidgetUpdates(this)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}

		// Alarm Channel - Vakit alarmları için
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"scheduleAlarm" -> {
						val prayerName = call.argument<String>("prayerName") ?: ""
						val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
						val soundPath = call.argument<String>("soundPath")
						val useVibration = call.argument<Boolean>("useVibration") ?: true
						val alarmId = call.argument<Int>("alarmId") ?: prayerName.hashCode()

						if (prayerName.isNotEmpty() && triggerAtMillis > System.currentTimeMillis()) {
							AlarmReceiver.scheduleAlarm(
								context = this,
								alarmId = alarmId,
								prayerName = prayerName,
								triggerAtMillis = triggerAtMillis,
								soundPath = soundPath,
								useVibration = useVibration
							)
							result.success(true)
						} else {
							result.success(false)
						}
					}
					"cancelAlarm" -> {
						val alarmId = call.argument<Int>("alarmId") ?: 0
						AlarmReceiver.cancelAlarm(this, alarmId)
						result.success(true)
					}
					"cancelAllAlarms" -> {
						AlarmReceiver.cancelAllAlarms(this)
						result.success(true)
					}
					"isAlarmPlaying" -> {
						result.success(com.example.huzur_vakti.alarm.AlarmService.isAlarmPlaying())
					}
					"stopAlarm" -> {
						val stopIntent = Intent(this, com.example.huzur_vakti.alarm.AlarmService::class.java)
						stopIntent.action = com.example.huzur_vakti.alarm.AlarmService.ACTION_STOP_ALARM
						startService(stopIntent)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}

		// DND Channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, dndChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"hasPolicyAccess" -> {
						val manager = getSystemService(NotificationManager::class.java)
						result.success(manager.isNotificationPolicyAccessGranted)
					}
					"openPolicySettings" -> {
						val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
						intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(true)
					}
					"scheduleDnd" -> {
						val manager = getSystemService(NotificationManager::class.java)
						if (!manager.isNotificationPolicyAccessGranted) {
							result.success(false)
							return@setMethodCallHandler
						}

						val entries = call.argument<List<Map<String, Any>>>("entries") ?: emptyList()
						val parsed = entries.mapNotNull { entry ->
							val startAt = (entry["startAt"] as? Number)?.toLong() ?: return@mapNotNull null
							val duration = (entry["durationMinutes"] as? Number)?.toInt() ?: 30
							val label = entry["label"]?.toString() ?: "Vakit"
							PrayerDndScheduler.DndEntry(startAt, duration, label)
						}
						PrayerDndScheduler.schedule(this, parsed)
						result.success(true)
					}
					"cancelDnd" -> {
						PrayerDndScheduler.cancelAll(this)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}

		// Permissions Channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"requestNotificationPermission" -> {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
							if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) 
								!= PackageManager.PERMISSION_GRANTED) {
								ActivityCompat.requestPermissions(
									this,
									arrayOf(Manifest.permission.POST_NOTIFICATIONS),
									NOTIFICATION_PERMISSION_CODE
								)
								result.success(false)
							} else {
								result.success(true)
							}
						} else {
							result.success(true)
						}
					}
					"hasOverlayPermission" -> {
						result.success(Settings.canDrawOverlays(this))
					}
					"openOverlaySettings" -> {
						val intent = Intent(
							Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
							Uri.parse("package:$packageName")
						)
						intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(true)
					}
					"hasExactAlarmPermission" -> {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
							val alarmManager = getSystemService(AlarmManager::class.java)
							result.success(alarmManager.canScheduleExactAlarms())
						} else {
							result.success(true)
						}
					}
					"openExactAlarmSettings" -> {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
							val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
							intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							startActivity(intent)
						}
						result.success(true)
					}
					"isBatteryOptimizationDisabled" -> {
						val powerManager = getSystemService(PowerManager::class.java)
						result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
					}
					"requestBatteryOptimizationExemption" -> {
						val powerManager = getSystemService(PowerManager::class.java)
						if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
							val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
							intent.data = Uri.parse("package:$packageName")
							intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							startActivity(intent)
						}
						result.success(true)
					}
					"openBatteryOptimizationSettings" -> {
						val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
						intent.data = Uri.parse("package:$packageName")
						intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}
	}
}
