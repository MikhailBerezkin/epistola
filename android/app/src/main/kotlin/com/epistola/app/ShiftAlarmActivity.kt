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
import android.widget.ImageView
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

        window.statusBarColor =
            Color.rgb(
                3,
                11,
                20,
            )

        window.navigationBarColor =
            Color.rgb(
                3,
                10,
                18,
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
        val width = screenWidth()
        val height = screenHeight()

        val root =
            FrameLayout(this).apply {
                background =
                    GradientDrawable(
                        GradientDrawable.Orientation.TOP_BOTTOM,
                        intArrayOf(
                            Color.rgb(
                                3,
                                12,
                                22,
                            ),
                            Color.rgb(
                                5,
                                20,
                                34,
                            ),
                            Color.rgb(
                                5,
                                18,
                                31,
                            ),
                            Color.rgb(
                                3,
                                10,
                                18,
                            ),
                        ),
                    )
            }

        addArtwork(
            root = root,
            screenWidth = width,
            screenHeight = height,
        )

        val snoozeButton =
            actionButton(
                text = "+10 минут",
                iconResId =
                    R.drawable.shift_alarm_snooze_icon,
                startColor =
                    Color.argb(
                        232,
                        40,
                        82,
                        132,
                    ),
                endColor =
                    Color.argb(
                        238,
                        15,
                        43,
                        76,
                    ),
                strokeColor =
                    Color.rgb(
                        132,
                        202,
                        255,
                    ),
                glowColor =
                    Color.argb(
                        90,
                        70,
                        165,
                        255,
                    ),
                action = {
                    snoozeAlarm()
                },
            )

        root.addView(
            snoozeButton,
            alarmButtonLayoutParams(
                centerY =
                    (height * 0.25f).toInt(),
            ),
        )

        val stopButton =
            actionButton(
                text = "Отключить",
                iconResId =
                    R.drawable.shift_alarm_stop_icon,
                startColor =
                    Color.argb(
                        238,
                        145,
                        32,
                        43,
                    ),
                endColor =
                    Color.argb(
                        242,
                        78,
                        16,
                        25,
                    ),
                strokeColor =
                    Color.rgb(
                        255,
                        91,
                        101,
                    ),
                glowColor =
                    Color.argb(
                        105,
                        255,
                        55,
                        67,
                    ),
                action = {
                    stopAlarmAndFinish()
                },
            )

        root.addView(
            stopButton,
            alarmButtonLayoutParams(
                centerY =
                    (height * 0.75f).toInt(),
            ),
        )

        return root
    }

    private fun addArtwork(
        root: FrameLayout,
        screenWidth: Int,
        screenHeight: Int,
    ) {
        /*
         * Исходная картинка квадратная.
         *
         * Поэтому не растягиваем её на весь портретный экран
         * и не используем CENTER_CROP.
         *
         * Высота изображения равна ширине экрана:
         * квадрат всегда показывается полностью.
         */
        val artworkSize =
            screenWidth

        /*
         * Центр всей квадратной картинки.
         *
         * Сама чайка в исходнике находится немного ниже
         * геометрического центра, поэтому 55.5% даёт
         * визуальный центр чайки примерно на 57–58%.
         */
        val artworkCenterY =
            (screenHeight * 0.555f).toInt()

        val artworkTop =
            artworkCenterY -
                artworkSize / 2

        val artworkImage =
            ImageView(this).apply {
                setImageResource(
                    R.drawable.shift_alarm_seagull_background,
                )

                scaleType =
                    ImageView.ScaleType.FIT_CENTER

                adjustViewBounds = false
            }

        root.addView(
            artworkImage,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                artworkSize,
            ).apply {
                gravity =
                    Gravity.TOP or
                        Gravity.CENTER_HORIZONTAL

                topMargin =
                    artworkTop
            },
        )

        /*
         * Мягкий градиент по верхнему и нижнему краю
         * квадратной картинки.
         *
         * Благодаря этому квадрат визуально превращается
         * в часть полноэкранного фона.
         */
        val artworkFade =
            View(this).apply {
                background =
                    GradientDrawable(
                        GradientDrawable.Orientation.TOP_BOTTOM,
                        intArrayOf(
                            Color.argb(
                                235,
                                3,
                                12,
                                22,
                            ),
                            Color.argb(
                                75,
                                3,
                                12,
                                22,
                            ),
                            Color.TRANSPARENT,
                            Color.TRANSPARENT,
                            Color.argb(
                                65,
                                3,
                                10,
                                18,
                            ),
                            Color.argb(
                                225,
                                3,
                                10,
                                18,
                            ),
                        ),
                    )
            }

        root.addView(
            artworkFade,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                artworkSize,
            ).apply {
                gravity =
                    Gravity.TOP or
                        Gravity.CENTER_HORIZONTAL

                topMargin =
                    artworkTop
            },
        )

        /*
         * В исходном artwork справа снизу есть 19/4.
         *
         * Вместо грубой заплатки используем диагональное
         * затемнение края. Оно заодно делает изображение
         * ближе к нашему рендеру.
         */
        val cornerFadeSize =
            (screenWidth * 0.42f).toInt()

        val cornerFade =
            View(this).apply {
                background =
                    GradientDrawable(
                        GradientDrawable.Orientation.BR_TL,
                        intArrayOf(
                            Color.argb(
                                255,
                                3,
                                10,
                                18,
                            ),
                            Color.argb(
                                235,
                                3,
                                10,
                                18,
                            ),
                            Color.argb(
                                125,
                                3,
                                10,
                                18,
                            ),
                            Color.TRANSPARENT,
                        ),
                    )
            }

        root.addView(
            cornerFade,
            FrameLayout.LayoutParams(
                cornerFadeSize,
                cornerFadeSize,
            ).apply {
                gravity =
                    Gravity.TOP or
                        Gravity.END

                topMargin =
                    artworkTop +
                        artworkSize -
                        cornerFadeSize
            },
        )
    }

    private fun alarmButtonLayoutParams(
        centerY: Int,
    ): FrameLayout.LayoutParams {
        val width =
            screenWidth()

        val buttonWidth =
            (width * 0.76f)
                .toInt()

        val buttonHeight =
            (width * 0.18f)
                .toInt()
                .coerceIn(
                    dp(64),
                    dp(78),
                )

        return FrameLayout.LayoutParams(
            buttonWidth,
            buttonHeight,
        ).apply {
            gravity =
                Gravity.TOP or
                    Gravity.CENTER_HORIZONTAL

            topMargin =
                centerY -
                    buttonHeight / 2
        }
    }

    private fun actionButton(
        text: String,
        iconResId: Int,
        startColor: Int,
        endColor: Int,
        strokeColor: Int,
        glowColor: Int,
        action: () -> Unit,
    ): View {
        val outer =
            FrameLayout(this).apply {
                clipChildren = false
                clipToPadding = false
            }

        val glow =
            View(this).apply {
                alpha = 0.42f

                scaleX = 1.035f
                scaleY = 1.10f

                background =
                    GradientDrawable().apply {
                        shape =
                            GradientDrawable.RECTANGLE

                        cornerRadius =
                            dp(42).toFloat()

                        setColor(
                            glowColor,
                        )
                    }
            }

        outer.addView(
            glow,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        val button =
            LinearLayout(this).apply {
                orientation =
                    LinearLayout.HORIZONTAL

                gravity =
                    Gravity.CENTER

                isClickable = true
                isFocusable = true

                elevation =
                    dp(10).toFloat()

                setPadding(
                    dp(24),
                    0,
                    dp(24),
                    0,
                )

                background =
                    GradientDrawable(
                        GradientDrawable.Orientation.TOP_BOTTOM,
                        intArrayOf(
                            startColor,
                            endColor,
                        ),
                    ).apply {
                        shape =
                            GradientDrawable.RECTANGLE

                        cornerRadius =
                            dp(40).toFloat()

                        setStroke(
                            dp(1),
                            strokeColor,
                        )
                    }

                setOnClickListener {
                    action()
                }
            }

        outer.addView(
            button,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        val icon =
            ImageView(this).apply {
                setImageResource(
                    iconResId,
                )

                scaleType =
                    ImageView.ScaleType.CENTER_INSIDE
            }

        button.addView(
            icon,
            LinearLayout.LayoutParams(
                dp(34),
                dp(34),
            ).apply {
                marginEnd =
                    dp(22)
            },
        )

        val label =
            TextView(this).apply {
                this.text =
                    text

                textSize =
                    21f

                gravity =
                    Gravity.CENTER

                includeFontPadding =
                    false

                setTextColor(
                    Color.WHITE,
                )
            }

        button.addView(
            label,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        return outer
    }

    private fun screenWidth(): Int {
        return resources.displayMetrics.widthPixels
    }

    private fun screenHeight(): Int {
        return resources.displayMetrics.heightPixels
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

        if (Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.TIRAMISU
        ) {
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

    private fun dp(
        value: Int,
    ): Int {
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