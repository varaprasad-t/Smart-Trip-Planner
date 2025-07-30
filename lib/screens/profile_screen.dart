import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_trip_planner/screens/login_screen.dart';
import 'package:smart_trip_planner/services/auth_service.dart';
import 'package:hive/hive.dart';
import 'package:smart_trip_planner/utils/debug_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  final AuthService _auth = AuthService();
  Future<void> _editNameDialog() async {
    final nameController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? "",
    );
    bool isLoading = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Name"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Your Name"),
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setStateDialog(() {
                            isLoading = true;
                          });
                          final currentUser = FirebaseAuth.instance.currentUser;
                          await currentUser?.updateDisplayName(
                            nameController.text.trim(),
                          );
                          await currentUser?.reload();
                          setState(
                            () {},
                          ); // refresh profile screen with updated user info
                          Navigator.pop(context);
                        },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final tokensBox = Hive.box('userTokens');
    final tokens = tokensBox.get(uid, defaultValue: {'req': 0, 'res': 0});
    final reqCount = tokens['req'];
    final resCount = tokens['res'];
    final maxReq = 1000;
    final maxRes = 1000;

    final costBox = Hive.box('usageCost');
    final totalCost = costBox.get(uid, defaultValue: 0.0);
    final safeName =
        (FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty ?? false)
        ? FirebaseAuth.instance.currentUser!.displayName!
        : 'Traveler';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Text('Profile', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 350,
              width: 0.9 * MediaQuery.of(context).size.width,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10, // softness
                      spreadRadius: 2, // thickness
                      offset: Offset(0, 0), // equal shadow on all sides
                    ),
                  ],
                ),

                child: Column(
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: CircleAvatar(
                            backgroundColor: const Color.fromARGB(
                              255,
                              45,
                              105,
                              47,
                            ),
                            radius: 30,
                            child: Text(
                              debugSafeFirstChar(safeName).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    safeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 20,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: _editNameDialog,
                                  ),
                                ],
                              ),
                              Text(user?.email ?? 'No Email'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Container(
                      width:
                          0.8 *
                          MediaQuery.of(context).size.width, // your X width
                      height: 1, // thin line
                      color: Colors.grey, // line color
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Container(
                          height: 65,
                          width: 0.8 * MediaQuery.of(context).size.width,
                          child: Card(
                            color: Colors.grey[200],
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        10,
                                        5,
                                      ),
                                      child: Text(
                                        'Request Tokens',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        10,
                                        5,
                                      ),
                                      child: Text(
                                        '$reqCount/$maxReq',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(10),
                                    value: reqCount / maxReq,
                                    backgroundColor: Colors.white,
                                    color: const Color.fromARGB(
                                      255,
                                      45,
                                      105,
                                      47,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Container(
                          height: 65,
                          width: 0.8 * MediaQuery.of(context).size.width,
                          child: Card(
                            color: Colors.grey[200],
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        10,
                                        5,
                                      ),
                                      child: Text(
                                        'Response Tokens',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        10,
                                        5,
                                      ),
                                      child: Text(
                                        '$resCount/$maxRes',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(10),
                                    value: resCount / maxRes,
                                    backgroundColor: Colors.white,
                                    color: const Color.fromARGB(
                                      255,
                                      179,
                                      49,
                                      49,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Container(
                          height: 55,
                          width: 0.8 * MediaQuery.of(context).size.width,
                          child: Card(
                            color: Colors.grey[200],

                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        10,
                                        5,
                                      ),
                                      child: Text(
                                        'Total Cost',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        10,
                                        5,
                                      ),
                                      child: Text(
                                        '\$${totalCost.toStringAsFixed(4)} USD',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(Colors.white),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _auth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Signed out'),
                    duration: const Duration(milliseconds: 700),
                  ),
                );
              }
            },
            child: SizedBox(
              width: 80,
              child: Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Color.fromARGB(255, 186, 59, 59),
                  ),
                  Text(
                    "  Log Out",
                    style: TextStyle(
                      color: const Color.fromARGB(255, 186, 59, 59),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Devloper:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Image.network(
                  'https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png',
                  height: 36,
                  width: 36,
                ),
                onPressed: () async {
                  final Uri url = Uri.parse('https://github.com/varaprasad-t');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                tooltip: 'View GitHub Profile',
              ),
              IconButton(
                icon: Image.asset(
                  'assets/images/linkedin.png',
                  height: 36,
                  width: 36,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: 'LinkedIn (coming soon)',
              ),

              IconButton(
                icon: Image.asset(
                  'assets/images/instagram.png',
                  height: 36,
                  width: 36,
                ),
                onPressed: () async {
                  final Uri url = Uri.parse(
                    'https://www.instagram.com/_iamvaraprasad_/',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                tooltip: 'Instagram',
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Smart Trip Planner v1.0.0\n© 2025 ",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
