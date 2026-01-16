# 🏃‍♂️ AI Activity Recognition App (Flutter + TensorFlow Lite)

A high-performance mobile application that uses **On-Device Machine Learning** to detect human physical activities (Walking, Jogging, Sitting, Standing) in real-time using smartphone sensors.

##  Key Features
* **Edge AI:** Runs a custom trained **1D-Convolutional Neural Network (CNN)** directly on the device using TensorFlow Lite. No internet required.
* **Real-Time Processing:** Processes continuous streams of Accelerometer & Gyroscope data at **50Hz**.
* **High-Performance UI:** Features a custom-painted **Oscilloscope Waveform** that visualizes sensor energy magnitude at 60FPS using Dart's `CustomPainter`.
* **Battery Efficient:** Implements smart stream throttling and "Sliding Window" buffering to minimize CPU usage while maintaining high inference accuracy.

##  Tech Stack
* **Mobile:** Flutter (Dart), `sensors_plus`, `tflite_flutter`
* **AI/ML:** Python, TensorFlow/Keras, Pandas, Scikit-Learn
* **Data Processing:** Sliding Window Algorithm, Signal Magnitude Area (SMA)

##  The Model Architecture
The AI "Brain" was trained on the *MotionSense Dataset* using Python.
1.  **Input:** 2.5 seconds of sensor data (Window size 100 x 6 channels).
2.  **Layers:** 1D-Conv -> BatchNorm -> MaxPool -> Dropout -> Dense.
3.  **Optimization:** Converted to `.tflite` with quantization for mobile efficiency (Size: <100KB).

## 📸 Screenshots

![activity_flutter_app](https://github.com/user-attachments/assets/114efc89-1fb1-4469-87f7-c46e9a2dc999)

## 👨‍💻 How to Run
1.  Clone the repo.
2.  Run `flutter pub get`.
3.  Connect an Android device and run `flutter run`.
