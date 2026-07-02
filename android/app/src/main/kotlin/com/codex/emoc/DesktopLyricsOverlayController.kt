package com.codex.emoc

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Point
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import kotlin.math.roundToInt

class DesktopLyricsOverlayController(private val context: Context) {
    private val windowManager =
        context.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val prefs = context.applicationContext.getSharedPreferences("emoc", Context.MODE_PRIVATE)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var rootView: FrameLayout? = null
    private var backgroundView: View? = null
    private var lyricView: TextView? = null
    private var handleView: View? = null
    private var leftHandleView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var backgroundAnimator: ValueAnimator? = null
    private var textColorAnimator: ValueAnimator? = null

    private var opacity = prefs.getString("desktopLyricsOpacity", "0.42")
        ?.toFloatOrNull()
        ?.coerceIn(0f, 0.85f) ?: 0.42f
    private var fontSize = prefs.getString("desktopLyricsFontSize", "18")
        ?.toFloatOrNull()
        ?.coerceIn(14f, 32f) ?: 18f
    private var fontWeight = prefs.getString("desktopLyricsFontWeight", "800")
        ?.toIntOrNull()
        ?.coerceIn(300, 900) ?: 800
    private var locked = prefs.getString("desktopLyricsLocked", "false") == "true"
    private var multiLine = prefs.getString("desktopLyricsMultiLine", "false") == "true"
    private var centerLineLocked =
        prefs.getString("desktopLyricsCenterLineLocked", "false") == "true"
    private var autoHideInForeground =
        prefs.getString("desktopLyricsAutoHideInForeground", "false") == "true"
    private var followDynamicColor =
        prefs.getString("desktopLyricsFollowDynamicColor", "false") == "true"
    private var backgroundColor = prefs.getInt("desktopLyricsBackgroundColor", Color.BLACK)
    private var textColor = prefs.getInt("desktopLyricsTextColor", Color.WHITE)
    private var currentText = "用音乐安放此刻"
    private var renderedBackgroundColor = desktopBackgroundColor()
    private var renderedTextColor = textColor
    private var lastMinOverlayHeight = minOverlayHeight()
    private var appInForeground = false
    private val hideHandleRunnable = Runnable { fadeHandleOut() }

    fun setEnabled(enabled: Boolean, requestPermission: Boolean): Boolean {
        if (!enabled) {
            hide()
            return false
        }
        if (!canDrawOverlays()) {
            if (requestPermission) openOverlayPermissionSettings()
            return false
        }
        show()
        return true
    }

    fun updateStyle(
        opacity: Float,
        fontSize: Float,
        fontWeight: Int,
        locked: Boolean,
        multiLine: Boolean,
        centerLineLocked: Boolean,
        autoHideInForeground: Boolean,
        followDynamicColor: Boolean,
        backgroundColor: Int,
        textColor: Int
    ) {
        this.opacity = opacity.coerceIn(0f, 0.85f)
        this.fontSize = fontSize.coerceIn(14f, 32f)
        this.fontWeight = fontWeight.coerceIn(300, 900)
        this.locked = locked
        this.multiLine = multiLine
        this.centerLineLocked = centerLineLocked
        this.autoHideInForeground = autoHideInForeground
        this.followDynamicColor = followDynamicColor
        this.backgroundColor = backgroundColor
        this.textColor = textColor
        prefs.edit()
            .putString("desktopLyricsOpacity", this.opacity.toString())
            .putString("desktopLyricsFontSize", this.fontSize.toString())
            .putString("desktopLyricsFontWeight", this.fontWeight.toString())
            .putString("desktopLyricsLocked", this.locked.toString())
            .putString("desktopLyricsMultiLine", this.multiLine.toString())
            .putString("desktopLyricsCenterLineLocked", this.centerLineLocked.toString())
            .putString("desktopLyricsAutoHideInForeground", this.autoHideInForeground.toString())
            .putString("desktopLyricsFollowDynamicColor", this.followDynamicColor.toString())
            .putInt("desktopLyricsBackgroundColor", this.backgroundColor)
            .putInt("desktopLyricsTextColor", this.textColor)
            .apply()
        applyStyle()
    }

    fun setAppInForeground(inForeground: Boolean) {
        appInForeground = inForeground
        applyForegroundVisibility(animated = true)
    }

    fun updateText(text: String, title: String, artist: String) {
        currentText = text.ifBlank {
            listOf(title, artist)
                .filter { it.isNotBlank() }
                .joinToString(" · ")
                .ifBlank { "用音乐安放此刻" }
        }
        lyricView?.text = currentText
    }

    fun release() {
        hide()
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)
    }

    private fun openOverlayPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun show() {
        if (rootView != null) {
            applyStyle()
            return
        }
        val view = createView()
        rootView = view
        lyricView?.text = currentText
        val params = createLayoutParams()
        layoutParams = params
        applyStyle()
        try {
            windowManager.addView(view, params)
        } catch (_: Exception) {
            rootView = null
            backgroundView = null
            lyricView = null
            handleView = null
            layoutParams = null
        }
    }

    private fun hide() {
        val view = rootView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: Exception) {
        }
        backgroundAnimator?.cancel()
        backgroundAnimator = null
        textColorAnimator?.cancel()
        textColorAnimator = null
        mainHandler.removeCallbacks(hideHandleRunnable)
        rootView = null
        backgroundView = null
        lyricView = null
        handleView = null
        leftHandleView = null
        layoutParams = null
    }

    private data class ScreenBounds(val width: Int, val height: Int)

    private fun screenBounds(): ScreenBounds {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            return ScreenBounds(bounds.width().coerceAtLeast(1), bounds.height().coerceAtLeast(1))
        }
        val size = Point()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealSize(size)
        return ScreenBounds(size.x.coerceAtLeast(1), size.y.coerceAtLeast(1))
    }

    private fun centeredX(width: Int, bounds: ScreenBounds): Int {
        return ((bounds.width - width) / 2).coerceAtLeast(0)
    }

    private fun createLayoutParams(): WindowManager.LayoutParams {
        val bounds = screenBounds()
        val defaultWidth = 320.dp()
        val defaultHeight = minOverlayHeight()
        val minWidth = minOverlayWidth()
        val minHeight = minOverlayHeight()
        lastMinOverlayHeight = minHeight
        val width = prefs.getInt("desktopLyricsWidth", defaultWidth)
            .coerceIn(minWidth, (bounds.width - 24.dp()).coerceAtLeast(minWidth))
        val height = prefs.getInt("desktopLyricsHeight", defaultHeight)
            .coerceIn(minHeight, (bounds.height - 32.dp()).coerceAtLeast(minHeight))
        val savedX = prefs.getInt("desktopLyricsX", 24.dp())
        val x = if (centerLineLocked) {
            centeredX(width, bounds)
        } else {
            savedX.coerceIn(0, (bounds.width - width).coerceAtLeast(0))
        }
        val y = prefs.getInt("desktopLyricsY", 120.dp())
            .coerceIn(0, (bounds.height - height).coerceAtLeast(0))
        return WindowManager.LayoutParams(
            width,
            height,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            overlayFlags(),
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            this.y = y
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createView(): FrameLayout {
        val root = FrameLayout(context.applicationContext).apply {
            clipChildren = true
            clipToPadding = true
            setWillNotDraw(false)
            setBackgroundColor(Color.TRANSPARENT)
        }
        val background = View(context.applicationContext).apply {
            setBackground(desktopBackgroundDrawable(renderedBackgroundColor))
        }
        val text = TextView(context.applicationContext).apply {
            gravity = Gravity.CENTER
            includeFontPadding = true
            setTextColor(textColor)
            typeface = desktopTypeface()
            setShadowLayer(5f, 0f, 1.5f, Color.argb(175, 0, 0, 0))
            setSingleLine(false)
            ellipsize = TextUtils.TruncateAt.END
            setLineSpacing(2.dp().toFloat(), 1.0f)
            setPadding(18.dp(), 10.dp(), 18.dp(), 10.dp())
        }
        val leftHandle = ResizeCornerView(context.applicationContext, ResizeCorner.LEFT).apply {
            alpha = 0f
            visibility = View.GONE
        }
        val handle = ResizeCornerView(context.applicationContext, ResizeCorner.RIGHT).apply {
            alpha = 0f
            visibility = View.GONE
        }
        root.addView(
            background,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
        root.addView(
            text,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
        root.addView(
            leftHandle,
            FrameLayout.LayoutParams(36.dp(), 36.dp(), Gravity.BOTTOM or Gravity.START).apply {
                marginStart = 12.dp()
                bottomMargin = 10.dp()
            }
        )
        root.addView(
            handle,
            FrameLayout.LayoutParams(36.dp(), 36.dp(), Gravity.BOTTOM or Gravity.END).apply {
                marginEnd = 12.dp()
                bottomMargin = 10.dp()
            }
        )
        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0
        var startWidth = 0
        var startHeight = 0
        var resizing = false
        var resizingLeft = false
        root.setOnTouchListener { _, event ->
            if (locked) return@setOnTouchListener false
            val params = layoutParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = params.x
                    startY = params.y
                    startWidth = params.width
                    startHeight = params.height
                    val nearBottom = event.y >= root.height - 34.dp()
                    val nearLeft = event.x <= 44.dp()
                    val nearRight = event.x >= root.width - 44.dp()
                    resizing = nearBottom && (nearLeft || nearRight)
                    resizingLeft = resizing && nearLeft
                    showHandle()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downRawX).roundToInt()
                    val dy = (event.rawY - downRawY).roundToInt()
                    if (resizing) {
                        if (resizingLeft) {
                            resizeFromLeft(params, startX, startWidth, startHeight, dx, dy)
                        } else {
                            resize(params, startWidth + dx, startHeight + dy)
                        }
                    } else {
                        move(params, startX + dx, startY + dy)
                    }
                    showHandle()
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    saveBounds(params)
                    scheduleHandleHide()
                    true
                }
                else -> false
            }
        }
        backgroundView = background
        lyricView = text
        handleView = handle
        leftHandleView = leftHandle
        return root
    }

    private fun move(params: WindowManager.LayoutParams, nextX: Int, nextY: Int) {
        val bounds = screenBounds()
        params.x = if (centerLineLocked) {
            centeredX(params.width, bounds)
        } else {
            nextX.coerceIn(0, (bounds.width - params.width).coerceAtLeast(0))
        }
        params.y = nextY.coerceIn(0, (bounds.height - params.height).coerceAtLeast(0))
        updateLayout(params)
    }

    private fun resize(params: WindowManager.LayoutParams, nextWidth: Int, nextHeight: Int) {
        val bounds = screenBounds()
        val minWidth = minOverlayWidth()
        val minHeight = minOverlayHeight()
        val maxWidth = (bounds.width - 24.dp()).coerceAtLeast(minWidth)
        val maxHeight = (bounds.height - 32.dp()).coerceAtLeast(minHeight)
        params.width = nextWidth.coerceIn(minWidth, maxWidth)
        params.height = nextHeight.coerceIn(minHeight, maxHeight)
        params.x = if (centerLineLocked) {
            centeredX(params.width, bounds)
        } else {
            params.x.coerceIn(0, (bounds.width - params.width).coerceAtLeast(0))
        }
        params.y = params.y.coerceIn(0, (bounds.height - params.height).coerceAtLeast(0))
        updateLayout(params)
    }

    private fun resizeFromLeft(
        params: WindowManager.LayoutParams,
        startX: Int,
        startWidth: Int,
        startHeight: Int,
        dx: Int,
        dy: Int
    ) {
        val bounds = screenBounds()
        val minWidth = minOverlayWidth()
        val minHeight = minOverlayHeight()
        val maxWidth = (bounds.width - 24.dp()).coerceAtLeast(minWidth)
        val maxHeight = (bounds.height - 32.dp()).coerceAtLeast(minHeight)
        val width = (startWidth - dx).coerceIn(minWidth, maxWidth)
        params.width = width
        params.height = (startHeight + dy).coerceIn(minHeight, maxHeight)
        params.x = if (centerLineLocked) {
            centeredX(params.width, bounds)
        } else {
            val rightEdge = startX + startWidth
            (rightEdge - params.width).coerceIn(0, (bounds.width - params.width).coerceAtLeast(0))
        }
        params.y = params.y.coerceIn(0, (bounds.height - params.height).coerceAtLeast(0))
        updateLayout(params)
    }

    private fun updateLayout(params: WindowManager.LayoutParams) {
        rootView?.let {
            try {
                windowManager.updateViewLayout(it, params)
            } catch (_: Exception) {
            }
        }
    }

    private fun applyStyle() {
        animateBackgroundColor()
        animateTextColor()
        lyricView?.apply {
            typeface = desktopTypeface()
            setShadowLayer(5f, 0f, 1.5f, Color.argb(175, 0, 0, 0))
            textSize = fontSize
            maxLines = maxDisplayLines()
            text = currentText
        }
        if (locked) {
            mainHandler.removeCallbacks(hideHandleRunnable)
            handleView?.animate()?.cancel()
            handleView?.visibility = View.GONE
            handleView?.alpha = 0f
            leftHandleView?.animate()?.cancel()
            leftHandleView?.visibility = View.GONE
            leftHandleView?.alpha = 0f
        }
        layoutParams?.let {
            ensureReadableBounds(it)
            it.flags = overlayFlags()
            updateLayout(it)
            saveBounds(it)
        }
        applyForegroundVisibility(animated = true)
    }

    private fun desktopBackgroundDrawable(color: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 12.dp().toFloat()
            setColor(color)
        }
    }

    private fun desktopBackgroundColor(): Int {
        val alpha = (opacity.toDouble() * 255.0).roundToInt().coerceIn(0, 255)
        return (alpha shl 24) or (backgroundColor and 0x00FFFFFF)
    }

    private fun animateBackgroundColor() {
        val target = desktopBackgroundColor()
        val view = backgroundView
        if (view == null) {
            renderedBackgroundColor = target
            return
        }
        if (renderedBackgroundColor == target) {
            view.setBackground(desktopBackgroundDrawable(target))
            return
        }
        backgroundAnimator?.cancel()
        val start = renderedBackgroundColor
        backgroundAnimator = ValueAnimator.ofObject(ArgbEvaluator(), start, target).apply {
            duration = 220L
            addUpdateListener { animator ->
                val color = animator.animatedValue as Int
                renderedBackgroundColor = color
                view.setBackground(desktopBackgroundDrawable(color))
            }
            start()
        }
    }

    private fun animateTextColor() {
        val view = lyricView
        if (view == null) {
            renderedTextColor = textColor
            return
        }
        if (renderedTextColor == textColor) {
            view.setTextColor(textColor)
            return
        }
        textColorAnimator?.cancel()
        val start = renderedTextColor
        textColorAnimator = ValueAnimator.ofObject(ArgbEvaluator(), start, textColor).apply {
            duration = 220L
            addUpdateListener { animator ->
                val color = animator.animatedValue as Int
                renderedTextColor = color
                view.setTextColor(color)
            }
            start()
        }
    }

    private fun applyForegroundVisibility(animated: Boolean) {
        val root = rootView ?: return
        val shouldHide = autoHideInForeground && appInForeground
        root.animate().cancel()
        if (shouldHide) {
            if (animated) {
                root.animate()
                    .alpha(0f)
                    .setDuration(180L)
                    .withEndAction {
                        if (autoHideInForeground && appInForeground) {
                            root.visibility = View.INVISIBLE
                        }
                    }
                    .start()
            } else {
                root.alpha = 0f
                root.visibility = View.INVISIBLE
            }
            return
        }
        root.visibility = View.VISIBLE
        if (animated) {
            root.animate()
                .alpha(1f)
                .setDuration(180L)
                .start()
        } else {
            root.alpha = 1f
        }
    }

    private fun desktopTypeface(): Typeface {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Typeface.create(Typeface.DEFAULT, fontWeight.coerceIn(300, 900), false)
        } else {
            Typeface.create(
                Typeface.DEFAULT,
                if (fontWeight >= 650) Typeface.BOLD else Typeface.NORMAL
            )
        }
    }

    private fun showHandle() {
        if (locked) return
        val handle = handleView ?: return
        val leftHandle = leftHandleView ?: return
        mainHandler.removeCallbacks(hideHandleRunnable)
        handle.animate().cancel()
        leftHandle.animate().cancel()
        handle.visibility = View.VISIBLE
        leftHandle.visibility = View.VISIBLE
        handle.animate()
            .alpha(1f)
            .setDuration(120L)
            .start()
        leftHandle.animate()
            .alpha(1f)
            .setDuration(120L)
            .start()
    }

    private fun scheduleHandleHide() {
        if (locked) return
        mainHandler.removeCallbacks(hideHandleRunnable)
        mainHandler.postDelayed(hideHandleRunnable, 1000L)
    }

    private fun fadeHandleOut() {
        val handle = handleView ?: return
        val leftHandle = leftHandleView ?: return
        handle.animate().cancel()
        leftHandle.animate().cancel()
        handle.animate()
            .alpha(0f)
            .setDuration(240L)
            .withEndAction {
                if (handle.alpha <= 0.01f) {
                    handle.visibility = View.GONE
                }
            }
            .start()
        leftHandle.animate()
            .alpha(0f)
            .setDuration(240L)
            .withEndAction {
                if (leftHandle.alpha <= 0.01f) {
                    leftHandle.visibility = View.GONE
                }
            }
            .start()
    }

    private fun ensureReadableBounds(params: WindowManager.LayoutParams) {
        val bounds = screenBounds()
        val minWidth = minOverlayWidth()
        val minHeight = minOverlayHeight()
        val maxWidth = (bounds.width - 24.dp()).coerceAtLeast(minWidth)
        val maxHeight = (bounds.height - 32.dp()).coerceAtLeast(minHeight)
        val shouldFollowModeHeight = params.height <= lastMinOverlayHeight + 2.dp()
        params.width = params.width.coerceIn(minWidth, maxWidth)
        params.height = if (shouldFollowModeHeight) {
            minHeight.coerceIn(minHeight, maxHeight)
        } else {
            params.height.coerceIn(minHeight, maxHeight)
        }
        params.x = if (centerLineLocked) {
            centeredX(params.width, bounds)
        } else {
            params.x.coerceIn(0, (bounds.width - params.width).coerceAtLeast(0))
        }
        params.y = params.y.coerceIn(0, (bounds.height - params.height).coerceAtLeast(0))
        lastMinOverlayHeight = minHeight
    }

    private fun minOverlayWidth(): Int {
        return 220.dp()
    }

    private fun minOverlayHeight(): Int {
        val lineHeightPx = fontSize * context.resources.displayMetrics.scaledDensity * 1.36f
        return (lineHeightPx * maxDisplayLines() + 26.dp()).roundToInt()
            .coerceAtLeast(72.dp())
    }

    private fun maxDisplayLines(): Int {
        return if (multiLine) 6 else 3
    }

    private fun overlayFlags(): Int {
        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        if (locked) {
            flags = flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        return flags
    }

    private fun saveBounds(params: WindowManager.LayoutParams) {
        prefs.edit()
            .putInt("desktopLyricsX", params.x)
            .putInt("desktopLyricsY", params.y)
            .putInt("desktopLyricsWidth", params.width)
            .putInt("desktopLyricsHeight", params.height)
            .apply()
    }

    private fun Int.dp(): Int {
        return (this * context.resources.displayMetrics.density).roundToInt()
    }

    private enum class ResizeCorner { LEFT, RIGHT }

    private class ResizeCornerView(
        context: Context,
        private val corner: ResizeCorner
    ) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(210, 255, 255, 255)
            strokeWidth = 3.5f * context.resources.displayMetrics.density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            style = Paint.Style.STROKE
        }
        private val path = Path()

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val pad = 7f * resources.displayMetrics.density
            val left = pad
            val right = width - pad
            val bottom = height - pad
            val length = 18f * resources.displayMetrics.density
            val radius = 7f * resources.displayMetrics.density
            path.reset()
            if (corner == ResizeCorner.LEFT) {
                path.moveTo(left, bottom - length)
                path.lineTo(left, bottom - radius)
                path.quadTo(left, bottom, left + radius, bottom)
                path.lineTo(left + length, bottom)
            } else {
                path.moveTo(right, bottom - length)
                path.lineTo(right, bottom - radius)
                path.quadTo(right, bottom, right - radius, bottom)
                path.lineTo(right - length, bottom)
            }
            canvas.drawPath(path, paint)
        }
    }
}
