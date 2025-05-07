import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dv8bbvd5q';
  static const String uploadPreset =
      'instagram_image'; // preset cần được định nghĩa trong Cloudinary
  final String apiKey = '694346715987963'; // API Key
  final String apiSecret = 'DGz1DSJ9HXmP61_8geOOp7lDl-Y'; // API Secret

  // Hàm tải ảnh lên Cloudinary
  static Future<String?> uploadImage(Uint8List imageBytes) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    // Tạo request multipart để tải ảnh lên Cloudinary
    var request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: 'avatar.jpg'),
    );

    try {
      // Gửi request và nhận response
      final response = await request.send();
      if (response.statusCode == 200) {
        // Đọc dữ liệu trả về từ server
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);

        // Trả về secure_url chứa URL ảnh đã upload
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
