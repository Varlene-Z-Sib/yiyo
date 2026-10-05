import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/venue.dart';
import '../services/api_service.dart';


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
    extends State<CreateEventScreen> {
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

  Venue? _selectedVenue;

  List<Venue> _venueResults = [];

  DateTime? _startsAt;
  DateTime? _endsAt;

  Position? _position;

  bool _searchingVenues = false;
  bool _submitting = false;

  String? _venueSearchError;


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueSearchController.dispose();
    _ticketUrlController.dispose();
    _posterUrlController.dispose();
    _tagsController.dispose();

    super.dispose();
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


  Future<Position?>
      _getPosition() async {
    if (_position != null) {
      return _position;
    }

    final serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showMessage(
        "Turn on location services "
        "to search for venues.",
      );

      return null;
    }

    var permission =
        await Geolocator
            .checkPermission();

    if (
        permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator
              .requestPermission();
    }

    if (
        permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission
                .deniedForever) {
      _showMessage(
        "Location permission is "
        "required for venue search.",
      );

      return null;
    }

    try {
      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      _position = position;

      return position;
    } catch (_) {
      _showMessage(
        "Couldn't get your location.",
      );

      return null;
    }
  }


  Future<void> _searchVenues()
      async {
    final query =
        _venueSearchController
            .text
            .trim();

    if (query.length < 2) {
      _showMessage(
        "Enter at least 2 characters.",
      );

      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _searchingVenues = true;
      _venueSearchError = null;
      _venueResults = [];
    });

    final position =
        await _getPosition();

    if (position == null) {
      if (mounted) {
        setState(() {
          _searchingVenues = false;
        });
      }

      return;
    }

    try {
      final result =
          await ApiService
              .searchVenues(
        query:
            query,
        lat:
            position.latitude,
        lng:
            position.longitude,
        enrichArea:
            false,
      );

      final Venue? bestMatch =
          result["best_match"]
              as Venue?;

      final related =
          result["related_venues"]
                  as List<Venue>? ??
              [];

      final venues =
          <Venue>[];

      final seen =
          <String>{};

      if (bestMatch != null) {
        venues.add(
          bestMatch,
        );

        seen.add(
          bestMatch.id,
        );
      }

      for (final venue in related) {
        if (!seen.contains(
          venue.id,
        )) {
          venues.add(
            venue,
          );

          seen.add(
            venue.id,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _venueResults = venues;
        _searchingVenues = false;

        if (venues.isEmpty) {
          _venueSearchError =
              "No matching venues found.";
        }
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _venueSearchError =
            e.message;

        _searchingVenues = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _venueSearchError =
            "Venue search failed.";

        _searchingVenues = false;
      });
    }
  }


  Future<DateTime?>
      _pickDateTime({
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

    if (date == null ||
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

    if (value == null ||
        !mounted) {
      return;
    }

    setState(() {
      _startsAt = value;

      if (
          _endsAt != null &&
          !_endsAt!.isAfter(
            value,
          )) {
        _endsAt = null;
      }
    });
  }


  Future<void>
      _pickEndTime() async {
    final start =
        _startsAt;

    if (start == null) {
      _showMessage(
        "Choose the event start time first.",
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

    if (value == null ||
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
      _endsAt = value;
    });
  }


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
            .take(8)
            .toList();

    return tags;
  }


  Future<void> _submit()
      async {
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

    setState(() {
      _submitting = true;
    });

    try {
      final event =
          await ApiService
              .createEvent(
        title:
            title,

        venueId:
            venue.id,

        startsAt:
            startsAt,

        endsAt:
            _endsAt,

        description:
            _descriptionController
                .text
                .trim(),

        posterUrl:
            _posterUrlController
                .text
                .trim(),

        ticketUrl:
            _ticketUrlController
                .text
                .trim(),

        tags:
            _tags(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        event,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      _showMessage(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      _showMessage(
        "Couldn't create event.",
      );
    }
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
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                "Event details",
                style:
                    Theme.of(context)
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

              Text(
                "Venue",
                style:
                    Theme.of(context)
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

              if (_selectedVenue !=
                  null)
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
                    ),
                    subtitle:
                        Text(
                      _selectedVenue!
                          .address,
                    ),
                    trailing:
                        IconButton(
                      tooltip:
                          "Change venue",
                      onPressed:
                          () {
                        setState(() {
                          _selectedVenue =
                              null;
                        });
                      },
                      icon:
                          const Icon(
                        Icons.close,
                      ),
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller:
                      _venueSearchController,
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
                    suffixIcon:
                        IconButton(
                      onPressed:
                          _searchingVenues
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
                        const EdgeInsets
                            .only(
                      top: 10,
                    ),
                    child:
                        Text(
                      _venueSearchError!,
                      style:
                          TextStyle(
                        color:
                            Theme.of(context)
                                .colorScheme
                                .error,
                      ),
                    ),
                  ),

                if (_venueResults
                    .isNotEmpty)
                  Card(
                    margin:
                        const EdgeInsets.only(
                      top: 10,
                    ),
                    child:
                        Column(
                      children:
                          _venueResults
                              .take(8)
                              .map(
                                (venue) =>
                                    ListTile(
                                  leading:
                                      const Icon(
                                    Icons
                                        .place_outlined,
                                  ),
                                  title:
                                      Text(
                                    venue.name,
                                  ),
                                  subtitle:
                                      Text(
                                    venue.address,
                                    maxLines:
                                        2,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),
                                  onTap:
                                      () {
                                    setState(() {
                                      _selectedVenue =
                                          venue;

                                      _venueResults =
                                          [];
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                  ),
              ],

              const SizedBox(
                height: 24,
              ),

              Text(
                "When",
                style:
                    Theme.of(context)
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
                          },
              ),

              const SizedBox(
                height: 24,
              ),

              Text(
                "Optional",
                style:
                    Theme.of(context)
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