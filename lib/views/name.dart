import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/dob.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class NameInputScreen extends ConsumerStatefulWidget {
  const NameInputScreen({super.key});

  @override
  ConsumerState<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends ConsumerState<NameInputScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _firstNameController = TextEditingController(text: user.name);
    _lastNameController = TextEditingController(text: user.lastName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final error = ref.watch(errorProvider);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenSize.height * 0.04),
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
                      "What's your name?",
                      style: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.06,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenSize.height * 0.04),
                _buildFirstNameInput(error, screenSize),
                SizedBox(height: screenSize.height * 0.03),
                _buildLastNameInput(screenSize),
                const Spacer(),
                _buildNextButton(screenSize, error),
                SizedBox(height: screenSize.height * 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFirstNameInput(AppError? error, Size screenSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: error?.type == ErrorType.validation
                    ? Colors.red
                    : Colors.white54,
                width: 1.5,
              ),
            ),
          ),
          child: TextField(
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
              border: InputBorder.none,
            ),
            onChanged: (value) => _updateName(value, _lastNameController.text),
          ),
        ),
        if (error?.type == ErrorType.validation)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              error!.message,
              style: GoogleFonts.poppins(
                color: Colors.redAccent,
                fontSize: screenSize.width * 0.035,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLastNameInput(Size screenSize) {
    return TextField(
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
      onChanged: (value) => _updateName(_firstNameController.text, value),
    );
  }

  Widget _buildNextButton(Size screenSize, AppError? error) {
    final isValid = ref.read(userProvider.notifier).isNameValid();

    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: error == null && isValid
            ? () => _handleNextButton()
            : null, // Disable button if there are errors
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: error != null || !isValid
              ? Colors.grey.shade400 // Disable button if there are errors
              : Colors.white,
          shadowColor: Colors.black.withOpacity(0.2),
          elevation: 8,
          padding: EdgeInsets.all(16), // Adjusted padding
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: 24, // Adjusted icon size
          color: error != null || !isValid
              ? Colors.white54 // Change icon color when disabled
              : const Color(0xFF8B5CF6),
        ),
      ),
    );
  }

  void _updateName(String firstName, String lastName) {
    ref.read(userProvider.notifier).updateName(firstName, lastName);
  }

  void _handleNextButton() {
    ref.read(errorProvider.notifier).clearError();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DateOfBirthScreen()),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
