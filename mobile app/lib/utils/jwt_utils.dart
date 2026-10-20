import "dart:convert";

class JwtUtils {
  static bool isExpired(String token, {DateTime? now}) {
    final DateTime nowTime = now ?? DateTime.now().toUtc();

    try {
      final List<String> parts = token.split(".");
      if (parts.length != 3) return true;

      final String payload = _decodeBase64Url(parts[1]);
      final dynamic decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return true;

      final dynamic exp = decoded["exp"];
      if (exp is! num) return true;

      final DateTime expiry =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return !expiry.isAfter(nowTime);
    } catch (_) {
      return true;
    }
  }

  static String _decodeBase64Url(String input) {
    final String normalized = base64Url.normalize(input);
    return utf8.decode(base64Url.decode(normalized));
  }
}

