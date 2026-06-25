import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Generates and plays a short nature-themed shutter click entirely in code —
/// no asset file required. The sound is a soft "leaf-snap" transient:
/// a brief sine chirp that decays quickly, giving an organic feel.
class ShutterSoundService {
  final AudioPlayer _player = AudioPlayer();

  /// Call once when the screen initialises.
  Future<void> init() async {
    await _player.setVolume(1.0);
  }

  /// Plays the shutter click. Safe to call fire-and-forget.
  Future<void> play() async {
    final bytes = _buildWav();
    await _player.play(BytesSource(bytes));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  // ── WAV synthesis ──────────────────────────────────────────────────────────

  /// Builds a raw WAV in memory.
  ///
  /// The sound is two layers mixed together:
  ///  1. A short high-frequency chirp (3 500 Hz) that decays in ~60 ms —
  ///     this gives the crisp "click" transient.
  ///  2. A softer mid-frequency tone (900 Hz) that decays in ~120 ms —
  ///     this adds a warm woody body so the click doesn't feel harsh.
  Uint8List _buildWav() {
    const sampleRate = 44100;
    const durationMs = 180; // total envelope length in ms
    final numSamples = (sampleRate * durationMs / 1000).round();

    final samples = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate; // time in seconds

      // ── Layer 1: crisp click transient ─────────────────────────────────
      final clickDecay = exp(-t / 0.018); // very fast decay (~18 ms)
      final click = sin(2 * pi * 3500 * t) * clickDecay;

      // ── Layer 2: warm woody body ────────────────────────────────────────
      final bodyDecay = exp(-t / 0.055); // slower decay (~55 ms)
      final body = sin(2 * pi * 900 * t) * bodyDecay * 0.45;

      // ── Layer 3: ultra-soft noise burst (texture) ───────────────────────
      final noiseDecay = exp(-t / 0.008);
      final noise = (Random().nextDouble() * 2 - 1) * noiseDecay * 0.15;

      final mixed = (click + body + noise).clamp(-1.0, 1.0);
      samples[i] = (mixed * 32767).round();
    }

    return _encodeWav(samples, sampleRate);
  }

  /// Encodes [samples] (16-bit signed PCM, mono) into a valid WAV byte array.
  Uint8List _encodeWav(Int16List samples, int sampleRate) {
    final dataBytes = samples.buffer.asUint8List();
    final fileSize = 44 + dataBytes.length;
    final buf = ByteData(fileSize);
    int o = 0; // write offset

    void writeStr(String s) {
      for (final c in s.codeUnits) {
        buf.setUint8(o++, c);
      }
    }

    void u32(int v) {
      buf.setUint32(o, v, Endian.little);
      o += 4;
    }

    void u16(int v) {
      buf.setUint16(o, v, Endian.little);
      o += 2;
    }

    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    writeStr('RIFF');
    u32(fileSize - 8); // chunk size
    writeStr('WAVE');
    writeStr('fmt ');
    u32(16); // subchunk1 size (PCM)
    u16(1); // audio format: PCM
    u16(channels);
    u32(sampleRate);
    u32(byteRate);
    u16(blockAlign);
    u16(bitsPerSample);
    writeStr('data');
    u32(dataBytes.length);

    // Write PCM samples
    final out = buf.buffer.asUint8List();
    out.setRange(44, fileSize, dataBytes);

    return out;
  }
}
