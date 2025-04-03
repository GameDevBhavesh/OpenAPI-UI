import 'dart:convert' as jsonn;
import 'dart:io' show File;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/languages/json.dart';
import 'package:openapi_ui/main.dart';
import 'package:openapi_ui/services/api_service.dart';

/// A widget that allows the user to craft an HTTP request (headers/body/url)
/// and send it via Dio, including file uploads for Form-Data.
class RequestMaker extends StatefulWidget {
  const RequestMaker({
    super.key,
    required this.request,
    required this.onResponse,
  });

  final RequestItem request;
  final Function(String) onResponse; // Callback to pass response back.

  @override
  State<RequestMaker> createState() => _RequestMakerState();
}

class _RequestMakerState extends State<RequestMaker> {
  // URL
  late TextEditingController _urlController;

  // HTTP method
  late String _selectedMethod;

  // Code editor for body
  late CodeController _codeController;

  // Body types
  final _bodyTypes = ['JSON', 'Raw-Text', 'Form-Data', 'x-www-form-urlencoded'];
  String _selectedBodyType = 'JSON';

  // Headers
  List<HeaderEntry> _headers = [
    HeaderEntry(
      keyController: TextEditingController(text: 'Content-Type'),
      valueController: TextEditingController(text: 'application/json'),
    ),
  ];

  // File picking: we'll store the path/bytes after picking a file
  String? _pickedFilePath;
  Uint8List? _pickedFileBytes;
  String? _pickedFileName; // optional to keep track of the original filename

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: 'http://${OpenApiMainScreen.host}${widget.request.path}',
    );
    _selectedMethod = widget.request.method;

    // Code controller for JSON or raw text
    _codeController = CodeController(
      text: '',
      language: json, // from 'highlight/languages/json.dart'
    );
  }

  @override
  void didUpdateWidget(covariant RequestMaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _urlController.text =
        'http://${OpenApiMainScreen.host}${widget.request.path}';
    _selectedMethod = widget.request.method;
  }

  /// Convert UI’s body type to string for internal logic
  String _mapBodyType(String uiType) {
    switch (uiType) {
      case 'JSON':
        return 'json';
      case 'Raw-Text':
        return 'raw';
      case 'Form-Data':
        return 'form-data';
      case 'x-www-form-urlencoded':
        return 'urlencoded';
      default:
        return 'raw';
    }
  }

  /// Let the user pick a file from the device or web
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      // type: FileType.any, // or FileType.custom, etc.
    );
    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.first;
      setState(() {
        _pickedFileName = picked.name;
        if (kIsWeb) {
          // On web, no actual file path. We get bytes.
          _pickedFileBytes = picked.bytes;
          _pickedFilePath = null;
        } else {
          // On mobile/desktop, we can get a path to the file.
          _pickedFilePath = picked.path;
          _pickedFileBytes = null;
        }
      });
    }
  }

  Future<void> _sendRequest() async {
    // Collect headers from UI
    final headersMap = <String, String>{};
    for (final entry in _headers) {
      final key = entry.keyController.text.trim();
      final value = entry.valueController.text.trim();
      if (key.isNotEmpty) {
        headersMap[key] = value;
      }
    }

    final url = _urlController.text.trim();
    final rawText = _codeController.text.trim();

    // 1) Decide body type
    final bodyType = _mapBodyType(_selectedBodyType);

    // 2) Prepare body, if any
    dynamic body;
    if (rawText.isNotEmpty) {
      switch (_selectedBodyType) {
        case 'JSON':
          try {
            body = jsonn.jsonDecode(rawText);
          } catch (_) {
            body = rawText; // fallback to raw
          }
          break;
        case 'Raw-Text':
          body = rawText;
          break;
        case 'Form-Data':
          // If user has typed something for form-data, you can parse it or treat as raw.
          // Also, if a file was picked, let’s add it to the form.
          // This example just always sends `FormData`.
          final formMap = <String, dynamic>{};

          // Suppose you want to store the raw text in a "field" called "data"
          // OR parse key-value lines from raw text. For now, we just do:
          if (rawText.isNotEmpty) {
            // naive approach: put entire text under a "data" field
            formMap['data'] = rawText;
          }

          // If a file is picked, add it to the map
          if (_pickedFilePath != null) {
            // On mobile/desktop, we have a real path
            final fileData = await MultipartFile.fromFile(
              _pickedFilePath!,
              filename: _pickedFileName ?? 'upload.file',
            );
            formMap['file'] = fileData;
          } else if (_pickedFileBytes != null) {
            // On web, we only have bytes
            final fileData = MultipartFile.fromBytes(
              _pickedFileBytes!,
              filename: _pickedFileName ?? 'upload.file',
            );
            formMap['file'] = fileData;
          }

          // Convert the map to FormData
          body = FormData.fromMap(formMap);
          break;
        case 'x-www-form-urlencoded':
          // Typically parse "key1=value1&key2=value2" or build from user inputs
          // We'll just send it as-is.
          body = rawText;
          break;
      }
    }

    // 3) Perform the request using Dio
    final dio = Dio();

    // If no Content-Type provided, pick from bodyType
    if (!headersMap.containsKey('Content-Type')) {
      switch (bodyType) {
        case 'json':
          headersMap['Content-Type'] = 'application/json';
          break;
        case 'raw':
          headersMap['Content-Type'] = 'text/plain';
          break;
        case 'form-data':
          // Typically handled automatically by Dio
          break;
        case 'urlencoded':
          headersMap['Content-Type'] = 'application/x-www-form-urlencoded';
          break;
      }
    }

    final options = Options(
      method: _selectedMethod.toUpperCase(),
      headers: headersMap,
    );

    try {
      final response = await dio.request(url, data: body, options: options);

      // Return stringified response
      widget.onResponse(response.data?.toString() ?? '');
    } on DioError catch (e) {
      widget.onResponse(
        'Error: ${e.message} (status: ${e.response?.statusCode})',
      );
    } catch (err) {
      widget.onResponse('Error: $err');
    }
  }

  /// Add another header entry
  void _addHeaderRow() {
    setState(() {
      _headers.add(
        HeaderEntry(
          keyController: TextEditingController(),
          valueController: TextEditingController(),
        ),
      );
    });
  }

  /// Remove a header entry
  void _removeHeaderRow(int index) {
    setState(() {
      _headers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // URL + Method
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Request URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedMethod,
                  items:
                      ['GET', 'POST', 'PUT', 'DELETE']
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMethod = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Body Type
            Row(
              children: [
                const Text('Body Type: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedBodyType,
                  items:
                      _bodyTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBodyType = val);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // If Form-Data is selected, show file-pick button
            if (_selectedBodyType == 'Form-Data') ...[
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Pick File'),
              ),
              if (_pickedFilePath != null || _pickedFileBytes != null)
                Text(
                  'Picked file: ${_pickedFileName ?? 'Unnamed'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 16),
            ],

            // Headers
            const Text(
              'Headers:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._headers.asMap().entries.map((entry) {
              final index = entry.key;
              final headerEntry = entry.value;
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: headerEntry.keyController,
                      decoration: const InputDecoration(
                        labelText: 'Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: headerEntry.valueController,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () => _removeHeaderRow(index),
                  ),
                ],
              );
            }).toList(),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _addHeaderRow,
              child: const Text('Add Header'),
            ),
            const SizedBox(height: 16),

            // Body Editor
            const Text(
              'Request Body:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: SingleChildScrollView(
                child: CodeTheme(
                  data: CodeThemeData(styles: githubTheme),
                  child: CodeField(
                    controller: _codeController,
                    textStyle: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Send Request
            ElevatedButton(
              onPressed: _sendRequest,
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Basic object to hold our header row controllers
class HeaderEntry {
  final TextEditingController keyController;
  final TextEditingController valueController;

  HeaderEntry({required this.keyController, required this.valueController});
}

// /// Displays the final HTTP response (or error) in a scrollable text box
// class ResponseViewerWidget extends StatelessWidget {
//   final String response;

//   const ResponseViewerWidget({super.key, required this.response});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       color: Colors.black12,
//       child: SingleChildScrollView(
//         child: Text(
//           response,
//           style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
//         ),
//       ),
//     );
//   }
// }
