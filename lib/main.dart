import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Processor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ImageProcessorPage(),
    );
  }
}

class ImageProcessorPage extends StatefulWidget {
  const ImageProcessorPage({super.key});

  @override
  _ImageProcessorPageState createState() => _ImageProcessorPageState();
}

class _ImageProcessorPageState extends State<ImageProcessorPage> {
  File? _image;
  File? _processedImage;
  final picker = ImagePicker();
  tflite.Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  Map<String, dynamic> _imageStats = {};
  int _originalWidth = 0;
  int _originalHeight = 0;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    loadModel();
  }

  Future<void> requestPermissions() async {
    if (await Permission.camera.isGranted && await Permission.storage.isGranted) {
      return; // Permissions are already granted
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.storage] != PermissionStatus.granted ||
        statuses[Permission.photos] != PermissionStatus.granted) {
      // Show an alert to the user indicating that permissions are necessary
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
              'Please grant camera and storage permissions in the settings to use this app.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> loadModel() async {
    try {
      if (kDebugMode) {
        print('Attempting to load model...');
      }
      _interpreter = await tflite.Interpreter.fromAsset('assets/unet_model.tflite');
      _isModelLoaded = true;
      if (kDebugMode) {
        print('Model loaded successfully');
        print('Input shape: ${_interpreter?.getInputTensor(0).shape}');
        print('Output shape: ${_interpreter?.getOutputTensor(0).shape}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading model: $e');
      }
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Imagen',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              _buildImageContainer(
                  _image,
                  'Original Image',
                  _originalWidth > 0 ? '${_originalWidth}x${_originalHeight}' : null
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Select Image'),
                    onPressed: getImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_fix_high),
                    label: _isProcessing
                        ? const Text('Processing...')
                        : const Text('Enhance'),
                    onPressed: _isProcessing || _image == null ? null : processImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_processedImage != null) ...[
                _buildImageContainer(
                    _processedImage,
                    'Enhanced Image',
                    _originalWidth > 0 ? '${_originalWidth}x${_originalHeight}' : null
                ),
                const SizedBox(height: 16),
                _buildImageStatsCard(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download Report'),
                  onPressed: _imageStats.isNotEmpty ? generateAndDownloadReport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContainer(File? imageFile, String title, String? dimensions) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title bar with label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (dimensions != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '($dimensions)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Image or placeholder
          imageFile == null
              ? SizedBox(
            height: 250,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 50, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text(
                  title == 'Original Image'
                      ? 'Select an image to enhance'
                      : 'Enhanced image will appear here',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          )
              : ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
            child: Image.file(
              imageFile,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStatsCard() {
    if (_imageStats.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          _buildStatRow('Dimensions', '${_imageStats['width']}x${_imageStats['height']} px'),
          _buildStatRow('Average Brightness (Before)', '${_imageStats['avgBrightnessBefore'].toStringAsFixed(2)}%'),
          _buildStatRow('Average Brightness (After)', '${_imageStats['avgBrightnessAfter'].toStringAsFixed(2)}%'),
          _buildStatRow('Brightness Improvement', '${_imageStats['brightnessImprovement'].toStringAsFixed(2)}%'),
          _buildStatRow('Contrast (Before)', _imageStats['contrastBefore'].toStringAsFixed(2)),
          _buildStatRow('Contrast (After)', _imageStats['contrastAfter'].toStringAsFixed(2)),
          _buildStatRow('Contrast Improvement', '${_imageStats['contrastImprovement'].toStringAsFixed(2)}%'),
          _buildStatRow('Processing Time', '${_imageStats['processingTime']} ms'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future getImage() async {
    final ImageSource? source = await _chooseImageSource(context);
    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _processedImage = null;
        _imageStats = {};
      } else {
        if (kDebugMode) {
          print('No image selected.');
        }
      }
    });

    // Get original dimensions
    if (_image != null) {
      try {
        final bytes = await _image!.readAsBytes();
        final decodedImage = img.decodeImage(bytes);
        if (decodedImage != null) {
          setState(() {
            _originalWidth = decodedImage.width;
            _originalHeight = decodedImage.height;
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error getting image dimensions: $e');
        }
      }
    }
  }

  Future<ImageSource?> _chooseImageSource(BuildContext context) async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Choose image source'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, ImageSource.camera);
              },
              child: const Text('Camera'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, ImageSource.gallery);
              },
              child: const Text('Gallery'),
            ),
          ],
        );
      },
    );
  }

  Future<void> processImage() async {
    if (_image == null) return;

    if (!_isModelLoaded) {
      if (kDebugMode) {
        print('Interpreter is not initialized yet.');
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final stopwatch = Stopwatch()..start();

      // Decode the original image and save its stats
      final bytes = await _image!.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        if (kDebugMode) {
          print('Error decoding image.');
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Calculate original image statistics
      final originalStats = calculateImageStats(originalImage);

      // Resize for model processing
      img.Image resizedImage = img.copyResize(originalImage, width: 256, height: 256);
      var inputImage = Float32List(3 * 256 * 256);

      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          var pixel = resizedImage.getPixel(x, y);
          inputImage[(0 * 256 * 256) + (y * 256) + x] =
              img.getRed(pixel) / 255.0;
          inputImage[(1 * 256 * 256) + (y * 256) + x] =
              img.getGreen(pixel) / 255.0;
          inputImage[(2 * 256 * 256) + (y * 256) + x] =
              img.getBlue(pixel) / 255.0;
        }
      }

      var input = inputImage.reshape([1, 3, 256, 256]);
      var output = Float32List(3 * 256 * 256).reshape([1, 3, 256, 256]);

      _interpreter!.run(input, output);

      // Create the enhanced image at the model's output size
      var enhancedImage = img.Image(256, 256);
      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          int r = (output[0][0][y][x] * 255).round().clamp(0, 255);
          int g = (output[0][1][y][x] * 255).round().clamp(0, 255);
          int b = (output[0][2][y][x] * 255).round().clamp(0, 255);
          enhancedImage.setPixel(x, y, img.getColor(r, g, b));
        }
      }

      // Calculate enhanced image statistics
      final enhancedStats = calculateImageStats(enhancedImage);

      // Resize the enhanced image back to the original dimensions
      img.Image finalEnhancedImage = img.copyResize(
          enhancedImage,
          width: _originalWidth,
          height: _originalHeight
      );

      final tempDir = await getTemporaryDirectory();
      File outputFile = File('${tempDir.path}/output.png');
      await outputFile.writeAsBytes(img.encodePng(finalEnhancedImage));

      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;

      // Calculate improvement stats
      final double brightnessImprovement =
      ((enhancedStats['brightness']! - originalStats['brightness']!) /
          originalStats['brightness']! * 100);

      final double contrastImprovement =
      ((enhancedStats['contrast']! - originalStats['contrast']!) /
          originalStats['contrast']! * 100);

      setState(() {
        _processedImage = outputFile;
        _imageStats = {
          'width': _originalWidth,
          'height': _originalHeight,
          'avgBrightnessBefore': originalStats['brightness'],
          'avgBrightnessAfter': enhancedStats['brightness'],
          'brightnessImprovement': brightnessImprovement,
          'contrastBefore': originalStats['contrast'],
          'contrastAfter': enhancedStats['contrast'],
          'contrastImprovement': contrastImprovement,
          'processingTime': processingTime,
        };
        _isProcessing = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image: $e');
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, double> calculateImageStats(img.Image image) {
    double totalBrightness = 0;
    List<double> pixelBrightness = [];

    // Calculate average brightness
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);

        // Standard luminance formula
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255 * 100;
        totalBrightness += brightness;
        pixelBrightness.add(brightness);
      }
    }

    final avgBrightness = totalBrightness / (image.width * image.height);

    // Calculate contrast (standard deviation of brightness)
    double varianceSum = 0;
    for (final brightness in pixelBrightness) {
      varianceSum += math.pow(brightness - avgBrightness, 2);
    }

    final variance = varianceSum / pixelBrightness.length;
    final contrast = math.sqrt(variance);

    return {
      'brightness': avgBrightness,
      'contrast': contrast,
    };
  }

  Future<void> generateAndDownloadReport() async {
    if (_imageStats.isEmpty) return;

    final now = DateTime.now();
    final dateString = '${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}';
    final fileName = 'image_enhancement_report_$dateString.txt';

    String reportContent = """
IMAGE ENHANCEMENT REPORT
Generated: ${now.toString()}

ORIGINAL IMAGE
Dimensions: ${_imageStats['width']}x${_imageStats['height']} pixels
Average Brightness: ${_imageStats['avgBrightnessBefore']!.toStringAsFixed(2)}%
Contrast: ${_imageStats['contrastBefore']!.toStringAsFixed(2)}

ENHANCED IMAGE
Dimensions: ${_imageStats['width']}x${_imageStats['height']} pixels
Average Brightness: ${_imageStats['avgBrightnessAfter']!.toStringAsFixed(2)}%
Contrast: ${_imageStats['contrastAfter']!.toStringAsFixed(2)}

IMPROVEMENTS
Brightness Improvement: ${_imageStats['brightnessImprovement']!.toStringAsFixed(2)}%
Contrast Improvement: ${_imageStats['contrastImprovement']!.toStringAsFixed(2)}%

TECHNICAL DETAILS
Processing Time: ${_imageStats['processingTime']} milliseconds
Model: GAN-based Low Light Enhancement
Framework: TensorFlow Lite
Platform: Flutter (${Platform.operatingSystem})

NOTES
This report was generated automatically by the Low Light Image Enhancement application.
The enhancement process uses a Generative Adversarial Network (GAN) to improve
image visibility in low-light conditions while maintaining natural appearance.
""";

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(reportContent);

      // Show success dialog with file path
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report Generated'),
          content: Text('Report saved to:\n${file.path}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving report: $e');
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to save report: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

extension ReshapeExtension on Float32List {
  List<List<List<List<double>>>> reshape(List<int> shape) {
    int total = shape.reduce((a, b) => a * b);
    if (length != total) {
      throw ArgumentError(
          'Total elements mismatch expected: $total elements but found $length');
    }

    return [
      List.generate(shape[1], (c) {
        return List.generate(shape[2], (y) {
          return List.generate(shape[3], (x) {
            return this[(c * shape[2] * shape[3]) + (y * shape[3]) + x]
                .toDouble();
          });
        });
      })
    ];
  }
}