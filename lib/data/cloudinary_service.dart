import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = 'dv8bbvd5q';
  static const String uploadPresetImage = 'instagram_image';
  static const String uploadPresetVideo = 'instagram_video';

  // 📸 Upload ảnh (avatar, post, ...)
  static Future<String?> uploadImage(
    Uint8List imageBytes, {
    String folder = 'others',
    String? fileName,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    var request =
        http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPresetImage
          ..fields['folder'] = folder
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              imageBytes,
              filename:
                  fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        return jsonMap['secure_url'];
      } else {
        print('❌ Upload ảnh thất bại: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Lỗi khi upload ảnh: $e');
      return null;
    }
  }

  // 🎥 Upload video (reels, story, ...)
  static Future<String?> uploadVideo(XFile videoFile) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
      );

      Uint8List videoBytes = await videoFile.readAsBytes();

      var request =
          http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = uploadPresetVideo
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                videoBytes,
                filename: videoFile.name,
              ),
            );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        return jsonMap['secure_url'];
      } else {
        print('❌ Upload video thất bại: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Lỗi khi upload video: $e');
      return null;
    }
  }
}
