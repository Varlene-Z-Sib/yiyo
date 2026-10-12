import 'package:flutter/material.dart';

import '../services/api_service.dart';

String _friendlyFlagError(
  ApiException error,
) {
  switch (error.statusCode) {
    case 400:
    case 409:
    case 429:
      return error.message;

    case 401:
      return "Your session has expired. "
          "Please sign in again.";

    case 404:
      return "This community update is no longer available.";

    default:
      return "We couldn't report this update. "
          "Please try again.";
  }
}

Future<bool?> showReportFlagSheet({
  required BuildContext context,
  required String reportId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(
      0xFF111111,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(
          24,
        ),
      ),
    ),
    builder: (_) {
      return _ReportFlagSheet(
        reportId: reportId,
      );
    },
  );
}

class _ReportFlagSheet
    extends StatefulWidget {
  final String reportId;

  const _ReportFlagSheet({
    required this.reportId,
  });

  @override
  State<_ReportFlagSheet> createState() =>
      _ReportFlagSheetState();
}

class _ReportFlagSheetState
    extends State<_ReportFlagSheet> {
  final TextEditingController
      _detailsController =
      TextEditingController();

  String _reason =
      "false_information";

  String? _errorMessage;

  bool _isSubmitting =
      false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting =
          true;

      _errorMessage =
          null;
    });

    try {
      await ApiService.flagReport(
        reportId:
            widget.reportId,
        reason:
            _reason,
        details:
            _detailsController
                .text
                .trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(
        true,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting =
            false;

        _errorMessage =
            _friendlyFlagError(
          error,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting =
            false;

        _errorMessage =
            "Something went wrong. "
            "Please try again.";
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final mediaQuery =
        MediaQuery.of(
      context,
    );

    final keyboardInset =
        mediaQuery.viewInsets.bottom;

    final systemBottomInset =
        mediaQuery.viewPadding.bottom;

    final extraBottomPadding =
        keyboardInset > 0
            ? keyboardInset + 16
            : systemBottomInset + 20;

    return AnimatedPadding(
      duration:
          const Duration(
        milliseconds: 180,
      ),
      curve:
          Curves.easeOut,
      padding:
          EdgeInsets.only(
        bottom:
            extraBottomPadding,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(
            maxHeight:
                mediaQuery.size.height *
                    0.9,
          ),
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              18,
              16,
              16,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.grey[
                        700
                      ],
                      borderRadius:
                          BorderRadius.circular(
                        999,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                const Center(
                  child: Text(
                    "Report this update",
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Center(
                  child: Text(
                    "Let us know why this "
                    "community update may "
                    "need review.",
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.grey[
                        400
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                DropdownButtonFormField<
                    String>(
                  value:
                      _reason,
                  decoration:
                      const InputDecoration(
                    labelText:
                        "Reason",
                    border:
                        OutlineInputBorder(),
                  ),
                  items:
                      const [
                    DropdownMenuItem(
                      value:
                          "false_information",
                      child: Text(
                        "False information",
                      ),
                    ),

                    DropdownMenuItem(
                      value:
                          "spam",
                      child: Text(
                        "Spam",
                      ),
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
                      value:
                          "other",
                      child: Text(
                        "Other",
                      ),
                    ),
                  ],
                  onChanged:
                      _isSubmitting
                          ? null
                          : (
                              value,
                            ) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setState(() {
                                _reason =
                                    value;

                                _errorMessage =
                                    null;
                              });
                            },
                ),

                const SizedBox(
                  height: 12,
                ),

                TextField(
                  controller:
                      _detailsController,
                  enabled:
                      !_isSubmitting,
                  maxLines: 3,
                  maxLength: 500,
                  textInputAction:
                      TextInputAction.done,
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

                if (_errorMessage !=
                    null) ...[
                  const SizedBox(
                    height: 4,
                  ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.red
                              .withValues(
                        alpha:
                            0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color:
                              Colors.redAccent,
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style:
                                const TextStyle(
                              color:
                                  Colors.redAccent,
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
                        _isSubmitting
                            ? null
                            : _submit,
                    icon:
                        const Icon(
                      Icons.flag_outlined,
                    ),
                    label:
                        Text(
                      _isSubmitting
                          ? "Submitting..."
                          : "Submit report",
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}