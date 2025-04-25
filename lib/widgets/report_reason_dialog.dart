// File: lib/widgets/report_reason_dialog.dart
import 'package:dtx/utils/app_enums.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<ReportReason?> showReportReasonDialog(BuildContext context) async {
  return await showDialog<ReportReason>(
    context: context,
    builder: (BuildContext dialogContext) {
      ReportReason? selectedReason; // Local state for the dialog
      return StatefulBuilder(
        // Use StatefulBuilder for local state update
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Report User",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            contentPadding:
                const EdgeInsets.fromLTRB(24, 20, 24, 0), // Adjust padding
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ReportReason.values.map((reason) {
                  return RadioListTile<ReportReason>(
                    title: Text(reason.label, style: GoogleFonts.poppins()),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (ReportReason? value) {
                      setState(() {
                        // Use the setState from StatefulBuilder
                        selectedReason = value;
                      });
                    },
                    activeColor: const Color(0xFF8B5CF6),
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey)),
                onPressed: () => Navigator.of(dialogContext)
                    .pop(null), // Return null on cancel
              ),
              TextButton(
                child: Text('Submit Report',
                    style: GoogleFonts.poppins(color: Colors.redAccent)),
                // Enable button only if a reason is selected
                onPressed: selectedReason == null
                    ? null
                    : () => Navigator.of(dialogContext).pop(selectedReason),
              ),
            ],
          );
        },
      );
    },
  );
}
