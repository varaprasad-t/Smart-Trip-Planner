import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

class GeminiService {
  Future<Map<String, dynamic>> generateItinerary(String prompt) async {
    if (geminiApiKey.isEmpty) {
      throw Exception("❌ Gemini API key is missing. Check your .env file.");
    }

    try {
      return await _callGeminiModel('gemini-2.5-pro', prompt);
    } catch (e) {
      final errMsg = e.toString().toLowerCase();
      if (errMsg.contains('503') ||
          errMsg.contains('overloaded') ||
          errMsg.contains('invalid json') ||
          errMsg.contains('unexpected end of input')) {
        print("⚠️ 2.5 Pro failed, falling back to 1.5 Flash...");
        try {
          return await _callGeminiModel('gemini-1.5-flash', prompt);
        } catch (e2) {
          throw Exception("❌ Both 2.5 Pro and 1.5 Flash failed: $e2");
        }
      } else {
        throw e;
      }
    }
  }

  Future<Map<String, dynamic>> _callGeminiModel(
    String modelName,
    String prompt,
  ) async {
    final model = GenerativeModel(
      model: modelName,
      apiKey: geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.25,
        maxOutputTokens: 2500,
      ),
    );

    final content = [
      Content.text(
        "You are a travel assistant. Always respond ONLY in JSON with this schema: "
        "{title: string, startDate: string, endDate: string, days: [{date: string, summary: string, items: [{time: string, activity: string, location: string}]}]}. "
        "Prompt: $prompt",
      ),
    ];

    final response = await model.generateContent(content);

    if (response.text == null || response.text!.isEmpty) {
      throw Exception("Gemini API returned empty response");
    }

    final cleaned = response.text!
        .trim()
        .replaceAll(RegExp(r'^[^{]*'), '')
        .replaceAll(RegExp(r'[^}]*$'), '');

    try {
      return jsonDecode(cleaned);
    } catch (_) {
      throw Exception("invalid json");
    }
  }
}
