package com.codex.emoc;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor.AudioFormat;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import kotlin.Unit;
import org.junit.Test;

public final class PlaybackSpectrumAudioProcessorTest {
    @Test
    public void forwardsDecodedPcmWithoutChangingAByte() throws Exception {
        AtomicReference<PlaybackSpectrumFrame> frame = new AtomicReference<>();
        CountDownLatch analyzed = new CountDownLatch(1);
        PlaybackSpectrumAudioProcessor processor = new PlaybackSpectrumAudioProcessor(value -> {
            frame.set(value);
            analyzed.countDown();
            return Unit.INSTANCE;
        });
        processor.configure(new AudioFormat(44_100, 2, C.ENCODING_PCM_16BIT));
        processor.flush();
        processor.setEnabled(true);

        byte[] inputBytes = stereoTone(440.0);
        processor.queueInput(
            ByteBuffer.wrap(inputBytes.clone()).order(ByteOrder.LITTLE_ENDIAN)
        );
        ByteBuffer output = processor.getOutput();
        byte[] outputBytes = new byte[output.remaining()];
        output.get(outputBytes);

        assertArrayEquals(inputBytes, outputBytes);
        assertTrue(analyzed.await(2, TimeUnit.SECONDS));
        assertEquals(48, frame.get().getBands().length);
        assertTrue(frame.get().getRms() > 0.05f);
        processor.reset();
    }

    @Test
    public void spectrumCentroidMovesWithTheDecodedPitch() throws Exception {
        PlaybackSpectrumFrame low = analyzeTone(180.0);
        PlaybackSpectrumFrame high = analyzeTone(3_200.0);

        assertTrue(high.getCentroid() > low.getCentroid() + 0.05f);
    }

    @Test
    public void analyzesSideDecodedPcmWithoutAnAudioSink() throws Exception {
        AtomicReference<PlaybackSpectrumFrame> frame = new AtomicReference<>();
        CountDownLatch analyzed = new CountDownLatch(1);
        PlaybackSpectrumAudioProcessor processor = new PlaybackSpectrumAudioProcessor(value -> {
            frame.set(value);
            analyzed.countDown();
            return Unit.INSTANCE;
        });
        processor.setEnabled(true);
        processor.analyzeDecodedPcm(
            ByteBuffer.wrap(stereoTone(880.0)).order(ByteOrder.LITTLE_ENDIAN),
            44_100,
            2,
            C.ENCODING_PCM_16BIT
        );

        assertTrue(analyzed.await(2, TimeUnit.SECONDS));
        assertEquals(48, frame.get().getBands().length);
        assertTrue(frame.get().getRms() > 0.05f);
        processor.reset();
    }

    private static PlaybackSpectrumFrame analyzeTone(double frequency) throws Exception {
        AtomicReference<PlaybackSpectrumFrame> frame = new AtomicReference<>();
        CountDownLatch analyzed = new CountDownLatch(1);
        PlaybackSpectrumAudioProcessor processor = new PlaybackSpectrumAudioProcessor(value -> {
            frame.set(value);
            analyzed.countDown();
            return Unit.INSTANCE;
        });
        processor.configure(new AudioFormat(44_100, 2, C.ENCODING_PCM_16BIT));
        processor.flush();
        processor.setEnabled(true);
        processor.queueInput(
            ByteBuffer.wrap(stereoTone(frequency)).order(ByteOrder.LITTLE_ENDIAN)
        );
        assertTrue(analyzed.await(2, TimeUnit.SECONDS));
        PlaybackSpectrumFrame result = frame.get();
        processor.reset();
        return result;
    }

    private static byte[] stereoTone(double frequency) {
        int sampleRate = 44_100;
        int frameCount = 2_048;
        ByteBuffer buffer = ByteBuffer
            .allocate(frameCount * 2 * Short.BYTES)
            .order(ByteOrder.LITTLE_ENDIAN);
        for (int index = 0; index < frameCount; index++) {
            double phase = 2.0 * Math.PI * frequency * index / sampleRate;
            short sample = (short) Math.round(Math.sin(phase) * Short.MAX_VALUE * 0.55);
            buffer.putShort(sample);
            buffer.putShort(sample);
        }
        return buffer.array();
    }
}
