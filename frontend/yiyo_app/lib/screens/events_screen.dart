import 'package:flutter/material.dart';

import '../models/app_permissions.dart';
import '../models/yiyo_event.dart';
import '../services/api_service.dart';
import 'create_event_screen.dart';
import 'event_approvals_screen.dart';
import 'event_details_screen.dart';
import 'my_events_screen.dart';


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


  bool get _canCreateEvents =>
      _permissions?.createEvents == true;

  bool get _canManageApprovals =>
      _permissions?.manageVenues == true ||
      _permissions?.superAdmin == true;

  bool get _hasEventTools =>
      _canCreateEvents ||
      _canManageApprovals;


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
      // Event discovery remains available
      // if permission loading fails.
    }
  }


  Future<void> _loadEvents() async {
    try {
      final events =
          await ApiService.getEvents(
        limit: 50,
      );

      events.sort(
        (a, b) =>
            a.startsAt.compareTo(
          b.startsAt,
        ),
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
    await Future.wait([
      _loadEvents(),
      _loadPermissions(),
    ]);
  }


  Future<void> _openCreateEvent() async {
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


  Future<void> _openMyEvents() async {
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


  Future<void> _openApprovals() async {
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

    // Hype / Going may have changed
    // while the details screen was open.
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

    if (
        now.weekday >=
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


  List<YiyoEvent> _happeningNow() {
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


  List<YiyoEvent> _thisWeekend() {
    final now =
        DateTime.now();

    return _events
        .where(
          (event) {
            final start =
                event.startsAt
                    .toLocal();

            return _effectiveEnd(
                  event,
                ).isAfter(
                  now,
                ) &&
                !_isHappeningNow(
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

            return _effectiveEnd(
                  event,
                ).isAfter(
                  now,
                ) &&
                !_isHappeningNow(
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


  String _eventMonth(
    YiyoEvent event,
  ) {
    const months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC",
    ];

    final local =
        event.startsAt.toLocal();

    return months[
      local.month - 1
    ];
  }


  String _eventDay(
    YiyoEvent event,
  ) {
    return event.startsAt
        .toLocal()
        .day
        .toString();
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
          "Events",
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
    if (
        _isLoading &&
        _events.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          24,
        ),

        children: [
          const SizedBox(
            height: 130,
          ),

          Center(
            child:
                Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white
                            .withValues(
                      alpha:
                          0.06,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons
                        .celebration_outlined,
                    size: 30,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                const CircularProgressIndicator(),

                const SizedBox(
                  height: 16,
                ),

                Text(
                  "Finding what's happening...",
                  style:
                      TextStyle(
                    color:
                        Colors.grey[
                      500
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }


    if (_error != null) {
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

            Container(
              padding:
                  const EdgeInsets.all(
                24,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF151517,
                ),

                borderRadius:
                    BorderRadius.circular(
                  22,
                ),
              ),

              child:
                  Column(
                children: [
                  const Icon(
                    Icons
                        .event_busy_outlined,
                    size: 46,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    "Events aren't loading",
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          20,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    _error!,
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.grey[
                        500
                      ],
                      height:
                          1.4,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        50,
                    child:
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
                  ),
                ],
              ),
            ),
          ],
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
              const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            32,
          ),

          children: [
            _buildHeader(),

            if (_hasEventTools) ...[
              const SizedBox(
                height: 22,
              ),

              _buildEventTools(),
            ],

            const SizedBox(
              height: 70,
            ),

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                24,
                32,
                24,
                32,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF151517,
                ),

                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),

              child:
                  Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white
                              .withValues(
                        alpha:
                            0.07,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons
                          .celebration_outlined,
                      size: 34,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    "No upcoming events yet",
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    "Events from YIYO venues "
                    "and organisers will appear here.",
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.grey[
                        500
                      ],
                      height: 1.45,
                    ),
                  ),

                  if (_canCreateEvents) ...[
                    const SizedBox(
                      height: 22,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height:
                          50,
                      child:
                          FilledButton.icon(
                        onPressed:
                            _openCreateEvent,
                        icon:
                            const Icon(
                          Icons.add,
                        ),
                        label:
                            const Text(
                          "Create an event",
                        ),
                      ),
                    ),
                  ],
                ],
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

      child:
          ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          34,
        ),

        children: [
          _buildHeader(),

          if (_hasEventTools) ...[
            const SizedBox(
              height: 20,
            ),

            _buildEventTools(),
          ],

          const SizedBox(
            height: 28,
          ),

          if (happeningNow.isNotEmpty)
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

              eventMonth:
                  _eventMonth,

              eventDay:
                  _eventDay,

              onOpen:
                  _openEvent,

              live:
                  true,
            ),

          if (tonight.isNotEmpty)
            _EventSection(
              title:
                  "Tonight",

              subtitle:
                  "Your moves for later",

              events:
                  tonight,

              eventTime:
                  _eventTime,

              eventDate:
                  _eventDate,

              eventMonth:
                  _eventMonth,

              eventDay:
                  _eventDay,

              onOpen:
                  _openEvent,
            ),

          if (weekend.isNotEmpty)
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

              eventMonth:
                  _eventMonth,

              eventDay:
                  _eventDay,

              onOpen:
                  _openEvent,
            ),

          if (later.isNotEmpty)
            _EventSection(
              title:
                  "Coming up",

              subtitle:
                  "More nights worth knowing about",

              events:
                  later,

              eventTime:
                  _eventTime,

              eventDate:
                  _eventDate,

              eventMonth:
                  _eventMonth,

              eventDay:
                  _eventDay,

              onOpen:
                  _openEvent,
            ),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            const Expanded(
              child:
                  Text(
                "What's happening?",
                style:
                    TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      -0.9,
                ),
              ),
            ),

            if (_events.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white
                          .withValues(
                    alpha:
                        0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child:
                    Text(
                  "${_events.length}",
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          "Find your next move.",
          style:
              TextStyle(
            color:
                Colors.grey[
              500
            ],
            fontSize: 15,
          ),
        ),
      ],
    );
  }


  Widget _buildEventTools() {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
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
          Text(
            _canManageApprovals
                ? "Event tools"
                : "Your events",
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_canCreateEvents)
                FilledButton.icon(
                  onPressed:
                      _openCreateEvent,
                  style:
                      FilledButton
                          .styleFrom(
                    backgroundColor:
                        Colors.white,
                    foregroundColor:
                        Colors.black,
                  ),
                  icon:
                      const Icon(
                    Icons
                        .add_circle_outline,
                  ),
                  label:
                      const Text(
                    "Create",
                  ),
                ),

              if (_canCreateEvents)
                OutlinedButton.icon(
                  onPressed:
                      _openMyEvents,
                  icon:
                      const Icon(
                    Icons
                        .event_note_outlined,
                  ),
                  label:
                      const Text(
                    "My events",
                  ),
                ),

              if (_canManageApprovals)
                OutlinedButton.icon(
                  onPressed:
                      _openApprovals,
                  icon:
                      const Icon(
                    Icons
                        .fact_check_outlined,
                  ),
                  label:
                      const Text(
                    "Approvals",
                  ),
                ),
            ],
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

  final List<YiyoEvent> events;

  final String Function(
    YiyoEvent event,
  ) eventTime;

  final String Function(
    YiyoEvent event,
  ) eventDate;

  final String Function(
    YiyoEvent event,
  ) eventMonth;

  final String Function(
    YiyoEvent event,
  ) eventDay;

  final ValueChanged<YiyoEvent>
      onOpen;

  final bool live;


  const _EventSection({
    required this.title,
    required this.subtitle,
    required this.events,
    required this.eventTime,
    required this.eventDate,
    required this.eventMonth,
    required this.eventDay,
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
        bottom: 30,
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing:
                            -0.5,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      subtitle,
                      style:
                          TextStyle(
                        color:
                            Colors.grey[
                          500
                        ],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                "${events.length}",
                style:
                    TextStyle(
                  color:
                      Colors.grey[
                    500
                  ],
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
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

                month:
                    eventMonth(
                  event,
                ),

                day:
                    eventDay(
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
  final String month;
  final String day;

  final bool live;

  final VoidCallback onTap;


  const _EventCard({
    required this.event,
    required this.date,
    required this.time,
    required this.month,
    required this.day,
    required this.onTap,
    this.live = false,
  });


  bool get _hasPoster =>
      event.posterUrl != null &&
      event.posterUrl!
          .trim()
          .isNotEmpty;


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF151517,
        ),

        borderRadius:
            BorderRadius.circular(
          22,
        ),

        border:
            Border.all(
          color:
              live
                  ? Colors.red
                      .withValues(
                      alpha: 0.32,
                    )
                  : Colors.white
                      .withValues(
                      alpha: 0.06,
                    ),
        ),
      ),

      clipBehavior:
          Clip.antiAlias,

      child:
          Material(
        color:
            Colors.transparent,

        child:
            InkWell(
          onTap:
              onTap,

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (_hasPoster)
                SizedBox(
                  height: 142,
                  width:
                      double.infinity,
                  child:
                      Image.network(
                    event.posterUrl!,
                    fit:
                        BoxFit.cover,

                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return _EventVisualFallback(
                        event:
                            event,
                      );
                    },
                  ),
                ),

              Padding(
                padding:
                    const EdgeInsets.all(
                  15,
                ),

                child:
                    Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _DateBadge(
                      month:
                          month,
                      day:
                          day,
                      time:
                          time,
                      live:
                          live,
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (live) ...[
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.red
                                        .withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius:
                                    BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child:
                                  const Text(
                                "LIVE NOW",
                                style:
                                    TextStyle(
                                  color:
                                      Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w900,
                                  letterSpacing:
                                      0.4,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 8,
                            ),
                          ],

                          Text(
                            event.title,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing:
                                  -0.3,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          Row(
                            children: [
                              Icon(
                                Icons
                                    .location_on_outlined,
                                size: 16,
                                color:
                                    Colors.grey[
                                  400
                                ],
                              ),

                              const SizedBox(
                                width: 5,
                              ),

                              Expanded(
                                child:
                                    Text(
                                  event
                                      .venueName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.grey[
                                      300
                                    ],
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            "$date · $time",
                            style:
                                TextStyle(
                              color:
                                  Colors.grey[
                                500
                              ],
                              fontSize: 13,
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
                                      .take(
                                        2,
                                      )
                                      .map(
                                        (tag) =>
                                            Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color:
                                                Colors.white
                                                    .withValues(
                                              alpha: 0.06,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child:
                                              Text(
                                            tag,
                                            style:
                                                TextStyle(
                                              color:
                                                  Colors.grey[
                                                300
                                              ],
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],

                          const SizedBox(
                            height: 13,
                          ),

                          Row(
                            children: [
                              _EngagementCount(
                                icon:
                                    Icons
                                        .local_fire_department,
                                value:
                                    event
                                        .hypeCount,
                                label:
                                    "Hype",
                                color:
                                    Colors.deepOrangeAccent,
                              ),

                              const SizedBox(
                                width: 15,
                              ),

                              _EngagementCount(
                                icon:
                                    Icons
                                        .check_circle,
                                value:
                                    event
                                        .goingCount,
                                label:
                                    "Going",
                                color:
                                    Colors.greenAccent,
                              ),

                              const Spacer(),

                              Icon(
                                Icons
                                    .chevron_right,
                                color:
                                    Colors.grey[
                                  500
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DateBadge
    extends StatelessWidget {
  final String month;
  final String day;
  final String time;
  final bool live;


  const _DateBadge({
    required this.month,
    required this.day,
    required this.time,
    required this.live,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 62,
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            live
                ? Colors.red
                    .withValues(
                    alpha: 0.13,
                  )
                : Colors.white
                    .withValues(
                    alpha: 0.07,
                  ),

        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),

      child:
          Column(
        children: [
          Text(
            live
                ? "LIVE"
                : month,
            style:
                TextStyle(
              color:
                  live
                      ? Colors.redAccent
                      : Colors.grey[
                          400
                        ],
              fontSize: 10,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  0.5,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            day,
            style:
                const TextStyle(
              fontSize: 25,
              fontWeight:
                  FontWeight.w900,
              height: 1,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            time,
            style:
                TextStyle(
              color:
                  Colors.grey[
                500
              ],
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


class _EngagementCount
    extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;


  const _EngagementCount({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: color,
        ),

        const SizedBox(
          width: 4,
        ),

        Text(
          "$value $label",
          style:
              const TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}


class _EventVisualFallback
    extends StatelessWidget {
  final YiyoEvent event;


  const _EventVisualFallback({
    required this.event,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(
              0xFF31151D,
            ),
            Color(
              0xFF171217,
            ),
            Color(
              0xFF0B0B0C,
            ),
          ],
        ),
      ),

      alignment:
          Alignment.center,

      padding:
          const EdgeInsets.all(
        18,
      ),

      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const Icon(
            Icons
                .celebration_outlined,
            size: 34,
          ),

          const SizedBox(
            width: 12,
          ),

          Flexible(
            child:
                Text(
              event.title,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}