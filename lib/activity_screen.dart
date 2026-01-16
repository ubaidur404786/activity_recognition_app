import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with TickerProviderStateMixin {
  // ===================================================
  //               1. CONFIGURATION
  // ===================================================
  static const List<String> _labels = [
    'Downstairs', 'Jogging', 'Sitting', 'Standing', 'Upstairs', 'Walking'
  ];
  static const int _windowSize = 100;

  // AI & Sensors
  Interpreter? _interpreter;
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;
  
  List<List<double>> _dataBuffer = []; 
  List<double> _latestGyro = [0.0, 0.0, 0.0]; 

  // UI State
  bool _isDetecting = false;   
  bool _isModelLoaded = false; 
  String _currentActivity = "Idle";
  double _confidence = 0.0;
  List<double> _probabilities = [];

  // Waveform Data (Visuals)
  // FIX 1: Added 'growable: true' to prevent the crash
  List<double> _energyHistory = List.filled(100, 0.0, growable: true);
  int _renderThrottler = 0; 

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initModel();
    _startSensors(); 
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  // ===================================================
  //                  2. AI LOGIC
  // ===================================================
  Future<void> _initModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/activity_model.tflite');
      _interpreter!.allocateTensors();
      setState(() => _isModelLoaded = true);
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  void _startSensors() {
    _gyroSubscription = gyroscopeEvents.listen((event) {
      _latestGyro = [event.x, event.y, event.z];
    });

    _accelSubscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval
    ).listen((event) {
      
      // --- 1. WAVEFORM UPDATES ---
      double energy = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Update the list (Logic is now safe because list is growable)
      if (_energyHistory.isNotEmpty) {
        _energyHistory.removeAt(0);
        _energyHistory.add(energy);
      }

      // Throttled Re-draw (Update UI ~30fps)
      _renderThrottler++;
      if (_renderThrottler % 2 == 0) {
         if (mounted) setState(() {});
      }

      // --- 2. AI RECORDING ---
      if (!_isDetecting || !_isModelLoaded) return;

      List<double> row = [
        event.x, event.y, event.z,
        _latestGyro[0], _latestGyro[1], _latestGyro[2]
      ];
      _dataBuffer.add(row);

      if (_dataBuffer.length >= _windowSize) {
        _runInference(List.from(_dataBuffer));
        _dataBuffer.removeRange(0, 50); 
      }
    });
  }

  void _runInference(List<List<double>> inputData) {
    if (_interpreter == null) return;

    var input = [inputData];
    var output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

    _interpreter!.run(input, output);

    List<double> result = List<double>.from(output[0]);
    double maxScore = -1;
    int maxIndex = -1;
    for (int i = 0; i < result.length; i++) {
      if (result[i] > maxScore) {
        maxScore = result[i];
        maxIndex = i;
      }
    }

    if (mounted) {
      setState(() {
        _currentActivity = _labels[maxIndex];
        _probabilities = result;
        _confidence = maxScore;
      });
    }
  }

  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
      if (_isDetecting) {
        _currentActivity = "Detecting...";
      } else {
        _currentActivity = "Paused";
        _confidence = 0.0;
        _probabilities = [];
        _dataBuffer.clear();
      }
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _pulseController.dispose();
    _interpreter?.close();
    super.dispose();
  }

  // ===================================================
  //                    3. UI CODE
  // ===================================================
  @override
  Widget build(BuildContext context) {
    Color accentColor = _isDetecting ? Colors.tealAccent : Colors.grey;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 20),
                
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isDetecting ? Colors.green.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _isDetecting ? Colors.green : Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: _isDetecting ? Colors.green : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _isDetecting ? "LIVE TRACKING" : "READY",
                        style: TextStyle(
                           color: _isDetecting ? Colors.green : Colors.grey, 
                           fontWeight: FontWeight.bold, fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Hero Section
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                      child: Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 50, spreadRadius: 10)
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200, height: 200,
                      child: CircularProgressIndicator(
                        value: _isDetecting ? _confidence : 0.0,
                        strokeWidth: 15,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                    Icon(
                      _getActivityIcon(_currentActivity),
                      size: 80,
                      color: Colors.white,
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),

                Text(
                  _currentActivity.toUpperCase(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                ),
                Text(
                  "CONFIDENCE: ${(_confidence * 100).toInt()}%",
                  style: const TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1.2),
                ),

                const Spacer(),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showDetailsPopup,
                        icon: const Icon(Icons.analytics_outlined, color: Colors.white70),
                        label: const Text("VIEW ANALYSIS", style: TextStyle(color: Colors.white70)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isModelLoaded ? _toggleDetection : null, 
                          icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
                          label: Text(_isDetecting ? "STOP" : "START"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDetecting ? Colors.redAccent : Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- POPUP DETAILS ---
  void _showDetailsPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Timer.periodic(const Duration(milliseconds: 30), (t) {
              if (!mounted || !context.mounted) {
                t.cancel();
              } else {
                setModalState(() {}); 
              }
            });

            return Container(
              height: 550,
              decoration: const BoxDecoration(
                color: Color(0xFF16213E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Center(child: Container(width: 40, height: 4, color: Colors.white24)),
                  const SizedBox(height: 20),
                  const Text("Real-time Analysis", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Waveform Container
                  Container(
                    height: 120,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
                    child: CustomPaint(
                      painter: WavePainter(_energyHistory, Colors.tealAccent),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  const Text("Sensor Energy (Magnitude)", style: TextStyle(color: Colors.white30, fontSize: 10)),
                  const SizedBox(height: 20),

                  // Probabilities List
                  Expanded(
                    child: _probabilities.isEmpty 
                      ? const Center(child: Text("Start tracking to see predictions...", style: TextStyle(color: Colors.white30)))
                      : ListView.builder(
                          itemCount: _labels.length,
                          itemBuilder: (context, index) {
                            final label = _labels[index];
                            final prob = _probabilities[index];
                            final isHighlight = label == _currentActivity;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  SizedBox(width: 80, child: Text(label, style: TextStyle(color: isHighlight ? Colors.white : Colors.white30))),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: prob,
                                      backgroundColor: Colors.white10,
                                      color: isHighlight ? Colors.tealAccent : Colors.teal.withOpacity(0.3),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text("${(prob * 100).toInt()}%", style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getActivityIcon(String activity) {
    switch (activity) {
      case 'Walking': return Icons.directions_walk;
      case 'Jogging': return Icons.directions_run;
      case 'Sitting': return Icons.chair;
      case 'Standing': return Icons.accessibility_new;
      case 'Upstairs': return Icons.stairs;
      case 'Downstairs': return Icons.trending_down; 
      default: return Icons.bolt;
    }
  }
}

// --- WAVE PAINTER ---
class WavePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  WavePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    double stepX = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      
      // FIX 2: Increased sensitivity to 50.0 so movements are VERY visible
      double val = data[i] * 50.0; 
      
      // Clamp prevents it from going off the chart
      double h = (val / 15.0).clamp(0.0, 1.0) * (size.height / 2);
      
      double y = (size.height / 2) - h; 
      
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}