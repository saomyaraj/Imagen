import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter_plus/tflite_flutter_plus.dart';
import 'dart:typed_data';

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

  @override
  void initState() {
    super.initState();
    requestPermissions();
    loadModel();
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.storage] != PermissionStatus.granted ||
        statuses[Permission.photos] != PermissionStatus.granted) {
      openAppSettings();
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
      backgroundColor: Colors.grey[100], // Light background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text('Image Enhancement',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              _image == null
                  ? Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 50,
                        color: Colors.grey[400]
                    ),
                    SizedBox(height: 10),
                    Text('Select an image to enhance',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16
                      ),
                    )
                  ],
                ),
              )
                  : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(_image!),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.add_photo_alternate),
                    label: Text('Select Image'),
                    onPressed: getImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.auto_fix_high),
                    label: Text('Enhance'),
                    onPressed: _image == null ? null : processImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              if (_processedImage != null) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(_processedImage!),
                  ),
                ),
                SizedBox(height: 16),
                Text('Enhanced Image',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800]
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future getImage() async {
    await requestPermissions();

    final ImageSource? source = await _chooseImageSource(context);
    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _processedImage = null;
      } else {
        if (kDebugMode) {
          print('No image selected.');
        }
      }
    });
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

    try {
      img.Image? image = img.decodeImage(await _image!.readAsBytes());
      if (image == null) {
        if (kDebugMode) {
          print('Error decoding image.');
        }
        return;
      }

      image = img.copyResize(image, width: 256, height: 256);
      var inputImage = Float32List(3 * 256 * 256);

      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          var pixel = image.getPixel(x, y);
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

      var outputImage = img.Image(256, 256);
      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          int r = (output[0][0][y][x] * 255).round().clamp(0, 255);
          int g = (output[0][1][y][x] * 255).round().clamp(0, 255);
          int b = (output[0][2][y][x] * 255).round().clamp(0, 255);
          outputImage.setPixel(x, y, img.getColor(r, g, b));
        }
      }

      final tempDir = await getTemporaryDirectory();
      File outputFile = File('${tempDir.path}/output.png');
      await outputFile.writeAsBytes(img.encodePng(outputImage));

      setState(() {
        _processedImage = outputFile;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image: $e');
      }
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