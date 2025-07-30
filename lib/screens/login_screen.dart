import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_trip_planner/screens/home_screen.dart';
import 'package:smart_trip_planner/screens/signup_screen.dart';
import 'package:smart_trip_planner/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  bool _hidepass = true;
  TextEditingController _email = TextEditingController();
  TextEditingController _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Icon(
                      Icons.flight,
                      size: 40,
                      color: const Color.fromARGB(255, 234, 196, 8),
                    ),
                  ),
                  SizedBox(width: 15),
                  Center(
                    child: Text(
                      'Itinera AI',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 17, 135, 2),
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Spacer(),
              Center(
                child: Text(
                  'Hi,Welcome Back',
                  style: TextStyle(fontSize: 35, fontWeight: FontWeight.w700),
                ),
              ),
              Center(
                child: Text(
                  'Login to your account',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Spacer(),
              Center(
                child: SizedBox(
                  width: 250,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      try {
                        User? user = await _auth.signInWithGoogle(
                          webClientId:
                              '269088732896-08v3gno7q0p8nel1fltda70gbgefl2eo.apps.googleusercontent.com',
                        );
                        if (user != null) {
                          _showSnackbar('Google Sign-In successful');
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomeScreen(),
                            ),
                          );
                        } else {
                          _showSnackbar('Google Sign-In cancelled');
                        }
                      } catch (e) {
                        _showSnackbar('Google Sign-In failed: $e');
                      }
                    },
                    icon: Image.asset(
                      'assets/images/google-icon.png',
                      height: 20,
                    ),
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: Text(
                  '-------------------or Sign in with Gmail------------------',
                  style: TextStyle(
                    fontWeight: FontWeight.w200,
                    color: const Color.fromARGB(255, 11, 10, 10),
                  ),
                ),
              ),
              Spacer(),
              Text('Email address'),
              SizedBox(
                height: 40,
                width: 300,
                child: TextField(
                  controller: _email,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 1),
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Spacer(),
              Text('Password'),
              SizedBox(
                height: 40,
                width: 300,
                child: TextField(
                  obscureText: _hidepass,
                  controller: _password,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 1),
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hidepass = !_hidepass;
                        });
                      },
                      icon: Icon(
                        _hidepass ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Spacer(),
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll(Colors.green),
                ),
                onPressed: _login,
                child: Text('Login', style: TextStyle(color: Colors.white)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Don\'t have an account?'),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => Signupscreen()),
                      );
                    },
                    child: Text(
                      'Sign up',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 7, 47, 221),
                      ),
                    ),
                  ),
                ],
              ),
              Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  void _login() async {
    String email = _email.text.trim();
    String password = _password.text.trim();

    try {
      User? user = await _auth.signInWithEmailAndPassword(email, password);

      if (!context.mounted) return;

      if (user != null) {
        _showSnackbar('Login successful');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = '';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format';
          break;
        default:
          errorMessage = 'Login failed: ${e.code}';
      }

      _showSnackbar(errorMessage);
    } catch (e) {
      _showSnackbar('Something went wrong: $e');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: Duration(milliseconds: 700), content: Text(msg)),
    );
  }

  Future<void> openInMaps(String lat, String lng) async {
    final Uri uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not open the map.';
    }
  }
}
