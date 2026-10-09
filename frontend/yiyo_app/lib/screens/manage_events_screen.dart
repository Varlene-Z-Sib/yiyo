import 'package:flutter/material.dart';

import '../models/yiyo_event.dart';
import '../services/api_service.dart';
import 'edit_event_screen.dart';


class ManageEventsScreen
    extends StatefulWidget {
  const ManageEventsScreen({
    super.key,
  });

  @override
  State<ManageEventsScreen>
      createState() =>
          _ManageEventsScreenState();
}


class _ManageEventsScreenState
    extends State<ManageEventsScreen> {
  bool _isLoading = true;

  String? _error;

  String? _workingEventId;

  List<YiyoEvent> _events = [];


  @override
  void initState() {
    super.initState();

    _load();
  }


  Future<void> _load() async {
    try {
      final events =
          await ApiService
              .getManageableEvents();

      if (!mounted) {
        return;
      }

      setState(() {
        _events =
            events;

        _error =
            null;

        _isLoading =
            false;
      });
    } on ApiException catch (
        error) {
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
            "Couldn't load managed events.";

        _isLoading =
            false;
      });
    }
  }


  Future<void> _refresh() async {
    setState(() {
      _isLoading =
          true;

      _error =
          null;
    });

    await _load();
  }


  Future<void> _edit(
    YiyoEvent event,
  ) async {
    final updated =
        await Navigator.of(
      context,
    ).push<YiyoEvent>(
      MaterialPageRoute(
        builder: (_) =>
            EditEventScreen(
          event:
              event,
        ),
      ),
    );

    if (
        updated == null ||
        !mounted) {
      return;
    }

    await _refresh();
  }


  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result =
        await showDialog<bool>(
      context:
          context,

      builder:
          (context) {
        return AlertDialog(
          title:
              Text(
            title,
          ),

          content:
              Text(
            message,
          ),

          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(
                context,
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
                context,
              ).pop(
                true,
              ),

              child:
                  Text(
                action,
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }


  Future<void> _cancel(
    YiyoEvent event,
  ) async {
    final confirmed =
        await _confirm(
      title:
          "Cancel event?",

      message:
          "\"${event.title}\" will stop "
          "appearing as an active event.",

      action:
          "Cancel event",
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _workingEventId =
          event.id;
    });

    try {
      await ApiService
          .cancelEvent(
        event.id,
      );

      if (!mounted) {
        return;
      }

      await _refresh();
    } on ApiException catch (
        error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingEventId =
            null;
      });

      _message(
        error.message,
      );
    }
  }


  Future<void> _delete(
    YiyoEvent event,
  ) async {
    final confirmed =
        await _confirm(
      title:
          "Permanently delete?",

      message:
          "\"${event.title}\" will be "
          "permanently removed. "
          "Published events should normally "
          "be cancelled instead.",

      action:
          "Delete",
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _workingEventId =
          event.id;
    });

    try {
      await ApiService
          .deleteEvent(
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

      _message(
        "Event deleted.",
      );
    } on ApiException catch (
        error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workingEventId =
            null;
      });

      _message(
        error.message,
      );
    }
  }


  void _message(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }


  Color _statusColor(
    String status,
  ) {
    switch (
        status.toLowerCase()) {
      case "published":
        return Colors.green;

      case "pending":
        return Colors.orange;

      case "cancelled":
        return Colors.grey;

      case "rejected":
        return Colors.red;

      default:
        return Colors.blueGrey;
    }
  }


  String _statusLabel(
    String status,
  ) {
    switch (
        status.toLowerCase()) {
      case "published":
        return "Published";

      case "pending":
        return "Pending";

      case "cancelled":
        return "Cancelled";

      case "rejected":
        return "Rejected";

      default:
        return status;
    }
  }


  String _date(
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


  bool _canCancel(
    YiyoEvent event,
  ) {
    final status =
        event.status
            .toLowerCase();

    return status ==
            "published" ||
        status ==
            "pending";
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
          "Manage events",
          style:
              TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
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
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height:
                    16,
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

          children: const [
            SizedBox(
              height:
                  130,
            ),

            Icon(
              Icons
                  .event_available_outlined,
              size:
                  50,
            ),

            SizedBox(
              height:
                  12,
            ),

            Center(
              child:
                  Text(
                "No events to manage.",
              ),
            ),
          ],
        ),
      );
    }

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
          10,
          16,
          32,
        ),

        children: [
          const Text(
            "All manageable events",
            style:
                TextStyle(
              fontSize:
                  24,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                5,
          ),

          Text(
            "${_events.length} events",
            style:
                TextStyle(
              color:
                  Colors.grey[
                500
              ],
            ),
          ),

          const SizedBox(
            height:
                18,
          ),

          ..._events.map(
            _buildCard,
          ),
        ],
      ),
    );
  }


  Widget _buildCard(
    YiyoEvent event,
  ) {
    final working =
        _workingEventId ==
        event.id;

    final statusColor =
        _statusColor(
      event.status,
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            12,
      ),

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

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    Text(
                  event.title,
                  style:
                      const TextStyle(
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      9,
                  vertical:
                      5,
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
                    fontWeight:
                        FontWeight.w800,
                    fontSize:
                        11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            event.venueName,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
                4,
          ),

          Text(
            _date(
              event,
            ),
            style:
                TextStyle(
              color:
                  Colors.grey[
                500
              ],
            ),
          ),

          const SizedBox(
            height:
                16,
          ),

          if (working)
            const Center(
              child:
                  Padding(
                padding:
                    EdgeInsets.all(
                  8,
                ),
                child:
                    CircularProgressIndicator(),
              ),
            )
          else
            Wrap(
              spacing:
                  8,
              runSpacing:
                  8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _edit(
                    event,
                  ),

                  icon:
                      const Icon(
                    Icons.edit_outlined,
                  ),

                  label:
                      const Text(
                    "Edit",
                  ),
                ),

                if (_canCancel(
                  event,
                ))
                  OutlinedButton.icon(
                    onPressed: () =>
                        _cancel(
                      event,
                    ),

                    icon:
                        const Icon(
                      Icons
                          .event_busy_outlined,
                    ),

                    label:
                        const Text(
                      "Cancel",
                    ),
                  ),

                OutlinedButton.icon(
                  onPressed: () =>
                      _delete(
                    event,
                  ),

                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        Colors.redAccent,
                  ),

                  icon:
                      const Icon(
                    Icons
                        .delete_outline,
                  ),

                  label:
                      const Text(
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