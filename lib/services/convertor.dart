import 'dart:convert';

String convertOpenApiToMarkdown(Map<String, dynamic> openApi) {
  final buffer = StringBuffer();

  buffer.writeln('# ${openApi['info']['title']}');
  buffer.writeln('**Version:** ${openApi['info']['version']}\n');
  buffer.writeln('${openApi['info']['description'] ?? ''}\n');

  if (openApi.containsKey('paths')) {
    buffer.writeln('## API Endpoints\n');
    openApi['paths'].forEach((path, methods) {
      buffer.writeln('### `$path`');
      (methods as Map<String, dynamic>).forEach((method, details) {
        buffer.writeln('#### ${method.toUpperCase()}');
        buffer.writeln('- **Summary:** ${details['summary'] ?? 'No summary'}');
        buffer.writeln(
          '- **Description:** ${details['description'] ?? 'No description'}',
        );

        // Categorize parameters
        final Map<String, List<Map<String, dynamic>>> parameters = {
          'query': [],
          'header': [],
          'path': [],
          'cookie': [],
        };
        if (details.containsKey('parameters') &&
            details['parameters'] is List) {
          for (var param in details['parameters']) {
            if (param is Map<String, dynamic> &&
                parameters.containsKey(param['in'])) {
              parameters[param['in']]!.add(param);
            }
          }
        }

        parameters.forEach((key, paramList) {
          if (paramList.isNotEmpty) {
            buffer.writeln(
              '- **${key[0].toUpperCase()}${key.substring(1)} Parameters:**',
            );
            buffer.writeln(
              '| Name | Type | Description | Example |\n|------|------|-------------|---------|',
            );
            for (var param in paramList) {
              buffer.writeln(
                '| `${param['name']}` | ${param['schema']?['type'] ?? 'Unknown'} | ${param['description'] ?? 'No description'} | ${param['example'] ?? 'N/A'} |',
              );
            }
          }
        });

        if (details.containsKey('requestBody')) {
          buffer.writeln('- **Request Body:**');
          final content = details['requestBody']['content'] ?? {};
          content.forEach((type, schema) {
            buffer.writeln('  - **Type:** `$type`');
            buffer.writeln(
              '  - **Schema:** ${resolveSchema(schema['schema'])}',
            );
          });
        }

        if (details.containsKey('responses')) {
          buffer.writeln('- **Responses:**');
          buffer.writeln(
            '| Code | Description | Content Type | Example |\n|------|-------------|--------------|---------|',
          );
          details['responses'].forEach((code, response) {
            final contentTypes = response['content']?.keys.join(', ') ?? 'None';
            final example =
                response['content']?.values.first['example'] ?? 'N/A';
            buffer.writeln(
              '| **$code** | ${response['description'] ?? 'No description'} | $contentTypes | $example |',
            );
          });
        }
        buffer.writeln('');
      });
    });
  }

  if (openApi.containsKey('components') &&
      openApi['components'].containsKey('schemas')) {
    buffer.writeln('## Schemas\n');
    openApi['components']['schemas'].forEach((name, schema) {
      buffer.writeln('### `$name`');
      buffer.writeln('**Type:** ${schema['type'] ?? 'Unknown'}');
      if (schema.containsKey('properties')) {
        buffer.writeln('**Properties:**');
        buffer.writeln(
          '| Name | Type | Description | Example |\n|------|------|-------------|---------|',
        );
        schema['properties'].forEach((propName, propDetails) {
          buffer.writeln(
            '| `$propName` | ${propDetails['type'] ?? 'Unknown'} | ${propDetails['description'] ?? 'No description'} | ${propDetails['example'] ?? 'N/A'} |',
          );
        });
      }
      buffer.writeln('');
    });
  }
  return buffer.toString();
}

String resolveSchema(dynamic schema) {
  if (schema == null) return 'No schema';
  if (schema is Map<String, dynamic>) {
    if (schema.containsKey('\$ref')) {
      return schema['\$ref'].split('/').last;
    }
    return schema['type'] ?? 'Unknown';
  }
  return 'Invalid schema';
}
