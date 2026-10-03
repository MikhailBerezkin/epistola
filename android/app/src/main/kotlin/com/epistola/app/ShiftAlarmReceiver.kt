package com.epistola.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat

class ShiftAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val notificationId =
            intent.getIntExtra(
                EXTRA_NOTIFICATION_ID,
                0,
            )

        val title =
            intent.getStringExtra(EXTRA_TITLE)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: "Будильник"

        ensureAlarmChannel(context)

        val alarmIntent =
            ShiftAlarmNativeScheduler.activityIntent(
                context = context,
                notificationId = notificationId,
                title = title,
            )

        val pendingIntent =
            PendingIntent.getActivity(
                context,
                notificationId,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE,
            )

        val notification =
            NotificationCompat.Builder(
                context,
                CHANNEL_ID,
            )
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(
                    "Будильник рабочего календаря",
                )
                .setCategory(
                    NotificationCompat.CATEGORY_ALARM,
                )
                .setPriority(
                    NotificationCompat.PRIORITY_MAX,
                )
                .setVisibility(
                    NotificationCompat.VISIBILITY_PUBLIC,
                )
                .setOngoing(true)
                .setAutoCancel(false)
                .setContentIntent(pendingIntent)
                .setFullScreenIntent(
                    pendingIntent,
                    true,
                )
                .build()

        notification.flags =
            notification.flags or
                Notification.FLAG_INSISTENT or
                Notification.FLAG_ONGOING_EVENT

        val notificationManager =
            context.getSystemService(
                Context.NOTIFICATION_SERVICE,
            ) as NotificationManager

        notificationManager.notify(
            notificationId,
            notification,
        )
    }

    private fun ensureAlarmChannel(
        context: Context,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager =
            context.getSystemService(
                Context.NOTIFICATION_SERVICE,
            ) as NotificationManager

        if (
            notificationManager
                .getNotificationChannel(CHANNEL_ID) != null
        ) {
            return
        }

        val alarmSound =
            RingtoneManager.getDefaultUri(
                RingtoneManager.TYPE_ALARM,
            )

        val audioAttributes =
            AudioAttributes.Builder()
                .setUsage(
                    AudioAttributes.USAGE_ALARM,
                )
                .setContentType(
                    AudioAttributes.CONTENT_TYPE_SONIFICATION,
                )
                .build()

        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Будильники смен Epistola",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description =
                    "Полноэкранные будильники рабочего календаря"

                enableVibration(true)

                setSound(
                    alarmSound,
                    audioAttributes,
                )
            }

        notificationManager.createNotificationChannel(
            channel,
        )
    }

    companion object {
        const val CHANNEL_ID =
            "epistola_shift_alarms_v3"

        const val EXTRA_NOTIFICATION_ID =
            "notificationId"

        const val EXTRA_TITLE =
            "title"
    }
}