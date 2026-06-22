import 'dart:convert';

import 'package:http/http.dart' as http;

import 'crossword_generation_exception.dart';
import 'dto/crossword_generation_request.dart';
import 'dto/crossword_generation_response.dart';

/// Calls `POST /crossword-puzzles/generate` and returns the parsed response.
class CrosswordGenerationRemoteDataSource {
  static const String _defaultBaseUrl = 'https://api.ikors.se';

  final http.Client _client;
  final String _baseUrl;

  CrosswordGenerationRemoteDataSource({
    http.Client? client,
    String baseUrl = _defaultBaseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  Future<CrosswordGenerationResponse> generate(
    CrosswordGenerationRequest request,
  ) async {
    final uri = Uri.parse('$_baseUrl/crossword-puzzles/generate');
    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
    } catch (e) {
      throw CrosswordGenerationException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw CrosswordGenerationException(
        'Server returned ${response.statusCode}',
      );
    }

    final parsed = CrosswordGenerationResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (!parsed.success) {
      throw CrosswordGenerationException(
        parsed.failureReason ?? 'Generation failed',
      );
    }
    return parsed;
  }
}
