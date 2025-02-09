import 'package:dtx/views/dob.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NameInputScreen extends StatefulWidget {
  const NameInputScreen({super.key});

  @override
  _NameInputScreenState createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenSize.height * 0.04),

                  // Icon and Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "What’s your name?",
                        style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenSize.height * 0.04),

                  // First Name Input Field
                  TextFormField(
                    controller: _firstNameController,
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.05,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      labelText: "First name (required)",
                      labelStyle: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.042,
                        color: Colors.white54,
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54, width: 1.5),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 2.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'First name is required';
                      } else if (value.length < 3) {
                        return 'First name must be at least 3 characters long';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: screenSize.height * 0.03),

                  // Last Name Input Field
                  TextField(
                    controller: _lastNameController,
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.05,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      labelText: "Last name (optional)",
                      labelStyle: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.042,
                        color: Colors.white54,
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54, width: 1.5),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 2.0),
                      ),
                    ),
                  ),

                  Spacer(),

                  // Next Button (Circular with Forward Icon)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DateOfBirthScreen()),
                  );
                        }
                      },
                      child: Container(
                        width: screenSize.width * 0.15,
                        height: screenSize.width * 0.15,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 4), // Shadow position
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 28,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.04), // Bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}