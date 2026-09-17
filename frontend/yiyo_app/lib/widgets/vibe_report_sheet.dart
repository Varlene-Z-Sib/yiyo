import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../models/vibe_report_request.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

Future<bool?> showVibeReportSheet({
  required BuildContext context,
  required Venue venue,
}) async {
  if (AuthService.currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please log in to submit a report"),
      ),
    );

    return false;
  }

  String crowdLevel = "Busy";
  String safetyLevel = "Safe";
  String musicType = "Amapiano";
  String queueLength = "Short";
  String yiyoStatus = "Kind of";

  String parkingAvailability = "Available";
  String parkingSafety = "Safe";

  final commentController = TextEditingController();
  final parkingNoteController = TextEditingController();

  try {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            Future<void> submit() async {
              if (isSubmitting) return;

              setModalState(() {
                isSubmitting = true;
              });

              try {
                final report = VibeReportRequest(
                  venueId: venue.id,
                  venueName: venue.name,
                  crowdLevel: crowdLevel,
                  safetyLevel: safetyLevel,
                  musicType: musicType,
                  queueLength: queueLength,
                  yiyoStatus: yiyoStatus,
                  parkingAvailability: parkingAvailability,
                  parkingSafety: parkingSafety,
                  parkingNote: parkingNoteController.text.trim(),
                  comment: commentController.text.trim(),
                  reportedAt:
                      DateTime.now().toUtc().toIso8601String(),
                );

                await ApiService.submitVibeReport(report);

                if (!sheetContext.mounted) return;

                Navigator.of(sheetContext).pop(true);
              } catch (e) {
                if (!sheetContext.mounted) return;

                setModalState(() {
                  isSubmitting = false;
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Failed to submit report: $e",
                      ),
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                        16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Report Vibe",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      venue.name,
                      style: const TextStyle(fontSize: 15),
                    ),

                    const SizedBox(height: 18),

                    DropdownButtonFormField<String>(
                      value: yiyoStatus,
                      decoration: const InputDecoration(
                        labelText:
                            "Is this place YIYO right now?",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Yes definitely",
                          child: Text("Yes definitely"),
                        ),
                        DropdownMenuItem(
                          value: "Kind of",
                          child: Text("Kind of"),
                        ),
                        DropdownMenuItem(
                          value: "No",
                          child: Text("No"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(
                            () => yiyoStatus = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: crowdLevel,
                      decoration: const InputDecoration(
                        labelText: "Crowd Level",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Dead",
                          child: Text("Dead"),
                        ),
                        DropdownMenuItem(
                          value: "Chill",
                          child: Text("Chill"),
                        ),
                        DropdownMenuItem(
                          value: "Busy",
                          child: Text("Busy"),
                        ),
                        DropdownMenuItem(
                          value: "Packed",
                          child: Text("Packed"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(
                            () => crowdLevel = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: safetyLevel,
                      decoration: const InputDecoration(
                        labelText: "Safety Level",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Safe",
                          child: Text("Safe"),
                        ),
                        DropdownMenuItem(
                          value: "Okay",
                          child: Text("Okay"),
                        ),
                        DropdownMenuItem(
                          value: "Sketchy",
                          child: Text("Sketchy"),
                        ),
                        DropdownMenuItem(
                          value: "Unsafe",
                          child: Text("Unsafe"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(
                            () => safetyLevel = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: musicType,
                      decoration: const InputDecoration(
                        labelText: "Music Type",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Amapiano",
                          child: Text("Amapiano"),
                        ),
                        DropdownMenuItem(
                          value: "Afrobeat",
                          child: Text("Afrobeat"),
                        ),
                        DropdownMenuItem(
                          value: "House",
                          child: Text("House"),
                        ),
                        DropdownMenuItem(
                          value: "Hip-hop",
                          child: Text("Hip-hop"),
                        ),
                        DropdownMenuItem(
                          value: "Mixed",
                          child: Text("Mixed"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(
                            () => musicType = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: queueLength,
                      decoration: const InputDecoration(
                        labelText: "Queue Length",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "No queue",
                          child: Text("No queue"),
                        ),
                        DropdownMenuItem(
                          value: "Short",
                          child: Text("Short"),
                        ),
                        DropdownMenuItem(
                          value: "Long",
                          child: Text("Long"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(
                            () => queueLength = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: parkingAvailability,
                      decoration: const InputDecoration(
                        labelText: "Parking Availability",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Available",
                          child: Text("Available"),
                        ),
                        DropdownMenuItem(
                          value: "Limited",
                          child: Text("Limited"),
                        ),
                        DropdownMenuItem(
                          value: "Full",
                          child: Text("Full"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(
                            () =>
                                parkingAvailability = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: parkingSafety,
                      decoration: const InputDecoration(
                        labelText: "Parking Safety",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Safe",
                          child: Text("Safe"),
                        ),
                        DropdownMenuItem(
                          value: "Okay",
                          child: Text("Okay"),
                        ),
                        DropdownMenuItem(
                          value: "Risky",
                          child: Text("Risky"),
                        ),
                        DropdownMenuItem(
                          value: "Unsafe",
                          child: Text("Unsafe"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(
                            () => parkingSafety = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: parkingNoteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText:
                            "Parking Note (optional)",
                        border: OutlineInputBorder(),
                        hintText:
                            "Guards visible? Street parking? Valet?",
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Optional Comment",
                        border: OutlineInputBorder(),
                        hintText:
                            "How’s the vibe right now?",
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isSubmitting ? null : submit,
                        child: Text(
                          isSubmitting
                              ? "Submitting..."
                              : "Submit Report",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    commentController.dispose();
    parkingNoteController.dispose();
  }
}