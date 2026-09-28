package com.epistola.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SCHEDULE -> {
                    val notificationId =
                        call.argument<Int>("notificationId")

                    val title =
                        call.argument<String>("title")

                    val triggerAtMilliseconds =
                        call.argument<Number>("triggerAtMilliseconds")
                            ?.toLong()

                    if (
                        notificationId == null ||
                        title.isNullOrBlank() ||
                        triggerAtMilliseconds == null
                    ) {
                        result.error(
                            "invalid_arguments",
                            "Missing shift alarm scheduling arguments.",
                            null,
                        )

                        return@setMethodCallHandler
                    }

                    result.success(
                        ShiftAlarmNativeScheduler.schedule(
                            context = this,
                            notificationId = notificationId,
                            title = title,
                            triggerAtMilliseconds =
                                triggerAtMilliseconds,
                        ),
                    )
                }

                METHOD_CANCEL -> {
                    val notificationId =
                        call.argument<Int>("notificationId")

                    if (notificationId == null) {
                        result.error(
                            "invalid_arguments",
                            "Missing shift alarm notification id.",
                            null,
                        )

                        return@setMethodCallHandler
                    }

                    ShiftAlarmNativeScheduler.cancel(
                        context = this,
                        notificationId = notificationId,
                    )

                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL_NAME =
            "epistola/shift_alarm"

        private const val METHOD_SCHEDULE =
            "schedule"

        private const val METHOD_CANCEL =
            "cancel"
    }
}