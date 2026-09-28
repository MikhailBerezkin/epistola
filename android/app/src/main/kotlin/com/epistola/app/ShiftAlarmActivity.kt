package com.epistola.app

import android.app.Activity
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class ShiftAlarmActivity : Activity() {
    private var notificationId: Int = 0
    private var alarmTitle: String = "Будильник"

    private var actionInProgress = false
    private var touchStartY = 0f

    private var screenOffReceiverRegistered = false

    private val screenOffReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(
                context: Context?,
                intent: Intent?,
            ) {
                if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                    stopAlarmAndFinish()
                }
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        notificationId =
            intent.getIntExtra(
                ShiftAlarmReceiver.EXTRA_NOTIFICATION_ID,
                0,
            )

        alarmTitle =
            intent.getStringExtra(
                ShiftAlarmReceiver.EXTRA_TITLE,
            )
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: "Будильник"

        configureAlarmWindow()
        registerScreenOffReceiver()
        setContentView(buildContent())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        setIntent(intent)

        notificationId =
            intent.getIntExtra(
                ShiftAlarmReceiver.EXTRA_NOTIFICATION_ID,
                notificationId,
            )

        alarmTitle =
            intent.getStringExtra(
                ShiftAlarmReceiver.EXTRA_TITLE,
            )
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: alarmTitle

        actionInProgress = false

        setContentView(buildContent())
    }

    override fun dispatchTouchEvent(
        event: MotionEvent,
    ): Boolean {
        if (actionInProgress) {
            return true
        }

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                touchStartY = event.rawY
            }

            MotionEvent.ACTION_UP -> {
                val distance =
                    event.rawY - touchStartY

                val threshold =
                    dp(80).toFloat()

                if (abs(distance) >= threshold) {
                    if (distance < 0f) {
                        snoozeAlarm()
                    } else {
                        stopAlarmAndFinish()
                    }

                    return true
                }
            }
        }

        return super.dispatchTouchEvent(event)
    }

    override fun onDestroy() {
        unregisterScreenOffReceiver()
        super.onDestroy()
    }

    private fun configureAlarmWindow() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }

    private fun buildContent(): View {
        val root =
            FrameLayout(this).apply {
                setBackgroundColor(
                    Color.rgb(
                        18,
                        18,
                        20,
                    ),
                )
            }

        val snoozeButton =
            actionButton(
                text = "+10 минут",
                backgroundColor =
                    Color.rgb(
                        56,
                        88,
                        138,
                    ),
                action = {
                    snoozeAlarm()
                },
            )

        root.addView(
            snoozeButton,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(76),
            ).apply {
                gravity =
                    Gravity.TOP or
                        Gravity.CENTER_HORIZONTAL

                leftMargin = dp(24)
                rightMargin = dp(24)

                topMargin =
                    screenHeightQuarter() -
                        dp(38)
            },
        )

        val center =
            LinearLayout(this).apply {
                orientation =
                    LinearLayout.VERTICAL

                gravity =
                    Gravity.CENTER

                setPadding(
                    dp(28),
                    0,
                    dp(28),
                    0,
                )
            }

        root.addView(
            center,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity =
                    Gravity.CENTER
            },
        )

        center.addView(
            TextView(this).apply {
                text = "⏰"

                textSize = 60f

                gravity =
                    Gravity.CENTER

                setTextColor(
                    Color.WHITE,
                )
            },
        )

        center.addView(
            TextView(this).apply {
                text =
                    alarmTitle

                textSize = 28f

                gravity =
                    Gravity.CENTER

                setTextColor(
                    Color.WHITE,
                )

                setPadding(
                    0,
                    dp(20),
                    0,
                    dp(8),
                )
            },
        )

        center.addView(
            TextView(this).apply {
                text =
                    "Будильник рабочего календаря"

                textSize = 18f

                gravity =
                    Gravity.CENTER

                setTextColor(
                    Color.rgb(
                        190,
                        190,
                        195,
                    ),
                )
            },
        )

        center.addView(
            TextView(this).apply {
                text =
                    "Свайп вверх — +10 минут\n" +
                        "Свайп вниз — остановить"

                textSize = 15f

                gravity =
                    Gravity.CENTER

                setTextColor(
                    Color.rgb(
                        150,
                        150,
                        156,
                    ),
                )

                setPadding(
                    0,
                    dp(24),
                    0,
                    0,
                )
            },
        )

        val stopButton =
            actionButton(
                text = "Остановить",
                backgroundColor =
                    Color.rgb(
                        58,
                        62,
                        70,
                    ),
                action = {
                    stopAlarmAndFinish()
                },
            )

        root.addView(
            stopButton,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(76),
            ).apply {
                gravity =
                    Gravity.TOP or
                        Gravity.CENTER_HORIZONTAL

                leftMargin = dp(24)
                rightMargin = dp(24)

                topMargin =
                    screenHeightThreeQuarters() -
                        dp(38)
            },
        )

        return root
    }

    private fun actionButton(
        text: String,
        backgroundColor: Int,
        action: () -> Unit,
    ): TextView {
        return TextView(this).apply {
            this.text = text

            textSize = 22f

            gravity =
                Gravity.CENTER

            setTextColor(
                Color.WHITE,
            )

            isClickable = true
            isFocusable = true

            background =
                GradientDrawable().apply {
                    shape =
                        GradientDrawable.RECTANGLE

                    cornerRadius =
                        dp(18).toFloat()

                    setColor(
                        backgroundColor,
                    )
                }

            setOnClickListener {
                action()
            }
        }
    }

    private fun screenHeightQuarter(): Int {
        return resources.displayMetrics.heightPixels / 4
    }

    private fun screenHeightThreeQuarters(): Int {
        return (
            resources.displayMetrics.heightPixels *
                3
            ) / 4
    }

    private fun snoozeAlarm() {
        if (actionInProgress) {
            return
        }

        actionInProgress = true

        cancelCurrentNotification()

        val triggerAtMilliseconds =
            System.currentTimeMillis() +
                SNOOZE_MILLISECONDS

        ShiftAlarmNativeScheduler.schedule(
            context = this,
            notificationId = notificationId,
            title = alarmTitle,
            triggerAtMilliseconds =
                triggerAtMilliseconds,
        )

        finishAlarmActivity()
    }

    private fun stopAlarmAndFinish() {
        if (actionInProgress) {
            return
        }

        actionInProgress = true

        cancelCurrentNotification()

        ShiftAlarmNativeScheduler.cancel(
            context = this,
            notificationId = notificationId,
        )

        finishAlarmActivity()
    }

    private fun cancelCurrentNotification() {
        val notificationManager =
            getSystemService(
                Context.NOTIFICATION_SERVICE,
            ) as NotificationManager

        notificationManager.cancel(
            notificationId,
        )
    }

    private fun finishAlarmActivity() {
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
        )

        finishAndRemoveTask()
    }

    private fun registerScreenOffReceiver() {
        if (screenOffReceiverRegistered) {
            return
        }

        val filter =
            IntentFilter(
                Intent.ACTION_SCREEN_OFF,
            )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                screenOffReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(
                screenOffReceiver,
                filter,
            )
        }

        screenOffReceiverRegistered = true
    }

    private fun unregisterScreenOffReceiver() {
        if (!screenOffReceiverRegistered) {
            return
        }

        unregisterReceiver(
            screenOffReceiver,
        )

        screenOffReceiverRegistered = false
    }

    private fun dp(value: Int): Int {
        return (
            value *
                resources.displayMetrics.density
            ).toInt()
    }

    companion object {
        private const val SNOOZE_MILLISECONDS =
            10L * 60L * 1000L
    }
}