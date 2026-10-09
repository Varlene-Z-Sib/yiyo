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
        _engagement =
            state;

        _loadingEngagement =
            false;
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

        _loadingEngagement =
            false;
      });
    }
  }


  EventEngagement _fallbackEngagement() {
    return EventEngagement(
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
  }


  Future<void> _toggleHype() async {
    if (_changingHype) {
      return;
    }

    setState(() {
      _changingHype =
          true;
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
          result["active"] ==
              true;

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
                    _fallbackEngagement())
                .copyWith(
          hypeCount:
              count,

          hypedByMe:
              active,
        );

        _changingHype =
            false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingHype =
            false;
      });

      _showMessage(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingHype =
            false;
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
      _changingGoing =
          true;
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
          result["active"] ==
              true;

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
                    _fallbackEngagement())
                .copyWith(
          goingCount:
              count,

          goingByMe:
              active,
        );

        _changingGoing =
            false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingGoing =
            false;
      });

      _showMessage(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingGoing =
            false;
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
            Text(
          message,
        ),
      ),
    );
  }


  Future<void> _copyTicketLink() async {
    final ticketUrl =
        widget.event.ticketUrl;

    if (
        ticketUrl == null ||
        ticketUrl.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text:
            ticketUrl,
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


  String _clockTime(
    DateTime value,
  ) {
    final local =
        value.toLocal();

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


  String get _timeLabel {
    return _clockTime(
      widget.event.startsAt,
    );
  }


  String get _timeRangeLabel {
    final start =
        _timeLabel;

    final end =
        widget.event.endsAt;

    if (end == null) {
      return start;
    }

    return "$start – "
        "${_clockTime(end)}";
  }


  bool get _hasPoster =>
      widget.event.posterUrl != null &&
      widget.event.posterUrl!
          .trim()
          .isNotEmpty;


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
          "Event",
          style:
              TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.only(
          bottom: 34,
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildPoster(),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                20,
                18,
                0,
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (_isHappeningNow) ...[
                    _buildLiveBadge(),

                    const SizedBox(
                      height: 12,
                    ),
                  ],

                  Text(
                    widget.event.title,
                    style:
                        const TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          -0.9,
                      height: 1.05,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons
                            .location_on_outlined,
                        size: 21,
                        color:
                            Colors.grey[
                          400
                        ],
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event
                                  .venueName,
                              style:
                                  const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.w800,
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
                                      Colors.grey[
                                    500
                                  ],
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                            _InfoCard(
                          icon:
                              Icons
                                  .calendar_today_outlined,
                          label:
                              "Date",
                          value:
                              _dateLabel,
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                            _InfoCard(
                          icon:
                              Icons
                                  .schedule_outlined,
                          label:
                              "Time",
                          value:
                              _timeRangeLabel,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 26,
                  ),

                  const Text(
                    "Are you feeling it?",
                    style:
                        TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    "Let people know what's catching attention.",
                    style:
                        TextStyle(
                      color:
                          Colors.grey[
                        500
                      ],
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
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

                          selectedColor:
                              Colors
                                  .deepOrangeAccent,

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

                          selectedColor:
                              Colors
                                  .greenAccent,

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
                      height: 28,
                    ),

                    const Text(
                      "Vibe",
                      style:
                          TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
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
                                    Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 7,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.white
                                            .withValues(
                                      alpha: 0.07,
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
                                        const TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
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
                      height: 28,
                    ),

                    const Text(
                      "About",
                      style:
                          TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height: 9,
                    ),

                    Text(
                      widget
                          .event
                          .description
                          .trim(),
                      style:
                          TextStyle(
                        color:
                            Colors.grey[
                          300
                        ],
                        height: 1.55,
                        fontSize: 15,
                      ),
                    ),
                  ],

                  if (widget
                      .event
                      .hasTicketLink) ...[
                    const SizedBox(
                      height: 30,
                    ),

                    Container(
                      width:
                          double.infinity,

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
                      ),

                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons
                                    .confirmation_number_outlined,
                                size: 20,
                              ),

                              SizedBox(
                                width: 8,
                              ),

                              Text(
                                "Tickets",
                                style:
                                    TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          Text(
                            "Copy the ticket link and open it in your browser.",
                            style:
                                TextStyle(
                              color:
                                  Colors.grey[
                                500
                              ],
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          SizedBox(
                            width:
                                double.infinity,
                            height:
                                50,
                            child:
                                FilledButton.icon(
                              onPressed:
                                  _copyTicketLink,
                              style:
                                  FilledButton
                                      .styleFrom(
                                backgroundColor:
                                    Colors.white,
                                foregroundColor:
                                    Colors.black,

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    15,
                                  ),
                                ),
                              ),
                              icon:
                                  const Icon(
                                Icons.copy,
                              ),
                              label:
                                  const Text(
                                "Copy ticket link",
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLiveBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
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

        border:
            Border.all(
          color:
              Colors.red
                  .withValues(
            alpha: 0.3,
          ),
        ),
      ),

      child:
          const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons
                .fiber_manual_record,
            size: 11,
            color:
                Colors.redAccent,
          ),

          SizedBox(
            width: 5,
          ),

          Text(
            "LIVE NOW",
            style:
                TextStyle(
              color:
                  Colors.redAccent,
              fontWeight:
                  FontWeight.w900,
              fontSize: 11,
              letterSpacing:
                  0.5,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPoster() {
    if (_hasPoster) {
      return AspectRatio(
        aspectRatio:
            16 / 9,

        child:
            Image.network(
          widget.event.posterUrl!,
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
          16 / 9,

      child:
          Container(
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
                0xFF39141E,
              ),
              Color(
                0xFF181217,
              ),
              Color(
                0xFF0B0B0C,
              ),
            ],
          ),
        ),

        padding:
            const EdgeInsets.all(
          24,
        ),

        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.09,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .celebration_outlined,
                size: 32,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              widget.event.title,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
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
              height: 7,
            ),

            Text(
              widget.event.venueName,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
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
          ],
        ),
      ),
    );
  }
}


class _InfoCard
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;


  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 96,
      ),

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
          18,
        ),

        border:
            Border.all(
          color:
              Colors.white
                  .withValues(
            alpha: 0.06,
          ),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color:
                Colors.grey[
              400
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            label,
            style:
                TextStyle(
              color:
                  Colors.grey[
                500
              ],
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            value,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
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

  final Color selectedColor;

  final VoidCallback? onPressed;


  const _EngagementButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.loading,
    required this.selectedColor,
    required this.onPressed,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height: 66,

      child:
          OutlinedButton(
        onPressed:
            onPressed,

        style:
            OutlinedButton
                .styleFrom(
          foregroundColor:
              selected
                  ? selectedColor
                  : Colors.white,

          backgroundColor:
              selected
                  ? selectedColor
                      .withValues(
                      alpha: 0.12,
                    )
                  : const Color(
                      0xFF151517,
                    ),

          side:
              BorderSide(
            color:
                selected
                    ? selectedColor
                    : Colors.white
                        .withValues(
                        alpha: 0.10,
                      ),
            width:
                selected
                    ? 1.6
                    : 1,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),

        child:
            loading
                ? SizedBox(
                    width: 21,
                    height: 21,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color:
                          selectedColor,
                    ),
                  )
                : Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Row(
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

                          Text(
                            "$count",
                            style:
                                const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        label,
                        style:
                            const TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing:
                              0.5,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}