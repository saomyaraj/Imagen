# Imagen - An AI based Image Enhancement App

A Flutter-based mobile application that processes images using a TensorFlow Lite model. The app allows users to select an image, apply image segmentation or enhancement using a U-Net model, and view the processed output.

---

## Features

- **Image Selection**: Choose an image from the device's gallery or capture a new one using the camera.
- **Image Processing**: Process images using a TensorFlow Lite U-Net model for tasks like segmentation or enhancement.
- **Dynamic UI**: Intuitive user interface built with Flutter for seamless interaction.
- **Temporary Storage**: Save processed images to the device's temporary storage.

---

## Prerequisites

1. Flutter SDK installed on your system.
2. Android Studio or Xcode for running the application.
3. Ensure you have the following permissions enabled on your device:
   - Camera
   - Storage

---

## Installation Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/saomyaraj/Imagen.git
   ```

2. Navigate to the project directory:

   ```bash
   cd Imagen
   ```

3. Get the dependencies:

   ```bash
   flutter pub get
   ```

4. Run the app:

   ```bash
   flutter run
   ```

---

## Usage

1. Launch the app on your device.
2. Tap **Select Image** to choose an image from your gallery or capture one using the camera.
3. Click **Process Image** to apply the TensorFlow Lite model on the selected image.
4. View and save the processed image.

---

## Key Technologies

- **Flutter**: Framework for building cross-platform mobile apps.
- **Dart**: Programming language used by Flutter.
- **TensorFlow Lite**: Lightweight deep learning model for mobile devices.
- **Image Package**: Library for image manipulation in Dart.
- **Permission Handler**: For managing device permissions.

---

## Model Details

- **Model Name**: GAN based U-Net
- **Purpose**: Image segmentation or enhancement.
- **Input Dimensions**: `256x256x3`
- **Output Dimensions**: `256x256x3`

Ensure that the model file `unet_model.tflite` is placed in the `assets/` directory.

---

## Contributing

1. Fork the repository.
2. Create your feature branch:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. Commit your changes:

   ```bash
   git commit -m 'Add some feature'
   ```

4. Push to the branch:

   ```bash
   git push origin feature/your-feature-name
   ```

5. Open a pull request.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Contact

- **Developer**: [Saomyaraj Jha](https://github.com/saomyaraj)
- **Email**: <saomyaraj.dev@gmail.com>
- **GitHub**: [https://github.com/saomyaraj](https://github.com/saomyaraj)
