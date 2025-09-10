import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/profile/profile_screen.dart';


class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text('Safe Travel App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Welcome\nYour journey, secured.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
              icon: Icon(Icons.call),
              label: Text('Continue with Phone Number'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.g_mobiledata),
              label: Text('Continue with Google'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.email),
              label: Text('Email'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 15),
            Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                children: [
                  TextSpan(
                    text: 'Log In',
                    style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text('By signing in, agree to our Terms & Privacy', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}