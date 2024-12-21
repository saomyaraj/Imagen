# Suppress warnings for TensorFlow Lite GPU classes
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-keep class org.tensorflow.lite.gpu.** { *; }
