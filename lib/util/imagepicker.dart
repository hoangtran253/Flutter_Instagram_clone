import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class ImagePickerr {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> pickImageAsBytes(String inputSource) async {
    final XFile? pickedImage = await _picker.pickImage(
      source:
          inputSource == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (pickedImage == null) return null;
    return await pickedImage.readAsBytes();
  }
}
