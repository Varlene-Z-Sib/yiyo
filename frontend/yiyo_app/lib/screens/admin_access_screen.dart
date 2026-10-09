import 'package:flutter/material.dart';

import '../models/admin_user_access.dart';
import '../services/api_service.dart';


class AdminAccessScreen
    extends StatefulWidget {
  const AdminAccessScreen({
    super.key,
  });

  @override
  State<AdminAccessScreen>
      createState() =>
          _AdminAccessScreenState();
}


class _AdminAccessScreenState
    extends State<AdminAccessScreen> {
  final _usernameController =
      TextEditingController();

  final _venueSearchController =
    TextEditingController();

  List<AdminVenueOption>
      _venueResults = [];

  AdminVenueOption?
      _selectedVenue;

  bool _searchingVenues = false;

  AdminUserAccess? _user;

  bool _searching = false;

  String? _working;

  String? _error;


  @override
  void dispose() {
    _usernameController.dispose();
    _venueSearchController.dispose();

    super.dispose();
  }


  Future<void> _search() async {
    final username =
        _usernameController.text
            .trim();

    if (username.isEmpty) {
      setState(() {
        _error =
            "Enter a YIYO username.";
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

      _user =
          null;
    });

    try {
      final user =
          await ApiService
              .getAdminUserByUsername(
        username,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _user =
            user;

        _searching =
            false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            e.message;

        _searching =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "Couldn't look up that user.";

        _searching =
            false;
      });
    }
  }


  Future<void> _reload() async {
    final user =
        _user;

    if (user == null) {
      return;
    }

    final refreshed =
        await ApiService
            .getAdminUserByUsername(
      user.username,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _user =
          refreshed;

      _working =
          null;
    });
  }


  Future<void>
      _grantPromoter() async {
    final user =
        _user;

    if (user == null) {
      return;
    }

    setState(() {
      _working =
          "promoter";
    });

    try {
      await ApiService
          .grantBusinessMembership(
        userId:
            user.uid,

        role:
            "promoter",
      );

      await _reload();

      if (!mounted) {
        return;
      }

      _message(
        "Promoter access granted.",
      );
    } on ApiException catch (e) {
      _fail(
        e.message,
      );
    } catch (_) {
      _fail(
        "Couldn't grant promoter access.",
      );
    }
  }


  Future<void>
    _grantVenueManager() async {
      final user =
          _user;

      final venue =
          _selectedVenue;

      if (user == null) {
        return;
      }

      if (venue == null) {
        setState(() {
          _error =
              "Search for and select "
              "a venue first.";
        });

        return;
      }

      setState(() {
        _working =
            "venue_manager";

        _error =
            null;
      });

      try {
        await ApiService
            .grantBusinessMembership(
          userId:
              user.uid,

          role:
              "venue_manager",

          venueId:
              venue.id,
        );

        _venueSearchController.clear();

        setState(() {
          _venueResults =
              [];

          _selectedVenue =
              null;
        });

        await _reload();

        if (!mounted) {
          return;
        }

        _message(
          "Venue manager access granted "
          "for ${venue.name}.",
        );
      } on ApiException catch (e) {
        _fail(
          e.message,
        );
      } catch (_) {
        _fail(
          "Couldn't grant venue "
          "manager access.",
        );
      }
    }


  Future<void> _revoke(
    AdminMembership membership,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context:
          context,

      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            "Revoke access?",
          ),

          content:
              Text(
            membership.isPromoter
                ? "This user will no longer "
                    "have promoter access."
                : "This user will no longer "
                    "manage venue "
                    "${membership.venueId}.",
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
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),

              onPressed: () =>
                  Navigator.of(
                context,
              ).pop(
                true,
              ),

              child:
                  const Text(
                "Revoke",
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _working =
          membership.id;
    });

    try {
      await ApiService
          .revokeBusinessMembership(
        membership.id,
      );

      await _reload();

      if (!mounted) {
        return;
      }

      _message(
        "Access revoked.",
      );
    } on ApiException catch (e) {
      _fail(
        e.message,
      );
    } catch (_) {
      _fail(
        "Couldn't revoke access.",
      );
    }
  }


  void _fail(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _working =
          null;

      _error =
          message;
    });
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
          "Manage access",
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
            ListView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            32,
          ),

          children: [
            const Text(
              "Find a YIYO user",
              style:
                  TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              "Search by their unique "
              "@username.",
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  500
                ],
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            TextField(
              controller:
                  _usernameController,

              textInputAction:
                  TextInputAction.search,

              onSubmitted:
                  (_) =>
                      _search(),

              decoration:
                  InputDecoration(
                hintText:
                    "@username",

                prefixIcon:
                    const Icon(
                  Icons
                      .alternate_email,
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
                  alpha:
                      0.06,
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
                height: 24,
              ),

              const Center(
                child:
                    CircularProgressIndicator(),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(
                height: 16,
              ),

              Text(
                _error!,
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ],

            if (_user != null) ...[
              const SizedBox(
                height: 24,
              ),

              _buildUserCard(
                _user!,
              ),

              const SizedBox(
                height: 18,
              ),

              _buildPromoterCard(
                _user!,
              ),

              const SizedBox(
                height: 18,
              ),

              _buildVenueManagerCard(
                _user!,
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildUserCard(
    AdminUserAccess user,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
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
          Text(
            user.usernameLabel,
            style:
                const TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          if (user.fullName
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 5,
            ),

            Text(
              user.fullName,
            ),
          ],

          if (user.email
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 4,
            ),

            Text(
              user.email,
              style:
                  TextStyle(
                color:
                    Colors.grey[
                  500
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildPromoterCard(
    AdminUserAccess user,
  ) {
    final promoter =
        user.activePromoter;

    return _AccessCard(
      title:
          "Promoter",

      subtitle:
          promoter != null
              ? "This user can create "
                  "events across YIYO."
              : "Allow this user to "
                  "submit events.",

      active:
          promoter != null,

      working:
          _working ==
              "promoter" ||
          (
            promoter != null &&
            _working ==
                promoter.id
          ),

      onPressed:
          promoter != null
              ? () =>
                  _revoke(
                    promoter,
                  )
              : _grantPromoter,

      buttonLabel:
          promoter != null
              ? "Revoke promoter"
              : "Grant promoter",
    );
  }

  Future<void> _searchVenues() async {
  final query =
      _venueSearchController.text
          .trim();

  if (query.length < 2) {
    setState(() {
      _error =
          "Enter at least 2 characters "
          "to search for a venue.";
    });

    return;
  }

  FocusScope.of(
    context,
  ).unfocus();

  setState(() {
    _searchingVenues =
        true;

    _venueResults =
        [];

    _selectedVenue =
        null;

    _error =
        null;
  });

  try {
    final venues =
        await ApiService
            .searchAdminVenues(
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
        _error =
            "No stored YIYO venues "
            "matched that search.";
      }
    });
  } on ApiException catch (e) {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchingVenues =
          false;

      _error =
          e.message;
    });
  } catch (_) {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchingVenues =
          false;

      _error =
          "Couldn't search venues.";
    });
  }
}

  Widget _buildVenueManagerCard(
    AdminUserAccess user,
  ) {
    final memberships =
        user
            .venueManagerMemberships;

    return Container(
      padding:
          const EdgeInsets.all(
        18,
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
          const Text(
            "Venue manager",
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            "Venue managers can manage "
            "events for specific venues.",
            style:
                TextStyle(
              color:
                  Colors.grey[
                500
              ],
            ),
          ),

          if (memberships
              .isNotEmpty) ...[
            const SizedBox(
              height: 16,
            ),

            ...memberships.map(
              (membership) {
                return Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 8,
                  ),

                  padding:
                      const EdgeInsets.all(
                    12,
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
                      14,
                    ),
                  ),

                  child:
                      Row(
                    children: [
                      Expanded(
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              membership.venueName ??
                                    membership.venueId ??
                                    "Unknown venue",

                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              membership
                                      .isActive
                                  ? "ACTIVE"
                                  : membership
                                      .status
                                      .toUpperCase(),

                              style:
                                  TextStyle(
                                color:
                                    membership
                                            .isActive
                                        ? Colors
                                            .greenAccent
                                        : Colors
                                            .grey[
                                          500
                                        ],
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (membership
                          .isActive)
                        TextButton(
                          onPressed:
                              _working ==
                                      membership
                                          .id
                                  ? null
                                  : () =>
                                      _revoke(
                                        membership,
                                      ),

                          child:
                              const Text(
                            "Revoke",
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(
            height: 12,
          ),

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
        "Find venue",

    hintText:
        "Drama, Konka, Montana...",

    prefixIcon:
        const Icon(
      Icons.search,
    ),

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

    filled:
        true,

    fillColor:
        Colors.white
            .withValues(
      alpha: 0.05,
    ),

    border:
        OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(
        14,
      ),

      borderSide:
          BorderSide.none,
    ),
  ),
),

if (_searchingVenues) ...[
  const SizedBox(
    height: 14,
  ),

  const Center(
    child:
        CircularProgressIndicator(),
  ),
],

if (_venueResults
    .isNotEmpty) ...[
  const SizedBox(
    height: 12,
  ),

  Container(
    decoration:
        BoxDecoration(
      color:
          Colors.white
              .withValues(
        alpha:
            0.04,
      ),

      borderRadius:
          BorderRadius.circular(
        14,
      ),
    ),

    child:
        Column(
      children:
          _venueResults.map(
        (venue) {
          final selected =
              _selectedVenue?.id ==
              venue.id;

          return ListTile(
            onTap: () {
                setState(() {
                  _selectedVenue =
                      venue;

                  // Hide the long results list
                  // once a venue is selected.
                  _venueResults =
                      [];

                  // Leave the chosen venue's
                  // name in the search box.
                  _venueSearchController.text =
                      venue.name;
                });

                FocusScope.of(
                  context,
                ).unfocus();
              },

            leading:
                Icon(
              selected
                  ? Icons
                      .radio_button_checked
                  : Icons
                      .radio_button_off,

              color:
                  selected
                      ? Colors.white
                      : Colors.grey,
            ),

            title:
                Text(
              venue.name,

              style:
                  TextStyle(
                fontWeight:
                    selected
                        ? FontWeight.w900
                        : FontWeight.w600,
              ),
            ),

            subtitle:
                venue.address
                        .trim()
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
          );
        },
      ).toList(),
    ),
  ),
],

if (_selectedVenue != null) ...[
  const SizedBox(
    height: 12,
  ),

  Container(
    width:
        double.infinity,

    padding:
        const EdgeInsets.all(
      13,
    ),

    decoration:
        BoxDecoration(
      color:
          Colors.green
              .withValues(
        alpha:
            0.10,
      ),

      borderRadius:
          BorderRadius.circular(
        14,
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
                  fontSize:
                      11,
                  color:
                      Colors.greenAccent,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                _selectedVenue!
                    .name,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedVenue =
                  null;

              _venueResults =
                  [];

              _venueSearchController
                  .clear();
            });
          },

          child:
              const Text(
            "Change",
          ),
        ),
      ],
    ),
  ),
],

const SizedBox(
  height: 12,
),

SizedBox(
  width:
      double.infinity,

  child:
      OutlinedButton.icon(
    onPressed:
        _working != null ||
                _selectedVenue ==
                    null
            ? null
            : _grantVenueManager,

    icon:
        const Icon(
      Icons
          .storefront_outlined,
    ),

    label:
        Text(
      _selectedVenue == null
          ? "Select a venue first"
          : "Grant venue manager access",
    ),
  ),
),

          const SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }
}


class _AccessCard
    extends StatelessWidget {
  final String title;

  final String subtitle;

  final bool active;

  final bool working;

  final String buttonLabel;

  final VoidCallback onPressed;


  const _AccessCard({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.working,
    required this.buttonLabel,
    required this.onPressed,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
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
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      (
                        active
                            ? Colors.green
                            : Colors.grey
                      ).withValues(
                    alpha:
                        0.12,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                    Text(
                  active
                      ? "ACTIVE"
                      : "NOT ACTIVE",

                  style:
                      TextStyle(
                    color:
                        active
                            ? Colors.greenAccent
                            : Colors.grey[
                                500
                              ],

                    fontSize: 10,

                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            subtitle,
            style:
                TextStyle(
              color:
                  Colors.grey[
                500
              ],
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          SizedBox(
            width:
                double.infinity,

            child:
                OutlinedButton(
              onPressed:
                  working
                      ? null
                      : onPressed,

              child:
                  working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          buttonLabel,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}