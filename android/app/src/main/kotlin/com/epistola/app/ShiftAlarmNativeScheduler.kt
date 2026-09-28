package com.epistola.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object ShiftAlarmNativeScheduler {
    fun schedule(
        context: Context,
        notificationId: Int,
        title: String,
        triggerAtMilliseconds: Long,
    ): Boolean {
        if (triggerAtMilliseconds <= System.currentTimeMillis()) {
            cancel(
                context = context,
                notificationId = notificationId,
            )

            return false
        }

        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val operation = PendingIntent.getBroadcast(
            context,
            notificationId,
            receiverIntent(
                context = context,
                notificationId = notificationId,
                title = title,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE,
        )

        val showIntent = PendingIntent.getActivity(
            context,
            notificationId,
            activityIntent(
                context = context,
                notificationId = notificationId,
                title = title,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE,
        )

        return try {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(
                    triggerAtMilliseconds,
                    showIntent,
                ),
                operation,
            )

            true
        } catch (_: SecurityException) {
            false
        }
    }

    fun cancel(
        context: Context,
        notificationId: Int,
    ) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val operation = PendingIntent.getBroadcast(
            context,
            notificationId,
            Intent(
                context,
                ShiftAlarmReceiver::class.java,
            ),
            PendingIntent.FLAG_NO_CREATE or
                PendingIntent.FLAG_IMMUTABLE,
        )

        if (operation != null) {
            alarmManager.cancel(operation)
            operation.cancel()
        }
    }

    fun activityIntent(
        context: Context,
        notificationId: Int,
        title: String,
    ): Intent {
        return Intent(
            context,
            ShiftAlarmActivity::class.java,
        ).apply {
            putExtra(
                ShiftAlarmReceiver.EXTRA_NOTIFICATION_ID,
                notificationId,
            )

            putExtra(
                ShiftAlarmReceiver.EXTRA_TITLE,
                title,
            )

            flags =
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
    }

    private fun receiverIntent(
        context: Context,
        notificationId: Int,
        title: String,
    ): Intent {
        return Intent(
            context,
            ShiftAlarmReceiver::class.java,
        ).apply {
            putExtra(
                ShiftAlarmReceiver.EXTRA_NOTIFICATION_ID,
                notificationId,
            )

            putExtra(
                ShiftAlarmReceiver.EXTRA_TITLE,
                title,
            )
        }
    }
}