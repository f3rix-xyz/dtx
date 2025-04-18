// File: lib/views/height.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// Removed unused app_enums import
import '../providers/user_provider.dart';
import 'hometown.dart'; // Keep for onboarding flow

class HeightSelectionScreen extends ConsumerStatefulWidget {
  final bool isEditing; // <<< ADDED

  const HeightSelectionScreen({
    super.key,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  ConsumerState<HeightSelectionScreen> createState() =>
      _HeightSelectionScreenState();
}

class _HeightSelectionScreenState extends ConsumerState<HeightSelectionScreen> {
  String _unit = "FT"; // Default unit is Feet
  int _selectedFeetIndex = 0; // Start at the first index (4' 0")
  int _selectedCmIndex = 30; // Start at 150 cm (index 30 for 120cm base)

  // Define the starting and ending points explicitly
  int _startFeet = 4;
  int _startInches = 0;
  int _endFeet = 7; // Extended range up to 7'0"
  int _endInches = 0;

  int _startCm = 120;
  int _endCm = 213; // Approx 7'0"

  late List<String> _feetValues;
  late List<String> _cmValues;

  String _initialHeightValue = ''; // Store initial value for comparison/reset

  // Function to convert CM to Feet and Inches string
  String _cmToFeet(int cm) {
    double totalInches = cm * 0.393701;
    int feet = (totalInches / 12).floor();
    int inches = (totalInches % 12).round();
    if (inches == 12) {
      feet++;
      inches = 0;
    }
    return "$feet' $inches\""; // API format
  }

  // Function to convert Feet and Inches string to CM
  int _feetToCm(String feetInchStr) {
    try {
      final parts = feetInchStr.replaceAll('"', '').split("'");
      if (parts.length == 2) {
        final feet = int.tryParse(parts[0]) ?? 0;
        final inches = int.tryParse(parts[1]) ?? 0;
        double totalInches = (feet * 12) + inches.toDouble();
        return (totalInches / 0.393701).round();
      }
    } catch (e) {
      print("Error parsing height $feetInchStr: $e");
    }
    return _startCm; // Default fallback
  }

  @override
  void initState() {
    super.initState();

    // Generate Feet Values (4'0" to 7'0")
    _feetValues = List.generate(
      ((_endFeet * 12) + _endInches) - ((_startFeet * 12) + _startInches) + 1,
      (index) {
        int totalInches = ((_startFeet * 12) + _startInches) + index;
        int feet = totalInches ~/ 12;
        int inches = totalInches % 12;
        return "$feet' $inches\""; // API format
      },
    );

    // Generate CM Values (120cm to 213cm)
    _cmValues = List.generate(
        _endCm - _startCm + 1, (index) => "${_startCm + index} cm");

    // Load initial value if editing
    if (widget.isEditing) {
      final currentHeight = ref.read(userProvider).height;
      _initialHeightValue = currentHeight ?? '';
      if (currentHeight != null && currentHeight.isNotEmpty) {
        // Determine initial unit and index
        if (currentHeight.contains("'")) {
          // Assume FT format
          _unit = "FT";
          _selectedFeetIndex = _feetValues.indexOf(currentHeight);
          if (_selectedFeetIndex == -1) _selectedFeetIndex = 0; // Fallback
        } else if (currentHeight.toLowerCase().contains('cm')) {
          // Assume CM format (unlikely based on save logic, but check)
          _unit = "CM";
          _selectedCmIndex = _cmValues.indexOf(currentHeight);
          if (_selectedCmIndex == -1) _selectedCmIndex = 30; // Fallback ~150cm
        } else {
          // If format is unknown, try parsing as FT
          _unit = "FT";
          _selectedFeetIndex = _feetValues.indexOf(currentHeight);
          if (_selectedFeetIndex == -1) _selectedFeetIndex = 0; // Fallback
        }
      } else {
        // Default if no existing height
        _unit = "FT";
        _selectedFeetIndex = 11; // Default to 5'11" approx
      }
    } else {
      // Default for onboarding
      _unit = "FT";
      _selectedFeetIndex = 11; // Default to 5'11" approx
    }
  }

  void _handleNext() {
    _updateHeight(ref, forceUpdate: true); // Ensure provider is updated
    if (widget.isEditing) {
      print("[HeightSelectionScreen] Editing done, popping back.");
      Navigator.of(context).pop(); // Pop back to ProfileScreen
    } else {
      // Original onboarding navigation
      print("[HeightSelectionScreen] Onboarding next: Hometown.");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HometownScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final userState =
        ref.watch(userProvider); // Watch for external updates if needed

    // Use appropriate values for the current unit
    final List<String> currentValues = _unit == "FT" ? _feetValues : _cmValues;
    int currentIndex = _unit == "FT" ? _selectedFeetIndex : _selectedCmIndex;

    // Check if the current value in the provider matches the displayed value
    final bool hasValueChanged = (_unit == "FT" &&
            userState.height != _feetValues[currentIndex]) ||
        (_unit == "CM" &&
            userState.height !=
                _cmToFeet(
                    int.parse(_cmValues[currentIndex].replaceAll(" cm", ""))));

    // Determine if the "Done" button should be enabled
    final bool canProceed =
        userState.height != null && userState.height!.isNotEmpty;

    // --- Create FixedExtentScrollController ---
    final scrollController =
        FixedExtentScrollController(initialItem: currentIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4), // Light background
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Adjusted Header for Edit Mode ---
              Padding(
                padding: EdgeInsets.only(
                  top: screenSize.height * 0.02,
                  left: screenSize.width * 0.02,
                  right: screenSize.width * 0.06,
                ),
                child: Row(
                  mainAxisAlignment: widget.isEditing
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.start,
                  children: [
                    if (widget.isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 40), // Placeholder

                    Text(
                      widget.isEditing ? "Edit Height" : "",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (widget.isEditing)
                      TextButton(
                        onPressed: canProceed ? _handleNext : null,
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            color: canProceed
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40), // Placeholder
                  ],
                ),
              ),
              // --- End Adjusted Header ---

              SizedBox(
                  height: widget.isEditing ? 40 : screenSize.height * 0.02),

              // Title (Shown in both modes, slightly smaller in edit)
              Center(
                child: Text(
                  "How tall are you?",
                  style: GoogleFonts.poppins(
                    fontSize: widget.isEditing
                        ? screenSize.width * 0.08
                        : screenSize.width * 0.1,
                    fontWeight: FontWeight.w700, // More bold title
                    color: const Color(0xFF333333), // Darker title color
                  ),
                ),
              ),

              SizedBox(
                  height: screenSize.height *
                      0.05), // Increased spacing below title

              // Height Selector
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  controller: scrollController, // Use the controller
                  itemExtent: 70, // Increased item extent for better spacing
                  diameterRatio: 1.3, // Adjusted for better visual
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      if (_unit == "FT") {
                        _selectedFeetIndex = index;
                      } else {
                        _selectedCmIndex = index;
                      }
                      // Update provider immediately on scroll change
                      _updateHeight(ref);
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: currentValues.length,
                    builder: (context, index) {
                      final isSelected = index == currentIndex;
                      return Center(
                        child: Text(
                          currentValues[index],
                          style: GoogleFonts.poppins(
                            fontSize: isSelected
                                ? 30
                                : 22, // Larger font sizes for list items
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400, // Adjusted weight
                            color: isSelected
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey
                                    .shade700, // Highlighted selected color, darker unselected
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(
                  height: screenSize.height *
                      0.03), // Reduced spacing above buttons

              // Unit Toggle Buttons - Improved UI
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width *
                        0.1), // Add horizontal padding for buttons
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceAround, // Space buttons evenly
                  children: [
                    _buildUnitButton("FT", screenSize, scrollController),
                    _buildUnitButton("CM", screenSize, scrollController),
                  ],
                ),
              ),

              SizedBox(
                  height: screenSize.height *
                      0.04), // Spacing before forward button

              // --- Hide FAB in Edit Mode ---
              if (!widget.isEditing)
                Center(
                  child: GestureDetector(
                    onTap: canProceed ? _handleNext : null,
                    child: Container(
                      width: 70, // Even larger button
                      height: 70,
                      decoration: BoxDecoration(
                        color: canProceed
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(35), // More rounded
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 32, // Larger icon
                      ),
                    ),
                  ),
                ),
              // --- End Hide FAB ---
              SizedBox(
                  height: screenSize.height * 0.06), // Increased bottom spacing
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitButton(String unit, Size screenSize,
      FixedExtentScrollController scrollController) {
    final isSelected = _unit == unit;
    return GestureDetector(
      onTap: () {
        if (_unit != unit) {
          // Only update if switching units
          setState(() {
            _unit = unit;
            // Update the scroll position when unit changes
            if (_unit == "FT") {
              // Convert CM index to approximate FT index
              final currentCm = _startCm + _selectedCmIndex;
              final feetStr = _cmToFeet(currentCm);
              _selectedFeetIndex = _feetValues.indexOf(feetStr);
              if (_selectedFeetIndex == -1) _selectedFeetIndex = 11; // Fallback
              // Animate scroll AFTER setState completes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateToItem(_selectedFeetIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              });
            } else {
              // Switching to CM
              // Convert FT index to approximate CM index
              final currentFt = _feetValues[_selectedFeetIndex];
              final cmValue = _feetToCm(currentFt);
              _selectedCmIndex = cmValue - _startCm;
              if (_selectedCmIndex < 0 ||
                  _selectedCmIndex >= _cmValues.length) {
                _selectedCmIndex = 30; // Fallback
              }
              // Animate scroll AFTER setState completes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateToItem(_selectedCmIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              });
            }
            // Update provider after unit switch and index calculation
            _updateHeight(ref);
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: screenSize.width * 0.08), // Dynamic horizontal padding
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5CF6)
              : Colors.white, // White background for unselected
          border: Border.all(color: Colors.grey.shade300), // Subtle border
          borderRadius: BorderRadius.circular(30), // Even more rounded corners
          boxShadow: [
            // Subtle shadow for depth
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 0,
              blurRadius: 3,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: Text(
          unit,
          style: GoogleFonts.poppins(
            fontSize: 18, // Larger font size for buttons
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.w500, // Slightly bolder for selected
            color: isSelected
                ? Colors.white
                : const Color(0xFF555555), // Darker text for unselected
          ),
        ),
      ),
    );
  }

  // Modified to accept forceUpdate flag
  void _updateHeight(WidgetRef ref, {bool forceUpdate = false}) {
    String selectedValue = _unit == "FT"
        ? _feetValues[_selectedFeetIndex]
        : _cmValues[_selectedCmIndex];

    // Convert CM selection to FT' IN" format for saving
    String heightToSave = (_unit == "CM")
        ? _cmToFeet(int.parse(selectedValue.replaceAll(" cm", "")))
        : selectedValue;

    // Only update the provider if the value changed or if forced (e.g., on Done)
    if (forceUpdate || ref.read(userProvider).height != heightToSave) {
      print(
          "[HeightSelectionScreen] Updating height in provider to: $heightToSave");
      ref.read(userProvider.notifier).updateHeight(heightToSave);
    }
  }
}
