package com.codex.emoc

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.abs
import kotlin.math.min

/**
 * Decodes the current audio URL in parallel for visualization only.
 *
 * The audible ExoPlayer remains on Android's standard AudioSink. A decoder
 * failure therefore disables only the spectrum and can never interrupt,
 * accelerate, pause, or otherwise alter playback.
 */
@UnstableApi
class PlaybackSpectrumDecoder(
    val sourceUrl: String,
    private val headers: Map<String, String>,
    private val onSpectrum: (PlaybackSpectrumFrame) -> Unit
) {
    @Volatile
    private var playbackPositionMs = 0L

    @Volatile
    private var playbackPlaying = false

    private val requestedSeekUs = AtomicLong(0L)
    private val runGeneration = AtomicInteger(0)
    private var lastClockPositionMs = -1L
    private var executor: ExecutorService? = null

    fun start(initialPositionMs: Long, playing: Boolean) {
        stop()
        playbackPositionMs = initialPositionMs.coerceAtLeast(0L)
        playbackPlaying = playing
        lastClockPositionMs = playbackPositionMs
        requestedSeekUs.set(playbackPositionMs * 1_000L)
        val generation = runGeneration.incrementAndGet()
        executor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "EmoC-spectrum-decoder").apply { isDaemon = true }
        }.also { worker ->
            worker.execute {
                var attempts = 0
                while (isCurrent(generation) && attempts < 2) {
                    attempts += 1
                    val completed = runCatching {
                        decode(generation)
                    }.isSuccess
                    if (completed || !isCurrent(generation)) break
                    sleepQuietly(700L)
                }
            }
        }
    }

    fun updatePlaybackState(positionMs: Long, playing: Boolean) {
        val safePosition = positionMs.coerceAtLeast(0L)
        val previous = lastClockPositionMs
        playbackPositionMs = safePosition
        playbackPlaying = playing
        if (previous >= 0L && abs(safePosition - previous) > SEEK_JUMP_THRESHOLD_MS) {
            requestedSeekUs.set(safePosition * 1_000L)
        }
        lastClockPositionMs = safePosition
    }

    fun seekTo(positionMs: Long) {
        val safePosition = positionMs.coerceAtLeast(0L)
        playbackPositionMs = safePosition
        lastClockPositionMs = safePosition
        requestedSeekUs.set(safePosition * 1_000L)
    }

    fun stop() {
        runGeneration.incrementAndGet()
        executor?.shutdownNow()
        executor = null
        playbackPlaying = false
    }

    private fun decode(generation: Int) {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        val spectrum = PlaybackSpectrumAudioProcessor { frame ->
            if (isCurrent(generation) && playbackPlaying) onSpectrum(frame)
        }.also { it.enabled = true }

        try {
            extractor.setDataSource(sourceUrl, headers)
            val trackIndex = findAudioTrack(extractor)
            check(trackIndex >= 0) { "No audio track found" }
            extractor.selectTrack(trackIndex)
            val inputFormat = extractor.getTrackFormat(trackIndex)
            val mime = inputFormat.getString(MediaFormat.KEY_MIME)
                ?: error("Audio MIME type is missing")
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()

            var outputFormat = inputFormat
            var inputEnded = false
            var outputEnded = false
            // A retry may happen after the original seek request was consumed.
            // Always begin from the audible player's latest position instead
            // of decoding from the start and racing to catch up.
            val initialSeekUs = requestedSeekUs.getAndSet(NO_SEEK)
                .takeIf { it >= 0L }
                ?: playbackPositionMs.coerceAtLeast(0L) * 1_000L
            seekDecoder(extractor, decoder, spectrum, initialSeekUs)
            val bufferInfo = MediaCodec.BufferInfo()

            while (isCurrent(generation) && !outputEnded) {
                val latestSeekUs = requestedSeekUs.getAndSet(NO_SEEK)
                if (latestSeekUs >= 0L) {
                    seekDecoder(extractor, decoder, spectrum, latestSeekUs)
                    inputEnded = false
                    outputEnded = false
                }

                if (!playbackPlaying) {
                    sleepQuietly(PAUSED_POLL_MS)
                    continue
                }

                if (!inputEnded) {
                    val inputIndex = decoder.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
                    if (inputIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputIndex)
                        val sampleSize = if (inputBuffer == null) {
                            -1
                        } else {
                            inputBuffer.clear()
                            extractor.readSampleData(inputBuffer, 0)
                        }
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                0L,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputEnded = true
                        } else {
                            decoder.queueInputBuffer(
                                inputIndex,
                                0,
                                sampleSize,
                                extractor.sampleTime.coerceAtLeast(0L),
                                extractor.sampleFlags
                            )
                            extractor.advance()
                        }
                    }
                }

                when (val outputIndex = decoder.dequeueOutputBuffer(
                    bufferInfo,
                    DEQUEUE_TIMEOUT_US
                )) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        outputFormat = decoder.outputFormat
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    else -> if (outputIndex >= 0) {
                        val presentationMs = bufferInfo.presentationTimeUs / 1_000L
                        waitUntilPresentation(generation, presentationMs)
                        val distanceMs = presentationMs - playbackPositionMs
                        if (
                            isCurrent(generation) &&
                            playbackPlaying &&
                            bufferInfo.size > 0 &&
                            distanceMs in -MAX_LATE_FRAME_MS..MAX_EARLY_FRAME_MS
                        ) {
                            decoder.getOutputBuffer(outputIndex)?.let { output ->
                                spectrum.analyzeDecodedPcm(
                                    slice(output, bufferInfo),
                                    sampleRate(outputFormat, inputFormat),
                                    channelCount(outputFormat, inputFormat),
                                    pcmEncoding(outputFormat)
                                )
                            }
                        }
                        decoder.releaseOutputBuffer(outputIndex, false)
                        outputEnded = bufferInfo.flags and
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    }
                }
            }
        } finally {
            spectrum.enabled = false
            spectrum.reset()
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            runCatching { extractor.release() }
        }
    }

    private fun waitUntilPresentation(generation: Int, presentationMs: Long) {
        while (isCurrent(generation)) {
            // Do not let a queued output timestamp delay a user seek. The
            // outer decode loop will release this stale buffer and flush the
            // codec immediately on its next iteration.
            if (requestedSeekUs.get() >= 0L) return
            if (!playbackPlaying) {
                sleepQuietly(PAUSED_POLL_MS)
                continue
            }
            val leadMs = presentationMs - playbackPositionMs
            if (leadMs <= TARGET_LEAD_MS) return
            sleepQuietly(min(35L, (leadMs - TARGET_LEAD_MS).coerceAtLeast(5L)))
        }
    }

    private fun seekDecoder(
        extractor: MediaExtractor,
        codec: MediaCodec,
        spectrum: PlaybackSpectrumAudioProcessor,
        positionUs: Long
    ) {
        codec.flush()
        extractor.seekTo(positionUs.coerceAtLeast(0L), MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        spectrum.clearAnalysis()
    }

    private fun findAudioTrack(extractor: MediaExtractor): Int {
        for (index in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) return index
        }
        return -1
    }

    private fun sampleRate(output: MediaFormat, fallback: MediaFormat): Int {
        return formatInt(output, MediaFormat.KEY_SAMPLE_RATE)
            ?: formatInt(fallback, MediaFormat.KEY_SAMPLE_RATE)
            ?: 44_100
    }

    private fun channelCount(output: MediaFormat, fallback: MediaFormat): Int {
        return formatInt(output, MediaFormat.KEY_CHANNEL_COUNT)
            ?: formatInt(fallback, MediaFormat.KEY_CHANNEL_COUNT)
            ?: 2
    }

    private fun pcmEncoding(format: MediaFormat): Int {
        val platformEncoding = formatInt(format, MediaFormat.KEY_PCM_ENCODING)
            ?: AudioFormat.ENCODING_PCM_16BIT
        return when (platformEncoding) {
            AudioFormat.ENCODING_PCM_8BIT -> C.ENCODING_PCM_8BIT
            AudioFormat.ENCODING_PCM_FLOAT -> C.ENCODING_PCM_FLOAT
            21 -> C.ENCODING_PCM_24BIT
            22 -> C.ENCODING_PCM_32BIT
            else -> C.ENCODING_PCM_16BIT
        }
    }

    private fun formatInt(format: MediaFormat, key: String): Int? {
        return if (format.containsKey(key)) runCatching { format.getInteger(key) }.getOrNull()
        else null
    }

    private fun slice(buffer: ByteBuffer, info: MediaCodec.BufferInfo): ByteBuffer {
        val duplicate = buffer.asReadOnlyBuffer()
        val start = info.offset.coerceIn(0, duplicate.capacity())
        val end = (start + info.size).coerceIn(start, duplicate.capacity())
        duplicate.position(start)
        duplicate.limit(end)
        return duplicate.slice()
    }

    private fun isCurrent(generation: Int): Boolean {
        return runGeneration.get() == generation && !Thread.currentThread().isInterrupted
    }

    private fun sleepQuietly(durationMs: Long) {
        try {
            Thread.sleep(durationMs)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }

    companion object {
        private const val NO_SEEK = -1L
        private const val DEQUEUE_TIMEOUT_US = 8_000L
        private const val PAUSED_POLL_MS = 30L
        private const val SEEK_JUMP_THRESHOLD_MS = 750L
        private const val TARGET_LEAD_MS = 90L
        private const val MAX_EARLY_FRAME_MS = 220L
        private const val MAX_LATE_FRAME_MS = 380L
    }
}
