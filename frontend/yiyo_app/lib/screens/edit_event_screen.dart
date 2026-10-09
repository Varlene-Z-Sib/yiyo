import 'package:flutter/material.dart';

import '../models/yiyo_event.dart';
import '../services/api_service.dart';


class EditEventScreen
    extends StatefulWidget {
  final YiyoEvent event;

  const EditEventScreen({
    super.key,
    required this.event,
  });

  @override
  State<EditEventScreen>
      createState() =>
          _EditEventScreenState();
}


class _EditEventScreenState
    extends State<EditEventScreen> {
  late final TextEditingController
      _titleController;

  late final TextEditingController
      _descriptionController;

  late final TextEditingController
      _posterController;

  late final TextEditingController
      _ticketController;

  late final TextEditingController
      _tagsController;

  late DateTime _startsAt;

  DateTime? _endsAt;

  bool _isSaving = false;

  String? _error;


  @override
  void initState() {
    super.initState();

    _titleController =
        TextEditingController(
      text:
          widget.event.title,
    );

    _descriptionController =
        TextEditingController(
      text:
          widget.event.description,
    );

    _posterController =
        TextEditingController(
      text:
          widget.event.posterUrl ??
          "",
    );

    _ticketController =
        TextEditingController(
      text:
          widget.event.ticketUrl ??
          "",
    );

    _tagsController =
        TextEditingController(
      text:
          widget.event.tags.join(
        ", ",
      ),
    );

    _startsAt =
        widget.event.startsAt
            .toLocal();

    _endsAt =
        widget.event.endsAt
            ?.toLocal();
  }


  @override
  void dispose() {
    _titleController.dispose();

    _descriptionController.dispose();

    _posterController.dispose();

    _ticketController.dispose();

    _tagsController.dispose();

    super.dispose();
  }


  Future<DateTime?>
      _pickDateTime(
    DateTime initial,
  ) async {
    final date =
        await showDatePicker(
      context:
          context,

      initialDate:
          initial,

      firstDate:
          DateTime.now(),

      lastDate:
          DateTime.now().add(
        const Duration(
          days: 730,
        ),
      ),
    );

    if (
        date == null ||
        !mounted) {
      return null;
    }

    final time =
        await showTimePicker(
      context:
          context,

      initialTime:
          TimeOfDay.fromDateTime(
        initial,
      ),
    );

    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }


  Future<void>
      _changeStart() async {
    final value =
        await _pickDateTime(
      _startsAt,
    );

    if (
        value == null ||
        !mounted) {
      return;
    }

    setState(() {
      _startsAt =
          value;

      if (
          _endsAt != null &&
          !_endsAt!.isAfter(
            _startsAt,
          )) {
        _endsAt =
            _startsAt.add(
          const Duration(
            hours: 4,
          ),
        );
      }
    });
  }


  Future<void>
      _changeEnd() async {
    final initial =
        _endsAt ??
        _startsAt.add(
          const Duration(
            hours: 4,
          ),
        );

    final value =
        await _pickDateTime(
      initial,
    );

    if (
        value == null ||
        !mounted) {
      return;
    }

    if (!value.isAfter(
      _startsAt,
    )) {
      setState(() {
        _error =
            "End time must be after "
            "the event start time.";
      });

      return;
    }

    setState(() {
      _endsAt =
          value;

      _error =
          null;
    });
  }


  String _dateTimeLabel(
    DateTime value,
  ) {
    final local =
        value.toLocal();

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
        "${local.year} · "
        "$hour:$minute";
  }


  List<String> _tags() {
    return _tagsController.text
        .split(",")
        .map(
          (value) =>
              value.trim(),
        )
        .where(
          (value) =>
              value.isNotEmpty,
        )
        .take(
          8,
        )
        .toList();
  }


  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final title =
        _titleController.text
            .trim();

    if (title.length < 2) {
      setState(() {
        _error =
            "Enter an event title.";
      });

      return;
    }

    if (!_startsAt.isAfter(
      DateTime.now(),
    )) {
      setState(() {
        _error =
            "Event start time must "
            "be in the future.";
      });

      return;
    }

    if (
        _endsAt != null &&
        !_endsAt!.isAfter(
          _startsAt,
        )) {
      setState(() {
        _error =
            "End time must be after "
            "the start time.";
      });

      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _isSaving =
          true;

      _error =
          null;
    });

    try {
      final updated =
          await ApiService
              .updateEvent(
        eventId:
            widget.event.id,

        title:
            title,

        startsAt:
            _startsAt,

        endsAt:
            _endsAt,

        description:
            _descriptionController.text
                .trim(),

        posterUrl:
            _posterController.text
                .trim(),

        ticketUrl:
            _ticketController.text
                .trim(),

        tags:
            _tags(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(
        updated,
      );
    } on ApiException catch (
        error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            error.message;

        _isSaving =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "Couldn't update event.";

        _isSaving =
            false;
      });
    }
  }


  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
  }) {
    return InputDecoration(
      labelText:
          label,

      hintText:
          hint,

      filled:
          true,

      fillColor:
          Colors.white
              .withValues(
        alpha: 0.06,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        borderSide:
            BorderSide.none,
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        borderSide:
            const BorderSide(
          color:
              Colors.white,
        ),
      ),
    );
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
          "Edit event",
          style:
              TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            32,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Container(
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
                    18,
                  ),
                ),

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
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      "Venue cannot be changed "
                      "after an event is created.",
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
                ),
              ),

              const SizedBox(
                height:
                    20,
              ),

              TextField(
                controller:
                    _titleController,

                enabled:
                    !_isSaving,

                textCapitalization:
                    TextCapitalization
                        .sentences,

                decoration:
                    _fieldDecoration(
                  "Event title",
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              TextField(
                controller:
                    _descriptionController,

                enabled:
                    !_isSaving,

                minLines:
                    4,

                maxLines:
                    8,

                textCapitalization:
                    TextCapitalization
                        .sentences,

                decoration:
                    _fieldDecoration(
                  "Description",
                  hint:
                      "What should people know?",
                ),
              ),

              const SizedBox(
                height:
                    22,
              ),

              const Text(
                "When",
                style:
                    TextStyle(
                  fontSize:
                      18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    10,
              ),

              _DateTimeTile(
                title:
                    "Starts",

                value:
                    _dateTimeLabel(
                  _startsAt,
                ),

                onTap:
                    _isSaving
                        ? null
                        : _changeStart,
              ),

              const SizedBox(
                height:
                    10,
              ),

              _DateTimeTile(
                title:
                    "Ends",

                value:
                    _endsAt == null
                        ? "No end time"
                        : _dateTimeLabel(
                            _endsAt!,
                          ),

                onTap:
                    _isSaving
                        ? null
                        : _changeEnd,

                trailing:
                    _endsAt == null
                        ? null
                        : IconButton(
                            tooltip:
                                "Remove end time",

                            onPressed:
                                _isSaving
                                    ? null
                                    : () {
                                        setState(() {
                                          _endsAt =
                                              null;
                                        });
                                      },

                            icon:
                                const Icon(
                              Icons.close,
                            ),
                          ),
              ),

              const SizedBox(
                height:
                    22,
              ),

              TextField(
                controller:
                    _tagsController,

                enabled:
                    !_isSaving,

                decoration:
                    _fieldDecoration(
                  "Tags",
                  hint:
                      "Amapiano, R&B, Party",
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              TextField(
                controller:
                    _ticketController,

                enabled:
                    !_isSaving,

                keyboardType:
                    TextInputType.url,

                decoration:
                    _fieldDecoration(
                  "Ticket URL",
                  hint:
                      "Optional",
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              TextField(
                controller:
                    _posterController,

                enabled:
                    !_isSaving,

                keyboardType:
                    TextInputType.url,

                decoration:
                    _fieldDecoration(
                  "Poster image URL",
                  hint:
                      "Optional",
                ),
              ),

              if (_error != null) ...[
                const SizedBox(
                  height:
                      16,
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.red
                            .withValues(
                      alpha:
                          0.10,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),

                  child:
                      Text(
                    _error!,
                    style:
                        const TextStyle(
                      color:
                          Colors.redAccent,
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height:
                    26,
              ),

              SizedBox(
                height:
                    54,

                child:
                    FilledButton(
                  onPressed:
                      _isSaving
                          ? null
                          : _save,

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
                        16,
                      ),
                    ),
                  ),

                  child:
                      _isSaving
                          ? const SizedBox(
                              width:
                                  22,
                              height:
                                  22,

                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2.5,
                                color:
                                    Colors.black,
                              ),
                            )
                          : const Text(
                              "Save changes",
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                ),
              ),

              if (widget.event.isPublished) ...[
                const SizedBox(
                  height:
                      12,
                ),

                Text(
                  "If you're the promoter who "
                  "submitted this published event, "
                  "your changes will be sent back "
                  "for approval.",
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        Colors.grey[
                      500
                    ],
                    fontSize:
                        12,
                    height:
                        1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _DateTimeTile
    extends StatelessWidget {
  final String title;
  final String value;

  final VoidCallback? onTap;

  final Widget? trailing;


  const _DateTimeTile({
    required this.title,
    required this.value,
    required this.onTap,
    this.trailing,
  });


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
          16,
        ),
      ),

      child:
          ListTile(
        onTap:
            onTap,

        leading:
            const Icon(
          Icons
              .schedule_outlined,
        ),

        title:
            Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),

        subtitle:
            Text(
          value,
        ),

        trailing:
            trailing ??
            const Icon(
              Icons.edit_outlined,
            ),
      ),
    );
  }
}