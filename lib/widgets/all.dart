import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:openapi_ui/services/api_service.dart';
import 'package:openapi_ui/widgets/request_maker.dart';

/// Widget to display a list of API requests (the sidebar).
class RequestListWidget extends StatelessWidget {
  final List<RequestItem> requests;
  final RequestItem? selectedRequest;
  final Function(RequestItem) onSelect;

  RequestListWidget({
    required this.requests,
    required this.selectedRequest,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey)),
      ),
      child: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final req = requests[index];
          bool isSelected = req == selectedRequest;
          return ListTile(
            title: Text('${req.method} ${req.path}'),
            subtitle: Text(
              req.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: isSelected,
            onTap: () => onSelect(req),
          );
        },
      ),
    );
  }
}

/// Widget for editing request details and sending the API request.
class InspectRequestScreen extends StatefulWidget {
  final RequestItem request;
  final List<RequestItem> selections;
  final Function(String) onResponse; // Callback to pass response back.
  final Function(RequestItem) onClose;

  InspectRequestScreen({
    required this.request,
    required this.onResponse,
    required this.selections,
    required this.onClose,
  });

  @override
  _InspectRequestScreenState createState() => _InspectRequestScreenState();
}

class _InspectRequestScreenState extends State<InspectRequestScreen> {
  int selected = 0;

  @override
  void didUpdateWidget(covariant InspectRequestScreen oldWidget) {
    setState(() {
      selected = widget.selections.indexOf(widget.request);
    });

    // TODO: implement didUpdateWidget
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.selections.length; i++)
                  TextButton(
                    style: ButtonStyle(
                      backgroundColor:
                          i == selected
                              ? WidgetStatePropertyAll(
                                Colors.white.withValues(alpha: .1),
                              )
                              : null,
                    ),
                    onPressed: () {
                      setState(() {
                        selected = i;
                      });
                    },
                    child: Row(
                      children: [
                        Text(widget.selections[i].path),
                        IconButton(
                          onPressed: () {
                            widget.onClose(widget.selections[i]);
                          },
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              for (int i = 0; i < widget.selections.length; i++)
                Visibility.maintain(
                  visible: selected == i,
                  child: RequestMaker(
                    onResponse: widget.onResponse,
                    request: widget.selections[i],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// class RequestMaker extends StatefulWidget {
//   const RequestMaker({
//     super.key,
//     required this.request,

//     required this.onResponse,
//   });
//   final RequestItem request;

//   final Function(String) onResponse; // Callback to pass response back.

//   @override
//   State<RequestMaker> createState() => _RequestMakerState();
// }

// class _RequestMakerState extends State<RequestMaker> {
//   final TextEditingController _bodyController = TextEditingController();
//   // For simplicity, assume URL is the combination of a base URL and the request's path.
//   late TextEditingController _urlController;
//   late String _selectedMethod;
//   @override
//   void initState() {
//     super.initState();
//     _urlController = TextEditingController(
//       text: 'http://localhost:3000${widget.request.path}',
//     );
//     _selectedMethod = widget.request.method;
//   }

//   @override
//   void didUpdateWidget(covariant RequestMaker oldWidget) {
//     print("update");

//     _urlController = TextEditingController(
//       text: 'http://localhost:3000${widget.request.path}',
//     );
//     _selectedMethod = widget.request.method; // TODO: implement didUpdateWidget
//     super.didUpdateWidget(oldWidget);
//   }

//   Future<void> _sendRequest() async {
//     String url = _urlController.text;
//     dynamic body;
//     if (_bodyController.text.isNotEmpty) {
//       try {
//         body = json.decode(_bodyController.text);
//       } catch (e) {
//         body = _bodyController.text;
//       }
//     }
//     try {
//       String response = await ApiService.sendRequest(
//         _selectedMethod,
//         url,
//         body: body,
//       );
//       widget.onResponse(response);
//     } catch (e) {
//       widget.onResponse('Error: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // URL & Method editor
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _urlController,
//                     decoration: InputDecoration(
//                       labelText: 'Request URL',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 DropdownButton<String>(
//                   value: _selectedMethod,
//                   items:
//                       ['GET', 'POST', 'PUT', 'DELETE']
//                           .map(
//                             (method) => DropdownMenuItem(
//                               child: Text(method),
//                               value: method,
//                             ),
//                           )
//                           .toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _selectedMethod = value!;
//                     });
//                   },
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             // JSON/Text Editor for request body
//             Text(
//               'Request Body (JSON or Plain Text):',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             JSONEditor(controller: _bodyController),
//             SizedBox(height: 16),
//             // Send Request Button
//             ElevatedButton(
//               onPressed: _sendRequest,
//               child: Text('Send Request'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

/// A simple widget for editing JSON or plain text.
class JSONEditor extends StatelessWidget {
  final TextEditingController controller;

  JSONEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 8,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter JSON or text here...',
      ),
    );
  }
}

/// Widget to display the API response.
class ResponseViewerWidget extends StatelessWidget {
  final String response;

  ResponseViewerWidget({required this.response});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Container(
        padding: EdgeInsets.all(16),
        color: Colors.black12,
        child: SingleChildScrollView(
          child: Text(
            response,
            style: TextStyle(fontFamily: 'Courier', fontSize: 14),
          ),
        ),
      ),
    );
  }
}
