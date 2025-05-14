import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dv8bbvd5q';
  static const String uploadPreset =
      'instagram_image'; // preset trong Cloudinary

  // Hàm tải ảnh lên Cloudinary, có thể phân loại (avatar, post, ...)
  static Future<String?> uploadImage(
    Uint8List imageBytes, {
    String folder = 'others',
    String? fileName,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    var request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = folder;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        return jsonMap['secure_url'];
      } else {
        print('Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}
