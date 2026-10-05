import 'package:flutter/material.dart';

import '../models/yiyo_event.dart';
import '../services/api_service.dart';
import 'event_details_screen.dart';
import '../models/app_permissions.dart';
import 'create_event_screen.dart';
import 'my_events_screen.dart';
import 'event_approvals_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
  });

  @override
  State<EventsScreen> createState() =>
      _EventsScreenState();
}


class _EventsScreenState
    extends State<EventsScreen> {
  bool _isLoading = true;

  String? _error;

  List<YiyoEvent> _events = [];

  AppPermissions? _permissions;

  @override
  void initState() {
    super.initState();

    _loadEvents();
    _loadPermissions();
  }

 Future<void> _loadPermissions() async {
  try {
    final permissions =
        await ApiService
            .getMyPermissions();

    if (!mounted) {
      return;
    }

    setState(() {
      _permissions =
          permissions;
    });
  } catch (_) {
    // Event discovery should remain available
    // even if permission loading fails.
  }
}


Future<void> _openCreateEvent()
    async {
  final event =
      await Navigator.of(
    context,
  ).push<YiyoEvent>(
    MaterialPageRoute(
      builder: (_) =>
          const CreateEventScreen(),
    ),
  );

  if (
      event == null ||
      !mounted) {
    return;
  }

  if (event.isPublished) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content:
            Text(
          "Event published.",
        ),
      ),
    );

    await _refresh();
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content:
            Text(
          "Event submitted for approval.",
        ),
      ),
    );
  }
}

Future<void> _openMyEvents()
    async {
  await Navigator.of(
    context,
  ).push(
    MaterialPageRoute(
      builder: (_) =>
          const MyEventsScreen(),
    ),
  );

  if (!mounted) {
    return;
  }

  await _refresh();
}

  Future<void> _loadEvents() async {
    try {
      final events =
          await ApiService.getEvents(
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
            "Couldn't load events.";
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


  DateTime _effectiveEnd(
    YiyoEvent event,
  ) {
    if (event.endsAt != null) {
      return event.endsAt!
          .toLocal();
    }

    return event.startsAt
        .toLocal()
        .add(
          const Duration(
            hours: 8,
          ),
        );
  }


  bool _isHappeningNow(
    YiyoEvent event,
    DateTime now,
  ) {
    final start =
        event.startsAt.toLocal();

    final end =
        _effectiveEnd(
      event,
    );

    return !now.isBefore(
          start,
        ) &&
        now.isBefore(
          end,
        );
  }


  bool _isSameDay(
    DateTime first,
    DateTime second,
  ) {
    return first.year ==
            second.year &&
        first.month ==
            second.month &&
        first.day ==
            second.day;
  }


  DateTime _weekendStart(
    DateTime now,
  ) {
    final dayStart =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (now.weekday >=
        DateTime.friday) {
      return dayStart.subtract(
        Duration(
          days:
              now.weekday -
              DateTime.friday,
        ),
      );
    }

    return dayStart.add(
      Duration(
        days:
            DateTime.friday -
            now.weekday,
      ),
    );
  }


  bool _isThisWeekend(
    YiyoEvent event,
    DateTime now,
  ) {
    final start =
        event.startsAt.toLocal();

    final weekendStart =
        _weekendStart(
      now,
    );

    final weekendEnd =
        weekendStart.add(
      const Duration(
        days: 3,
      ),
    );

    return !start.isBefore(
          weekendStart,
        ) &&
        start.isBefore(
          weekendEnd,
        );
  }


  List<YiyoEvent>
      _happeningNow() {
    final now =
        DateTime.now();

    return _events
        .where(
          (event) =>
              _isHappeningNow(
            event,
            now,
          ),
        )
        .toList();
  }


  List<YiyoEvent> _tonight() {
    final now =
        DateTime.now();

    return _events
        .where(
          (event) {
            final start =
                event.startsAt
                    .toLocal();

            return !_isHappeningNow(
                  event,
                  now,
                ) &&
                start.isAfter(
                  now,
                ) &&
                _isSameDay(
                  start,
                  now,
                );
          },
        )
        .toList();
  }


  List<YiyoEvent>
      _thisWeekend() {
    final now =
        DateTime.now();

    return _events
        .where(
          (event) {
            final start =
                event.startsAt
                    .toLocal();

            return !_isHappeningNow(
                  event,
                  now,
                ) &&
                !_isSameDay(
                  start,
                  now,
                ) &&
                _isThisWeekend(
                  event,
                  now,
                );
          },
        )
        .toList();
  }


  List<YiyoEvent> _later() {
    final now =
        DateTime.now();

    return _events
        .where(
          (event) {
            final start =
                event.startsAt
                    .toLocal();

            return !_isHappeningNow(
                  event,
                  now,
                ) &&
                !(
                  start.isAfter(
                        now,
                      ) &&
                      _isSameDay(
                        start,
                        now,
                      )
                ) &&
                !_isThisWeekend(
                  event,
                  now,
                );
          },
        )
        .toList();
  }


  String _eventTime(
    YiyoEvent event,
  ) {
    final local =
        event.startsAt.toLocal();

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

    return "$hour:$minute";
  }


  String _eventDate(
    YiyoEvent event,
  ) {
    final local =
        event.startsAt.toLocal();

    const weekdays = [
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun",
    ];

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

    return "${weekdays[local.weekday - 1]}, "
        "${local.day} "
        "${months[local.month - 1]}";
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

Future<void> _openApprovals()
    async {
  await Navigator.of(
    context,
  ).push(
    MaterialPageRoute(
      builder: (_) =>
          const EventApprovalsScreen(),
    ),
  );

  if (!mounted) {
    return;
  }

  await _refresh();
}

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          "Events",
        ),

        actions: [
          if (
              _permissions?.manageVenues ==
                  true ||
              _permissions?.superAdmin ==
                  true)
            IconButton(
              tooltip:
                  "Event approvals",
              onPressed:
                  _openApprovals,
              icon:
                  const Icon(
                Icons.fact_check_outlined,
              ),
            ),

          if (_permissions
                  ?.createEvents ==
              true)
            IconButton(
              tooltip:
                  "My events",
              onPressed:
                  _openMyEvents,
              icon:
                  const Icon(
                Icons.event_note_outlined,
              ),
            ),

          if (_permissions
                  ?.createEvents ==
              true)
            IconButton(
              tooltip:
                  "Create event",
              onPressed:
                  _openCreateEvent,
              icon:
                  const Icon(
                Icons.add_circle_outline,
              ),
            ),
        ],
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
                size: 42,
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
                height: 12,
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
                  .celebration_outlined,
              size: 52,
              color:
                  Colors.grey[500],
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              "No upcoming events yet",
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              "Events from YIYO venues "
              "and organisers will appear "
              "here.",
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

    final happeningNow =
        _happeningNow();

    final tonight =
        _tonight();

    final weekend =
        _thisWeekend();

    final later =
        _later();

    return RefreshIndicator(
      onRefresh:
          _refresh,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          32,
        ),
        children: [
          Text(
            "What's happening?",
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
            height: 4,
          ),

          Text(
            "Discover events around YIYO.",
            style:
                TextStyle(
              color:
                  Colors.grey[600],
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          if (happeningNow
              .isNotEmpty)
            _EventSection(
              title:
                  "Happening now",
              subtitle:
                  "Live right now",
              events:
                  happeningNow,
              eventTime:
                  _eventTime,
              eventDate:
                  _eventDate,
              onOpen:
                  _openEvent,
              live:
                  true,
            ),

          if (tonight
              .isNotEmpty)
            _EventSection(
              title:
                  "Tonight",
              subtitle:
                  "Coming up today",
              events:
                  tonight,
              eventTime:
                  _eventTime,
              eventDate:
                  _eventDate,
              onOpen:
                  _openEvent,
            ),

          if (weekend
              .isNotEmpty)
            _EventSection(
              title:
                  "This weekend",
              subtitle:
                  "Plan the weekend",
              events:
                  weekend,
              eventTime:
                  _eventTime,
              eventDate:
                  _eventDate,
              onOpen:
                  _openEvent,
            ),

          if (later
              .isNotEmpty)
            _EventSection(
              title:
                  "Coming up",
              subtitle:
                  "More events ahead",
              events:
                  later,
              eventTime:
                  _eventTime,
              eventDate:
                  _eventDate,
              onOpen:
                  _openEvent,
            ),
        ],
      ),
    );
  }
}


class _EventSection
    extends StatelessWidget {
  final String title;
  final String subtitle;

  final List<YiyoEvent>
      events;

  final String Function(
    YiyoEvent event,
  ) eventTime;

  final String Function(
    YiyoEvent event,
  ) eventDate;

  final ValueChanged<YiyoEvent>
      onOpen;

  final bool live;

  const _EventSection({
    required this.title,
    required this.subtitle,
    required this.events,
    required this.eventTime,
    required this.eventDate,
    required this.onOpen,
    this.live = false,
  });


  @override
  Widget build(
    BuildContext context,
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
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 21,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            subtitle,
            style:
                TextStyle(
              color:
                  Colors.grey[600],
              fontSize: 13,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          ...events.map(
            (event) =>
                Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child:
                  _EventCard(
                event:
                    event,
                date:
                    eventDate(
                  event,
                ),
                time:
                    eventTime(
                  event,
                ),
                live:
                    live,
                onTap: () =>
                    onOpen(
                  event,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _EventCard
    extends StatelessWidget {
  final YiyoEvent event;

  final String date;
  final String time;

  final bool live;

  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.date,
    required this.time,
    required this.onTap,
    this.live = false,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap:
            onTap,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _EventPoster(
              event:
                  event,
            ),

            Padding(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (live) ...[
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red
                                .withValues(
                          alpha: 0.12,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                      ),
                      child:
                          const Text(
                        "LIVE NOW",
                        style:
                            TextStyle(
                          color:
                              Colors.red,
                          fontWeight:
                              FontWeight.bold,
                          fontSize:
                              11,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),
                  ],

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
                    height: 5,
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
                    height: 5,
                  ),

                  Text(
                    "$date · $time",
                    style:
                        TextStyle(
                      color:
                          Colors.grey[600],
                    ),
                  ),

                  if (event.tags
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          event.tags
                              .take(4)
                              .map(
                                (tag) =>
                                    Chip(
                                  visualDensity:
                                      VisualDensity.compact,
                                  label:
                                      Text(
                                    tag,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],

                  const SizedBox(
                    height: 12,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .local_fire_department_outlined,
                        size: 19,
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Text(
                        "${event.hypeCount} Hype",
                      ),

                      const SizedBox(
                        width: 18,
                      ),

                      const Icon(
                        Icons
                            .check_circle_outline,
                        size: 18,
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Text(
                        "${event.goingCount} Going",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _EventPoster
    extends StatelessWidget {
  final YiyoEvent event;

  const _EventPoster({
    required this.event,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    if (event.posterUrl != null) {
      return AspectRatio(
        aspectRatio:
            16 / 9,
        child: Image.network(
          event.posterUrl!,
          fit:
              BoxFit.cover,
          errorBuilder:
              (
            context,
            error,
            stackTrace,
          ) {
            return _fallback(
              context,
            );
          },
        ),
      );
    }

    return _fallback(
      context,
    );
  }


  Widget _fallback(
    BuildContext context,
  ) {
    return AspectRatio(
      aspectRatio:
          16 / 9,
      child: Container(
        color:
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
        alignment:
            Alignment.center,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .celebration_outlined,
              size: 44,
            ),

            const SizedBox(
              height: 8,
            ),

            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 16,
              ),
              child: Text(
                event.venueName,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
