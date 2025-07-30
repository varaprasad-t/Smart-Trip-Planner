import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_trip_planner/screens/chat_screen.dart';
import 'package:smart_trip_planner/screens/profile_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_trip_planner/utils/debug_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInternet();
  }

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasInternet = true;
        });
      }
    } on SocketException catch (_) {
      setState(() {
        _hasInternet = false;
      });
    }
  }

  TextEditingController _tripController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  @override
  Widget build(BuildContext context) {
    final safeName =
        (FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty ?? false)
        ? FirebaseAuth.instance.currentUser!.displayName!
        : 'Traveler';
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snapshot) {
              // final user = snapshot.data;
              return Text(
                '  Hey $safeName  👋',
                style: const TextStyle(
                  color: Color.fromARGB(255, 7, 117, 3),
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
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
                      ? NetworkImage(
                          FirebaseAuth.instance.currentUser!.photoURL!,
                        )
                      : null,
                  child: FirebaseAuth.instance.currentUser?.photoURL == null
                      ? Text(
                          FirebaseAuth
                                      .instance
                                      .currentUser
                                      ?.displayName
                                      ?.isNotEmpty ==
                                  true
                              ? FirebaseAuth
                                    .instance
                                    .currentUser!
                                    .displayName![0]
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
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            if (mounted && _checkInternet != null) {
              await _checkInternet();
              setState(() {});
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 60),
                  Text(
                    'What\'s your vision \n     for this trip?',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  if (_hasInternet) ...[
                    Stack(
                      children: [
                        Container(
                          width: 0.9 * MediaQuery.of(context).size.width,
                          height: 0.2 * MediaQuery.of(context).size.height,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color.fromARGB(255, 10, 135, 14),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _tripController,
                            maxLines: null,
                            style: TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintStyle: TextStyle(color: Colors.blueGrey),
                              hintText:
                                  "Describe your trip... e.g., 5 days in Kyoto next April, solo, mid-range budget",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Material(
                            color: Colors.white,
                            shape: CircleBorder(),
                            child: InkWell(
                              customBorder: CircleBorder(),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 1),
                                    content: Text('Voice input coming soon'),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.mic,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: 0.9 * MediaQuery.of(context).size.width,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: MaterialStatePropertyAll(
                            const Color.fromARGB(255, 19, 126, 22),
                          ),
                        ),
                        onPressed: () {
                          final uid =
                              FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                          final box = Hive.box('userTokens');
                          final current = box.get(
                            uid,
                            defaultValue: {'req': 0, 'res': 0},
                          );

                          box.put(uid, {
                            'req': current['req'] + 1,
                            'res': current['res'], // don’t touch here
                          });
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChatScreen(prompt: _tripController.text),
                            ),
                          );
                        },
                        child: Text(
                          'Create My Itinerary',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ] else ...[
                    Icon(Icons.wifi_off, size: 50, color: Colors.red),
                    SizedBox(height: 10),
                    Text(
                      'No internet connection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'You can still view saved itineraries',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 20),
                  ],
                  Center(
                    child: Text(
                      'Offline Saved Itineraries',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ValueListenableBuilder(
                    valueListenable: Hive.box('savedTrips').listenable(),
                    builder: (context, Box box, _) {
                      final currentUid =
                          FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                      final userTrips = box.values
                          .where((trip) => trip['uid'] == currentUid)
                          .toList();
                      if (userTrips.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                'No saved itineraries yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: userTrips.map<Widget>((trip) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              onTap: () {
                                final historyList =
                                    (trip['itineraryHistory'] is List)
                                    ? (trip['itineraryHistory'] as List).map((
                                        e,
                                      ) {
                                        final msg = Map<String, dynamic>.from(
                                          e,
                                        );
                                        if (msg['content'] is Map) {
                                          msg['content'] =
                                              Map<String, dynamic>.from(
                                                msg['content'],
                                              );
                                        }
                                        return msg;
                                      }).toList()
                                    : [
                                        {
                                          'role': 'ai',
                                          'content': trip['itinerary'] is Map
                                              ? Map<String, dynamic>.from(
                                                  trip['itinerary'],
                                                )
                                              : {},
                                        },
                                      ];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      prompt:
                                          trip['prompt'] ?? trip['title'] ?? '',
                                      itineraryHistoryOffline: historyList,
                                      isOffline: true,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Container(
                                  width:
                                      0.91 * MediaQuery.of(context).size.width,
                                  height: 70,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.offline_pin,
                                        color: Colors.orange[700],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              trip['title'] ?? 'Untitled Trip',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            // Extract the first AI itinerary from the stored history (null-safe, safer version)
                                            (() {
                                              final historyList =
                                                  (trip['itineraryHistory']
                                                      is List)
                                                  ? (trip['itineraryHistory']
                                                            as List)
                                                        .map((e) {
                                                          final msg =
                                                              Map<
                                                                String,
                                                                dynamic
                                                              >.from(e);
                                                          if (msg['content']
                                                              is Map) {
                                                            msg['content'] =
                                                                Map<
                                                                  String,
                                                                  dynamic
                                                                >.from(
                                                                  msg['content'],
                                                                );
                                                          }
                                                          return msg;
                                                        })
                                                        .toList()
                                                  : [
                                                      {
                                                        'role': 'ai',
                                                        'content':
                                                            trip['itinerary']
                                                                is Map
                                                            ? Map<
                                                                String,
                                                                dynamic
                                                              >.from(
                                                                trip['itinerary'],
                                                              )
                                                            : {},
                                                      },
                                                    ];
                                              final List<Map<String, dynamic>>
                                              aiMessages = historyList
                                                  .where(
                                                    (msg) =>
                                                        msg['role'] == 'ai' &&
                                                        msg['content'] is Map,
                                                  )
                                                  .map(
                                                    (msg) =>
                                                        Map<
                                                          String,
                                                          dynamic
                                                        >.from(
                                                          msg['content'] as Map,
                                                        ),
                                                  )
                                                  .toList();

                                              String preview = '';
                                              if (aiMessages.isNotEmpty) {
                                                final firstAi =
                                                    aiMessages.first;
                                                final days = firstAi['days'];
                                                if (days is List &&
                                                    days.isNotEmpty) {
                                                  preview = days
                                                      .map(
                                                        (day) => day['summary'],
                                                      )
                                                      .where(
                                                        (summary) =>
                                                            summary != null &&
                                                            summary
                                                                .toString()
                                                                .isNotEmpty,
                                                      )
                                                      .join(" • ");
                                                }
                                              }
                                              if (preview.isEmpty) {
                                                preview = trip['prompt'] ?? '';
                                              }
                                              return Text(
                                                preview,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black54,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            })(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
