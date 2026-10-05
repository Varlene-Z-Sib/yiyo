import 'package:flutter/material.dart';

import '../models/yiyo_event.dart';
import '../services/api_service.dart';
import 'event_details_screen.dart';


class MyEventsScreen
    extends StatefulWidget {
  const MyEventsScreen({
    super.key,
  });

  @override
  State<MyEventsScreen>
      createState() =>
          _MyEventsScreenState();
}


class _MyEventsScreenState
    extends State<MyEventsScreen> {
  bool _isLoading = true;

  String? _error;

  List<YiyoEvent> _events = [];

  String? _cancellingEventId;


  @override
  void initState() {
    super.initState();

    _loadEvents();
  }


  Future<void> _loadEvents() async {
    try {
      final events =
          await ApiService
              .getMyEvents(
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


  Future<void> _refresh()
      async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadEvents();
  }


  void _openEvent(
    YiyoEvent event,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EventDetailsScreen(
          event: event,
        ),
      ),
    );
  }


  Future<void> _cancelEvent(
    YiyoEvent event,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context:
          context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            "Cancel event?",
          ),
          content:
              Text(
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
              child:
                  const Text(
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
              child:
                  const Text(
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
          await ApiService
              .cancelEvent(
        event.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events =
            _events.map(
          (item) {
            if (item.id ==
                updated.id) {
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
          content:
              Text(
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
          content:
              Text(
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
          content:
              Text(
            "Couldn't cancel event.",
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
        return Theme.of(context)
            .colorScheme
            .error;

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


  bool _canCancel(
    YiyoEvent event,
  ) {
    return event.status ==
            "published" ||
        event.status ==
            "pending";
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          "My Events",
        ),
      ),
      body:
          _buildBody(),
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
                size:
                    44,
              ),
              const SizedBox(
                height:
                    12,
              ),
              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height:
                    14,
              ),
              FilledButton(
                onPressed:
                    _refresh,
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

    if (_events.isEmpty) {
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
              height:
                  100,
            ),
            Icon(
              Icons
                  .event_note_outlined,
              size:
                  52,
              color:
                  Colors.grey[500],
            ),
            const SizedBox(
              height:
                  16,
            ),
            const Text(
              "No events yet",
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              "Events you create will "
              "appear here.",
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
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
      child:
          ListView(
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
          Text(
            "Manage your events",
            style:
                Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
          ),

          const SizedBox(
            height:
                4,
          ),

          Text(
            "Track what is live, "
            "waiting for approval, "
            "or no longer active.",
            style:
                TextStyle(
              color:
                  Colors.grey[600],
            ),
          ),

          const SizedBox(
            height:
                24,
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
        bottom:
            26,
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontSize:
                  19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
                10,
          ),

          ...events.map(
            (event) =>
                Padding(
              padding:
                  const EdgeInsets.only(
                bottom:
                    10,
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

    final statusColor =
        _statusColor(
      context,
      event.status,
    );

    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text(
                    event.title,
                    style:
                        const TextStyle(
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      8,
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        8,
                    vertical:
                        4,
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
                  child:
                      Text(
                    _statusLabel(
                      event.status,
                    ),
                    style:
                        TextStyle(
                      color:
                          statusColor,
                      fontSize:
                          10,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
                  7,
            ),

            Text(
              event.venueName,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height:
                  4,
            ),

            Text(
              _dateLabel(
                event,
              ),
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
              ),
            ),

            if (event.status ==
                "pending") ...[
              const SizedBox(
                height:
                    9,
              ),
              Text(
                "Waiting for venue "
                "or admin approval.",
                style:
                    TextStyle(
                  color:
                      Colors.orange[
                    300
                  ],
                  fontSize:
                      13,
                ),
              ),
            ],

            if (event.status ==
                "published") ...[
              const SizedBox(
                height:
                    10,
              ),
              Row(
                children: [
                  const Icon(
                    Icons
                        .local_fire_department_outlined,
                    size:
                        17,
                  ),
                  const SizedBox(
                    width:
                        4,
                  ),
                  Text(
                    "${event.hypeCount}",
                  ),
                  const SizedBox(
                    width:
                        16,
                  ),
                  const Icon(
                    Icons
                        .check_circle_outline,
                    size:
                        17,
                  ),
                  const SizedBox(
                    width:
                        4,
                  ),
                  Text(
                    "${event.goingCount}",
                  ),
                ],
              ),
            ],

            const SizedBox(
              height:
                  12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton(
                    onPressed:
                        () =>
                            _openEvent(
                      event,
                    ),
                    child:
                        const Text(
                      "View",
                    ),
                  ),
                ),

                if (_canCancel(
                  event,
                )) ...[
                  const SizedBox(
                    width:
                        8,
                  ),
                  Expanded(
                    child:
                        OutlinedButton(
                      onPressed:
                          cancelling
                              ? null
                              : () =>
                                  _cancelEvent(
                                event,
                              ),
                      child:
                          cancelling
                              ? const SizedBox(
                                  width:
                                      18,
                                  height:
                                      18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Text(
                                  "Cancel",
                                ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}