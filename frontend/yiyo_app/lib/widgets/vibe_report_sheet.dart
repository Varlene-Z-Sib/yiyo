import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../models/vibe_report_request.dart';
import '../services/api_service.dart';


Future<bool?> showVibeReportSheet({
  required BuildContext context,
  required Venue venue,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor:
        Theme.of(context)
            .scaffoldBackgroundColor,
    shape:
        const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
    builder: (_) {
      return _VibeReportSheetContent(
        venue: venue,
      );
    },
  );
}


class _VibeReportSheetContent
    extends StatefulWidget {
  final Venue venue;

  const _VibeReportSheetContent({
    required this.venue,
  });

  @override
  State<_VibeReportSheetContent>
      createState() =>
          _VibeReportSheetContentState();
}


class _VibeReportSheetContentState
    extends State<
        _VibeReportSheetContent> {
  String? _yiyoStatus;
  String? _crowdLevel;

  String? _safetyLevel;
  String? _musicType;
  String? _queueLength;

  String? _parkingAvailability;
  String? _parkingSafety;

  bool _showDetails = false;
  bool _isSubmitting = false;

  String? _errorMessage;

  final TextEditingController
      _parkingNoteController =
      TextEditingController();

  final TextEditingController
      _commentController =
      TextEditingController();

  bool get _canSubmit {
    return _yiyoStatus != null &&
        _crowdLevel != null &&
        !_isSubmitting;
  }

  @override
  void dispose() {
    _parkingNoteController.dispose();
    _commentController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final request =
        VibeReportRequest(
      venueId: widget.venue.id,
      venueName: widget.venue.name,

      crowdLevel: _crowdLevel!,
      yiyoStatus: _yiyoStatus!,

      safetyLevel:
          _safetyLevel,

      musicType:
          _musicType,

      queueLength:
          _queueLength,

      parkingAvailability:
          _parkingAvailability,

      parkingSafety:
          _parkingSafety,

      parkingNote:
          _parkingNoteController
              .text
              .trim(),

      comment:
          _commentController
              .text
              .trim(),

      reportedAt:
          DateTime.now()
              .toUtc()
              .toIso8601String(),
    );

    try {
      await ApiService
          .submitVibeReport(
        request,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pop(true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage =
            e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;

        _errorMessage =
            "Couldn't update the vibe. "
            "Please try again.";
      });
    }
  }

  void _selectOptional(
    String value,
    String? currentValue,
    ValueChanged<String?>
        onChanged,
  ) {
    if (currentValue == value) {
      onChanged(null);
    } else {
      onChanged(value);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final keyboardHeight =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return ConstrainedBox(
      constraints:
          BoxConstraints(
        maxHeight:
            MediaQuery.of(context)
                    .size
                    .height *
                0.92,
      ),
      child:
          SingleChildScrollView(
        padding:
            EdgeInsets.only(
          left: 18,
          right: 18,
          top: 10,
          bottom:
              keyboardHeight + 20,
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
                margin:
                    const EdgeInsets.only(
                  bottom: 18,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey[500],
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
              ),
            ),

            const Text(
              "Update the vibe",
              style:
                  TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              widget.venue.name,
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
                fontSize: 15,
              ),
            ),

            const SizedBox(
              height: 26,
            ),

            const Text(
              "Worth it right now?",
              style:
                  TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              "Go with your gut.",
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _QuickOptionButton(
                    label: "YIYO",
                    subtitle:
                        "Worth it",
                    selected:
                        _yiyoStatus ==
                            "Yes definitely",
                    onTap: () {
                      setState(() {
                        _yiyoStatus =
                            "Yes definitely";
                        _errorMessage =
                            null;
                      });
                    },
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child:
                      _QuickOptionButton(
                    label: "KINDA",
                    subtitle:
                        "Maybe",
                    selected:
                        _yiyoStatus ==
                            "Kind of",
                    onTap: () {
                      setState(() {
                        _yiyoStatus =
                            "Kind of";
                        _errorMessage =
                            null;
                      });
                    },
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child:
                      _QuickOptionButton(
                    label: "NO",
                    subtitle:
                        "Not now",
                    selected:
                        _yiyoStatus ==
                            "No",
                    onTap: () {
                      setState(() {
                        _yiyoStatus =
                            "No";
                        _errorMessage =
                            null;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 28,
            ),

            const Text(
              "How busy?",
              style:
                  TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _CrowdButton(
                    label: "Dead",
                    selected:
                        _crowdLevel ==
                            "Dead",
                    onTap: () {
                      setState(() {
                        _crowdLevel =
                            "Dead";
                        _errorMessage =
                            null;
                      });
                    },
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child:
                      _CrowdButton(
                    label: "Chill",
                    selected:
                        _crowdLevel ==
                            "Chill",
                    onTap: () {
                      setState(() {
                        _crowdLevel =
                            "Chill";
                        _errorMessage =
                            null;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _CrowdButton(
                    label: "Busy",
                    selected:
                        _crowdLevel ==
                            "Busy",
                    onTap: () {
                      setState(() {
                        _crowdLevel =
                            "Busy";
                        _errorMessage =
                            null;
                      });
                    },
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child:
                      _CrowdButton(
                    label: "Packed",
                    selected:
                        _crowdLevel ==
                            "Packed",
                    onTap: () {
                      setState(() {
                        _crowdLevel =
                            "Packed";
                        _errorMessage =
                            null;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            InkWell(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              onTap: () {
                setState(() {
                  _showDetails =
                      !_showDetails;
                });
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .tune_outlined,
                      size: 20,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    const Expanded(
                      child: Text(
                        "Add more details",
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),

                    Icon(
                      _showDetails
                          ? Icons
                              .keyboard_arrow_up
                          : Icons
                              .keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
            ),

            AnimatedCrossFade(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              crossFadeState:
                  _showDetails
                      ? CrossFadeState
                          .showSecond
                      : CrossFadeState
                          .showFirst,
              firstChild:
                  const SizedBox.shrink(),
              secondChild:
                  _buildDetails(),
            ),

            if (_errorMessage !=
                null) ...[
              const SizedBox(
                height: 14,
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
                  color: Colors.red
                      .withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
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

            const SizedBox(
              height: 18,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 56,
              child:
                  ElevatedButton(
                onPressed:
                    _canSubmit
                        ? _submit
                        : null,
                child:
                    _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Text(
                            "UPDATE VIBE",
                            style:
                                TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Center(
              child: Text(
                "Takes a few seconds. "
                "Fresh updates help everyone.",
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 12,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Divider(),

          const SizedBox(
            height: 12,
          ),

          _OptionalOptionGroup(
            title:
                "Community safety",
            helper:
                "Only answer if you "
                "can judge it.",
            options: const [
              "Safe",
              "Okay",
              "Sketchy",
              "Unsafe",
            ],
            selectedValue:
                _safetyLevel,
            onSelected: (value) {
              setState(() {
                _selectOptional(
                  value,
                  _safetyLevel,
                  (newValue) {
                    _safetyLevel =
                        newValue;
                  },
                );
              });
            },
          ),

          const SizedBox(
            height: 22,
          ),

          _OptionalOptionGroup(
            title: "Music",
            options: const [
              "Amapiano",
              "Afrobeat",
              "House",
              "Hip-hop",
              "Mixed",
            ],
            selectedValue:
                _musicType,
            onSelected: (value) {
              setState(() {
                _selectOptional(
                  value,
                  _musicType,
                  (newValue) {
                    _musicType =
                        newValue;
                  },
                );
              });
            },
          ),

          const SizedBox(
            height: 22,
          ),

          _OptionalOptionGroup(
            title: "Queue",
            options: const [
              "No queue",
              "Short",
              "Long",
            ],
            selectedValue:
                _queueLength,
            onSelected: (value) {
              setState(() {
                _selectOptional(
                  value,
                  _queueLength,
                  (newValue) {
                    _queueLength =
                        newValue;
                  },
                );
              });
            },
          ),

          const SizedBox(
            height: 22,
          ),

          _OptionalOptionGroup(
            title:
                "Parking availability",
            options: const [
              "Available",
              "Limited",
              "Full",
            ],
            selectedValue:
                _parkingAvailability,
            onSelected: (value) {
              setState(() {
                _selectOptional(
                  value,
                  _parkingAvailability,
                  (newValue) {
                    _parkingAvailability =
                        newValue;
                  },
                );
              });
            },
          ),

          const SizedBox(
            height: 22,
          ),

          _OptionalOptionGroup(
            title:
                "Parking safety",
            helper:
                "Skip this if you're "
                "not sure.",
            options: const [
              "Safe",
              "Okay",
              "Risky",
              "Unsafe",
            ],
            selectedValue:
                _parkingSafety,
            onSelected: (value) {
              setState(() {
                _selectOptional(
                  value,
                  _parkingSafety,
                  (newValue) {
                    _parkingSafety =
                        newValue;
                  },
                );
              });
            },
          ),

          const SizedBox(
            height: 20,
          ),

          TextField(
            controller:
                _parkingNoteController,
            maxLength: 500,
            maxLines: 2,
            decoration:
                const InputDecoration(
              labelText:
                  "Parking note (optional)",
              hintText:
                  "Anything useful about parking?",
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          TextField(
            controller:
                _commentController,
            maxLength: 500,
            maxLines: 3,
            decoration:
                const InputDecoration(
              labelText:
                  "Extra note (optional)",
              hintText:
                  "Anything else people should know?",
              border:
                  OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}


class _QuickOptionButton
    extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _QuickOptionButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        onTap: onTap,
        child: Container(
          constraints:
              const BoxConstraints(
            minHeight: 82,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 12,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              width:
                  selected
                      ? 2
                      : 1,
              color:
                  selected
                      ? scheme.primary
                      : scheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      selected
                          ? scheme.primary
                          : null,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                subtitle,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CrowdButton
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CrowdButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        onTap: onTap,
        child: Container(
          height: 58,
          alignment:
              Alignment.center,
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              width:
                  selected
                      ? 2
                      : 1,
              color:
                  selected
                      ? scheme.primary
                      : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w600,
              color:
                  selected
                      ? scheme.primary
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}


class _OptionalOptionGroup
    extends StatelessWidget {
  final String title;
  final String? helper;

  final List<String> options;

  final String? selectedValue;

  final ValueChanged<String>
      onSelected;

  const _OptionalOptionGroup({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.helper,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        if (helper != null) ...[
          const SizedBox(
            height: 3,
          ),

          Text(
            helper!,
            style:
                TextStyle(
              color:
                  Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],

        const SizedBox(
          height: 9,
        ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map(
            (option) {
              return ChoiceChip(
                label:
                    Text(option),
                selected:
                    selectedValue ==
                        option,
                onSelected: (_) {
                  onSelected(
                    option,
                  );
                },
              );
            },
          ).toList(),
        ),
      ],
    );
  }
}