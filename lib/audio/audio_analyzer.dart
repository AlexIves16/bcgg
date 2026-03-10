import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';

class AudioAnalyzer {
  static final AudioAnalyzer _instance = AudioAnalyzer._internal();
  factory AudioAnalyzer() => _instance;
  AudioAnalyzer._internal();

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSubscription;
  final List<double> _sampleBuffer = [];
  
  // Configuration
  static const int sampleRate = 44100;
  static const int bufferSize = 4096; // Increased from 2048 for better frequency resolution (~10.7Hz)

  // Analysis results
  final _pitchController = StreamController<double?>.broadcast();
  Stream<double?> get pitchStream => _pitchController.stream;

  final _fftController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get fftStream => _fftController.stream;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  Future<bool> startAnalysis() async {
    // print("[AUDIO] startAnalysis called. isAnalyzing: $_isAnalyzing");
    if (_isAnalyzing) return true;

    final hasPermission = await _recorder.hasPermission();
    // print("[AUDIO] Microphone permission: $hasPermission");
    if (!hasPermission) return false;

    try {
      // print("[AUDIO] Starting stream with PCM 16-bit, 44.1kHz...");
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _isAnalyzing = true;
      
      final fft = FFT(bufferSize);

      // print("[AUDIO] Stream object: $stream");

      _audioSubscription = stream.listen(
        (data) {
          if (data.isEmpty) return;

          final samples = _convertToDoubleList(data);
          _sampleBuffer.addAll(samples);

          // Process all available windows of bufferSize
          while (_sampleBuffer.length >= bufferSize) {
            final processingBuffer = _sampleBuffer.sublist(0, bufferSize);
            _sampleBuffer.removeRange(0, bufferSize); // Sliding window would be better, but this is fixed-step

            final freqData = fft.realFft(processingBuffer);
            final List<double> magnitudes = freqData.magnitudes().toList();
            _fftController.add(magnitudes);

            // 1. FFT-based Pitch Detection
            double maxMag = 0;
            int peakIndex = -1;
            for (int i = 1; i < magnitudes.length / 2; i++) {
              if (magnitudes[i] > maxMag) {
                maxMag = magnitudes[i];
                peakIndex = i;
              }
            }

            if (peakIndex > 0 && peakIndex < magnitudes.length - 1 && maxMag > 0.01) { 
              // 1.1 Quadratic Interpolation for sub-bin accuracy
              final double y0 = magnitudes[peakIndex - 1];
              final double y1 = magnitudes[peakIndex];
              final double y2 = magnitudes[peakIndex + 1];
              
              // Parabolic interpolation formula
              final double p = (y2 - y0) / (2 * (2 * y1 - y2 - y0));
              final double refinedIndex = peakIndex + p;
              
              final pitchHz = refinedIndex * sampleRate / bufferSize;
              _pitchController.add(pitchHz);
            } else {
              _pitchController.add(null);
            }
          }
        },
        onError: (e) => print("[AUDIO] STREAM ERROR: $e"),
        onDone: () => print("[AUDIO] STREAM CLOSED"),
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      print("[AUDIO] Error starting analysis: $e");
      return false;
    }
  }

  Future<void> stopAnalysis() async {
    await _audioSubscription?.cancel();
    await _recorder.stop();
    _sampleBuffer.clear();
    _isAnalyzing = false;
  }

  List<double> _convertToDoubleList(Uint8List data) {
    // If the offset is not aligned to 2 bytes (Int16), we must copy it to an aligned buffer.
    // The RangeError (Offset 5 must be multiple of 2) confirms this happens on some devices.
    Uint8List alignedData = data;
    if (data.offsetInBytes % 2 != 0) {
      alignedData = Uint8List.fromList(data); 
    }

    final int lengthInSamples = alignedData.lengthInBytes ~/ 2;
    final Int16List int16Data = alignedData.buffer.asInt16List(alignedData.offsetInBytes, lengthInSamples);
    return int16Data.map((sample) => sample / 32768.0).toList();
  }

  /// Extracts dominant formants (peaks) from FFT magnitudes
  /// This is used for vowel identification
  List<double> getDominantFrequencies(List<double> magnitudes, int count) {
    // Basic peak finding logic - skip very low frequencies (below ~150Hz) to avoid rumble
    final List<MapEntry<int, double>> peaks = [];
    final int startBin = (150 * bufferSize / sampleRate).floor();
    for (int i = math.max(1, startBin); i < magnitudes.length - 1; i++) {
      if (magnitudes[i] > magnitudes[i - 1] && magnitudes[i] > magnitudes[i + 1]) {
        peaks.add(MapEntry(i, magnitudes[i]));
      }
    }
    
    peaks.sort((a, b) => b.value.compareTo(a.value));
    
    return peaks.take(count).map((e) {
      // Frequency = index * sampleRate / bufferSize
      return e.key * sampleRate / bufferSize;
    }).toList();
  }

  void dispose() {
    _pitchController.close();
    _fftController.close();
    _recorder.dispose();
  }
}
