import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/database_helper.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:snippet_coder_utils/FormHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  bool isAPIcallProcess = false;
  bool hidePassword = true;
  GlobalKey<FormState> globalFormKey = GlobalKey<FormState>();
  String? username;
  String? password;

  bool validateAndSave() {
    final form = globalFormKey.currentState;
    if (form != null && form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  Future<void> _login() async {
    if (!validateAndSave()) return;

    setState(() => isAPIcallProcess = true);

    try {
      
      if (username == "admin" && password == "123") {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        setState(() => isAPIcallProcess = false);
        if (mounted) Navigator.pushReplacementNamed(context, '/mainnav');
        return;
      }

      
      var user = await DatabaseHelper().getUser(username!, password!);
      setState(() => isAPIcallProcess = false);

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (mounted) Navigator.pushReplacementNamed(context, '/mainnav');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid username or password")),
          );
        }
      }
    } catch (e) {
      setState(() => isAPIcallProcess = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF87CEEB), Color(0xFF283B71)],
            ),
          ),
          child: ModalProgressHUD(
            inAsyncCall: isAPIcallProcess,
            opacity: 0.3,
            key: UniqueKey(),
            child: Form(key: globalFormKey, child: _loginUI(context)),
          ),
        ),
      ),
    );
  }

  Widget _loginUI(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height / 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.white],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(100),
                bottomRight: Radius.circular(100),
              ),
            ),
            child: Center(
              child: Image.asset(
                "assets/images/mamaabbys.jpg",
                width: 200,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 5, top: 80),
            child: Text(
              "Sign in",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 40,
                color: Colors.white,
              ),
            ),
          ),
          FormHelper.inputFieldWidget(
            context,
            "username",
            "Username",
            (val) => val.isEmpty ? "Username can't be empty" : null,
            (val) => username = val,
            prefixIcon: const Icon(Icons.person, color: Colors.white),
            borderFocusColor: Colors.white,
            borderColor: Colors.white,
            borderRadius: 10,
            textColor: Colors.white,
            hintColor: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 10),
          FormHelper.inputFieldWidget(
            context,
            "password",
            "Password",
            (val) => val.isEmpty ? "Password can't be empty" : null,
            (val) => password = val,
            prefixIcon: const Icon(Icons.lock, color: Colors.white),
            borderFocusColor: Colors.white,
            borderColor: Colors.white,
            textColor: Colors.white,
            hintColor: Colors.white.withOpacity(0.7),
            borderRadius: 10,
            obscureText: hidePassword,
            suffixIcon: IconButton(
              icon: Icon(
                hidePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => hidePassword = !hidePassword);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SizedBox(
              width: double.infinity,
              child: FormHelper.submitButton(
                "Login",
                _login,
                btnColor: Colors.white,
                borderColor: Colors.white,
                txtColor: Colors.blue,
                borderRadius: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
