import 'package:FitFriend/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:FitFriend/components/my_button.dart';
import 'package:FitFriend/components/my_textfield.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart'; 

class RegisterPage extends StatefulWidget {
  final Function()? onTap;

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmpasswordController = TextEditingController();
  final firstnameController = TextEditingController();
  final lastnameController = TextEditingController();
  final ageController = TextEditingController();

  bool isLoading = false;  

void signUserUp() async {
  if (!mounted) return; 
  
  setState(() {
    isLoading = true;  // Show loading indicator
  });

  if (passwordController.text != confirmpasswordController.text) {
    showErrorMessage("Passwords do not match!");
    if (mounted) {
      setState(() {
        isLoading = false;  // Hide loading indicator
      });
    }
    return;
  }

  try {
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text,
      password: passwordController.text,
    );

    await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
      'first_name': firstnameController.text,
      'last_name': lastnameController.text,
      'age': int.tryParse(ageController.text) ?? 0,
      'email': emailController.text,
    });

    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomePage()));
    }
  } on FirebaseAuthException catch (e) {
    if (mounted) {
      showErrorMessage(e.message ?? "An error occurred during the registration process");
    }
  } catch (e) {
    if (mounted) {
      showErrorMessage("An unexpected error occurred");
    }
  } finally {
    if (mounted) {
      setState(() {
        isLoading = false;  // Hide loading indicator after operation
      });
    }
  }
}


  void showErrorMessage(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[300],
      body: SafeArea(
        child: Center(
          child: isLoading
            ? CircularProgressIndicator()  // Display loading indicator when isLoading is true
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/images/FitFriendNewLogo.png',
                      width: 300,
                      height: 150,
                    ),
                    Text(
                      'Sign up to Fit Friend!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 25),
                    MyTextField(
                      controller: firstnameController,
                      hintText: 'First Name',
                      obscureText: false,
                    ),
                    const SizedBox(height: 10),
                    MyTextField(
                      controller: lastnameController,
                      hintText: 'Last Name',
                      obscureText: false,
                    ),
                    const SizedBox(height: 10),
                    MyTextField(
                      controller: ageController,
                      hintText: 'Age',
                      obscureText: false,
                    ),
                    const SizedBox(height: 10),
                    MyTextField(
                      controller: emailController,
                      hintText: 'Email',
                      obscureText: false,
                    ),
                    const SizedBox(height: 10),
                    MyTextField(
                      controller: passwordController,
                      hintText: 'Password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    MyTextField(
                      controller: confirmpasswordController,
                      hintText: 'Confirm Password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 25),
                    MyButton(
                      text: "Sign Up",
                      onTap: signUserUp,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already a member?',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => LoginPage(onTap: () {  },)));
                      },
                          child: const Text(
                            'Login now',
                            style: TextStyle(
                              color: Color.fromARGB(255, 0, 95, 172),
                              fontWeight: FontWeight.bold,
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
    );
  }
}
