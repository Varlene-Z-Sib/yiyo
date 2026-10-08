import 'package:flutter/material.dart';

import '../models/event_approval.dart';
import '../models/yiyo_event.dart';
import '../services/api_service.dart';


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

  String? _workingEventId;

  List<EventApproval> _approvals = [];


  @override
  void initState() {
    super.initState();

    _loadApprovals();
  }


  Future<void> _loadApprovals() async {
    try {
      final approvals =
          await ApiService
              .getEventApprovals();

      if (!mounted) {
        return;
      }

      setState(() {
        _approvals =
            approvals;

        _error =
            null;

        _isLoading =
            false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            e.message;

        _isLoading =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "Couldn't load event approvals.";

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

    await _loadApprovals();
  }


  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
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
                "Cancel",
              ),
            ),

            FilledButton(
              style:
                  destructive
                      ? FilledButton
                          .styleFrom(
                          backgroundColor:
                              Colors.red,
                          foregroundColor:
                              Colors.white,
                        )
                      : null,

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


  Future<void> _approve(
    EventApproval approval,
  ) async {
    final event =
        approval.event;

    final confirmed =
        await _confirm(
      title:
          "Approve event?",

      message:
          "\"${event.title}\" will become "
          "visible in YIYO Events.",

      action:
          "Approve",
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
          .approveEvent(
        event.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _approvals.removeWhere(
          (item) =>
              item.event.id ==
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
            "Event approved.",
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
    }
  }


  Future<void> _reject(
    EventApproval approval,
  ) async {
    final event =
        approval.event;

    final confirmed =
        await _confirm(
      title:
          "Reject event?",

      message:
          "\"${event.title}\" will not "
          "be published.",

      action:
          "Reject",

      destructive:
          true,
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
          .rejectEvent(
        event.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _approvals.removeWhere(
          (item) =>
              item.event.id ==
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
            "Event rejected.",
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
    }
  }


  String _dateLabel(
    YiyoEvent event,
  ) {
    final value =
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

    return "${value.day} "
        "${months[value.month - 1]}";
  }


  String _timeLabel(
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

    return "$hour:$minute";
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
          "Event approvals",
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
              const Icon(
                Icons
                    .fact_check_outlined,
                size:
                    46,
              ),

              const SizedBox(
                height:
                    14,
              ),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height:
                    18,
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

    if (_approvals.isEmpty) {
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
                  110,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                28,
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
                  const Icon(
                    Icons
                        .done_all,
                    size:
                        48,
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  const Text(
                    "You're all caught up",
                    style:
                        TextStyle(
                      fontSize:
                          20,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height:
                        7,
                  ),

                  Text(
                    "New promoter submissions "
                    "will appear here.",
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
          12,
          16,
          32,
        ),

        children: [
          const Text(
            "Needs review",
            style:
                TextStyle(
              fontSize:
                  26,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  -0.7,
            ),
          ),

          const SizedBox(
            height:
                5,
          ),

          Text(
            "${_approvals.length} pending "
            "event${_approvals.length == 1 ? "" : "s"}",
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
                22,
          ),

          ..._approvals.map(
            _buildApprovalCard,
          ),
        ],
      ),
    );
  }


  Widget _buildApprovalCard(
    EventApproval approval,
  ) {
    final event =
        approval.event;

    final isWorking =
        _workingEventId ==
        event.id;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            14,
      ),

      padding:
          const EdgeInsets.all(
        17,
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
            event.title,

            style:
                const TextStyle(
              fontSize:
                  20,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .location_on_outlined,
                size:
                    17,
              ),

              const SizedBox(
                width:
                    6,
              ),

              Expanded(
                child:
                    Text(
                  event.venueName,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                6,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .schedule_outlined,
                size:
                    17,
              ),

              const SizedBox(
                width:
                    6,
              ),

              Text(
                "${_dateLabel(event)}"
                " · "
                "${_timeLabel(event)}",
              ),
            ],
          ),

          if (event.description
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height:
                  14,
            ),

            Text(
              event.description.trim(),
              maxLines:
                  4,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  400
                ],
                height:
                    1.4,
              ),
            ),
          ],

          const SizedBox(
            height:
                18,
          ),

          Container(
            width:
                double.infinity,

            padding:
                const EdgeInsets.all(
              14,
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
                16,
              ),
            ),

            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Submitted by",
                  style:
                      TextStyle(
                    color:
                        Colors.grey[
                      500
                    ],
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                      7,
                ),

                Text(
                  approval.primaryIdentity,
                  style:
                      const TextStyle(
                    fontSize:
                        16,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                if (approval
                    .organizerUsername
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        3,
                  ),

                  Text(
                    approval.usernameLabel,
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

                if (approval
                    .organizerEmail
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        4,
                  ),

                  Text(
                    approval
                        .organizerEmail,
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

                const SizedBox(
                  height:
                      4,
                ),

                Text(
                  "UID: "
                  "${event.organizerUid}",
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color:
                        Colors.grey[
                      700
                    ],
                    fontSize:
                        10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
                18,
          ),

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton(
                  onPressed:
                      isWorking
                          ? null
                          : () =>
                              _reject(
                            approval,
                          ),

                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        Colors.redAccent,

                    side:
                        BorderSide(
                      color:
                          Colors.red
                              .withValues(
                        alpha:
                            0.5,
                      ),
                    ),

                    minimumSize:
                        const Size.fromHeight(
                      52,
                    ),
                  ),

                  child:
                      const Text(
                    "Reject",
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              Expanded(
                child:
                    FilledButton(
                  onPressed:
                      isWorking
                          ? null
                          : () =>
                              _approve(
                            approval,
                          ),

                  style:
                      FilledButton
                          .styleFrom(
                    backgroundColor:
                        Colors.white,

                    foregroundColor:
                        Colors.black,

                    minimumSize:
                        const Size.fromHeight(
                      52,
                    ),
                  ),

                  child:
                      isWorking
                          ? const SizedBox(
                              width:
                                  20,
                              height:
                                  20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Colors.black,
                              ),
                            )
                          : const Text(
                              "Approve",
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}