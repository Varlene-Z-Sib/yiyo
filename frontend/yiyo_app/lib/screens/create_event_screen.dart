import 'dart:async';

import 'package:flutter/material.dart';

import '../models/venue_lookup_option.dart';
import '../services/api_service.dart';
import '../services/draft_storage_service.dart';


class CreateEventScreen
    extends StatefulWidget {
  const CreateEventScreen({
    super.key,
  });

  @override
  State<CreateEventScreen>
      createState() =>
          _CreateEventScreenState();
}


class _CreateEventScreenState
    extends State<CreateEventScreen>
    with WidgetsBindingObserver {
  final _titleController =
      TextEditingController();

  final _descriptionController =
      TextEditingController();

  final _venueSearchController =
      TextEditingController();

  final _ticketUrlController =
      TextEditingController();

  final _posterUrlController =
      TextEditingController();

  final _tagsController =
      TextEditingController();

  VenueLookupOption? _selectedVenue;

  List<VenueLookupOption>
      _venueResults = [];

  DateTime? _startsAt;

  DateTime? _endsAt;

  bool _searchingVenues = false;

  bool _submitting = false;

  String? _venueSearchError;

  Timer? _draftSaveDebounce;

  bool _restoringDraft = true;

@override
void initState() {
  super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _titleController.addListener(
      _scheduleDraftSave,
    );

    _descriptionController.addListener(
      _scheduleDraftSave,
    );

    _ticketUrlController.addListener(
      _scheduleDraftSave,
    );

    _posterUrlController.addListener(
      _scheduleDraftSave,
    );

    _tagsController.addListener(
      _scheduleDraftSave,
    );

    _restoreDraft();
  }

@override
void didChangeAppLifecycleState(
  AppLifecycleState state,
) {
  if (
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    _draftSaveDebounce?.cancel();

    _saveDraft();
  }
}

  @override
void dispose() {
  // If the user backs out quickly,
  // capture the latest values before
  // the controllers are destroyed.
  _saveDraft();

  WidgetsBinding.instance.removeObserver(
    this,
  );

  _draftSaveDebounce?.cancel();

  _titleController.removeListener(
    _scheduleDraftSave,
  );

  _descriptionController.removeListener(
    _scheduleDraftSave,
  );

  _ticketUrlController.removeListener(
    _scheduleDraftSave,
  );

  _posterUrlController.removeListener(
    _scheduleDraftSave,
  );

  _tagsController.removeListener(
    _scheduleDraftSave,
  );

  _titleController.dispose();

  _descriptionController.dispose();

  _venueSearchController.dispose();

  _ticketUrlController.dispose();

  _posterUrlController.dispose();

  _tagsController.dispose();

  super.dispose();
}

void _scheduleDraftSave() {
  if (_restoringDraft) {
    return;
  }

  _draftSaveDebounce?.cancel();

  _draftSaveDebounce =
      Timer(
    const Duration(
      milliseconds: 350,
    ),
    _saveDraft,
  );
}


bool _hasDraftContent() {
  return _titleController.text
          .trim()
          .isNotEmpty ||
      _descriptionController.text
          .trim()
          .isNotEmpty ||
      _selectedVenue != null ||
      _startsAt != null ||
      _endsAt != null ||
      _tagsController.text
          .trim()
          .isNotEmpty ||
      _ticketUrlController.text
          .trim()
          .isNotEmpty ||
      _posterUrlController.text
          .trim()
          .isNotEmpty;
}


Map<String, dynamic> _draftData() {
  final venue =
      _selectedVenue;

  return {
    "title":
        _titleController.text,

    "description":
        _descriptionController.text,

    "venue":
        venue == null
            ? null
            : {
                "id":
                    venue.id,

                "name":
                    venue.name,

                "address":
                    venue.address,
              },

    "starts_at":
        _startsAt
            ?.toIso8601String(),

    "ends_at":
        _endsAt
            ?.toIso8601String(),

    "tags":
        _tagsController.text,

    "ticket_url":
        _ticketUrlController.text,

    "poster_url":
        _posterUrlController.text,
  };
}


Future<void> _saveDraft() async {
  if (
      _restoringDraft ||
      _submitting) {
    return;
  }

  if (!_hasDraftContent()) {
    await DraftStorageService
        .clearCreateEventDraft();

    return;
  }

  await DraftStorageService
      .saveCreateEventDraft(
    _draftData(),
  );
}


DateTime? _draftDate(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}


Future<void> _restoreDraft() async {
  try {
    final draft =
        await DraftStorageService
            .loadCreateEventDraft();

    if (!mounted) {
      return;
    }

    if (draft == null) {
      _restoringDraft = false;
      return;
    }

    final startsAt =
        _draftDate(
      draft["starts_at"],
    );

    // Don't restore an event start
    // time that has already passed.
    final validStart =
        startsAt != null &&
                startsAt.isAfter(
                  DateTime.now(),
                )
            ? startsAt
            : null;

    final endsAt =
        _draftDate(
      draft["ends_at"],
    );

    final validEnd =
        validStart != null &&
                endsAt != null &&
                endsAt.isAfter(
                  validStart,
                )
            ? endsAt
            : null;

    VenueLookupOption? venue;

    final venueData =
        draft["venue"];

    if (venueData is Map) {
      final id =
          (venueData["id"] ?? "")
              .toString()
              .trim();

      if (id.isNotEmpty) {
        venue =
            VenueLookupOption(
          id:
              id,

          name:
              (venueData["name"] ?? "")
                  .toString()
                  .trim(),

          address:
              (venueData["address"] ?? "")
                  .toString()
                  .trim(),
        );
      }
    }

    _titleController.text =
        (draft["title"] ?? "")
            .toString();

    _descriptionController.text =
        (draft["description"] ?? "")
            .toString();

    _tagsController.text =
        (draft["tags"] ?? "")
            .toString();

    _ticketUrlController.text =
        (draft["ticket_url"] ?? "")
            .toString();

    _posterUrlController.text =
        (draft["poster_url"] ?? "")
            .toString();

    setState(() {
      _selectedVenue =
          venue;

      _startsAt =
          validStart;

      _endsAt =
          validEnd;

      if (venue != null) {
        _venueSearchController.text =
            venue.name;
      }
    });

    _restoringDraft = false;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        _showMessage(
          "Event draft restored.",
        );
      },
    );
  } catch (_) {
    // Draft persistence must never
    // stop Create Event from opening.
    _restoringDraft = false;
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


  // ---------------------------------------------------------------------------
  // Venue registry search
  // ---------------------------------------------------------------------------

  Future<void> _searchVenues() async {
    final query =
        _venueSearchController.text
            .trim();

    if (query.length < 2) {
      setState(() {
        _venueSearchError =
            "Enter at least 2 characters.";
      });

      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _searchingVenues =
          true;

      _venueSearchError =
          null;

      _venueResults =
          [];
    });

    try {
      // IMPORTANT:
      //
      // This searches only YIYO's
      // Firestore venue registry.
      //
      // It does NOT use the public
      // venue search and therefore
      // does NOT trigger Google Places.
      final venues =
          await ApiService
              .searchVenueRegistry(
        query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _venueResults =
            venues;

        _searchingVenues =
            false;

        if (venues.isEmpty) {
          _venueSearchError =
              "No YIYO venues matched "
              "that search.";
        }
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _venueSearchError =
            e.message;

        _searchingVenues =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _venueSearchError =
            "Venue search failed.";

        _searchingVenues =
            false;
      });
    }
  }


  void _selectVenue(
    VenueLookupOption venue,
  ) {
    setState(() {
      _selectedVenue =
          venue;

      _venueSearchController.text =
          venue.name;

      // Collapse the search results
      // after a venue is chosen.
      _venueResults =
          [];

      _venueSearchError =
          null;
    });

    FocusScope.of(
      context,
    ).unfocus();

    _scheduleDraftSave();
  }


  void _changeVenue() {
    setState(() {
      _selectedVenue =
          null;

      _venueResults =
          [];

      _venueSearchError =
          null;

      _venueSearchController
          .clear();
    });

    _scheduleDraftSave();
  }


  // ---------------------------------------------------------------------------
  // Date / time
  // ---------------------------------------------------------------------------

  Future<DateTime?> _pickDateTime({
    DateTime? initialValue,
  }) async {
    final now =
        DateTime.now();

    final initial =
        initialValue ??
        now.add(
          const Duration(
            hours: 2,
          ),
        );

    final date =
        await showDatePicker(
      context:
          context,

      initialDate:
          initial,

      firstDate:
          DateTime(
        now.year,
        now.month,
        now.day,
      ),

      lastDate:
          DateTime(
        now.year + 2,
        now.month,
        now.day,
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
      _pickStartTime() async {
    final value =
        await _pickDateTime(
      initialValue:
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
            value,
          )) {
        _endsAt =
            null;
      }
    });

    _scheduleDraftSave();
  }


  Future<void>
      _pickEndTime() async {
    final start =
        _startsAt;

    if (start == null) {
      _showMessage(
        "Choose the event start "
        "time first.",
      );

      return;
    }

    final value =
        await _pickDateTime(
      initialValue:
          _endsAt ??
          start.add(
            const Duration(
              hours: 4,
            ),
          ),
    );

    if (
        value == null ||
        !mounted) {
      return;
    }

    if (!value.isAfter(
      start,
    )) {
      _showMessage(
        "End time must be after "
        "the start time.",
      );

      return;
    }

    setState(() {
      _endsAt =
          value;
    });

    _scheduleDraftSave();
  }


  // ---------------------------------------------------------------------------
  // Form helpers
  // ---------------------------------------------------------------------------

  List<String> _tags() {
    final tags =
        _tagsController.text
            .split(",")
            .map(
              (value) =>
                  value.trim(),
            )
            .where(
              (value) =>
                  value.isNotEmpty,
            )
            .toSet()
            .take(
              8,
            )
            .toList();

    return tags;
  }


  String _dateTimeLabel(
    DateTime? value,
  ) {
    if (value == null) {
      return "Not selected";
    }

    final day =
        value.day
            .toString()
            .padLeft(
              2,
              "0",
            );

    final month =
        value.month
            .toString()
            .padLeft(
              2,
              "0",
            );

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

    return "$day/$month/${value.year} "
        "$hour:$minute";
  }


  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final title =
        _titleController.text
            .trim();

    if (title.length < 2) {
      _showMessage(
        "Add an event title.",
      );

      return;
    }

    final venue =
        _selectedVenue;

    if (venue == null) {
      _showMessage(
        "Choose a venue.",
      );

      return;
    }

    final startsAt =
        _startsAt;

    if (startsAt == null) {
      _showMessage(
        "Choose the event start time.",
      );

      return;
    }

    if (!startsAt.isAfter(
      DateTime.now(),
    )) {
      _showMessage(
        "Event start time must "
        "be in the future.",
      );

      return;
    }

    if (
        _endsAt != null &&
        !_endsAt!.isAfter(
          startsAt,
        )) {
      _showMessage(
        "Event end time must be "
        "after its start time.",
      );

      return;
    }

    _draftSaveDebounce?.cancel();

      await _saveDraft();

      if (!mounted) {
        return;
      }

      FocusScope.of(
        context,
      ).unfocus();

      setState(() {
        _submitting =
            true;
      });

      setState(() {
        _submitting =
            true;
      });

    try {
      final event =
          await ApiService.createEvent(
        title:
            title,

        // This is now always the ID of
        // the selected venues_v2 record.
        venueId:
            venue.id,

        startsAt:
            startsAt,

        endsAt:
            _endsAt,

        description:
            _descriptionController.text
                .trim(),

        posterUrl:
            _posterUrlController.text
                .trim(),

        ticketUrl:
            _ticketUrlController.text
                .trim(),

        tags:
            _tags(),
      );
      
      _draftSaveDebounce?.cancel();

      await DraftStorageService
          .clearCreateEventDraft();

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(
        event,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting =
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
        _submitting =
            false;
      });

      _showMessage(
        "Couldn't create event.",
      );
    }
  }


  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          "Create Event",
        ),
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            16,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                "Event details",
                style:
                    Theme.of(
                  context,
                )
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              TextField(
                controller:
                    _titleController,

                maxLength:
                    120,

                textCapitalization:
                    TextCapitalization
                        .sentences,

                decoration:
                    const InputDecoration(
                  labelText:
                      "Event title",

                  hintText:
                      "Friday Night Live",

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              TextField(
                controller:
                    _descriptionController,

                maxLength:
                    2000,

                minLines:
                    3,

                maxLines:
                    6,

                textCapitalization:
                    TextCapitalization
                        .sentences,

                decoration:
                    const InputDecoration(
                  labelText:
                      "Description",

                  hintText:
                      "Tell people what "
                      "the night is about...",

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              // ---------------------------------------------------------------
              // Venue
              // ---------------------------------------------------------------

              Text(
                "Venue",
                style:
                    Theme.of(
                  context,
                )
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                "Choose a venue already "
                "listed on YIYO.",
                style:
                    TextStyle(
                  color:
                      Colors.grey[
                    600
                  ],

                  fontSize:
                      12,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              if (_selectedVenue != null)
                Card(
                  child:
                      ListTile(
                    leading:
                        const Icon(
                      Icons
                          .location_on_outlined,
                    ),

                    title:
                        Text(
                      _selectedVenue!
                          .name,

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    subtitle:
                        _selectedVenue!
                                .address
                                .isEmpty
                            ? null
                            : Text(
                                _selectedVenue!
                                    .address,
                              ),

                    trailing:
                        TextButton(
                      onPressed:
                          _submitting
                              ? null
                              : _changeVenue,

                      child:
                          const Text(
                        "Change",
                      ),
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller:
                      _venueSearchController,

                  enabled:
                      !_submitting,

                  textInputAction:
                      TextInputAction.search,

                  onSubmitted:
                      (_) =>
                          _searchVenues(),

                  decoration:
                      InputDecoration(
                    labelText:
                        "Search venue",

                    hintText:
                        "Kopano Lounge",

                    border:
                        const OutlineInputBorder(),

                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),

                    suffixIcon:
                        IconButton(
                      tooltip:
                          "Search",

                      onPressed:
                          _searchingVenues ||
                                  _submitting
                              ? null
                              : _searchVenues,

                      icon:
                          const Icon(
                        Icons.search,
                      ),
                    ),
                  ),
                ),

                if (_searchingVenues)
                  const Padding(
                    padding:
                        EdgeInsets.all(
                      20,
                    ),

                    child:
                        Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  ),

                if (_venueSearchError !=
                    null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 10,
                    ),

                    child:
                        Text(
                      _venueSearchError!,

                      style:
                          TextStyle(
                        color:
                            Theme.of(
                          context,
                        )
                                .colorScheme
                                .error,
                      ),
                    ),
                  ),

                if (_venueResults
                    .isNotEmpty)
                  Container(
                    constraints:
                        const BoxConstraints(
                      maxHeight:
                          300,
                    ),

                    margin:
                        const EdgeInsets.only(
                      top: 10,
                    ),

                    decoration:
                        BoxDecoration(
                      border:
                          Border.all(
                        color:
                            Theme.of(
                          context,
                        )
                                .colorScheme
                                .outlineVariant,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),

                    child:
                        ListView.separated(
                      shrinkWrap:
                          true,

                      itemCount:
                          _venueResults
                              .length,

                      separatorBuilder:
                          (
                            context,
                            index,
                          ) =>
                              const Divider(
                        height:
                            1,
                      ),

                      itemBuilder:
                          (
                            context,
                            index,
                          ) {
                        final venue =
                            _venueResults[
                          index
                        ];

                        return ListTile(
                          leading:
                              const Icon(
                            Icons
                                .place_outlined,
                          ),

                          title:
                              Text(
                            venue.name,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          subtitle:
                              venue.address
                                      .isEmpty
                                  ? null
                                  : Text(
                                      venue.address,

                                      maxLines:
                                          2,

                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),

                          trailing:
                              const Icon(
                            Icons
                                .chevron_right,
                          ),

                          onTap:
                              () =>
                                  _selectVenue(
                            venue,
                          ),
                        );
                      },
                    ),
                  ),
              ],

              const SizedBox(
                height: 24,
              ),

              // ---------------------------------------------------------------
              // Date / time
              // ---------------------------------------------------------------

              Text(
                "When",
                style:
                    Theme.of(
                  context,
                )
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              _DateTimeCard(
                title:
                    "Starts",

                value:
                    _dateTimeLabel(
                  _startsAt,
                ),

                icon:
                    Icons
                        .event_outlined,

                onTap:
                    _pickStartTime,
              ),

              const SizedBox(
                height: 8,
              ),

              _DateTimeCard(
                title:
                    "Ends",

                value:
                    _dateTimeLabel(
                  _endsAt,
                ),

                icon:
                    Icons
                        .schedule_outlined,

                onTap:
                    _pickEndTime,

                optional:
                    true,

                onClear:
                  _endsAt == null
                      ? null
                      : () {
                          setState(() {
                            _endsAt =
                                null;
                          });

                          _scheduleDraftSave();
                        },
                      ),

              const SizedBox(
                height: 24,
              ),

              // ---------------------------------------------------------------
              // Optional
              // ---------------------------------------------------------------

              Text(
                "Optional",
                style:
                    Theme.of(
                  context,
                )
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              TextField(
                controller:
                    _tagsController,

                enabled:
                    !_submitting,

                decoration:
                    const InputDecoration(
                  labelText:
                      "Tags",

                  hintText:
                      "Amapiano, Hip Hop, "
                      "Ladies Night",

                  helperText:
                      "Separate tags with commas",

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              TextField(
                controller:
                    _ticketUrlController,

                enabled:
                    !_submitting,

                keyboardType:
                    TextInputType.url,

                decoration:
                    const InputDecoration(
                  labelText:
                      "Ticket link",

                  hintText:
                      "https://...",

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              TextField(
                controller:
                    _posterUrlController,

                enabled:
                    !_submitting,

                keyboardType:
                    TextInputType.url,

                decoration:
                    const InputDecoration(
                  labelText:
                      "Poster image URL",

                  hintText:
                      "https://...",

                  helperText:
                      "Image uploads can be "
                      "added later.",

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              SizedBox(
                width:
                    double.infinity,

                height:
                    52,

                child:
                    FilledButton.icon(
                  onPressed:
                      _submitting
                          ? null
                          : _submit,

                  icon:
                      _submitting
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
                          : const Icon(
                              Icons
                                  .publish_outlined,
                            ),

                  label:
                      Text(
                    _submitting
                        ? "Creating..."
                        : "Create Event",
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DateTimeCard
    extends StatelessWidget {
  final String title;

  final String value;

  final IconData icon;

  final VoidCallback onTap;

  final bool optional;

  final VoidCallback? onClear;


  const _DateTimeCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
    this.optional = false,
    this.onClear,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child:
          ListTile(
        onTap:
            onTap,

        leading:
            Icon(
          icon,
        ),

        title:
            Text(
          optional
              ? "$title (optional)"
              : title,
        ),

        subtitle:
            Text(
          value,
        ),

        trailing:
            onClear != null
                ? IconButton(
                    tooltip:
                        "Clear",

                    onPressed:
                        onClear,

                    icon:
                        const Icon(
                      Icons.close,
                    ),
                  )
                : const Icon(
                    Icons
                        .chevron_right,
                  ),
      ),
    );
  }
}