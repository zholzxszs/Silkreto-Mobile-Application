import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteModelService {
  static final TFLiteModelService _instance = TFLiteModelService._internal();
  factory TFLiteModelService() => _instance;
  TFLiteModelService._internal();

  Interpreter? _interpreter;
  bool _isInitialized = false;

  static const int _numCandidates = 8400;
  static const int _numOutputs = 6;
  static const int _numClasses = 2;

  // thresholds
  final double confThreshold = 0.45;
  final double iouThreshold = 0.5;

  // class labels
  final List<String> labels = const ['Healthy', 'Diseased'];

  bool get isInitialized => _isInitialized;

  Future<void> initializeModel({
    String assetPath = 'assets/model/best_float32.tflite',
    int threads = 4,
  }) async {
    final options = InterpreterOptions()..threads = threads;
    _interpreter = await Interpreter.fromAsset(assetPath, options: options);
    _isInitialized = true;
  }

  Future<void> ensureInitialized({
    String assetPath = 'assets/model/best_float32.tflite',
    int threads = 4,
  }) async {
    if (_isInitialized && _interpreter != null) return;
    await initializeModel(assetPath: assetPath, threads: threads);
  }

  Future<ModelPrediction> predictFromImage(String imagePath) async {
    if (!_isInitialized || _interpreter == null) {
      return ModelPrediction.empty();
    }

    try {
      // preprocess in background isolate (so UI spinner animates)
      final List input4d = await _preprocessTo4DTensor(imagePath);

      // output: [1][6][8400]
      final output = List.generate(
        1,
        (_) => List.generate(
          _numOutputs,
          (_) => List<double>.filled(_numCandidates, 0.0),
        ),
      );

      _interpreter!.run(input4d, output);

      final detections = _postprocess(output);

      int healthy = 0;
      int diseased = 0;
      double bestScore = 0.0;

      for (final d in detections) {
        if (d.classId == 0) {
          healthy++;
        } else {
          diseased++;
        }
        bestScore = max(bestScore, d.score);
      }

      String status;
      if (detections.isEmpty) {
        status = 'Unknown';
      } else if (diseased > 0) {
        status = 'Diseased';
      } else {
        status = 'Healthy';
      }

      return ModelPrediction(
        status: status,
        confidence: bestScore,
        healthyCount: healthy,
        diseasedCount: diseased,
        detections: detections,
      );
    } catch (e) {
      // ignore: avoid_print
      print('predictFromImage error: $e');
      return ModelPrediction.empty();
    }
  }

  Future<List> _preprocessTo4DTensor(String imagePath) async {
    Uint8List bytes;

    if (imagePath.startsWith('assets/')) {
      final bd = await rootBundle.load(imagePath);
      bytes = bd.buffer.asUint8List();
    } else {
      final file = File(imagePath);
      if (!file.existsSync()) {
        throw Exception('Image not found: $imagePath');
      }
      bytes = await file.readAsBytes();
    }

    // Build [1][640][640][3] in an isolate
    return compute(_bytesToInput4D, bytes);
  }

  List<Detection> _postprocess(List<List<List<double>>> output) {
    final ch = output[0]; // [6][8400]
    if (ch.length != _numOutputs || ch[0].length != _numCandidates) {
      throw Exception('Unexpected output shape');
    }

    final cxArr = ch[0];
    final cyArr = ch[1];
    final wArr = ch[2];
    final hArr = ch[3];
    final c0 = ch[4];
    final c1 = ch[5];

    final raw = <Detection>[];

    for (int i = 0; i < _numCandidates; i++) {
      final s0 = c0[i];
      final s1 = c1[i];

      final classId = (s0 > s1) ? 1 : 0;
      final score = (classId == 1) ? s0 : s1;

      if (score < confThreshold) continue;

      final cx = cxArr[i];
      final cy = cyArr[i];
      final w = wArr[i];
      final h = hArr[i];

      final x1 = cx - w / 2.0;
      final y1 = cy - h / 2.0;
      final x2 = cx + w / 2.0;
      final y2 = cy + h / 2.0;

      raw.add(
        Detection(
          classId: classId,
          score: score,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
        ),
      );
    }

    // NMS per class
    final results = <Detection>[];
    for (int cls = 0; cls < _numClasses; cls++) {
      final clsDet = raw.where((d) => d.classId == cls).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      results.addAll(_nms(clsDet, iouThreshold));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  List<Detection> _nms(List<Detection> dets, double iouThr) {
    final kept = <Detection>[];
    final suppressed = List<bool>.filled(dets.length, false);

    for (int i = 0; i < dets.length; i++) {
      if (suppressed[i]) continue;
      final a = dets[i];
      kept.add(a);

      for (int j = i + 1; j < dets.length; j++) {
        if (suppressed[j]) continue;
        final b = dets[j];
        if (_iou(a, b) >= iouThr) suppressed[j] = true;
      }
    }
    return kept;
  }

  double _iou(Detection a, Detection b) {
    final interX1 = max(a.x1, b.x1);
    final interY1 = max(a.y1, b.y1);
    final interX2 = min(a.x2, b.x2);
    final interY2 = min(a.y2, b.y2);

    final interW = max(0.0, interX2 - interX1);
    final interH = max(0.0, interY2 - interY1);
    final interArea = interW * interH;

    final areaA = max(0.0, a.x2 - a.x1) * max(0.0, a.y2 - a.y1);
    final areaB = max(0.0, b.x2 - b.x1) * max(0.0, b.y2 - b.y1);

    final union = areaA + areaB - interArea;
    if (union <= 0) return 0.0;
    return interArea / union;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

class Detection {
  final int classId;
  final double score;
  final double x1, y1, x2, y2;

  Detection({
    required this.classId,
    required this.score,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
}

class ModelPrediction {
  final String status;
  final double confidence;
  final int healthyCount;
  final int diseasedCount;
  final List<Detection> detections;

  ModelPrediction({
    required this.status,
    required this.confidence,
    required this.healthyCount,
    required this.diseasedCount,
    required this.detections,
  });

  factory ModelPrediction.empty() => ModelPrediction(
    status: 'Unknown',
    confidence: 0.0,
    healthyCount: 0,
    diseasedCount: 0,
    detections: const [],
  );
}

///  TOP-LEVEL function required by compute()
/// Returns [1][640][640][3] with 0..1 floats
List _bytesToInput4D(Uint8List bytes) {
  const int inW = 640;
  const int inH = 640;
  const double normDiv = 255.0;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Failed to decode image');

  final resized = img.copyResize(decoded, width: inW, height: inH);

  // Build nested list [1][H][W][3]
  final input = List.generate(
    1,
    (_) => List.generate(
      inH,
      (y) => List.generate(inW, (x) {
        final p = resized.getPixel(x, y);

        // Works on image v4+: p.r/p.g/p.b are ints
        final r = (p.r as int) / normDiv;
        final g = (p.g as int) / normDiv;
        final b = (p.b as int) / normDiv;

        return <double>[r, g, b];
      }),
    ),
  );

  return input;
}
