import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:openapi_ui/services/api_service.dart';
import 'package:openapi_ui/widgets/all.dart';
import 'package:openapi_ui/services/convertor.dart';

class OpenApiMainScreen extends StatefulWidget {
  @override
  _OpenApiMainScreenState createState() => _OpenApiMainScreenState();
  static String host = 'localhost:3000';
}

class _OpenApiMainScreenState extends State<OpenApiMainScreen> {
  List<RequestItem> requests = [];
  RequestItem? selectedRequest;
  List<RequestItem>? selections = [];
  String responseText = '';
  String doc = "";
  bool docPage = false;
  @override
  void initState() {
    super.initState();
    loadDocs();
    fetchOpenApiRequests()
        .then((fetchedRequests) {
          setState(() {
            requests = fetchedRequests;
            if (requests.isNotEmpty) {
              selectedRequest = requests[0];
            }
          });
        })
        .catchError((error) {
          print("Error fetching OpenAPI spec: $error");
        });
  }

  void loadDocs() async {
    final response = await http.get(
      Uri.parse('http://localhost:3000/openapi.json'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        doc = convertOpenApiToMarkdown(data);
      });
    }
  }

  /// Fetches the OpenAPI spec from the server and extracts endpoints.
  Future<List<RequestItem>> fetchOpenApiRequests() async {
    final response = await http.get(
      Uri.parse('http://localhost:3000/openapi.json'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      OpenApiMainScreen.host = data["host"];
      List<RequestItem> items = [];
      if (data['paths'] != null) {
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
      throw Exception('Failed to load OpenAPI spec');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('OpenAPI Inspector'),
            IconButton(
              onPressed: () {
                setState(() {
                  docPage = true;
                });
              },
              icon: Row(children: [Icon(Icons.book_outlined)]),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  docPage = false;
                });
              },
              icon: Row(children: [Icon(Icons.edit_document)]),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!docPage)
            Expanded(
              child: Row(
                children: [
                  // Sidebar: List of API requests
                  RequestListWidget(
                    requests: requests,
                    selectedRequest: selectedRequest,
                    onSelect: (req) {
                      setState(() {
                        selectedRequest = req;
                        responseText = '';
                      });
                      setState(() {
                        if (!selections!.contains(req)) selections!.add(req);
                      });
                    },
                  ),
                  VerticalDivider(width: 1),
                  // Main panel: Request Builder and Response Viewer
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          flex: 2,
                          child:
                              selectedRequest == null
                                  ? Center(
                                    child: Text(
                                      'Select a request from the sidebar',
                                    ),
                                  )
                                  : InspectRequestScreen(
                                    request: selectedRequest!,
                                    selections: selections!,
                                    onResponse: (resp) {
                                      setState(() {
                                        responseText = resp;
                                      });
                                    },
                                    onClose: (RequestItem) {
                                      setState(() {
                                        selections!.remove(RequestItem);
                                      });
                                    },
                                  ),
                        ),
                        Divider(height: 1),
                        Expanded(
                          flex: 1,
                          child: ResponseViewerWidget(response: responseText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: SelectionArea(
                child: Markdown(
                  data: doc,
                  styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      title: 'OpenAPI-UI',
      theme: ThemeData.dark(),
      home: OpenApiMainScreen(),
    ),
  );
}
