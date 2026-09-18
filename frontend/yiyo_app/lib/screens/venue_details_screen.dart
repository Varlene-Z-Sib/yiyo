import 'package:flutter/material.dart';

import '../models/current_vibe_summary.dart';
import '../models/venue.dart';
import '../models/vibe_report.dart';
import '../services/api_service.dart';
import '../widgets/report_flag_sheet.dart';
import '../widgets/vibe_report_sheet.dart';

class VenueDetailsScreen
    extends StatefulWidget {
  final Venue venue;

  const VenueDetailsScreen({
    super.key,
    required this.venue,
  });

  @override
  State<VenueDetailsScreen> createState() =>
      _VenueDetailsScreenState();
}


class _VenueDetailsScreenState
    extends State<VenueDetailsScreen> {
  bool _isLoading = true;

  String _yiyoBadge = "MID";

  CurrentVibeSummary _summary =
      CurrentVibeSummary.empty();

  List<VibeReport> _reports = [];

  int _reportCount = 0;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final data =
          await ApiService.getVenueReports(
        widget.venue.id,
      );

      if (!mounted) {
        return;
      }

      final reports =
          data["reports"]
                  as List<VibeReport>? ??
              [];

      final summary =
          data["summary"]
                  as CurrentVibeSummary? ??
              CurrentVibeSummary.empty();

      setState(() {
        _yiyoBadge =
            (data["yiyo_badge"] ?? "MID")
                .toString();

        _reportCount =
            (data["count"] as num?)
                    ?.toInt() ??
                reports.length;

        _summary = summary;

        _reports = reports;

        _error = null;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "Failed to load venue reports";

        _isLoading = false;
      });
    }
  }

  Future<void>
      _openVibeReportSheet() async {
    final submitted =
        await showVibeReportSheet(
      context: context,
      venue: widget.venue,
    );

    if (submitted != true ||
        !mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadReports();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Vibe report submitted",
        ),
      ),
    );
  }

  Future<void> _openReportFlagSheet(
    VibeReport report,
  ) async {
    if (report.id.trim().isEmpty) {
      return;
    }

    final submitted =
        await showReportFlagSheet(
      context: context,
      reportId: report.id,
    );

    if (submitted != true ||
        !mounted) {
      return;
    }

    await _loadReports();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Thanks. This update "
          "has been reported "
          "for review.",
        ),
      ),
    );
  }

  Color _badgeColor(
    String badge,
  ) {
    switch (badge) {
      case "YIYO":
        return Colors.green;

      case "NOT YIYO":
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  String _displayValue(
    String value,
  ) {
    final trimmed =
        value.trim();

    return trimmed.isEmpty
        ? "Unknown"
        : trimmed;
  }

  String _signalAgreementLabel(
    CurrentVibeSignal signal,
  ) {
    if (!signal.hasValue) {
      return "No recent data";
    }

    if (_summary.reportCount <= 1) {
      return "Based on the latest update";
    }

    if (signal.agreementCount <= 1) {
      return "Latest supported signal";
    }

    return "${signal.agreementCount} "
        "recent updates agree";
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final venue =
        widget.venue;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          venue.name,
        ),
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              venue.name,
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              "⭐ "
              "${venue.rating.toStringAsFixed(1)}",
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              venue.address,
            ),

            if (venue.distanceKm !=
                null) ...[
              const SizedBox(
                height: 6,
              ),

              Text(
                "${venue.distanceKm!.toStringAsFixed(1)} "
                "km away",
              ),
            ],

            const SizedBox(
              height: 24,
            ),

            const Text(
              "Current vibe",
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding:
                      EdgeInsets.all(
                    24,
                  ),
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildErrorCard()
            else
              _buildCurrentVibe(),

            const SizedBox(
              height: 16,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _openVibeReportSheet,
                icon: const Icon(
                  Icons.bolt,
                ),
                label: const Text(
                  "Update the vibe",
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "Community updates",
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                if (!_isLoading &&
                    _error == null)
                  Text(
                    "$_reportCount "
                    "report"
                    "${_reportCount == 1 ? "" : "s"}",
                    style:
                        TextStyle(
                      color:
                          Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            if (!_isLoading &&
                _error == null)
              if (_reports.isEmpty)
                const Text(
                  "No reports yet. "
                  "Be the first to "
                  "update this venue.",
                )
              else
                ..._reports.map(
                  _buildReportCard,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
            ),

            const SizedBox(
              height: 8,
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });

                _loadReports();
              },
              child:
                  const Text(
                "Try again",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentVibe() {
    if (!_summary.hasCurrentReports) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildBadge(),

              const SizedBox(
                height: 12,
              ),

              const Text(
                "No vibe updates from "
                "the last 24 hours.",
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                _reports.isEmpty
                    ? "Be the first to "
                        "update this venue."
                    : "Older community "
                        "reports are still "
                        "available below.",
                style:
                    TextStyle(
                  color:
                      Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge(),

                const Spacer(),

                Flexible(
                  child: Text(
                    _summary
                        .freshnessLabel(),
                    textAlign:
                        TextAlign.right,
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

            const SizedBox(
              height: 8,
            ),

            Text(
              "Based on "
              "${_summary.reportCount} "
              "update"
              "${_summary.reportCount == 1 ? "" : "s"} "
              "from the last 24 hours",
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
                fontSize: 13,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            _buildSignalRow(
              icon:
                  Icons.groups_outlined,
              label: "Crowd",
              signal:
                  _summary.crowd,
            ),

            const Divider(
              height: 24,
            ),

            _buildSignalRow(
              icon:
                  Icons.shield_outlined,
              label: "Safety",
              signal:
                  _summary.safety,
            ),

            const Divider(
              height: 24,
            ),

            _buildSignalRow(
              icon:
                  Icons.music_note_outlined,
              label: "Music",
              signal:
                  _summary.music,
            ),

            const Divider(
              height: 24,
            ),

            _buildSignalRow(
              icon:
                  Icons.people_outline,
              label: "Queue",
              signal:
                  _summary.queue,
            ),

            if (_summary
                    .parkingAvailability
                    .hasValue ||
                _summary
                    .parkingSafety
                    .hasValue) ...[
              const Divider(
                height: 24,
              ),

              _buildParkingRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            _badgeColor(
          _yiyoBadge,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Text(
        _yiyoBadge,
        style:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSignalRow({
    required IconData icon,
    required String label,
    required CurrentVibeSignal signal,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    TextStyle(
                  color:
                      Colors.grey[600],
                  fontSize: 12,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                signal.value ??
                    "Unknown",
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                _signalAgreementLabel(
                  signal,
                ),
                style:
                    TextStyle(
                  color:
                      Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParkingRow() {
    final availability =
        _summary.parkingAvailability;

    final safety =
        _summary.parkingSafety;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.local_parking_outlined,
          size: 22,
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                "Parking",
                style:
                    TextStyle(
                  color:
                      Colors.grey[600],
                  fontSize: 12,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                [
                  if (availability.hasValue)
                    availability.value!,
                  if (safety.hasValue)
                    safety.value!,
                ].join(" • "),
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                availability
                        .agreementCount >
                    1
                    ? "${availability.agreementCount} "
                        "recent updates agree"
                    : "Based on recent updates",
                style:
                    TextStyle(
                  color:
                      Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(
    VibeReport report,
  ) {
    final current =
        report.isCurrent();

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${_displayValue(report.yiyoStatus)}"
                    " • "
                    "${_displayValue(report.crowdLevel)}"
                    " • "
                    "${_displayValue(report.safetyLevel)}",
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                if (!current)
                  Container(
                    margin:
                        const EdgeInsets.only(
                      left: 8,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.grey[300],
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                    ),
                    child:
                        const Text(
                      "Older",
                      style:
                          TextStyle(
                        fontSize: 11,
                        color:
                            Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              "Music: "
              "${_displayValue(report.musicType)}",
            ),

            Text(
              "Queue: "
              "${_displayValue(report.queueLength)}",
            ),

            if (report
                .parkingAvailability
                .trim()
                .isNotEmpty)
              Text(
                "Parking: "
                "${_displayValue(report.parkingAvailability)}"
                " • "
                "${_displayValue(report.parkingSafety)}",
              ),

            if (report
                .parkingNote
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: 4,
              ),

              Text(
                report.parkingNote,
              ),
            ],

            if (report.comment
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: 6,
              ),

              Text(
                report.comment,
              ),
            ],

            const SizedBox(
              height: 8,
            ),

            Row(
              children: [
                Expanded(
                  child: Text(
                    report
                        .freshnessLabel(),
                    style:
                        TextStyle(
                      color:
                          Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),

                if (report.id
                    .trim()
                    .isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        _openReportFlagSheet(
                      report,
                    ),
                    icon:
                        const Icon(
                      Icons.flag_outlined,
                      size: 16,
                    ),
                    label:
                        const Text(
                      "Report",
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}