import 'package:flutter/material.dart';

import '../models/yiyo_event.dart';
import '../services/api_service.dart';
import 'edit_event_screen.dart';
import 'event_details_screen.dart';


class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({
    super.key,
  });

  @override
  State<MyEventsScreen> createState() =>
      _MyEventsScreenState();
}


class _MyEventsScreenState
    extends State<MyEventsScreen> {
  bool _isLoading = true;

  String? _error;

  List<YiyoEvent> _events = [];

  String? _cancellingEventId;

  String? _deletingEventId;


  @override
  void initState() {
    super.initState();

    _loadEvents();
  }


  Future<void> _loadEvents() async {
    try {
      final events =
          await ApiService.getMyEvents(
        limit: 50,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events = events;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "Couldn't load your events.";
        _isLoading = false;
      });
    }
  }


  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadEvents();
  }


  Future<void> _openEvent(
    YiyoEvent event,
  ) async {
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) =>
            EventDetailsScreen(
          event: event,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadEvents();
  }


  Future<void> _editEvent(
    YiyoEvent event,
  ) async {
    final updated =
        await Navigator.of(
      context,
    ).push<YiyoEvent>(
      MaterialPageRoute(
        builder: (_) =>
            EditEventScreen(
          event: event,
        ),
      ),
    );

    if (
        updated == null ||
        !mounted) {
      return;
    }

    setState(() {
      _events = _events.map(
        (item) {
          if (item.id == updated.id) {
            return updated;
          }

          return item;
        },
      ).toList();
    });

    if (
        event.isPublished &&
        !updated.isPublished) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Changes submitted for approval.",
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Event updated.",
          ),
        ),
      );
    }
  }


  Future<void> _cancelEvent(
    YiyoEvent event,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            "Cancel event?",
          ),
          content: Text(
            "\"${event.title}\" "
            "will stop appearing "
            "in public event discovery.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },
              child: const Text(
                "Keep Event",
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },
              child: const Text(
                "Cancel Event",
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _cancellingEventId =
          event.id;
    });

    try {
      final updated =
          await ApiService.cancelEvent(
        event.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events = _events.map(
          (item) {
            if (item.id == updated.id) {
              return updated;
            }

            return item;
          },
        ).toList();

        _cancellingEventId =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Event cancelled.",
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cancellingEventId =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cancellingEventId =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't cancel event.",
          ),
        ),
      );
    }
  }


  Future<void> _deleteEvent(
    YiyoEvent event,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            "Delete event?",
          ),
          content: Text(
            "\"${event.title}\" will be "
            "permanently removed.\n\n"
            "This cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },
              child: const Text(
                "Keep Event",
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },
              child: const Text(
                "Delete",
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingEventId =
          event.id;
    });

    try {
      await ApiService.deleteEvent(
        event.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events.removeWhere(
          (item) =>
              item.id ==
              event.id,
        );

        _deletingEventId =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Event deleted.",
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deletingEventId =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deletingEventId =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't delete event.",
          ),
        ),
      );
    }
  }


  List<YiyoEvent> _eventsWithStatus(
    String status,
  ) {
    return _events
        .where(
          (event) =>
              event.status ==
              status,
        )
        .toList();
  }


  String _dateLabel(
    YiyoEvent event,
  ) {
    final local =
        event.startsAt.toLocal();

    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    final hour =
        local.hour
            .toString()
            .padLeft(
              2,
              "0",
            );

    final minute =
        local.minute
            .toString()
            .padLeft(
              2,
              "0",
            );

    return "${local.day} "
        "${months[local.month - 1]} "
        "· $hour:$minute";
  }


  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    switch (status) {
      case "published":
        return Colors.green;

      case "pending":
        return Colors.orange;

      case "cancelled":
        return Colors.grey;

      case "rejected":
        return Theme.of(
          context,
        ).colorScheme.error;

      default:
        return Colors.grey;
    }
  }


  String _statusLabel(
    String status,
  ) {
    switch (status) {
      case "published":
        return "PUBLISHED";

      case "pending":
        return "PENDING";

      case "cancelled":
        return "CANCELLED";

      case "rejected":
        return "REJECTED";

      default:
        return status.toUpperCase();
    }
  }


  bool _canEdit(
    YiyoEvent event,
  ) {
    return event.status ==
            "published" ||
        event.status ==
            "pending";
  }


  bool _canCancel(
    YiyoEvent event,
  ) {
    return event.status ==
            "published" ||
        event.status ==
            "pending";
  }


  bool _canDelete(
    YiyoEvent event,
  ) {
    // Promoters should not hard-delete
    // published events. Those should be
    // cancelled instead.
    return !event.isPublished;
  }


  bool _isWorking(
    YiyoEvent event,
  ) {
    return _cancellingEventId ==
            event.id ||
        _deletingEventId ==
            event.id;
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFF0B0B0C,
      ),

      appBar: AppBar(
        backgroundColor:
            const Color(
          0xFF0B0B0C,
        ),

        surfaceTintColor:
            Colors.transparent,

        title: const Text(
          "My Events",
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),

      body: _buildBody(),
    );
  }


  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons
                    .event_busy_outlined,
                size: 44,
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 14,
              ),

              FilledButton(
                onPressed:
                    _refresh,

                child: const Text(
                  "Try again",
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            _refresh,

        child: ListView(
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

            Icon(
              Icons
                  .event_note_outlined,
              size: 52,
              color:
                  Colors.grey[
                500
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              "No events yet",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              "Events you create will "
              "appear here.",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey[
                  600
                ],
              ),
            ),
          ],
        ),
      );
    }

    final published =
        _eventsWithStatus(
      "published",
    );

    final pending =
        _eventsWithStatus(
      "pending",
    );

    final cancelled =
        _eventsWithStatus(
      "cancelled",
    );

    final rejected =
        _eventsWithStatus(
      "rejected",
    );

    return RefreshIndicator(
      onRefresh:
          _refresh,

      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32,
        ),

        children: [
          const Text(
            "Manage your events",
            style: TextStyle(
              fontSize: 26,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  -0.6,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            "Track what's live, waiting for "
            "approval, or no longer active.",
            style: TextStyle(
              color:
                  Colors.grey[
                500
              ],
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          if (published.isNotEmpty)
            _buildSection(
              "Published",
              published,
            ),

          if (pending.isNotEmpty)
            _buildSection(
              "Pending approval",
              pending,
            ),

          if (rejected.isNotEmpty)
            _buildSection(
              "Rejected",
              rejected,
            ),

          if (cancelled.isNotEmpty)
            _buildSection(
              "Cancelled",
              cancelled,
            ),
        ],
      ),
    );
  }


  Widget _buildSection(
    String title,
    List<YiyoEvent> events,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 26,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white
                          .withValues(
                    alpha:
                        0.07,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child: Text(
                  "${events.length}",
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          ...events.map(
            (event) =>
                Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),

              child:
                  _buildEventCard(
                event,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEventCard(
    YiyoEvent event,
  ) {
    final cancelling =
        _cancellingEventId ==
        event.id;

    final deleting =
        _deletingEventId ==
        event.id;

    final working =
        _isWorking(
      event,
    );

    final statusColor =
        _statusColor(
      context,
      event.status,
    );

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF151517,
        ),

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              Colors.white
                  .withValues(
            alpha:
                0.06,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Expanded(
                child: Text(
                  event.title,
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      statusColor
                          .withValues(
                    alpha:
                        0.14,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child: Text(
                  _statusLabel(
                    event.status,
                  ),
                  style:
                      TextStyle(
                    color:
                        statusColor,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          Row(
            children: [
              Icon(
                Icons
                    .location_on_outlined,
                size: 16,
                color:
                    Colors.grey[
                  500
                ],
              ),

              const SizedBox(
                width: 5,
              ),

              Expanded(
                child: Text(
                  event.venueName,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 5,
          ),

          Row(
            children: [
              Icon(
                Icons
                    .schedule_outlined,
                size: 16,
                color:
                    Colors.grey[
                  500
                ],
              ),

              const SizedBox(
                width: 5,
              ),

              Text(
                _dateLabel(
                  event,
                ),
                style: TextStyle(
                  color:
                      Colors.grey[
                    500
                  ],
                ),
              ),
            ],
          ),

          if (event.status ==
              "pending") ...[
            const SizedBox(
              height: 10,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                10,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.orange
                        .withValues(
                  alpha:
                      0.08,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child: Text(
                "Waiting for venue or "
                "admin approval.",
                style: TextStyle(
                  color:
                      Colors.orange[
                    300
                  ],
                  fontSize: 13,
                ),
              ),
            ),
          ],

          if (event.status ==
              "published") ...[
            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                const Icon(
                  Icons
                      .local_fire_department_outlined,
                  size: 17,
                ),

                const SizedBox(
                  width: 4,
                ),

                Text(
                  "${event.hypeCount}",
                ),

                const SizedBox(
                  width: 16,
                ),

                const Icon(
                  Icons
                      .check_circle_outline,
                  size: 17,
                ),

                const SizedBox(
                  width: 4,
                ),

                Text(
                  "${event.goingCount}",
                ),
              ],
            ),
          ],

          if (event.status ==
              "rejected") ...[
            const SizedBox(
              height: 10,
            ),

            Text(
              "This event was not approved.",
              style: TextStyle(
                color:
                    Colors.red[
                  300
                ],
                fontSize: 13,
              ),
            ),
          ],

          if (event.status ==
              "cancelled") ...[
            const SizedBox(
              height: 10,
            ),

            Text(
              "This event is no longer active.",
              style: TextStyle(
                color:
                    Colors.grey[
                  500
                ],
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(
            height: 16,
          ),

          if (working)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                14,
              ),
              alignment:
                  Alignment.center,
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Text(
                    deleting
                        ? "Deleting..."
                        : cancelling
                            ? "Cancelling..."
                            : "Updating...",
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,

              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _openEvent(
                    event,
                  ),

                  icon: const Icon(
                    Icons
                        .visibility_outlined,
                  ),

                  label: const Text(
                    "View",
                  ),
                ),

                if (_canEdit(
                  event,
                ))
                  OutlinedButton.icon(
                    onPressed: () =>
                        _editEvent(
                      event,
                    ),

                    icon: const Icon(
                      Icons
                          .edit_outlined,
                    ),

                    label: const Text(
                      "Edit",
                    ),
                  ),

                if (_canCancel(
                  event,
                ))
                  OutlinedButton.icon(
                    onPressed: () =>
                        _cancelEvent(
                      event,
                    ),

                    icon: const Icon(
                      Icons
                          .event_busy_outlined,
                    ),

                    label: const Text(
                      "Cancel",
                    ),
                  ),

                if (_canDelete(
                  event,
                ))
                  OutlinedButton.icon(
                    onPressed: () =>
                        _deleteEvent(
                      event,
                    ),

                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          Colors.redAccent,
                    ),

                    icon: const Icon(
                      Icons
                          .delete_outline,
                    ),

                    label: const Text(
                      "Delete",
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}