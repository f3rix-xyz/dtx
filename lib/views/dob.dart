import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class DateOfBirthScreen extends ConsumerStatefulWidget {
  const DateOfBirthScreen({super.key});

  @override
  ConsumerState<DateOfBirthScreen> createState() => _DateOfBirthScreenState();
}

class _DateOfBirthScreenState extends ConsumerState<DateOfBirthScreen> {
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

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
                SizedBox(height: screenSize.height * 0.1),
                Text(
                  "What's your date of birth?",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.08,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenSize.height * 0.04),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDateInput("DD", _dayController, 2),
                    _buildDateInput("MM", _monthController, 2),
                    _buildDateInput("YYYY", _yearController, 4),
                  ],
                ),
                SizedBox(height: screenSize.height * 0.03),
                Text(
                  "We use this to calculate the age on your profile.",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.04,
                    color: Colors.white70,
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
                const Spacer(),
                _buildNextButton(screenSize),
                SizedBox(height: screenSize.height * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateInput(
      String hint, TextEditingController controller, int maxLength) {
    // Create a FocusNode for each input field
    final focusNode = FocusNode();

    return Expanded(
      flex: maxLength == 4 ? 2 : 1,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
          counterText: "",
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white54, width: 2.0),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 2.5),
          ),
        ),
        textAlign: TextAlign.center,
        onChanged: (value) {
          // Move to next field when max length is reached
          if (value.length == maxLength) {
            if (hint == "DD") {
              FocusScope.of(context).nextFocus();
            } else if (hint == "MM") {
              FocusScope.of(context).nextFocus();
            }
          }
          _validateInputs();
        },
      ),
    );
  }

  void _validateInputs() {
    ref.read(errorProvider.notifier).clearError();
    final day = int.tryParse(_dayController.text) ?? 0;
    final month = int.tryParse(_monthController.text) ?? 0;
    final year = int.tryParse(_yearController.text) ?? 0;

    if (_dayController.text.isEmpty ||
        _monthController.text.isEmpty ||
        _yearController.text.isEmpty) return;

    if (day < 1 || day > 31) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Invalid day"),
          );
      return;
    }

    if (month < 1 || month > 12) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Invalid month"),
          );
      return;
    }

    try {
      final date = DateTime(year, month, day);
      ref.read(userProvider.notifier).updateDateOfBirth(date);
    } catch (e) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Invalid date combination"),
          );
    }
  }

  Widget _buildNextButton(Size screenSize) {
    final isValid = _dayController.text.length == 2 &&
        _monthController.text.length == 2 &&
        _yearController.text.length == 4 &&
        ref.read(errorProvider) == null;

    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: isValid ? _handleNext : null,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: isValid ? Colors.white : Colors.grey.shade400,
          shadowColor: Colors.black.withOpacity(0.2),
          elevation: 8,
          padding: const EdgeInsets.all(16),
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: 24,
          color: isValid ? const Color(0xFF8B5CF6) : Colors.white54,
        ),
      ),
    );
  }

  void _handleNext() {
    final date = DateTime(
      int.parse(_yearController.text),
      int.parse(_monthController.text),
      int.parse(_dayController.text),
    );

    ref.read(userProvider.notifier).updateDateOfBirth(date);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationInputScreen()),
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }
}
