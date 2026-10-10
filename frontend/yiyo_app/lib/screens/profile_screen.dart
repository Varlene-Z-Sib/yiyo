import 'package:flutter/material.dart';

import '../models/user_contribution.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_access_summary.dart';



class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}


class _ProfileScreenState
    extends State<ProfileScreen> {
  bool _isLoading = true;

  bool _showAllContributions = false;
  bool _isDeletingAccount = false;

  final ScrollController _scrollController =
    ScrollController();

    bool _showBackToTop = false;

  String? _error;

  UserProfile? _profile;

  ProfileAccessSummary
    _accessSummary =
        ProfileAccessSummary.empty;

  List<UserContribution> _contributions = [];


  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _handleScroll,
    );

    _loadProfile();
  }

void _handleScroll() {
  if (!_scrollController.hasClients) {
    return;
  }

  final shouldShow =
      _showAllContributions &&
      _scrollController.offset > 500;

  if (
      shouldShow !=
      _showBackToTop) {
    setState(() {
      _showBackToTop =
          shouldShow;
    });
  }
}


Future<void> _scrollToTop() async {
  if (!_scrollController.hasClients) {
    return;
  }

  await _scrollController.animateTo(
    0,
    duration:
        const Duration(
      milliseconds: 450,
    ),
    curve:
        Curves.easeOutCubic,
  );
}

@override
void dispose() {
  _scrollController.removeListener(
    _handleScroll,
  );

  _scrollController.dispose();

  super.dispose();
}

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // These are the core Profile requests.
      // If either fails, Profile genuinely
      // cannot load correctly.
      final profile =
          await ApiService
              .getMyProfile();

      final contributions =
          await ApiService
              .getMyContributions();

      // Access/role information is optional
      // UI metadata.
      //
      // If this request fails, Profile should
      // STILL load normally.
      ProfileAccessSummary access =
          ProfileAccessSummary.empty;

      try {
        access =
            await ApiService
                .getMyAccessSummary();
      } catch (e) {
        debugPrint(
          "[PROFILE] Access summary "
          "failed: $e",
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profile =
            profile;

        _contributions =
            contributions;

        _accessSummary =
            access;

        _isLoading =
            false;

        _error =
            null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      debugPrint(
        "[PROFILE] Profile load "
        "failed: $e",
      );

      setState(() {
        _error =
            e.toString();

        _isLoading =
            false;
      });
    }
  }


  int _contributionCount(
    UserProfile profile,
  ) {
    // Normally reportCount is authoritative.
    //
    // This fallback prevents the UI from
    // showing "0" when historical reports
    // already loaded successfully but the
    // materialized user counter is stale.
    if (
        _contributions.length >
        profile.reportCount) {
      return _contributions.length;
    }

    return profile.reportCount;
  }


  Future<void> _openEditProfile(
    UserProfile profile,
  ) async {
    final updatedProfile =
        await Navigator.of(
      context,
    ).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) =>
            _EditProfileScreen(
          profile:
              profile,
        ),
      ),
    );

    if (
        updatedProfile == null ||
        !mounted) {
      return;
    }

    setState(() {
      _profile =
          updatedProfile;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content:
            Text(
          "Profile updated",
        ),
      ),
    );
  }


  Future<void> _signOut() async {
    final shouldSignOut =
        await showDialog<bool>(
      context:
          context,

      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            "Sign out?",
          ),

          content:
              const Text(
            "You can sign back in at any time.",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  false,
                );
              },
              child:
                  const Text(
                "Cancel",
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  true,
                );
              },
              child:
                  const Text(
                "Sign out",
              ),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) {
      return;
    }

    await AuthService.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).popUntil(
      (route) =>
          route.isFirst,
    );
  }

Future<bool> _confirmAccountDeletion() async {
  final result =
      await showDialog<bool>(
    context:
        context,

    builder:
        (context) {
      return AlertDialog(
        title:
            const Text(
          "Delete your account?",
        ),

        content:
            const Text(
          "This permanently removes your "
          "YIYO account and login.\n\n"
          "Your username will be released, "
          "your promoter/business access will "
          "be removed, and your Hype/Going "
          "activity will be deleted.\n\n"
          "Historical vibe updates may remain "
          "anonymously so community venue data "
          "isn't corrupted. Published events "
          "may also remain without your account "
          "identity.",
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pop(
                false,
              );
            },
            child:
                const Text(
              "Keep account",
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

            onPressed: () {
              Navigator.of(
                context,
              ).pop(
                true,
              );
            },

            child:
                const Text(
              "Continue",
            ),
          ),
        ],
      );
    },
  );

  return result == true;
}


Future<String?>
    _requestDeletionPassword() async {
  String passwordValue = "";

  var obscurePassword = true;

  final password =
      await showDialog<String>(
    context:
        context,

    barrierDismissible:
        false,

    builder:
        (dialogContext) {
      return StatefulBuilder(
        builder:
            (
          context,
          setDialogState,
        ) {
          return AlertDialog(
            title:
                const Text(
              "Confirm your password",
            ),

            content:
                Column(
              mainAxisSize:
                  MainAxisSize.min,

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  "Enter your password to "
                  "confirm this is really you.",
                ),

                const SizedBox(
                  height: 16,
                ),

                TextField(
                  autofocus:
                      true,

                  obscureText:
                      obscurePassword,

                  textInputAction:
                      TextInputAction.done,

                  onChanged:
                      (value) {
                    passwordValue =
                        value;
                  },

                  onSubmitted:
                      (value) {
                    final clean =
                        value.trim();

                    if (clean.isEmpty) {
                      return;
                    }

                    FocusScope.of(
                      dialogContext,
                    ).unfocus();

                    Navigator.of(
                      dialogContext,
                    ).pop(
                      value,
                    );
                  },

                  decoration:
                      InputDecoration(
                    labelText:
                        "Password",

                    prefixIcon:
                        const Icon(
                      Icons
                          .lock_outline,
                    ),

                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setDialogState(
                          () {
                            obscurePassword =
                                !obscurePassword;
                          },
                        );
                      },

                      icon:
                          Icon(
                        obscurePassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),

                    border:
                        const OutlineInputBorder(),
                  ),
                ),
              ],
            ),

            actions: [
              TextButton(
                onPressed: () {
                  FocusScope.of(
                    dialogContext,
                  ).unfocus();

                  Navigator.of(
                    dialogContext,
                  ).pop();
                },

                child:
                    const Text(
                  "Cancel",
                ),
              ),

              FilledButton(
                onPressed: () {
                  if (passwordValue
                      .isEmpty) {
                    return;
                  }

                  FocusScope.of(
                    dialogContext,
                  ).unfocus();

                  Navigator.of(
                    dialogContext,
                  ).pop(
                    passwordValue,
                  );
                },

                child:
                    const Text(
                  "Verify",
                ),
              ),
            ],
          );
        },
      );
    },
  );

  // Give the dialog route + keyboard/focus
  // overlay time to fully detach before
  // account deletion can rebuild AuthGate.
  FocusManager.instance.primaryFocus
      ?.unfocus();

  await Future<void>.delayed(
    const Duration(
      milliseconds: 250,
    ),
  );

  return password;
}


String _accountDeletionError(
  Object error,
) {
  if (error is ApiException) {
    return error.message;
  }

  if (
      error is FirebaseAuthException) {
    switch (error.code) {
      case "wrong-password":
      case "invalid-credential":
        return "That password is incorrect.";

      case "user-mismatch":
        return "Choose the Google account "
            "linked to this YIYO account.";

      case "network-request-failed":
        return "Check your internet connection "
            "and try again.";

      case "too-many-requests":
        return "Too many attempts. Try again "
            "shortly.";

      case "requires-recent-login":
        return "Please verify your account "
            "again before deleting it.";

      default:
        final message =
            error.message?.trim();

        if (
            message != null &&
            message.isNotEmpty) {
          return message;
        }
    }
  }

  return "Couldn't delete your account. "
      "Nothing else needs to be changed; "
      "please try again.";
}


Future<void> _deleteAccount() async {
  if (_isDeletingAccount) {
    return;
  }

  final confirmed =
      await _confirmAccountDeletion();

  if (!confirmed || !mounted) {
    return;
  }

  String? password;

  if (AuthService.usesPasswordProvider) {
    password =
        await _requestDeletionPassword();

    if (
        password == null ||
        password.isEmpty ||
        !mounted) {
      return;
    }
  }

  if (
      !AuthService.usesPasswordProvider &&
      !AuthService.usesGoogleProvider) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content:
            Text(
          "This sign-in method can't be "
          "verified for account deletion yet.",
        ),
      ),
    );

    return;
  }

  setState(() {
    _isDeletingAccount =
        true;
  });

  try {
    if (AuthService.usesPasswordProvider) {
      await AuthService
          .reauthenticateWithPassword(
        password!,
      );
    } else {
      final verified =
          await AuthService
              .reauthenticateWithGoogle();

      if (!verified) {
        if (mounted) {
          setState(() {
            _isDeletingAccount =
                false;
          });
        }

        return;
      }
    }

    await ApiService
    .deleteMyAccount();

    await AuthService
        .finishDeletedAccountSession();

    if (!mounted) {
      return;
    }

    // Profile is a pushed route sitting above
    // the root AuthGate.
    //
    // Firebase sign-out makes AuthGate switch
    // to AuthScreen. Removing the pushed routes
    // reveals that existing auth screen
    // immediately instead of waiting for
    // another user interaction.
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil(
      (route) =>
          route.isFirst,
    );

    return;
  } catch (error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isDeletingAccount =
          false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          _accountDeletionError(
            error,
          ),
        ),
      ),
    );
  }
}

  String _displayValue(
    String value,
  ) {
    final trimmed =
        value.trim();

    return trimmed.isEmpty
        ? "Unknown"
        : trimmed;
  }

  Color _statusColor(
    String status,
  ) {
    switch (
        status.toLowerCase()) {
      case "flagged":
        return Colors.orange;

      case "removed":
        return Colors.red;

      default:
        return Colors.green;
    }
  }


  String _statusLabel(
    String status,
  ) {
    switch (
        status.toLowerCase()) {
      case "flagged":
        return "Under review";

      case "removed":
        return "Removed";

      default:
        return "Active";
    }
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

      floatingActionButton:
          _showBackToTop
              ? FloatingActionButton.extended(
                  onPressed:
                      _scrollToTop,

                  heroTag:
                      "profile_back_to_top",

                  icon:
                      const Icon(
                    Icons
                        .keyboard_arrow_up,
                  ),

                  label:
                      const Text(
                    "Top",
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                )
              : null,

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
          "Profile",
          style:
              TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body:
          RefreshIndicator(
        onRefresh:
            _loadProfile,

        child:
            _buildBody(),
      ),
    );
  }


  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        children:
            const [
          SizedBox(
            height:
                220,
          ),

          Center(
            child:
                CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          24,
        ),

        children: [
          const SizedBox(
            height:
                80,
          ),

          const Icon(
            Icons
                .cloud_off_outlined,
            size:
                48,
          ),

          const SizedBox(
            height:
                16,
          ),

          const Text(
            "Couldn't load your profile",
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize:
                  20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
                8,
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
            ),
          ),

          const SizedBox(
            height:
                20,
          ),

          Center(
            child:
                FilledButton.icon(
              onPressed:
                  _loadProfile,

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
      );
    }

    final profile =
        _profile;

    if (profile == null) {
      return ListView(
        controller:
            _scrollController,

        physics:
            const AlwaysScrollableScrollPhysics(),

        children:
            const [
          SizedBox(
            height:
                120,
          ),

          Center(
            child:
                Text(
              "Profile unavailable",
            ),
          ),
        ],
      );
    }

    final count =
        _contributionCount(
      profile,
    );

    final visibleContributions =
        _showAllContributions
            ? _contributions
            : _contributions
                .take(
                  3,
                )
                .toList();

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32,
      ),

      children: [
        _buildProfileCard(
          profile,
          count,
        ),

        const SizedBox(
          height:
              28,
        ),

        _buildSectionHeader(
          title:
              "Account",
        ),

        const SizedBox(
          height:
              12,
        ),

        _buildAccountCard(
          profile,
        ),

        const SizedBox(
          height:
              30,
        ),

        _buildSectionHeader(
          title:
              "Your contributions",

          trailing:
              "$count",
        ),

        const SizedBox(
          height:
              6,
        ),

        if (_contributions.isNotEmpty)
          Text(
            _showAllContributions
                ? "Your contribution history"
                : "Your latest vibe updates",
            style:
                TextStyle(
              color:
                  Colors.grey[
                500
              ],
              fontSize:
                  13,
            ),
          ),

        const SizedBox(
          height:
              12,
        ),

        if (_contributions.isEmpty)
          _buildEmptyState()
        else ...[
          ...visibleContributions.map(
            _buildContributionCard,
          ),

          if (_contributions.length >
              3) ...[
            const SizedBox(
              height:
                  4,
            ),

            SizedBox(
              height:
                  50,
              child:
                  OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllContributions =
                        !_showAllContributions;

                    if (!_showAllContributions) {
                      _showBackToTop =
                          false;
                    }
                  });
                },

                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      Colors.white,

                  side:
                      BorderSide(
                    color:
                        Colors.white
                            .withValues(
                      alpha:
                          0.14,
                    ),
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      16,
                    ),
                  ),
                ),

                icon:
                    Icon(
                  _showAllContributions
                      ? Icons
                          .keyboard_arrow_up
                      : Icons
                          .history,
                ),

                label:
                    Text(
                  _showAllContributions
                      ? "Show recent only"
                      : "View all contributions",
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

Widget _buildAccessBadges() {
  if (!_accessSummary
      .hasBusinessAccess) {
    return const SizedBox.shrink();
  }

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (_accessSummary
          .superAdmin)
        _buildAccessBadge(
          icon:
              Icons
                  .admin_panel_settings_outlined,

          label:
              "Super Admin",
        ),

      if (_accessSummary
          .promoter)
        _buildAccessBadge(
          icon:
              Icons
                  .campaign_outlined,

          label:
              "Promoter",
        ),

      ..._accessSummary
          .managedVenues
          .map(
        (venue) =>
            _buildAccessBadge(
          icon:
              Icons
                  .storefront_outlined,

          label:
              "Venue Manager · "
              "${venue.name}",
        ),
      ),
    ],
  );
}

 Widget _buildProfileCard(
  UserProfile profile,
  int contributionCount,
) {
  final username =
      profile.username.trim();

  final fullName =
      profile.fullName.trim();

  final avatarText =
      username.isNotEmpty
          ? username
          : profile.displayLabel.trim();

  final initial =
      avatarText.isNotEmpty
          ? avatarText
              .substring(
                0,
                1,
              )
              .toUpperCase()
          : "Y";

  return Container(
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

      border:
          Border.all(
        color:
            Colors.white
                .withValues(
          alpha: 0.07,
        ),
      ),
    ),

    padding:
        const EdgeInsets.all(
      20,
    ),

    child:
        Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        // ---------------------------------------------------
        // Profile identity
        // ---------------------------------------------------

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,

          children: [
            Container(
              width: 64,
              height: 64,

              decoration:
                  const BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    Colors.white,
              ),

              alignment:
                  Alignment.center,

              child:
                  Text(
                initial,

                style:
                    const TextStyle(
                  color:
                      Colors.black,
                  fontSize:
                      26,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    username.isNotEmpty
                        ? "@$username"
                        : profile
                            .displayLabel,

                    maxLines: 1,

                    overflow:
                        TextOverflow
                            .ellipsis,

                    style:
                        const TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          -0.5,
                    ),
                  ),

                  if (fullName
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      fullName,

                      maxLines: 1,

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          TextStyle(
                        color:
                            Colors.grey[
                          400
                        ],

                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // ---------------------------------------------------
        // YIYO access / roles
        // ---------------------------------------------------

        if (_accessSummary
            .hasBusinessAccess) ...[
          const SizedBox(
            height: 16,
          ),

          _buildAccessBadges(),
        ],

        const SizedBox(
          height: 20,
        ),

        // ---------------------------------------------------
        // Edit profile
        // ---------------------------------------------------

        SizedBox(
          width:
              double.infinity,

          height:
              48,

          child:
              FilledButton.icon(
            onPressed: () =>
                _openEditProfile(
              profile,
            ),

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

            icon:
                const Icon(
              Icons.edit_outlined,
            ),

            label:
                const Text(
              "Edit profile",

              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 20,
        ),

        // ---------------------------------------------------
        // Profile stats
        // ---------------------------------------------------

        Row(
          children: [
            Expanded(
              child:
                  _buildStat(
                label:
                    "Contributor",

                value:
                    profile
                        .contributorLevel,

                icon:
                    Icons
                        .bolt_outlined,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  _buildStat(
                label:
                    "Vibe updates",

                value:
                    contributionCount
                        .toString(),

                icon:
                    Icons
                        .campaign_outlined,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildAccessBadge({
  required IconData icon,
  required String label,
}) {
  return Container(
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

      border:
          Border.all(
        color:
            Colors.white
                .withValues(
          alpha: 0.10,
        ),
      ),
    ),

    child:
        Row(
      mainAxisSize:
          MainAxisSize.min,

      children: [
        Icon(
          icon,
          size: 15,
        ),

        const SizedBox(
          width: 6,
        ),

        Text(
          label,
          style:
              const TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        color:
            Colors.white
                .withValues(
          alpha:
              0.06,
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size:
                20,
            color:
                Colors.grey[
              400
            ],
          ),

          const SizedBox(
            height:
                12,
          ),

          Text(
            value,
            maxLines:
                1,
            overflow:
                TextOverflow
                    .ellipsis,

            style:
                const TextStyle(
              fontSize:
                  18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height:
                3,
          ),

          Text(
            label,
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
    );
  }


  Widget _buildSectionHeader({
    required String title,
    String? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child:
              Text(
            title,
            style:
                const TextStyle(
              fontSize:
                  20,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  -0.3,
            ),
          ),
        ),

        if (trailing != null)
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal:
                  10,
              vertical:
                  5,
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
              trailing,
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
    );
  }


  Widget _buildEmptyState() {
    return Container(
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
          20,
        ),
      ),

      child:
          Column(
        children: [
          Container(
            width:
                54,
            height:
                54,

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
                  .bolt_outlined,
              size:
                  28,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          const Text(
            "No vibe updates yet",
            style:
                TextStyle(
              fontSize:
                  17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
                6,
          ),

          Text(
            "Update a venue's vibe and "
            "your contributions will appear here.",

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
        ],
      ),
    );
  }


  Widget _buildContributionCard(
    UserContribution contribution,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            10,
      ),

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

        border:
            Border.all(
          color:
              Colors.white
                  .withValues(
            alpha:
                0.05,
          ),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    Text(
                  contribution
                          .venueName
                          .trim()
                          .isEmpty
                      ? "Unknown venue"
                      : contribution
                          .venueName,

                  style:
                      const TextStyle(
                    fontSize:
                        16,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      9,
                  vertical:
                      5,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      _statusColor(
                    contribution
                        .status,
                  ).withValues(
                    alpha:
                        0.15,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                    Text(
                  _statusLabel(
                    contribution
                        .status,
                  ),

                  style:
                      TextStyle(
                    color:
                        _statusColor(
                      contribution
                          .status,
                    ),
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                12,
          ),

          Wrap(
            spacing:
                7,
            runSpacing:
                7,

            children: [
              _buildContributionChip(
                icon:
                    Icons
                        .local_fire_department_outlined,

                value:
                    _displayValue(
                  contribution
                      .yiyoStatus,
                ),
              ),

              _buildContributionChip(
                icon:
                    Icons
                        .groups_outlined,

                value:
                    _displayValue(
                  contribution
                      .crowdLevel,
                ),
              ),

              _buildContributionChip(
                icon:
                    Icons
                        .shield_outlined,

                value:
                    _displayValue(
                  contribution
                      .safetyLevel,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                12,
          ),

          _buildDetailRow(
            icon:
                Icons
                    .music_note_outlined,

            label:
                "Music",

            value:
                _displayValue(
              contribution
                  .musicType,
            ),
          ),

          const SizedBox(
            height:
                6,
          ),

          _buildDetailRow(
            icon:
                Icons
                    .people_outline,

            label:
                "Queue",

            value:
                _displayValue(
              contribution
                  .queueLength,
            ),
          ),

          if (contribution
              .comment
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height:
                  12,
            ),

            Container(
              width:
                  double.infinity,

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
                      0.04,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child:
                  Text(
                contribution
                    .comment,

                style:
                    TextStyle(
                  color:
                      Colors.grey[
                    300
                  ],
                  height:
                      1.35,
                ),
              ),
            ),
          ],

          const SizedBox(
            height:
                12,
          ),

          Row(
            children: [
              Icon(
                Icons
                    .schedule_outlined,
                size:
                    14,
                color:
                    Colors.grey[
                  600
                ],
              ),

              const SizedBox(
                width:
                    5,
              ),

              Text(
                contribution
                    .freshnessLabel(),

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
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildContributionChip({
    required IconData icon,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
        vertical:
            7,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white
                .withValues(
          alpha:
              0.06,
        ),

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
                15,
            color:
                Colors.grey[
              400
            ],
          ),

          const SizedBox(
            width:
                5,
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize:
                  12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size:
              17,
          color:
              Colors.grey[
            500
          ],
        ),

        const SizedBox(
          width:
              8,
        ),

        Text(
          "$label: ",
          style:
              TextStyle(
            color:
                Colors.grey[
              500
            ],
            fontSize:
                13,
          ),
        ),

        Expanded(
          child:
              Text(
            value,

            maxLines:
                1,

            overflow:
                TextOverflow
                    .ellipsis,

            style:
                const TextStyle(
              fontSize:
                  13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildAccountCard(
    UserProfile profile,
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
          20,
        ),
      ),

      child:
          Column(
        children: [
          ListTile(
            leading:
                Container(
              width:
                  42,
              height:
                  42,

              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withValues(
                  alpha:
                      0.06,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child:
                  const Icon(
                Icons
                    .mail_outline,
                size:
                    20,
              ),
            ),

            title:
                const Text(
              "Email",
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            subtitle:
                Text(
              profile.email
                      .trim()
                      .isEmpty
                  ? "Not available"
                  : profile.email,

              maxLines:
                  1,

              overflow:
                  TextOverflow
                      .ellipsis,
            ),
          ),

          Divider(
            height:
                1,

            color:
                Colors.white
                    .withValues(
              alpha:
                  0.06,
            ),
          ),

          ListTile(
            onTap:
                _signOut,

            leading:
                Container(
              width:
                  42,
              height:
                  42,

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
                  const Icon(
                Icons.logout,
                color:
                    Colors.redAccent,
                size:
                    20,
              ),
            ),

            title:
                const Text(
              "Sign out",
              style:
                  TextStyle(
                color:
                    Colors.redAccent,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            subtitle:
                const Text(
              "Sign in again whenever you're ready.",
            ),

            trailing:
                const Icon(
              Icons
                  .chevron_right,
            ),
          ),
          Divider(
            height: 1,
            color:
                Colors.white.withValues(
              alpha: 0.06,
            ),
          ),
          ListTile(
            onTap:
                _isDeletingAccount
                    ? null
                    : _deleteAccount,

            leading:
                Container(
              width:
                  42,
              height:
                  42,

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
                  const Icon(
                Icons
                    .delete_forever_outlined,
                color:
                    Colors.redAccent,
                size:
                    20,
              ),
            ),

            title:
                const Text(
              "Delete account",
              style:
                  TextStyle(
                color:
                    Colors.redAccent,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            subtitle:
                const Text(
              "Permanently remove your YIYO account.",
            ),

            trailing:
                _isDeletingAccount
                    ? const SizedBox(
                        width:
                            20,
                        height:
                            20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .chevron_right,
                      ),
          ),
        ],
      ),
    );
  }
}


class _EditProfileScreen
    extends StatefulWidget {
  final UserProfile profile;

  const _EditProfileScreen({
    required this.profile,
  });

  @override
  State<_EditProfileScreen>
      createState() =>
          _EditProfileScreenState();
}


class _EditProfileScreenState
    extends State<_EditProfileScreen> {
  late final TextEditingController
      _usernameController;

  late final TextEditingController
      _fullNameController;

  final FocusNode _usernameFocus =
      FocusNode();

  final FocusNode _fullNameFocus =
      FocusNode();

  bool _isSaving = false;

  String? _error;


  @override
  void initState() {
    super.initState();

    _usernameController =
        TextEditingController(
      text:
          widget.profile.username,
    );

    _fullNameController =
        TextEditingController(
      text:
          widget.profile.fullName,
    );
  }


  @override
  void dispose() {
    _usernameController.dispose();

    _fullNameController.dispose();

    _usernameFocus.dispose();

    _fullNameFocus.dispose();

    super.dispose();
  }


  bool _validUsername(
    String username,
  ) {
    return RegExp(
      r'^[A-Za-z0-9_]{3,24}$',
    ).hasMatch(
      username,
    );
  }


  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final username =
        _usernameController.text
            .trim()
            .replaceFirst(
              RegExp(
                r'^@+',
              ),
              '',
            );

    final fullName =
        _fullNameController.text
            .trim();

    if (!_validUsername(
      username,
    )) {
      setState(() {
        _error =
            "Username must be 3–24 characters "
            "using only letters, numbers, "
            "or underscores.";
      });

      _usernameFocus
          .requestFocus();

      return;
    }

    if (fullName.length > 80) {
      setState(() {
        _error =
            "Full name must be 80 characters "
            "or fewer.";
      });

      _fullNameFocus
          .requestFocus();

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
              .updateMyProfile(
        username:
            username,

        fullName:
            fullName,
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
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "Couldn't update your profile. "
            "Try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving =
              false;
        });
      }
    }
  }


  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText:
          label,

      hintText:
          hint,

      prefixText:
          prefixText,

      prefixIcon:
          Icon(
        icon,
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

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide(
          color:
              Colors.white
                  .withValues(
            alpha:
                0.06,
          ),
        ),
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
          width:
              1.4,
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
          "Edit profile",
          style:
              TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,

          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            30,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Your YIYO identity",
                style:
                    TextStyle(
                  fontSize:
                      25,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      -0.7,
                ),
              ),

              const SizedBox(
                height:
                    8,
              ),

              Text(
                "Your username is public. "
                "Your full name is account information "
                "and isn't your public YIYO identity.",

                style:
                    TextStyle(
                  color:
                      Colors.grey[
                    500
                  ],
                  height:
                      1.45,
                ),
              ),

              const SizedBox(
                height:
                    28,
              ),

              const Text(
                "Username",
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height:
                    8,
              ),

              TextField(
                controller:
                    _usernameController,

                focusNode:
                    _usernameFocus,

                enabled:
                    !_isSaving,

                autocorrect:
                    false,

                enableSuggestions:
                    false,

                textCapitalization:
                    TextCapitalization.none,

                textInputAction:
                    TextInputAction.next,

                onSubmitted:
                    (_) {
                  _fullNameFocus
                      .requestFocus();
                },

                decoration:
                    _decoration(
                  label:
                      "YIYO username",
                  hint:
                      "nightking",
                  prefixText:
                      "@",
                  icon:
                      Icons
                          .alternate_email,
                ),
              ),

              const SizedBox(
                height:
                    22,
              ),

              const Text(
                "Full name",
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height:
                    8,
              ),

              TextField(
                controller:
                    _fullNameController,

                focusNode:
                    _fullNameFocus,

                enabled:
                    !_isSaving,

                textCapitalization:
                    TextCapitalization.words,

                textInputAction:
                    TextInputAction.done,

                onSubmitted:
                    (_) =>
                        _save(),

                decoration:
                    _decoration(
                  label:
                      "Full name (optional)",
                  hint:
                      "Thabo Molefe",
                  icon:
                      Icons
                          .badge_outlined,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(
                  height:
                      18,
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
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height:
                    28,
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
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}