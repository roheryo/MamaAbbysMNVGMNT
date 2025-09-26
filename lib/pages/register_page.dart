import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/login_page.dart';
import 'package:flutter_applicationtest/database_helper.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:snippet_coder_utils/FormHelper.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  bool isAPIcallProcess = false;
  bool hidePassword = true;
  bool isRegisterHovering = false;
  bool isHovering = false;
  GlobalKey<FormState> globalFormKey = GlobalKey<FormState>();
  String? username;
  String? email;
  String? password;

  bool validateAndSave() {
    final form = globalFormKey.currentState;
    if (form != null && form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  Future<void> _submit() async {
    if (!validateAndSave()) return;

    setState(() => isAPIcallProcess = true);

    try {
      // Check for existing username or email
      if (await DatabaseHelper().checkUserExists(username: username)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username already exists')),
        );
      } else if (await DatabaseHelper().checkUserExists(email: email)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email already exists')));
      } else {
        // Save user to database
        await DatabaseHelper().insertUser(
          username: username!,
          email: email!,
          password: password!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully')),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => isAPIcallProcess = false);
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
            child: Form(key: globalFormKey, child: _registerUI(context)),
          ),
        ),
      ),
    );
  }

  Widget _registerUI(BuildContext context) {
    // Keep your original UI exactly as it is
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height / 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(100),
                bottomRight: Radius.circular(100),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    "assets/images/mamaabbys.jpg",
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 10, top: 80),
            child: Text(
              "Sign up",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 40,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Column(
              children: [
                FormHelper.inputFieldWidget(
                  context,
                  "username",
                  "Username",
                  (val) => val.isEmpty ? "Username can't be empty" : null,
                  (val) => username = val,
                  prefixIcon: const Icon(Icons.person, color: Colors.white),
                  borderColor: Colors.white,
                  borderFocusColor: Colors.white,
                  borderRadius: 10,
                  textColor: Colors.white,
                  hintColor: Colors.white70,
                ),
                const SizedBox(height: 15),
                FormHelper.inputFieldWidget(
                  context,
                  "email",
                  "Email",
                  (val) => val.isEmpty ? "Email can't be empty" : null,
                  (val) => email = val,
                  prefixIcon: const Icon(Icons.email, color: Colors.white),
                  borderColor: Colors.white,
                  borderFocusColor: Colors.white,
                  borderRadius: 10,
                  textColor: Colors.white,
                  hintColor: Colors.white70,
                ),
                const SizedBox(height: 15),
                FormHelper.inputFieldWidget(
                  context,
                  "password",
                  "Password",
                  (val) => val.isEmpty ? "Password can't be empty" : null,
                  (val) => password = val,
                  prefixIcon: const Icon(Icons.lock, color: Colors.white),
                  borderColor: Colors.white,
                  borderFocusColor: Colors.white,
                  borderRadius: 10,
                  obscureText: hidePassword,
                  textColor: Colors.white,
                  hintColor: Colors.white70,
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => isRegisterHovering = true),
                    onExit: (_) => setState(() => isRegisterHovering = false),
                    child: SizedBox(
                      width: double.infinity,
                      child: FormHelper.submitButton(
                        "Register",
                        _submit,
                        btnColor: isRegisterHovering
                            ? Colors.blue
                            : Colors.white,
                        borderColor: isRegisterHovering
                            ? Colors.blue
                            : Colors.white,
                        txtColor: isRegisterHovering
                            ? Colors.white
                            : Colors.blue,
                        borderRadius: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Colors.white),
                        ),
                        MouseRegion(
                          onEnter: (_) => setState(() => isHovering = true),
                          onExit: (_) => setState(() => isHovering = false),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Sign In Here",
                              style: TextStyle(
                                color: isHovering
                                    ? Colors.blueAccent
                                    : Colors.white,
                                decoration: TextDecoration.underline,
                                decorationColor: isHovering
                                    ? Colors.blueAccent
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
