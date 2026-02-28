import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('E:/Whatapplikeapp/Logo/applogo.png');
  final image = img.decodePng(file.readAsBytesSync());
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  // Find bounding box of non-transparent pixels
  int minX = image.width;
  int minY = image.height;
  int maxX = 0;
  int maxY = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a > 0) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Original size: ${image.width}x${image.height}');
  print('Bounding box: ($minX, $minY) to ($maxX, $maxY)');

  final cropWidth = maxX - minX + 1;
  final cropHeight = maxY - minY + 1;

  // Create a square image that fits the cropped area
  final size = cropWidth > cropHeight ? cropWidth : cropHeight;

  // Add padding for safe zone in adaptive icons.
  // The safe zone is ~66% of the total size for Android adaptive icons.
  // So size should be 60% of newSize to be safe.
  // newSize = size / 0.6
  final newSize = (size / 0.6).toInt();
  final paddingX = (newSize - cropWidth) ~/ 2;
  final paddingY = (newSize - cropHeight) ~/ 2;

  final newImage = img.Image(width: newSize, height: newSize);

  // Create a white background if the user wants a white box, but adaptive icons allow backgrounds.
  // We'll leave it transparent and set adaptive_icon_background to white in pubspec.

  final cropped = img.copyCrop(
    image,
    x: minX,
    y: minY,
    width: cropWidth,
    height: cropHeight,
  );
  img.compositeImage(newImage, cropped, dstX: paddingX, dstY: paddingY);

  final outFile = File('E:/Whatapplikeapp/Logo/zoomed_applogo.png');
  outFile.writeAsBytesSync(img.encodePng(newImage));
  print('Saved cropped and padded image to ${outFile.path}');
}
