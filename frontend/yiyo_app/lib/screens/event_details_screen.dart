import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/event_engagement.dart';
import '../models/yiyo_event.dart';
import '../services/api_service.dart';


class EventDetailsScreen
    extends StatefulWidget {
  final YiyoEvent event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailsScreen>
      createState() =>
          _EventDetailsScreenState();
}


class _EventDetailsScreenState
    extends State<EventDetailsScreen> {
  EventEngagement? _engagement;

  bool _loadingEngagement = true;
  bool _changingHype = false;
  bool _changingGoing = false;


  @override
  void initState() {
    super.initState();

    _loadEngagement();
  }


  Future<void> _loadEngagement() async {
    try {
      final state =
          await ApiService
              .getEventEngagement(
        widget.event.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _engagement = state;
        _loadingEngagement = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _engagement =
            EventEngagement(
          eventId:
              widget.event.id,
          hypeCount:
              widget.event.hypeCount,
          goingCount:
              widget.event.goingCount,
          hypedByMe:
              false,
          goingByMe:
              false,
        );

        _loadingEngagement = false;
      });
    }
  }


  Future<void> _toggleHype() async {
    if (_changingHype) {
      return;
    }

    setState(() {
      _changingHype = true;
    });

    try {
      final result =
          await ApiService
              .toggleEventHype(
        widget.event.id,
      );

      if (!mounted) {
        return;
      }

      final active =
          result["active"] == true;

      final count =
          int.tryParse(
            result["count"]
                    ?.toString() ??
                "",
          ) ??
          0;

      setState(() {
        _engagement =
            (_engagement ??
                    EventEngagement(
                      eventId:
                          widget.event.id,
                      hypeCount:
                          widget
                              .event
                              .hypeCount,
                      goingCount:
                          widget
                              .event
                              .goingCount,
                      hypedByMe:
                          false,
                      goingByMe:
                          false,
                    ))
                .copyWith(
          hypeCount:
              count,
          hypedByMe:
              active,
        );

        _changingHype = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingHype = false;
      });

      _showMessage(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingHype = false;
      });

      _showMessage(
        "Couldn't update Hype.",
      );
    }
  }


  Future<void> _toggleGoing() async {
    if (_changingGoing) {
      return;
    }

    setState(() {
      _changingGoing = true;
    });

    try {
      final result =
          await ApiService
              .toggleEventGoing(
        widget.event.id,
      );

      if (!mounted) {
        return;
      }

      final active =
          result["active"] == true;

      final count =
          int.tryParse(
            result["count"]
                    ?.toString() ??
                "",
          ) ??
          0;

      setState(() {
        _engagement =
            (_engagement ??
                    EventEngagement(
                      eventId:
                          widget.event.id,
                      hypeCount:
                          widget
                              .event
                              .hypeCount,
                      goingCount:
                          widget
                              .event
                              .goingCount,
                      hypedByMe:
                          false,
                      goingByMe:
                          false,
                    ))
                .copyWith(
          goingCount:
              count,
          goingByMe:
              active,
        );

        _changingGoing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingGoing = false;
      });

      _showMessage(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingGoing = false;
      });

      _showMessage(
        "Couldn't update Going.",
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


  Future<void>
      _copyTicketLink() async {
    final ticketUrl =
        widget.event.ticketUrl;

    if (ticketUrl == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: ticketUrl,
      ),
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      "Ticket link copied.",
    );
  }


  bool get _isHappeningNow {
    final now =
        DateTime.now();

    final start =
        widget.event.startsAt
            .toLocal();

    final end =
        widget.event.endsAt
                ?.toLocal() ??
            start.add(
              const Duration(
                hours: 8,
              ),
            );

    return !now.isBefore(
          start,
        ) &&
        now.isBefore(
          end,
        );
  }


  String get _dateLabel {
    final local =
        widget.event.startsAt
            .toLocal();

    const weekdays = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return "${weekdays[local.weekday - 1]}, "
        "${local.day} "
        "${months[local.month - 1]}";
  }


  String get _timeLabel {
    final local =
        widget.event.startsAt
            .toLocal();

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


  @override
  Widget build(
    BuildContext context,
  ) {
    final engagement =
        _engagement;

    final hypeCount =
        engagement?.hypeCount ??
            widget.event.hypeCount;

    final goingCount =
        engagement?.goingCount ??
            widget.event.goingCount;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          "Event",
        ),
      ),
      body:
          SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildPoster(),

            Padding(
              padding:
                  const EdgeInsets.all(
                18,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (_isHappeningNow) ...[
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 5,
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
                              12,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),
                  ],

                  Text(
                    widget.event.title,
                    style:
                        const TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    widget.event.venueName,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  if (widget
                      .event
                      .venueAddress
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      widget
                          .event
                          .venueAddress,
                      style:
                          TextStyle(
                        color:
                            Colors.grey[600],
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 16,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .calendar_today_outlined,
                        size: 19,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            Text(
                          _dateLabel,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 9,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .schedule_outlined,
                        size: 20,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Text(
                        _timeLabel,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            _EngagementButton(
                          icon:
                              Icons
                                  .local_fire_department,
                          label:
                              "HYPE",
                          count:
                              hypeCount,
                          selected:
                              engagement
                                      ?.hypedByMe ??
                                  false,
                          loading:
                              _changingHype,
                          onPressed:
                              _loadingEngagement
                                  ? null
                                  : _toggleHype,
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                            _EngagementButton(
                          icon:
                              Icons
                                  .check_circle,
                          label:
                              "GOING",
                          count:
                              goingCount,
                          selected:
                              engagement
                                      ?.goingByMe ??
                                  false,
                          loading:
                              _changingGoing,
                          onPressed:
                              _loadingEngagement
                                  ? null
                                  : _toggleGoing,
                        ),
                      ),
                    ],
                  ),

                  if (widget
                      .event
                      .tags
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 22,
                    ),

                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children:
                          widget
                              .event
                              .tags
                              .map(
                                (tag) =>
                                    Chip(
                                  label:
                                      Text(
                                    tag,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],

                  if (widget
                      .event
                      .description
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 26,
                    ),

                    const Text(
                      "About",
                      style:
                          TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      widget
                          .event
                          .description
                          .trim(),
                      style:
                          const TextStyle(
                        height: 1.45,
                      ),
                    ),
                  ],

                  if (widget.event
                      .hasTicketLink) ...[
                    const SizedBox(
                      height: 28,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _copyTicketLink,
                        icon:
                            const Icon(
                          Icons
                              .confirmation_number_outlined,
                        ),
                        label:
                            const Text(
                          "COPY TICKET LINK",
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPoster() {
    final posterUrl =
        widget.event.posterUrl;

    if (posterUrl != null) {
      return AspectRatio(
        aspectRatio:
            4 / 3,
        child: Image.network(
          posterUrl,
          fit:
              BoxFit.cover,
          errorBuilder:
              (
            context,
            error,
            stackTrace,
          ) {
            return _posterFallback();
          },
        ),
      );
    }

    return _posterFallback();
  }


  Widget _posterFallback() {
    return AspectRatio(
      aspectRatio:
          4 / 3,
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
              size: 62,
            ),

            const SizedBox(
              height: 10,
            ),

            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 24,
              ),
              child:
                  Text(
                widget.event.title,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _EngagementButton
    extends StatelessWidget {
  final IconData icon;
  final String label;

  final int count;

  final bool selected;
  final bool loading;

  final VoidCallback? onPressed;

  const _EngagementButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.loading,
    required this.onPressed,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return SizedBox(
      height: 62,
      child: OutlinedButton(
        onPressed:
            onPressed,
        style:
            OutlinedButton.styleFrom(
          backgroundColor:
              selected
                  ? scheme
                      .primaryContainer
                  : null,
          side:
              BorderSide(
            color:
                selected
                    ? scheme.primary
                    : scheme
                        .outlineVariant,
            width:
                selected
                    ? 2
                    : 1,
          ),
        ),
        child:
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                      ),

                      const SizedBox(
                        width: 6,
                      ),

                      Flexible(
                        child:
                            Text(
                          "$label  $count",
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}