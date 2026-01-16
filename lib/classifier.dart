import 'package:tflite_flutter/tflite_flutter.dart';

class Classifier {
  // --- CONSTANTS ---
  // The number of readings the model expects at once (must match Python)
  static const int WINDOW_SIZE = 100;

  // The labels in the exact alphabetical order used during Python training
  static const List<String> labels = [
    'Downstairs',
    'Jogging',
    'Sitting',
    'Standing',
    'Upstairs',
    'Walking'
  ];

  Interpreter? _interpreter;

  /// Loads the TFLite model from the assets folder.
  Future<void> loadModel() async {
    try {
      // Ensure you have added 'assets/activity_model.tflite' to pubspec.yaml
      _interpreter = await Interpreter.fromAsset('assets/activity_model.tflite');
      
      // Print debug info to console to verify shape
      var inputShape = _interpreter!.getInputTensor(0).shape;
      print(" Model Loaded. Expected Input Shape: $inputShape"); 
    } catch (e) {
      print(" Error loading model: $e");
    }
  }

  /// Runs inference on the input buffer.
  /// [inputData] must be a List of 100 rows, where each row has 6 values.
  /// Returns a Map with the 'label' and the 'probabilities'.
  Map<String, dynamic>? predict(List<List<double>> inputData) {
    if (_interpreter == null) return null;

    // 1. Prepare Input: Wrap the data in a batch [1, 100, 6]
    var input = [inputData];

    // 2. Prepare Output: A buffer to hold results [1, 6]
    var output = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);

    // 3. Run Inference
    _interpreter!.run(input, output);

    // 4. Process Results
    List<double> result = List<double>.from(output[0]);

    // Find the index with the highest probability
    double maxScore = -1;
    int maxIndex = -1;
    for (int i = 0; i < result.length; i++) {
      if (result[i] > maxScore) {
        maxScore = result[i];
        maxIndex = i;
      }
    }

    return {
      'label': labels[maxIndex],       // e.g., "Walking"
      'probabilities': result,         // e.g., [0.1, 0.8, 0.0, ...]
      'confidence': maxScore           // e.g., 0.8
    };
  }
  
  bool get isLoaded => _interpreter != null;

  void close() {
    _interpreter?.close();
  }
}