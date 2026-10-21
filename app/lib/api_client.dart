import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models/prediction.dart';

String _imageSubtype(String filename) {
  final extension = filename.toLowerCase().split('.').last;
  return switch (extension) {
    'png' => 'png',
    'webp' => 'webp',
    'gif' => 'gif',
    _ => 'jpeg',
  };
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8001',
  );

  final http.Client _client;

  Future<Prediction> predict(Uint8List bytes, String filename) async {
    final uri = Uri.parse(baseUrl).resolve('/predict');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('image', _imageSubtype(filename)),
        ),
      );
    late http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } on http.ClientException {
      throw const ApiException('Could not connect to the classifier. Check the API server and URL.');
    } catch (_) {
      throw const ApiException('Could not connect to the classifier. Check the API server and URL.');
    }
    late http.Response response;
    try {
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException('Could not read the response from the classifier.');
    }
    if (response.statusCode != 200) {
      var detail = 'The classifier returned an error (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final message = body['detail'] ?? body['error'];
          if (message is String && message.isNotEmpty) detail = message;
        }
      } catch (_) {
        // Keep the friendly status message when an error body is not JSON.
      }
      throw ApiException(detail);
    }
    late Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('The classifier returned invalid JSON.');
    }
    return Prediction.fromJson(decoded);
  }
}
