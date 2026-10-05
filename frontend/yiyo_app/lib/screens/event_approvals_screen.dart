import 'package:flutter/material.dart';

import '../models/yiyo_event.dart';
import '../services/api_service.dart';
import 'event_details_screen.dart';


class EventApprovalsScreen
    extends StatefulWidget {
  const EventApprovalsScreen({
    super.key,
  });

  @override
  State<EventApprovalsScreen>
      createState() =>
          _EventApprovalsScreenState();
}


class _EventApprovalsScreenState
    extends State<EventApprovalsScreen> {
  bool _isLoading = true;

  String? _error;

  List<YiyoEvent> _events = [];

  String? _workingEventId;


  @override
  void initState() {
    super.initState();

    _load();
  }


  Future<void> _load() async {
    try {
      final events =
          await ApiService
              .getEventApprovals();

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
            "Couldn't load "
            "event approvals.";
        _isLoading = false;
      });
    }
  }


  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _load();
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


  Future<void> _approve(
    YiyoEvent event,
  ) async {
    if (_workingEventId != null) {
      return;
    }

    setState(() {
      _workingEventId =
          event.id;
    });

    try {
      await ApiService.approveEvent(
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

        _workingEventId =
            null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            "Event approved and published.",
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingEventId =
            null;
      });

      _showMessage(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingEventId =
            null;
      });

      _showMessage(
        "Couldn't approve event.",
      );
    }
  }


  Future<void> _reject(
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
            "Reject event?",
          ),
          content:
              Text(
            "\"${event.title}\" "
            "will not be published.",
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(
                dialogContext,
              ).pop(
                false,
              ),
              child:
                  const Text(
                "Back",
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(
                dialogContext,
              ).pop(
                true,
              ),
              child:
                  const Text(
                "Reject",
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
      _workingEventId =
          event.id;
    });

    try {
      await ApiService.rejectEvent(
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

        _workingEventId =
            null;
      });

      _showMessage(
        "Event rejected.",
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingEventId =
            null;
      });

      _showMessage(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingEventId =
            null;
      });

      _showMessage(
        "Couldn't reject event.",
      );
    }
  }


  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }


  String _dateLabel(
    YiyoEvent event,
  ) {
    final value =
        event.startsAt.toLocal();

    final hour =
        value.hour
            .toString()
            .padLeft(
              2,
              "0",
            );

    final minute =
        value.minute
            .toString()
            .padLeft(
              2,
              "0",
            );

    return "${value.day}/"
        "${value.month}/"
        "${value.year} · "
        "$hour:$minute";
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
          "Event Approvals",
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
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 130,
            ),
            Icon(
              Icons
                  .task_alt_outlined,
              size: 52,
            ),
            SizedBox(
              height: 14,
            ),
            Text(
              "You're all caught up",
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(
              height: 6,
            ),
            Text(
              "No events are waiting "
              "for approval.",
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _refresh,
      child: ListView.builder(
        padding:
            const EdgeInsets.all(
          16,
        ),
        itemCount:
            _events.length,
        itemBuilder:
            (
          context,
          index,
        ) {
          final event =
              _events[index];

          final working =
              _workingEventId ==
                  event.id;

          return Card(
            margin:
                const EdgeInsets.only(
              bottom: 12,
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
                  Text(
                    event.title,
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
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
                    height: 4,
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

                  if (event
                      .description
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      event.description,
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(
                    height: 14,
                  ),

                  OutlinedButton(
                    onPressed:
                        () =>
                            _openEvent(
                      event,
                    ),
                    child:
                        const Text(
                      "View Details",
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            FilledButton.icon(
                          onPressed:
                              working
                                  ? null
                                  : () =>
                                      _approve(
                                    event,
                                  ),
                          icon:
                              const Icon(
                            Icons
                                .check,
                          ),
                          label:
                              const Text(
                            "Approve",
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              working
                                  ? null
                                  : () =>
                                      _reject(
                                    event,
                                  ),
                          icon:
                              const Icon(
                            Icons.close,
                          ),
                          label:
                              const Text(
                            "Reject",
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (working) ...[
                    const SizedBox(
                      height: 12,
                    ),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}