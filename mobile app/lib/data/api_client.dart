import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;

import "../services/auth_storage.dart";
import "../utils/constants/api_constants.dart";

class ApiClient {
  ApiClient({http.Client? httpClient, AuthStorage? storage})
    : _httpClient = httpClient ?? http.Client(),
      _storage = storage ?? AuthStorage();

  final http.Client _httpClient;
  final AuthStorage _storage;

  static const Duration _timeout = Duration(seconds: 20);

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: "GET",
      endpoint: endpoint,
      headers: headers,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: "POST",
      endpoint: endpoint,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: "PUT",
      endpoint: endpoint,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: "PATCH",
      endpoint: endpoint,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: "DELETE",
      endpoint: endpoint,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> postMultipart(
    String endpoint, {
    required List<http.MultipartFile> files,
    Map<String, String>? fields,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final Uri uri = _buildUri(endpoint, queryParameters: queryParameters);

    final Map<String, String> effectiveHeaders = <String, String>{
      "Accept": "application/json",
      ...?headers,
    };

    final String? accessToken = await _readAccessToken();
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      effectiveHeaders.putIfAbsent(
        "Authorization",
        () => "Bearer ${accessToken.trim()}",
      );
    }

    final http.MultipartRequest request = http.MultipartRequest("POST", uri)
      ..headers.addAll(effectiveHeaders);
    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }
    if (files.isNotEmpty) {
      request.files.addAll(files);
    }

    _debugLogRequest(
      method: "POST_MULTIPART",
      uri: uri,
      headers: effectiveHeaders,
      body: <String, Object?>{
        "fields": fields,
        "files": <Map<String, Object?>>[
          for (final http.MultipartFile f in files)
            <String, Object?>{
              "field": f.field,
              "filename": f.filename,
              "length": f.length,
            },
        ],
      },
    );

    try {
      final http.StreamedResponse streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final http.Response response = await http.Response.fromStream(streamed);
      _debugLogResponse(response);
      return _decodeOrThrow(response);
    } on TimeoutException {
      _debugLogError(
        "TimeoutException",
        "Request timed out",
        StackTrace.current,
      );
      throw ApiTimeoutException("Connection timeout");
    } on SocketException catch (e, st) {
      await _debugLogNetworkContext(uri);
      _debugLogError("SocketException", e.toString(), st);
      throw ApiNetworkException(e.toString());
    } on http.ClientException catch (e, st) {
      _debugLogError("ClientException", e.toString(), st);
      throw ApiClientException(e.toString());
    } on FormatException catch (e, st) {
      _debugLogError("FormatException", e.toString(), st);
      throw ApiParsingException("Invalid JSON response");
    } catch (e, st) {
      _debugLogError("UnknownException", e.toString(), st);
      throw ApiClientException(e.toString());
    }
  }

  Future<dynamic> _send({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    final Uri uri = _buildUri(endpoint, queryParameters: queryParameters);

    final Map<String, String> effectiveHeaders = <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json",
      ...?headers,
    };

    final String? accessToken = await _readAccessToken();
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      effectiveHeaders.putIfAbsent(
        "Authorization",
        () => "Bearer ${accessToken.trim()}",
      );
    }

    _debugLogRequest(
      method: method,
      uri: uri,
      headers: effectiveHeaders,
      body: body,
    );

    try {
      final http.Response response = await _dispatch(
        method: method,
        uri: uri,
        headers: effectiveHeaders,
        body: body,
      ).timeout(_timeout);

      _debugLogResponse(response);
      return _decodeOrThrow(response);
    } on TimeoutException {
      _debugLogError(
        "TimeoutException",
        "Request timed out",
        StackTrace.current,
      );
      throw ApiTimeoutException("Connection timeout");
    } on SocketException catch (e, st) {
      await _debugLogNetworkContext(uri);
      _debugLogError("SocketException", e.toString(), st);
      throw ApiNetworkException(e.toString());
    } on http.ClientException catch (e, st) {
      _debugLogError("ClientException", e.toString(), st);
      throw ApiClientException(e.toString());
    } on FormatException catch (e, st) {
      _debugLogError("FormatException", e.toString(), st);
      throw ApiParsingException("Invalid JSON response");
    } catch (e, st) {
      _debugLogError("UnknownException", e.toString(), st);
      throw ApiClientException(e.toString());
    }
  }

  Uri _buildUri(String endpoint, {Map<String, dynamic>? queryParameters}) {
    final Uri base = Uri.parse(ApiConstants.baseUrl);
    final String basePath = base.path.endsWith("/") && base.path.length > 1
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final String endpointPath = endpoint.startsWith("/")
        ? endpoint
        : "/$endpoint";
    final Uri url = base.replace(path: "$basePath$endpointPath");

    if (queryParameters == null || queryParameters.isEmpty) return url;

    return url.replace(
      queryParameters: queryParameters.map(
        (String k, dynamic v) => MapEntry<String, String>(k, v.toString()),
      ),
    );
  }

  Future<http.Response> _dispatch({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Object? body,
  }) {
    final String? encodedBody = _encodeBody(body);

    switch (method) {
      case "GET":
        return _httpClient.get(uri, headers: headers);
      case "POST":
        return _httpClient.post(uri, headers: headers, body: encodedBody);
      case "PUT":
        return _httpClient.put(uri, headers: headers, body: encodedBody);
      case "PATCH":
        return _httpClient.patch(uri, headers: headers, body: encodedBody);
      case "DELETE":
        return _httpClient.delete(uri, headers: headers, body: encodedBody);
      default:
        throw ApiClientException("Unsupported method: $method");
    }
  }

  dynamic _decodeOrThrow(http.Response response) {
    final int status = response.statusCode;

    final String bodyText = utf8.decode(response.bodyBytes);
    final dynamic decoded = bodyText.isEmpty ? null : jsonDecode(bodyText);

    if (status >= 200 && status < 300) return decoded;

    final String message = _extractMessage(decoded) ?? "Server error ($status)";
    throw ApiHttpException(status, message, decoded);
  }

  String? _extractMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final dynamic message =
          decoded["message"] ??
          decoded["error"] ??
          decoded["errors"] ??
          decoded["detail"];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }

  Future<String?> _readAccessToken() async {
    try {
      return await _storage.readAccessToken();
    } catch (_) {
      return null;
    }
  }

  String? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  void _debugLogRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Object? body,
  }) {
    assert(() {
      print("HTTP $method: $uri");
      final Map<String, String> sanitizedHeaders = Map<String, String>.from(
        headers,
      );
      if (sanitizedHeaders.containsKey("Authorization")) {
        final String raw = sanitizedHeaders["Authorization"] ?? "";
        if (raw.trim().length > 16) {
          sanitizedHeaders["Authorization"] =
              "${raw.substring(0, 16)}${'*' * (raw.length - 16)}";
        } else {
          sanitizedHeaders["Authorization"] = "***";
        }
      }
      if (sanitizedHeaders.containsKey("cookie")) {
        sanitizedHeaders["cookie"] = "***";
      }
      print("Headers: $sanitizedHeaders");
      final Object? sanitized = _sanitizeBody(body);
      if (sanitized != null) print("Body: ${jsonEncode(sanitized)}");
      return true;
    }());
  }

  void _debugLogResponse(http.Response response) {
    assert(() {
      print("Status: ${response.statusCode}");
      print("Response headers: ${response.headers}");
      final String rawBody = utf8.decode(response.bodyBytes);
      Object? decodedBody;
      try {
        decodedBody = rawBody.isEmpty ? null : jsonDecode(rawBody);
      } catch (_) {
        decodedBody = rawBody;
      }
      final Object? sanitized = _sanitizeBody(decodedBody);
      if (sanitized is String) {
        if (sanitized.trim().isNotEmpty) {
          print("Response body: $sanitized");
        }
      } else if (sanitized != null) {
        try {
          print("Response body: ${jsonEncode(sanitized)}");
        } catch (_) {
          print("Response body: (unprintable)");
        }
      }
      return true;
    }());
  }

  void _debugLogError(String type, String error, StackTrace st) {
    assert(() {
      print("$type: $error");
      print(st);
      return true;
    }());
  }

  static const Set<String> _sensitiveBodyKeys = <String>{
    "password",
    "deviceToken",
    "device_token",
    "token",
    "secret",
    "accessToken",
    "access_token",
    "refreshToken",
    "refresh_token",
    "currentPassword",
    "newPassword",
    "passwordHash",
    "hashedPassword",
  };

  Object? _sanitizeBody(Object? body) {
    if (body == null) return null;
    Object? walk(Object? input) {
      if (input is Map<String, dynamic>) {
        final Map<String, dynamic> out = <String, dynamic>{};
        input.forEach((String k, dynamic v) {
          if (_sensitiveBodyKeys.contains(k)) {
            out[k] = "***";
            return;
          }
          out[k] = walk(v);
        });
        return out;
      }
      if (input is Map) {
        final Map<String, dynamic> out = <String, dynamic>{};
        input.forEach((dynamic k, dynamic v) {
          final String key = k.toString();
          if (_sensitiveBodyKeys.contains(key)) {
            out[key] = "***";
            return;
          }
          out[key] = walk(v);
        });
        return out;
      }
      if (input is List) {
        return input.map<Object?>(walk).toList();
      }
      return input;
    }

    return walk(body);
  }

  Future<void> _debugLogNetworkContext(Uri uri) async {
    assert(() {
      print("Network target: ${uri.host}:${uri.port}");
      return true;
    }());

    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list();
      assert(() {
        for (final NetworkInterface i in interfaces) {
          final String addresses = i.addresses.map((a) => a.address).join(", ");
          print("Interface ${i.name}: $addresses");
        }
        return true;
      }());
    } catch (_) {}
  }
}

class ApiClientException implements Exception {
  ApiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiHttpException extends ApiClientException {
  ApiHttpException(this.statusCode, String message, this.payload)
    : super(message);

  final int statusCode;
  final dynamic payload;
}

class ApiNetworkException extends ApiClientException {
  ApiNetworkException(super.message);
}

class ApiTimeoutException extends ApiClientException {
  ApiTimeoutException(super.message);
}

class ApiParsingException extends ApiClientException {
  ApiParsingException(super.message);
}
