import 'package:flutter/material.dart';

import '../services/api_service.dart';

String _friendlyFlagError(ApiException error) {
  switch (error.statusCode) {
    case 400:
      return error.message;

    case 401:
      return "Your session has expired. Please sign in again.";

    case 404:
      return "This community update is no longer available.";

    case 409:
      return error.message;

    case 429:
      return error.message;

    default:
      return "We couldn't report this update. Please try again.";
  }
}

Future<bool?> showReportFlagSheet({
  required BuildContext context,
  required String reportId,
}) async {
  String reason = "false_information";
  String? errorMessage;

  final detailsController =
      TextEditingController();

  try {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          const Color(0xFF111111),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (
            sheetContext,
            setModalState,
          ) {
            Future<void> submit() async {
              if (isSubmitting) {
                return;
              }

              setModalState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              try {
                await ApiService.flagReport(
                  reportId: reportId,
                  reason: reason,
                  details:
                      detailsController
                          .text
                          .trim(),
                );

                if (!sheetContext.mounted) {
                  return;
                }

                Navigator.of(
                  sheetContext,
                ).pop(true);
              } on ApiException catch (e) {
                if (!sheetContext.mounted) {
                  return;
                }

                setModalState(() {
                  isSubmitting = false;
                  errorMessage =
                      _friendlyFlagError(e);
                });
              } catch (_) {
                if (!sheetContext.mounted) {
                  return;
                }

                setModalState(() {
                  isSubmitting = false;
                  errorMessage =
                      "Something went wrong. "
                      "Please try again.";
                });
              }
            }

            return Padding(
              padding:
                  EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom:
                    MediaQuery.of(
                          sheetContext,
                        )
                        .viewInsets
                        .bottom +
                    16,
              ),
              child:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Center(
                      child: Text(
                        "Report this update",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      "Let us know why this "
                      "community update may "
                      "need review.",
                      style: TextStyle(
                        color:
                            Colors.grey[400],
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    DropdownButtonFormField<
                        String>(
                      value: reason,
                      decoration:
                          const InputDecoration(
                        labelText: "Reason",
                        border:
                            OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value:
                              "false_information",
                          child: Text(
                            "False information",
                          ),
                        ),
                        DropdownMenuItem(
                          value: "spam",
                          child: Text("Spam"),
                        ),
                        DropdownMenuItem(
                          value:
                              "abusive_content",
                          child: Text(
                            "Abusive content",
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              "safety_concern",
                          child: Text(
                            "Safety concern",
                          ),
                        ),
                        DropdownMenuItem(
                          value: "other",
                          child: Text("Other"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setModalState(() {
                          reason = value;
                          errorMessage = null;
                        });
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          detailsController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Details (optional)",
                        hintText:
                            "Tell us what seems wrong.",
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(
                        height: 4,
                      ),

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.red
                              .withValues(
                            alpha: 0.12,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Icon(
                              Icons
                                  .info_outline,
                              size: 18,
                              color:
                                  Colors.redAccent,
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child: Text(
                                errorMessage!,
                                style:
                                    const TextStyle(
                                  color: Colors
                                      .redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 12,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          ElevatedButton.icon(
                        onPressed:
                            isSubmitting
                                ? null
                                : submit,
                        icon: const Icon(
                          Icons.flag_outlined,
                        ),
                        label: Text(
                          isSubmitting
                              ? "Submitting..."
                              : "Submit report",
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
    detailsController.dispose();
  }
}