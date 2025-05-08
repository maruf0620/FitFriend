import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();

  PasswordResetPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password'),
        backgroundColor: Colors.blue.shade300,
      ),
      body: Center(  
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Text(
                "Please enter the email associated with the account you used to sign up. "
                "We will then send you a link to reset your password.",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  labelStyle: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => resetPassword(context),
                child: Text('Send Reset Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void resetPassword(BuildContext context) async {
    final email = emailController.text;
    if (email.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: Colors.blue.shade300,
          ),
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reset email: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

