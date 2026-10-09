import 'package:flutter/material.dart';

import '../models/venue_lookup_option.dart';
import '../services/api_service.dart';


class VenueRegistryPicker
    extends StatefulWidget {
  final VenueLookupOption? selectedVenue;

  final ValueChanged<VenueLookupOption>
      onSelected;


  const VenueRegistryPicker({
    super.key,
    required this.selectedVenue,
    required this.onSelected,
  });


  @override
  State<VenueRegistryPicker>
      createState() =>
          _VenueRegistryPickerState();
}


class _VenueRegistryPickerState
    extends State<VenueRegistryPicker> {
  final _controller =
      TextEditingController();

  List<VenueLookupOption> _results = [];

  bool _searching = false;

  String? _error;


  @override
  void initState() {
    super.initState();

    final selected =
        widget.selectedVenue;

    if (selected != null) {
      _controller.text =
          selected.name;
    }
  }


  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }


  Future<void> _search() async {
    final query =
        _controller.text
            .trim();

    if (query.length < 2) {
      setState(() {
        _error =
            "Enter at least 2 characters.";
      });

      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _searching =
          true;

      _error =
          null;

      _results =
          [];
    });

    try {
      final results =
          await ApiService
              .searchVenueRegistry(
        query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _results =
            results;

        _searching =
            false;

        if (results.isEmpty) {
          _error =
              "No YIYO venues matched "
              "that search.";
        }
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searching =
            false;

        _error =
            e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searching =
            false;

        _error =
            "Couldn't search venues.";
      });
    }
  }


  void _select(
    VenueLookupOption venue,
  ) {
    widget.onSelected(
      venue,
    );

    setState(() {
      _controller.text =
          venue.name;

      // Collapse long search results
      // once a venue is selected.
      _results =
          [];

      _error =
          null;
    });

    FocusScope.of(
      context,
    ).unfocus();
  }


  void _change() {
    _controller.clear();

    setState(() {
      _results =
          [];

      _error =
          null;
    });
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    final selected =
        widget.selectedVenue;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          "Venue",
          style:
              TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          "Choose a venue already "
          "listed on YIYO.",
          style:
              TextStyle(
            color:
                Colors.grey[
              500
            ],
            fontSize: 12,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        TextField(
          controller:
              _controller,

          textInputAction:
              TextInputAction.search,

          onSubmitted:
              (_) =>
                  _search(),

          decoration:
              InputDecoration(
            hintText:
                "Search venue",

            prefixIcon:
                const Icon(
              Icons.search,
            ),

            suffixIcon:
                IconButton(
              onPressed:
                  _searching
                      ? null
                      : _search,

              icon:
                  const Icon(
                Icons.search,
              ),
            ),

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
          ),
        ),

        if (_searching) ...[
          const SizedBox(
            height: 14,
          ),

          const Center(
            child:
                CircularProgressIndicator(),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(
            height: 10,
          ),

          Text(
            _error!,
            style:
                const TextStyle(
              color:
                  Colors.redAccent,
              fontSize:
                  12,
            ),
          ),
        ],

        if (_results.isNotEmpty) ...[
          const SizedBox(
            height: 10,
          ),

          Container(
            constraints:
                const BoxConstraints(
              maxHeight: 280,
            ),

            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withValues(
                alpha: 0.04,
              ),

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child:
                ListView.builder(
              shrinkWrap:
                  true,

              itemCount:
                  _results.length,

              itemBuilder:
                  (
                    context,
                    index,
                  ) {
                final venue =
                    _results[
                  index
                ];

                return ListTile(
                  onTap: () =>
                      _select(
                    venue,
                  ),

                  leading:
                      const Icon(
                    Icons
                        .location_on_outlined,
                  ),

                  title:
                      Text(
                    venue.name,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  subtitle:
                      venue.address.isEmpty
                          ? null
                          : Text(
                              venue.address,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),

                  trailing:
                      const Icon(
                    Icons
                        .chevron_right,
                  ),
                );
              },
            ),
          ),
        ],

        if (selected != null) ...[
          const SizedBox(
            height: 12,
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
                  Colors.green
                      .withValues(
                alpha: 0.10,
              ),

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child:
                Row(
              children: [
                const Icon(
                  Icons
                      .check_circle_outline,
                  color:
                      Colors.greenAccent,
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Selected venue",
                        style:
                            TextStyle(
                          color:
                              Colors.greenAccent,
                          fontSize:
                              11,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        selected.name,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      if (selected
                          .address
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          selected.address,
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
                    ],
                  ),
                ),

                TextButton(
                  onPressed:
                      _change,

                  child:
                      const Text(
                    "Change",
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}