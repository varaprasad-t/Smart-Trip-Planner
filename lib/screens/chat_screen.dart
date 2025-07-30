import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:smart_trip_planner/screens/profile_screen.dart';
import 'package:smart_trip_planner/utils/debug_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_trip_planner/services/gemini_service.dart'
    show GeminiService;

class ChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? itineraryHistoryOffline;
  final String prompt;

  final bool isOffline;
  ChatScreen({
    super.key,
    required this.prompt,
    this.itineraryHistoryOffline,
    this.isOffline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  final safeName =
      (FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty ?? false)
      ? FirebaseAuth.instance.currentUser!.displayName!
      : 'Traveler';
  final TextEditingController followUpController = TextEditingController();
  // Each: { 'role': 'user'|'ai', 'content': dynamic }
  List<Map<String, dynamic>> itineraryHistory = [];
  bool _showFollowUpInput = false;
  bool _isFirstResponseCounted = false;
  Map<String, dynamic>? errorData;
  bool _isProcessingFollowUp = false;

  Future<void> openInMaps(String location) async {
    if (location.isEmpty) {
      print("❌ No location provided");
      return;
    }

    final cleaned = location.trim();
    Uri appUri;
    Uri webUri;

    // Prefer geo: scheme for Android maps app
    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      final isNumeric =
          double.tryParse(parts[0].trim()) != null &&
          double.tryParse(parts[1].trim()) != null;

      if (isNumeric) {
        appUri = Uri.parse("geo:${parts[0].trim()},${parts[1].trim()}");
        print("📍 Opening coordinates: ${parts[0].trim()},${parts[1].trim()}");
      } else {
        final query = Uri.encodeComponent(cleaned);
        appUri = Uri.parse("geo:0,0?q=$query");
        print("📍 Opening place search: $cleaned");
      }
    } else {
      final query = Uri.encodeComponent(cleaned);
      appUri = Uri.parse("geo:0,0?q=$query");
      print("📍 Opening place search: $cleaned");
    }

    // Fallback URL for browser
    webUri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cleaned)}",
    );

    // Try opening in external application first
    try {
      print("📍 Attempting to open location: $cleaned");

      bool launched = false;

      // Try opening in Maps app
      if (await canLaunchUrl(appUri)) {
        launched = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          print("✅ Opened in Maps app");
          return;
        }
      }

      // Fallback: try opening in browser
      if (await canLaunchUrl(webUri)) {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          print("✅ Opened in browser");
          return;
        }
      }

      if (!launched) {
        print("❌ Could not open the map in either Maps app or browser");
      }
    } catch (e) {
      print("❌ Error launching map: $e");
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Widget _buildFollowUpButtons({bool isGenerating = false}) {
    // normal green

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.message, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: isGenerating
                    ? const Color.fromARGB(255, 165, 183, 193)
                    : const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  _showFollowUpInput = true;
                });
              },
              label: const Text(
                'Follow up to refine',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          TextButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isGenerating
                  ? const Color.fromARGB(255, 165, 183, 193)
                  : Colors.transparent,
            ),
            icon: const Icon(Icons.bookmark_border, color: Colors.black87),
            onPressed: () async {
              final box = Hive.box('savedTrips');
              final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
              final saveKey =
                  '$uid|${widget.prompt.hashCode}'; // Save under unique key per itinerary

              await box.put(saveKey, {
                'uid': uid,
                'title': _getFirstAiTitle(),
                'prompt': widget.prompt,
                'itineraryHistory': itineraryHistory.map((msg) {
                  return {
                    'role': msg['role'],
                    'content': msg['content'] is Map<String, dynamic>
                        ? Map<String, dynamic>.from(msg['content'])
                        : msg['content'],
                  };
                }).toList(),
                'updatedAt': DateTime.now()
                    .toIso8601String(), // Show last saved update
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Itinerary saved (updated)')),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Itinerary saved offline')),
              );
            },
            label: const Text(
              'Save Offline',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  bool isLoading = true;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  String typedText = "";
  int _typingIndex = 0;
  int? _openLinkIndex;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.isOffline && widget.itineraryHistoryOffline != null) {
      print("📦 Offline itineraryHistory: ${widget.itineraryHistoryOffline}");
      setState(() {
        itineraryHistory.addAll(widget.itineraryHistoryOffline!);
        isLoading = false;
      });
      _controller.forward();
    } else {
      _startTyping();
    }
  }

  Future<void> _sendFollowUp(
    String followUpText, {
    bool isRetry = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final tokenBox = Hive.box('userTokens');
    final current = tokenBox.get(uid, defaultValue: {'req': 0, 'res': 0});
    tokenBox.put(uid, {'req': current['req'] + 1, 'res': current['res']});

    setState(() {
      if (!isRetry) {
        itineraryHistory.add({'role': 'user', 'content': followUpText});
      }
      itineraryHistory.add({'role': 'ai', 'content': null});
    });

    final gemini = GeminiService();
    // Find latest AI message for context
    final latestAi = itineraryHistory.lastWhere(
      (msg) => msg['role'] == 'ai' && msg['content'] is Map,
      orElse: () => {},
    );
    final latestItinerary = (latestAi.isNotEmpty && latestAi['content'] is Map)
        ? latestAi['content']
        : {};

    final followUpPrompt =
        """
Given this existing itinerary in JSON:
${latestItinerary.toString()}

Please update it based on the following instruction: $followUpText
Return only valid JSON, no extra commentary.
""";

    try {
      final result = await gemini.generateItinerary(followUpPrompt);
      if (result.isNotEmpty && result['title'] != null) {
        setState(() {
          final lastIndex = itineraryHistory.lastIndexWhere(
            (msg) => msg['role'] == 'ai' && msg['content'] == null,
          );
          if (lastIndex != -1) {
            itineraryHistory[lastIndex] = {'role': 'ai', 'content': result};
          }
        });
        _scrollToBottom();
      } else {
        setState(() {
          final lastIndex = itineraryHistory.lastIndexWhere(
            (msg) => msg['role'] == 'ai' && msg['content'] == null,
          );
          if (lastIndex != -1) {
            itineraryHistory[lastIndex] = {
              'role': 'ai',
              'content': {
                'error': "Invalid JSON from AI",
                'raw': result,
                'followUpText': followUpText,
              },
            };
          }
        });
      }
    } catch (e) {
      setState(() {
        final lastIndex = itineraryHistory.lastIndexWhere(
          (msg) => msg['role'] == 'ai' && msg['content'] == null,
        );
        if (lastIndex != -1) {
          itineraryHistory[lastIndex] = {
            'role': 'ai',
            'content': {
              'error': "Error from Gemini: $e",
              'followUpText': followUpText,
            },
          };
        }
      });
    }
  }

  void _startTyping() async {
    final gemini = GeminiService();
    print("📡 Sending request to Gemini...");
    print("📝 Prompt sent to API: ${widget.prompt}");

    itineraryHistory.add({'role': 'user', 'content': widget.prompt});
    try {
      final result = await gemini.generateItinerary(widget.prompt);
      print("🔍 Model: ${gemini}");
      print("🔍 Raw .text: ${result}");
      if (!_isFirstResponseCounted) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
        final box = Hive.box('userTokens');
        final current = box.get(uid, defaultValue: {'req': 0, 'res': 0});
        box.put(uid, {'req': current['req'], 'res': current['res'] + 1});
        _isFirstResponseCounted = true;
      }
      print("✅ Gemini raw response: $result");

      // Calculate and save estimated cost
      final uidCost = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final costBox = Hive.box('usageCost');
      final promptTokens = estimateTokens(widget.prompt);
      final responseTokens = estimateTokens(result.toString());
      const promptRate = 0.05;
      const completionRate = 0.08;
      final promptCost = (promptTokens / 1000) * promptRate;
      final completionCost = (responseTokens / 1000) * completionRate;
      final totalCost = promptCost + completionCost;
      final currentCost = costBox.get(uidCost, defaultValue: 0.0);
      costBox.put(uidCost, currentCost + totalCost);

      if (result.isNotEmpty && result['title'] != null) {
        itineraryHistory.add({'role': 'ai', 'content': result});
      } else {
        print("⚠️ Gemini returned empty or invalid JSON.");
        setState(() {
          errorData = {"error": "Invalid JSON from AI", "raw": result};
          isLoading = false;
        });
        return;
      }
    } catch (e) {
      print("❌ Error from Gemini: $e");
      setState(() {
        errorData = {"error": "Error from Gemini: $e"};
        isLoading = false;
      });
      return;
    }

    final lastAi = itineraryHistory.lastWhere(
      (msg) =>
          msg['role'] == 'ai' &&
          msg['content'] is Map &&
          msg['content']['title'] != null,
      orElse: () => {},
    );
    if (lastAi.isNotEmpty && lastAi['content'] is Map) {
      final fullText = lastAi['content']['title'] ?? '';
      typedText = "";
      _typingIndex = 0;

      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_typingIndex < fullText.length) {
          setState(() {
            typedText += fullText[_typingIndex];
            _typingIndex++;
          });
        } else {
          timer.cancel();
          _controller.forward();
          setState(() {
            isLoading = false;
          });
        }
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _hasValidAIResponse() {
    return itineraryHistory.any(
      (msg) =>
          msg['role'] == 'ai' &&
          msg['content'] is Map<String, dynamic> &&
          msg['content']['title'] != null &&
          msg['content']['error'] == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: const Color.fromARGB(255, 45, 105, 47),
                backgroundImage:
                    FirebaseAuth.instance.currentUser?.photoURL != null
                    ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                    : null,
                child: FirebaseAuth.instance.currentUser?.photoURL == null
                    ? Text(
                        FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName
                                    ?.isNotEmpty ==
                                true
                            ? FirebaseAuth.instance.currentUser!.displayName![0]
                                  .toUpperCase()
                            : 'T', // fallback letter
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
        title: Text(itineraryHistory.isNotEmpty ? typedText : 'Trip'),

        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: isLoading
          ? Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text(
                          'Generating your itinerary...',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildFollowUpButtons(
                  isGenerating: true, // <- pass a flag to render green style
                ),
              ],
            )
          : errorData != null
          ? SizedBox.expand(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getErrorIcon(errorData!["error"] ?? ""),
                      size: 60,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load itinerary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getErrorMessage(errorData!["error"] ?? ""),
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Try Again"),
                      onPressed: () {
                        setState(() {
                          errorData = null;
                        });
                        // Check if last message was a follow-up AI loading bubble
                        final lastWasFollowUp =
                            itineraryHistory.isNotEmpty &&
                            itineraryHistory.last['role'] == 'ai' &&
                            itineraryHistory.last['content'] == null;
                        if (lastWasFollowUp) {
                          // ✅ Remove last AI error/loading message
                          final lastAiIndex = itineraryHistory.lastIndexWhere(
                            (msg) => msg['role'] == 'ai',
                          );
                          if (lastAiIndex != -1) {
                            itineraryHistory.removeAt(lastAiIndex);
                          }

                          // ✅ Retry follow-up using the last user message
                          final lastUserMsgIndex = itineraryHistory
                              .lastIndexWhere(
                                (msg) => msg['role'] == 'user',
                                itineraryHistory.length - 1,
                              );
                          if (lastUserMsgIndex != -1 &&
                              itineraryHistory[lastUserMsgIndex]['content'] !=
                                  null) {
                            final followUpText =
                                itineraryHistory[lastUserMsgIndex]['content'];
                            _sendFollowUp(followUpText, isRetry: true);
                          }
                        } else {
                          // First-time or original request: retry in place without duplicating
                          setState(() {
                            errorData = null;
                            isLoading = true;
                          });

                          // Remove the last AI error bubble before retrying
                          final lastErrorIndex = itineraryHistory
                              .lastIndexWhere((msg) => msg['role'] == 'ai');
                          if (lastErrorIndex != -1) {
                            itineraryHistory.removeAt(lastErrorIndex);
                          }

                          // Call Gemini again without adding a new user bubble
                          final originalPrompt = widget.prompt;
                          final gemini = GeminiService();

                          gemini
                              .generateItinerary(originalPrompt)
                              .then((result) {
                                if (result.isNotEmpty &&
                                    result['title'] != null) {
                                  itineraryHistory.add({
                                    'role': 'ai',
                                    'content': result,
                                  });
                                } else {
                                  setState(() {
                                    errorData = {
                                      "error": "Invalid JSON from AI",
                                      "raw": result,
                                    };
                                    isLoading = false;
                                  });
                                  return;
                                }
                                setState(() {
                                  isLoading = false;
                                });
                              })
                              .catchError((e) {
                                setState(() {
                                  errorData = {
                                    "error": "Error from Gemini: $e",
                                  };
                                  isLoading = false;
                                });
                              });
                        }
                      },
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(child: _buildItineraryContent()),

                if (!widget.isOffline)
                  Column(
                    children: [
                      if (_showFollowUpInput)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            child: ElevatedButton.icon(
                              onPressed: _saveCurrentItinerary,
                              icon: const Icon(
                                Icons.bookmark,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF66BB6A,
                                ), // Soft green
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                minimumSize: Size(0, 40), // Fits content
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 2,
                                shadowColor: Colors.greenAccent.withOpacity(
                                  0.18,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 10),

                      if (_showFollowUpInput)
                        _buildFollowUpInputBar()
                      else if (_isProcessingFollowUp)
                        const SizedBox.shrink()
                      else
                        _buildFollowUpButtons(),
                    ],
                  ),
              ],
            ),
    );
  }

  String _getErrorMessage(String error) {
    error = error.toLowerCase();
    if (error.contains("503")) {
      return "The AI model is overloaded. Please try again in a few moments.";
    } else if (error.contains("invalid json")) {
      return "The AI returned an unexpected response.";
    } else if (error.contains("quota")) {
      return "API quota exceeded. Wait a while before retrying.";
    } else if (error.contains("network") || error.contains("socket")) {
      return "Check your internet connection and try again.";
    }
    // Fallback
    return errorData?["raw"]?.toString() ?? error;
  }

  IconData _getErrorIcon(String error) {
    if (error.contains("503")) {
      return Icons.cloud_off; // AI model overloaded
    } else if (error.toLowerCase().contains("invalid json")) {
      return Icons.code_off; // Invalid JSON
    } else if (error.toLowerCase().contains("quota")) {
      return Icons.lock_clock; // Quota exceeded
    } else if (error.toLowerCase().contains("network") ||
        error.toLowerCase().contains("socket")) {
      return Icons.wifi_off; // Network error
    }
    return Icons.error_outline; // Generic error
  }

  Future<void> _saveCurrentItinerary() async {
    final box = Hive.box('savedTrips');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final saveKey = '$uid|${widget.prompt.hashCode}';

    await box.put(saveKey, {
      'uid': uid,
      'title': _getFirstAiTitle(),
      'prompt': widget.prompt,
      'itineraryHistory': itineraryHistory.map((msg) {
        return {
          'role': msg['role'],
          'content': msg['content'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(msg['content'])
              : msg['content'],
        };
      }).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itinerary saved (updated)')),
      );
    }
  }

  Widget _buildFollowUpInputBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: followUpController,
              decoration: InputDecoration(
                // remove default Flutter border
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic, color: Color(0xFF2E7D32)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 1),
                        content: Text('Voice input coming soon'),
                      ),
                    );
                  },
                ),
                hintText: "Refine itinerary...",
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF2E7D32)),
            onPressed: () {
              final followUpText = followUpController.text.trim();
              if (followUpText.isNotEmpty) {
                setState(() {
                  // Keep input bar visible
                  // DO NOT set _showFollowUpInput = false;
                  _isProcessingFollowUp = true;
                });
                _sendFollowUp(followUpText).then((_) {
                  setState(() {
                    _isProcessingFollowUp = false;
                    // keep _showFollowUpInput = true;
                  });
                });
                followUpController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryContent() {
    return Column(
      children: [
        widget.isOffline
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    "Itinerary Created ✈️",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : Text(''),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: itineraryHistory.length,
            itemBuilder: (context, index) {
              final message = itineraryHistory[index];
              if (message['role'] == 'user') {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(message['content']),
                      ),
                    ],
                  ),
                );
              } else if (message['role'] == 'ai' &&
                  message['content'] == null) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text("Generating response..."),
                      ],
                    ),
                  ),
                );
              } else {
                final data = (message['content'] is Map)
                    ? Map<String, dynamic>.from(message['content'] as Map)
                    : <String, dynamic>{};
                if (data['error'] != null) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['error'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  final followUpText =
                                      message['content']['followUpText'];
                                  if (followUpText != null) {
                                    _sendFollowUp(followUpText);
                                  }
                                },
                              ),
                            ],
                          ),
                          if (data['raw'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                data['raw'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }
                int aiCount = 0;
                for (int i = 0; i <= index; i++) {
                  if (itineraryHistory[i]['role'] == 'ai') aiCount++;
                }
                return SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Itinera AI',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              // Convert AI itinerary map to readable text
                              String textToCopy = "";
                              if (data['title'] != null) {
                                textToCopy += "${data['title']}\n\n";
                              }
                              if (data['days'] != null &&
                                  data['days'] is List) {
                                for (var i = 0; i < data['days'].length; i++) {
                                  final day = data['days'][i];
                                  textToCopy +=
                                      "Day ${i + 1} • ${day['date'] ?? ''}\n";
                                  if (day['summary'] != null) {
                                    textToCopy += "${day['summary']}\n";
                                  }
                                  if (day['items'] != null &&
                                      day['items'] is List) {
                                    for (var item in day['items']) {
                                      textToCopy +=
                                          "- ${item['time']} — ${item['activity']} (${item['location'] ?? ''})\n";
                                    }
                                  }
                                  textToCopy += "\n";
                                }
                              }

                              Clipboard.setData(
                                ClipboardData(text: textToCopy.trim()),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Itinerary copied to clipboard',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      _buildAIBubble(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aiCount == 1
                                  ? "Initial Plan"
                                  : "Follow-up ${aiCount - 1}",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._buildDayBreakdown(data),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  String _getFirstAiTitle() {
    for (var msg in itineraryHistory) {
      if (msg['role'] == 'ai' &&
          msg['content'] is Map &&
          msg['content']['title'] != null) {
        return msg['content']['title'].toString();
      }
    }
    return 'Trip';
  }

  List<Widget> _buildDayBreakdown(Map<String, dynamic> data) {
    final List days = data['days'] ?? [];

    return List.generate(days.length, (index) {
      final day = days[index];
      final items = day['items'] ?? [];

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Day ${index + 1} • ${day['date'] ?? ''}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (day['summary'] != null)
              Text(day['summary'], style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            ...items.map<Widget>((item) {
              final loc = item['location'] ?? '';
              final mapUrl =
                  "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc)}";

              return ListTile(
                dense: true,
                leading: const Icon(Icons.place, size: 18),
                title: Text("${item['time']} - ${item['activity']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.map, color: Colors.blue),
                  onPressed: () {
                    openInMaps(loc);
                  },
                ),
              );
            }).toList(),
          ],
        ),
      );
    });
  }

  Widget _buildAIBubble({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

int estimateTokens(String text) {
  return (text.length / 4).ceil(); // ~4 chars per token
}
