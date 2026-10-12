import 'package:flutter/material.dart';

import '../models/moderation_queue.dart';
import '../services/api_service.dart';


class ModerationQueueScreen
    extends StatefulWidget {
  const ModerationQueueScreen({
    super.key,
  });

  @override
  State<ModerationQueueScreen>
      createState() =>
          _ModerationQueueScreenState();
}


class _ModerationQueueScreenState
    extends State<
        ModerationQueueScreen> {
  bool _isLoading =
      true;

  String? _error;

  ModerationQueue? _queue;

  String? _workingKey;


  @override
  void initState() {
    super.initState();

    _load();
  }


  Future<void> _load() async {
    try {
      final queue =
          await ApiService
              .getModerationQueue();

      if (!mounted) {
        return;
      }

      setState(() {
        _queue =
            queue;

        _error =
            null;

        _isLoading =
            false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            error.message;

        _isLoading =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "Couldn't load moderation queue.";

        _isLoading =
            false;
      });
    }
  }


  Future<void>
      _refresh() async {
    await _load();
  }


  Future<String?>
      _askForResolution({
    required String title,
    required String message,
    required String actionLabel,
    required bool destructive,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) {
        return _ModerationDecisionDialog(
          title:
              title,
          message:
              message,
          actionLabel:
              actionLabel,
          destructive:
              destructive,
        );
      },
    );
  }


  Future<void>
      _resolveCommunity(
    CommunityModerationCase item,
    String decision,
  ) async {
    final removing =
        decision ==
            "remove";

    final note =
        await _askForResolution(
      title:
          removing
              ? "Remove this update?"
              : "Keep this update?",

      message:
          removing
              ? "This community update will "
                  "be removed from YIYO and "
                  "its open reports will be "
                  "resolved."
              : "This community update will "
                  "remain active and its open "
                  "reports will be resolved.",

      actionLabel:
          removing
              ? "Remove"
              : "Keep",

      destructive:
          removing,
    );

    if (
        note == null ||
        !mounted) {
      return;
    }

    final key =
        "community:"
        "${item.reportId}";

    setState(() {
      _workingKey =
          key;
    });

    try {
      await ApiService
          .resolveCommunityModeration(
        reportId:
            item.reportId,
        decision:
            decision,
        note:
            note,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            removing
                ? "Community update removed."
                : "Community update kept.",
          ),
        ),
      );

      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingKey =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            error.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingKey =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            "Couldn't resolve this report.",
          ),
        ),
      );
    }
  }


  Future<void>
      _resolveEvent(
    EventModerationCase item,
    String decision,
  ) async {
    final removing =
        decision ==
            "remove";

    final note =
        await _askForResolution(
      title:
          removing
              ? "Remove this event?"
              : "Keep this event?",

      message:
          removing
              ? "The event will be cancelled "
                  "and its open reports will "
                  "be resolved."
              : "The event will remain "
                  "available and its open "
                  "reports will be resolved.",

      actionLabel:
          removing
              ? "Remove"
              : "Keep",

      destructive:
          removing,
    );

    if (
        note == null ||
        !mounted) {
      return;
    }

    final key =
        "event:"
        "${item.eventId}";

    setState(() {
      _workingKey =
          key;
    });

    try {
      await ApiService
          .resolveEventModeration(
        eventId:
            item.eventId,
        decision:
            decision,
        note:
            note,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            removing
                ? "Event removed."
                : "Event kept.",
          ),
        ),
      );

      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingKey =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            error.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingKey =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            "Couldn't resolve this event report.",
          ),
        ),
      );
    }
  }


  String _reasonLabel(
    String value,
  ) {
    switch (value) {
      case "false_information":
        return "False information";

      case "spam":
        return "Spam";

      case "abusive_content":
        return "Abusive content";

      case "safety_concern":
        return "Safety concern";

      case "other":
        return "Other";

      default:
        return value
            .replaceAll(
              "_",
              " ",
            )
            .trim();
    }
  }


  String _displayValue(
    String value,
  ) {
    final clean =
        value.trim();

    return clean.isEmpty
        ? "Not provided"
        : clean;
  }


  String _formatDate(
    int unix,
  ) {
    if (unix <= 0) {
      return "Unknown";
    }

    final date =
        DateTime
            .fromMillisecondsSinceEpoch(
          unix * 1000,
          isUtc: true,
        )
            .toLocal();

    String two(
      int value,
    ) {
      return value
          .toString()
          .padLeft(
            2,
            "0",
          );
    }

    return "${date.year}-"
        "${two(date.month)}-"
        "${two(date.day)} "
        "${two(date.hour)}:"
        "${two(date.minute)}";
  }


  Widget _buildReasonChips(
    Map<String, int> reasons,
  ) {
    if (reasons.isEmpty) {
      return const Text(
        "No reason data",
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children:
          reasons.entries
              .map(
                (entry) =>
                    Chip(
                  label:
                      Text(
                    "${_reasonLabel(entry.key)}"
                    " · ${entry.value}",
                  ),
                ),
              )
              .toList(),
    );
  }


  Widget _buildDetails(
    List<String> details,
  ) {
    if (details.isEmpty) {
      return Text(
        "No additional details supplied.",
        style:
            TextStyle(
          color:
              Colors.grey[
            500
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children:
          details
              .map(
                (detail) =>
                    Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 6,
                  ),
                  child:
                      Text(
                    "• $detail",
                  ),
                ),
              )
              .toList(),
    );
  }


  Widget _buildActions({
    required bool busy,
    required VoidCallback keep,
    required VoidCallback remove,
  }) {
    if (busy) {
      return const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 12,
        ),
        child:
            LinearProgressIndicator(),
      );
    }

    return Row(
      children: [
        Expanded(
          child:
              OutlinedButton.icon(
            onPressed:
                keep,
            icon:
                const Icon(
              Icons.check_circle_outline,
            ),
            label:
                const Text(
              "Keep",
            ),
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child:
              FilledButton.icon(
            onPressed:
                remove,
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  Colors.redAccent,
              foregroundColor:
                  Colors.white,
            ),
            icon:
                const Icon(
              Icons.delete_outline,
            ),
            label:
                const Text(
              "Remove",
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCommunityCard(
    CommunityModerationCase item,
  ) {
    final key =
        "community:"
        "${item.reportId}";

    final busy =
        _workingKey ==
            key;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
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
                const Expanded(
                  child:
                      Text(
                    "Community update",
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

                Chip(
                  label:
                      Text(
                    "${item.flagCount} "
                    "${item.flagCount == 1 ? 'report' : 'reports'}",
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              "Venue ID: "
              "${_displayValue(item.venueId)}",
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  500
                ],
                fontSize:
                    12,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            _ModerationValueRow(
              label:
                  "Vibe",
              value:
                  _displayValue(
                item.yiyoStatus,
              ),
            ),

            _ModerationValueRow(
              label:
                  "Crowd",
              value:
                  _displayValue(
                item.crowdLevel,
              ),
            ),

            _ModerationValueRow(
              label:
                  "Safety",
              value:
                  _displayValue(
                item.safetyLevel,
              ),
            ),

            if (item.musicType
                .isNotEmpty)
              _ModerationValueRow(
                label:
                    "Music",
                value:
                    item.musicType,
              ),

            if (item.queueLength
                .isNotEmpty)
              _ModerationValueRow(
                label:
                    "Queue",
                value:
                    item.queueLength,
              ),

            if (item.parkingAvailability
                    .isNotEmpty ||
                item.parkingSafety
                    .isNotEmpty)
              _ModerationValueRow(
                label:
                    "Parking",
                value: [
                  item.parkingAvailability,
                  item.parkingSafety,
                ]
                    .where(
                      (value) =>
                          value.isNotEmpty,
                    )
                    .join(
                      " · ",
                    ),
              ),

            if (item.parkingNote
                .isNotEmpty) ...[
              const SizedBox(
                height: 10,
              ),

              Text(
                item.parkingNote,
              ),
            ],

            if (item.comment
                .isNotEmpty) ...[
              const SizedBox(
                height: 10,
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
                      Colors.white
                          .withValues(
                    alpha:
                        0.05,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    Text(
                  item.comment,
                ),
              ),
            ],

            const SizedBox(
              height: 16,
            ),

            const Text(
              "Why users reported it",
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            _buildReasonChips(
              item.reasons,
            ),

            const SizedBox(
              height: 12,
            ),

            _buildDetails(
              item.details,
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              "Latest report: "
              "${_formatDate(item.latestFlaggedAtUnix)}",
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  500
                ],
                fontSize:
                    12,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            _buildActions(
              busy:
                  busy,

              keep: () =>
                  _resolveCommunity(
                item,
                "keep",
              ),

              remove: () =>
                  _resolveCommunity(
                item,
                "remove",
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEventCard(
    EventModerationCase item,
  ) {
    final key =
        "event:"
        "${item.eventId}";

    final busy =
        _workingKey ==
            key;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
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
                Expanded(
                  child:
                      Text(
                    item.title.isEmpty
                        ? "Event"
                        : item.title,
                    style:
                        const TextStyle(
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

                Chip(
                  label:
                      Text(
                    "${item.flagCount} "
                    "${item.flagCount == 1 ? 'report' : 'reports'}",
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              item.venueName.isEmpty
                  ? "Venue not available"
                  : item.venueName,
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  400
                ],
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            if (item.startsAtUnix >
                0) ...[
              const SizedBox(
                height: 4,
              ),

              Text(
                "Starts: "
                "${_formatDate(item.startsAtUnix)}",
                style:
                    TextStyle(
                  color:
                      Colors.grey[
                    500
                  ],
                  fontSize:
                      12,
                ),
              ),
            ],

            if (item.description
                .isNotEmpty) ...[
              const SizedBox(
                height: 14,
              ),

              Text(
                item.description,
              ),
            ],

            const SizedBox(
              height: 16,
            ),

            const Text(
              "Why users reported it",
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            _buildReasonChips(
              item.reasons,
            ),

            const SizedBox(
              height: 12,
            ),

            _buildDetails(
              item.details,
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              "Latest report: "
              "${_formatDate(item.latestFlaggedAtUnix)}",
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  500
                ],
                fontSize:
                    12,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            _buildActions(
              busy:
                  busy,

              keep: () =>
                  _resolveEvent(
                item,
                "keep",
              ),

              remove: () =>
                  _resolveEvent(
                item,
                "remove",
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _emptyState(
    String message,
  ) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.all(
        24,
      ),
      children: [
        const SizedBox(
          height: 120,
        ),

        Icon(
          Icons.verified_user_outlined,
          size: 48,
          color:
              Colors.grey[
            600
          ],
        ),

        const SizedBox(
          height: 16,
        ),

        Text(
          message,
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            color:
                Colors.grey[
              500
            ],
          ),
        ),
      ],
    );
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    final queue =
        _queue;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            const Color(
          0xFF0B0B0C,
        ),
        appBar:
            AppBar(
          backgroundColor:
              const Color(
            0xFF0B0B0C,
          ),
          surfaceTintColor:
              Colors.transparent,
          title:
              const Text(
            "Moderation",
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip:
                  "Refresh",
              onPressed:
                  _isLoading
                      ? null
                      : _refresh,
              icon:
                  const Icon(
                Icons.refresh,
              ),
            ),
          ],
          bottom:
              TabBar(
            tabs: [
              Tab(
                text:
                    "Community "
                    "(${queue?.communityCount ?? 0})",
              ),
              Tab(
                text:
                    "Events "
                    "(${queue?.eventCount ?? 0})",
              ),
            ],
          ),
        ),
        body:
            _buildBody(),
      ),
    );
  }


  Widget _buildBody() {
    if (_isLoading &&
        _queue == null) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null &&
        _queue == null) {
      return RefreshIndicator(
        onRefresh:
            _refresh,
        child:
            ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.all(
            24,
          ),
          children: [
            const SizedBox(
              height: 100,
            ),

            const Icon(
              Icons.error_outline,
              size: 48,
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              _error!,
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 18,
            ),

            FilledButton.icon(
              onPressed:
                  _refresh,
              icon:
                  const Icon(
                Icons.refresh,
              ),
              label:
                  const Text(
                "Try again",
              ),
            ),
          ],
        ),
      );
    }

    final queue =
        _queue ??
        const ModerationQueue(
          community: [],
          events: [],
          communityCount: 0,
          eventCount: 0,
          totalCount: 0,
        );

    return TabBarView(
      children: [
        RefreshIndicator(
          onRefresh:
              _refresh,
          child:
              queue.community.isEmpty
                  ? _emptyState(
                      "No community reports "
                      "need review.",
                    )
                  : ListView.builder(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      itemCount:
                          queue.community.length,
                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        return _buildCommunityCard(
                          queue.community[
                            index
                          ],
                        );
                      },
                    ),
        ),

        RefreshIndicator(
          onRefresh:
              _refresh,
          child:
              queue.events.isEmpty
                  ? _emptyState(
                      "No event reports "
                      "need review.",
                    )
                  : ListView.builder(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      itemCount:
                          queue.events.length,
                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        return _buildEventCard(
                          queue.events[
                            index
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }
}


class _ModerationValueRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _ModerationValueRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child:
                Text(
              label,
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  500
                ],
                fontSize:
                    13,
              ),
            ),
          ),

          Expanded(
            child:
                Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}


class _ModerationDecisionDialog
    extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;

  final bool destructive;

  const _ModerationDecisionDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.destructive,
  });

  @override
  State<_ModerationDecisionDialog>
      createState() =>
          _ModerationDecisionDialogState();
}


class _ModerationDecisionDialogState
    extends State<
        _ModerationDecisionDialog> {
  final TextEditingController
      _noteController =
      TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          Text(
        widget.title,
      ),
      content:
          SingleChildScrollView(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
            ),

            const SizedBox(
              height: 16,
            ),

            TextField(
              controller:
                  _noteController,
              maxLines: 3,
              maxLength: 1000,
              decoration:
                  const InputDecoration(
                labelText:
                    "Moderator note (optional)",
                hintText:
                    "Why did you make this decision?",
                border:
                    OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(
            context,
          ).pop(),
          child:
              const Text(
            "Cancel",
          ),
        ),

        FilledButton(
          style:
              widget.destructive
                  ? FilledButton.styleFrom(
                      backgroundColor:
                          Colors.redAccent,
                      foregroundColor:
                          Colors.white,
                    )
                  : null,
          onPressed: () =>
              Navigator.of(
            context,
          ).pop(
            _noteController
                .text
                .trim(),
          ),
          child:
              Text(
            widget.actionLabel,
          ),
        ),
      ],
    );
  }
}