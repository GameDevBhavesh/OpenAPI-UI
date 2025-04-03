import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  /// Sends an HTTP request with the given [method] and [url].
  ///
  /// [bodyType] can be: 'json', 'raw', 'form-data', or 'urlencoded'.
  ///
  /// For:
  ///  - **JSON**: [body] can be a Map or a JSON string.
  ///  - **Raw**: [body] is sent as-is (String or bytes).
  ///  - **Form-Data**: [body] should be a Map<String, dynamic>. Any [File] (mobile)
  ///    or [XFile/Uint8List] (web) values should be manually wrapped in `MultipartFile`.
  ///  - **URL-Encoded**: [body] is a Map<String, String> converted to `application/x-www-form-urlencoded`.
  static Future<String> sendRequest(
    String method,
    String url, {
    dynamic body,
    Map<String, String>? headers,
    String bodyType = 'json',
  }) async {
    final dio = Dio();

    // In case headers is null, create an empty map.
    headers ??= <String, String>{};

    // Make sure we handle content-types logically
    // (Set them if not already provided.)
    if (!headers.containsKey('Content-Type')) {
      switch (bodyType.toLowerCase()) {
        case 'json':
          headers['Content-Type'] = 'application/json';
          break;
        case 'raw-text':
          headers['Content-Type'] = 'text/plain';
          break;
        case 'form-data':
          // content-type will be handled automatically by Dio when using FormData
          break;
        case 'x-www-form-urlencoded':
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
          break;
      }
    }

    // Build Dio Options
    final options = Options(method: method.toUpperCase(), headers: headers);

    // Prepare the request body based on the type
    dynamic finalBody;

    switch (bodyType.toLowerCase()) {
      case 'json':
        // If the body is already a Map, pass it as JSON.
        // If the body is a String, try decoding; otherwise just pass the string.
        if (body is Map || body is List) {
          finalBody = body; // Dio will encode Map/List to JSON automatically
        } else if (body is String && body.trim().isNotEmpty) {
          try {
            finalBody = json.decode(body);
          } catch (_) {
            // If it's not valid JSON, just send raw string
            finalBody = body;
          }
        }
        break;

      case 'raw':
        // Send as raw text or binary
        finalBody = body;
        break;

      case 'form-data':
        // If using form data, we typically pass a Map<String,dynamic>.
        // Any file should be wrapped in `MultipartFile`.
        if (body is Map<String, dynamic>) {
          // Convert the Map into FormData.
          // If you have files, ensure they're already `MultipartFile`.
          finalBody = FormData.fromMap(body);
        } else {
          // If the body is not a Map, just pass as-is (unusual for form-data).
          finalBody = body;
        }
        break;

      case 'urlencoded':
        // Convert the Map to a URL-encoded string: key1=val1&key2=val2
        if (body is Map) {
          finalBody = body.entries
              .map(
                (entry) =>
                    '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}',
              )
              .join('&');
        } else {
          finalBody = body;
        }
        break;

      default:
        // Fallback: treat it as raw
        finalBody = body;
        break;
    }

    // Execute the HTTP call
    try {
      final response = await dio.request(
        url,
        data: finalBody,
        options: options,
      );

      // Return the response body as a string (Dio returns data in [response.data])
      String getPrettyJSONString(jsonObject) {
        var encoder = JsonEncoder.withIndent("     ");
        return encoder.convert(jsonObject);
      }

      return getPrettyJSONString(response.data);
    } on DioError catch (e) {
      // If the server returns an error, you can handle it here or rethrow
      throw Exception('Request failed: ${e.response?.statusCode} ${e.message}');
    }
  }

  /// Fetch OpenAPI requests from `http://localhost:3000/openapi.json`.
  /// Replaces the `http` package usage with Dio.
  static Future<List<RequestItem>> fetchOpenApiRequests() async {
    final dio = Dio();
    try {
      final response = await dio.get('http://localhost:3000/openapi.json');
      if (response.statusCode == 200) {
        final data = response.data;
        List<RequestItem> items = [];
        if (data is Map<String, dynamic> && data['paths'] != null) {
          final paths = data['paths'] as Map<String, dynamic>;
          paths.forEach((path, methods) {
            if (methods is Map<String, dynamic>) {
              methods.forEach((method, details) {
                String summary = details['summary'] ?? 'No summary provided';
                items.add(
                  RequestItem(
                    path: path,
                    method: method.toUpperCase(),
                    summary: summary,
                    details: details,
                  ),
                );
              });
            }
          });
        }
        return items;
      } else {
        throw Exception('Failed to load OpenAPI spec: ${response.statusCode}');
      }
    } on DioError catch (e) {
      throw Exception('Failed to load OpenAPI spec: ${e.message}');
    }
  }
}

/// Example model for an OpenAPI request item.
class RequestItem {
  final String path;
  final String method;
  final String summary;
  final Map<String, dynamic> details;

  RequestItem({
    required this.path,
    required this.method,
    required this.summary,
    required this.details,
  });
}
