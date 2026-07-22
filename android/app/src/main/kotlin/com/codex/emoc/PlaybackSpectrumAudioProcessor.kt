package com.codex.emoc

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor.AudioFormat
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

data class PlaybackSpectrumFrame(
    val bands: FloatArray,
    val rms: Float,
    val centroid: Float
)

/**
 * Observes EmoC's own decoded PCM while forwarding every byte unchanged to
 * Media3's audio sink. This does not capture the microphone or system output.
 */
@UnstableApi
class PlaybackSpectrumAudioProcessor(
    private val onSpectrum: (PlaybackSpectrumFrame) -> Unit
) : BaseAudioProcessor() {
    @Volatile
    var enabled: Boolean = false

    private val windowSize = 1024
    private val bandCount = 48
    private val samples = FloatArray(windowSize)
    private val smoothedBands = FloatArray(bandCount)
    @Volatile
    private var analysisExecutor: ExecutorService = createAnalysisExecutor()
    private val analysisRunning = AtomicBoolean(false)
    private var sampleCount = 0
    private var lastEmissionNanos = 0L
    @Volatile
    private var analysisGeneration = 0

    override fun onConfigure(inputAudioFormat: AudioFormat): AudioFormat {
        return if (inputAudioFormat.encoding in supportedPcmEncodings) {
            inputAudioFormat
        } else {
            AudioFormat.NOT_SET
        }
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val byteCount = inputBuffer.remaining()
        if (enabled && byteCount > 0) {
            // Spectrum analysis must never be able to interrupt audio output.
            // Some decoders deliver float/24-bit/32-bit PCM even when float
            // output is not requested, so observe all common PCM encodings.
            runCatching {
                consumePcm(
                    inputBuffer.asReadOnlyBuffer().order(ByteOrder.LITTLE_ENDIAN),
                    max(1, inputAudioFormat.sampleRate),
                    max(1, inputAudioFormat.channelCount),
                    inputAudioFormat.encoding
                )
            }
        }

        // The original buffer is copied verbatim. Analysis never changes the
        // bytes, sample rate, channel layout, timing, or playback speed.
        val outputBuffer = replaceOutputBuffer(byteCount)
        outputBuffer.put(inputBuffer)
        outputBuffer.flip()
    }

    override fun onFlush() {
        analysisGeneration += 1
        sampleCount = 0
        lastEmissionNanos = 0L
        samples.fill(0f)
        synchronized(smoothedBands) {
            smoothedBands.fill(0f)
        }
    }

    override fun onReset() {
        onFlush()
        analysisExecutor.shutdownNow()
        analysisRunning.set(false)
    }

    /**
     * Feeds PCM decoded by a side-channel decoder. This keeps spectrum
     * analysis independent from ExoPlayer's AudioSink on devices that reject
     * custom sink processors.
     */
    fun analyzeDecodedPcm(
        buffer: ByteBuffer,
        sampleRate: Int,
        channelCount: Int,
        encoding: Int
    ) {
        if (!enabled || !buffer.hasRemaining()) return
        runCatching {
            consumePcm(
                buffer.asReadOnlyBuffer().order(ByteOrder.LITTLE_ENDIAN),
                max(1, sampleRate),
                max(1, channelCount),
                encoding
            )
        }
    }

    fun clearAnalysis() {
        onFlush()
    }

    private fun consumePcm(
        buffer: ByteBuffer,
        sampleRate: Int,
        channelCount: Int,
        encoding: Int
    ) {
        val bytesPerSample = when (encoding) {
            C.ENCODING_PCM_8BIT -> 1
            C.ENCODING_PCM_16BIT -> 2
            C.ENCODING_PCM_24BIT -> 3
            C.ENCODING_PCM_32BIT, C.ENCODING_PCM_FLOAT -> 4
            else -> return
        }
        val frameBytes = channelCount * bytesPerSample
        while (buffer.remaining() >= frameBytes) {
            var mixed = 0f
            repeat(channelCount) {
                mixed += readSample(buffer, encoding)
            }
            samples[sampleCount++] = mixed / channelCount
            if (sampleCount == windowSize) {
                val now = System.nanoTime()
                if (now - lastEmissionNanos >= 42_000_000L &&
                    analysisRunning.compareAndSet(false, true)
                ) {
                    lastEmissionNanos = now
                    val window = samples.copyOf()
                    val generation = analysisGeneration
                    try {
                        activeExecutor().execute {
                            try {
                                val frame = analyzeWindow(window, sampleRate)
                                if (generation == analysisGeneration && enabled) {
                                    onSpectrum(frame)
                                }
                            } finally {
                                analysisRunning.set(false)
                            }
                        }
                    } catch (_: RuntimeException) {
                        analysisRunning.set(false)
                    }
                }
                sampleCount = 0
            }
        }
    }

    private fun readSample(buffer: ByteBuffer, encoding: Int): Float {
        return when (encoding) {
            C.ENCODING_PCM_8BIT -> ((buffer.get().toInt() and 0xff) - 128) / 128f
            C.ENCODING_PCM_16BIT -> buffer.short / 32768f
            C.ENCODING_PCM_24BIT -> {
                val raw = (buffer.get().toInt() and 0xff) or
                    ((buffer.get().toInt() and 0xff) shl 8) or
                    ((buffer.get().toInt() and 0xff) shl 16)
                val signed = if (raw and 0x800000 != 0) raw or -0x1000000 else raw
                signed / 8388608f
            }
            C.ENCODING_PCM_32BIT -> buffer.int / 2147483648f
            C.ENCODING_PCM_FLOAT -> buffer.float.coerceIn(-1f, 1f)
            else -> 0f
        }
    }

    @Synchronized
    private fun activeExecutor(): ExecutorService {
        if (analysisExecutor.isShutdown || analysisExecutor.isTerminated) {
            analysisExecutor = createAnalysisExecutor()
        }
        return analysisExecutor
    }

    private fun analyzeWindow(window: FloatArray, sampleRate: Int): PlaybackSpectrumFrame {
        val real = FloatArray(windowSize)
        val imaginary = FloatArray(windowSize)
        val magnitudes = FloatArray(windowSize / 2)
        var squareSum = 0.0
        for (index in 0 until windowSize) {
            val sample = window[index]
            squareSum += sample * sample
            val hann = 0.5 - 0.5 * cos(2.0 * PI * index / (windowSize - 1))
            real[index] = (sample * hann).toFloat()
            imaginary[index] = 0f
        }
        fft(real, imaginary)

        var magnitudeSum = 0.0
        var weightedFrequency = 0.0
        for (bin in 1 until windowSize / 2) {
            val magnitude = sqrt(
                real[bin].toDouble() * real[bin] +
                    imaginary[bin].toDouble() * imaginary[bin]
            ).toFloat()
            magnitudes[bin] = magnitude
            magnitudeSum += magnitude
            weightedFrequency += magnitude * (bin.toDouble() * sampleRate / windowSize)
        }

        val nyquist = sampleRate / 2.0
        val upperFrequency = min(16_000.0, nyquist)
        val lowerFrequency = min(45.0, upperFrequency)
        val rawBands = FloatArray(bandCount)
        var peak = 1e-6f
        for (band in 0 until bandCount) {
            val startRatio = band.toDouble() / bandCount
            val endRatio = (band + 1).toDouble() / bandCount
            val startFrequency = lowerFrequency *
                (upperFrequency / lowerFrequency).pow(startRatio)
            val endFrequency = lowerFrequency *
                (upperFrequency / lowerFrequency).pow(endRatio)
            val startBin = max(1, (startFrequency * windowSize / sampleRate).toInt())
            val endBin = min(
                windowSize / 2 - 1,
                max(startBin, (endFrequency * windowSize / sampleRate).toInt())
            )
            var sum = 0f
            for (bin in startBin..endBin) sum += magnitudes[bin]
            val average = sum / max(1, endBin - startBin + 1)
            rawBands[band] = ln(1.0 + average * 12.0).toFloat()
            peak = max(peak, rawBands[band])
        }

        val rms = sqrt(squareSum / windowSize).toFloat().coerceIn(0f, 1f)
        synchronized(smoothedBands) {
            for (band in 0 until bandCount) {
                val normalized = if (rms < 0.0008f) {
                    0f
                } else {
                    (rawBands[band] / peak).coerceIn(0f, 1f).pow(0.72f)
                }
                val smoothing = if (normalized > smoothedBands[band]) 0.62f else 0.2f
                smoothedBands[band] +=
                    (normalized - smoothedBands[band]) * smoothing
            }
        }
        val centroid = if (magnitudeSum <= 1e-9) {
            0f
        } else {
            (weightedFrequency / magnitudeSum / nyquist).toFloat().coerceIn(0f, 1f)
        }
        return PlaybackSpectrumFrame(
            bands = synchronized(smoothedBands) { smoothedBands.copyOf() },
            rms = rms,
            centroid = centroid
        )
    }

    private fun createAnalysisExecutor(): ExecutorService {
        return Executors.newSingleThreadExecutor { task ->
            Thread(task, "EmoC-spectrum").apply { isDaemon = true }
        }
    }

    private fun fft(real: FloatArray, imaginary: FloatArray) {
        var target = 0
        for (index in 1 until windowSize) {
            var bit = windowSize shr 1
            while (target and bit != 0) {
                target = target xor bit
                bit = bit shr 1
            }
            target = target xor bit
            if (index < target) {
                val realValue = real[index]
                real[index] = real[target]
                real[target] = realValue
                val imaginaryValue = imaginary[index]
                imaginary[index] = imaginary[target]
                imaginary[target] = imaginaryValue
            }
        }

        var length = 2
        while (length <= windowSize) {
            val angle = -2.0 * PI / length
            val stepReal = cos(angle).toFloat()
            val stepImaginary = sin(angle).toFloat()
            var offset = 0
            while (offset < windowSize) {
                var twiddleReal = 1f
                var twiddleImaginary = 0f
                for (index in 0 until length / 2) {
                    val even = offset + index
                    val odd = even + length / 2
                    val oddReal =
                        real[odd] * twiddleReal - imaginary[odd] * twiddleImaginary
                    val oddImaginary =
                        real[odd] * twiddleImaginary + imaginary[odd] * twiddleReal
                    real[odd] = real[even] - oddReal
                    imaginary[odd] = imaginary[even] - oddImaginary
                    real[even] += oddReal
                    imaginary[even] += oddImaginary
                    val nextReal =
                        twiddleReal * stepReal - twiddleImaginary * stepImaginary
                    twiddleImaginary =
                        twiddleReal * stepImaginary + twiddleImaginary * stepReal
                    twiddleReal = nextReal
                }
                offset += length
            }
            length = length shl 1
        }
    }

    companion object {
        private val supportedPcmEncodings = setOf(
            C.ENCODING_PCM_8BIT,
            C.ENCODING_PCM_16BIT,
            C.ENCODING_PCM_24BIT,
            C.ENCODING_PCM_32BIT,
            C.ENCODING_PCM_FLOAT
        )
    }
}
