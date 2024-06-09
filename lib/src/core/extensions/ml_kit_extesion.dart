import 'package:m7_livelyness_detection/index.dart';

extension MLKitUtils on AnalysisImage {
  InputImage toInputImage() {
    final planeDataBytesPerRow =
        when(nv21: (img) => img.planes, bgra8888: (img) => img.planes)?.first.bytesPerRow??0;

    return when(nv21: (image) {
      return InputImage.fromBytes(
        bytes: image.bytes,
        metadata: InputImageMetadata(
          rotation: inputImageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: planeDataBytesPerRow,
          size: image.size,
        ),
      );
    }, bgra8888: (image) {
      final inputImageData = InputImageMetadata(
        size: size,
        // FIXME: seems to be ignored on iOS...
        rotation: inputImageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: image.bytes,
        metadata: inputImageData,
      );
    })!;
  }

  InputImageRotation get inputImageRotation =>
      InputImageRotation.values.byName(rotation.name);

  InputImageFormat get inputImageFormat {
    switch (format) {
      case InputAnalysisImageFormat.bgra8888:
        return InputImageFormat.bgra8888;
      case InputAnalysisImageFormat.nv21:
        return InputImageFormat.nv21;
      default:
        return InputImageFormat.yuv420;
    }
  }
}
