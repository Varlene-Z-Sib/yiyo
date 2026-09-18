import 'package:flutter/material.dart';

import '../models/user_contribution.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class ProfileScreen
    extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen>
      createState() =>
          _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  bool _isLoading = true;

  String? _error;

  UserProfile? _profile;

  List<UserContribution>
      _contributions = [];

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final profile =
          await ApiService
              .getMyProfile();

      final contributions =
          await ApiService
              .getMyContributions();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _contributions =
            contributions;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
      appBar: AppBar(
        title:
            const Text("Profile"),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const
            AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 220,
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
            const EdgeInsets.all(16),
        children: [
          const SizedBox(
            height: 80,
          ),

          const Icon(
            Icons.error_outline,
            size: 48,
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            _error!,
            textAlign:
                TextAlign.center,
          ),

          const SizedBox(
            height: 12,
          ),

          Center(
            child: TextButton(
              onPressed:
                  _loadProfile,
              child:
                  const Text(
                "Try again",
              ),
            ),
          ),
        ],
      );
    }

    final profile = _profile;

    if (profile == null) {
      return ListView(
        physics: const
            AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 120,
          ),
          Center(
            child: Text(
              "Profile unavailable",
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.all(16),
      children: [
        _buildProfileCard(
          profile,
        ),

        const SizedBox(
          height: 24,
        ),

        Row(
          children: [
            const Expanded(
              child: Text(
                "Your contributions",
                style:
                    TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            Text(
              "${profile.reportCount}",
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        if (_contributions.isEmpty)
          _buildEmptyState()
        else
          ..._contributions.map(
            _buildContributionCard,
          ),
      ],
    );
  }

  Widget _buildProfileCard(
    UserProfile profile,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    profile
                        .displayLabel
                        .substring(
                          0,
                          1,
                        )
                        .toUpperCase(),
                    style:
                        const TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        profile
                            .displayLabel,
                        style:
                            const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      if (profile.email
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          profile.email,
                          style:
                              TextStyle(
                            color: Colors
                                .grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _buildStat(
                    label:
                        "Contributor",
                    value: profile
                        .contributorLevel,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      _buildStat(
                    label:
                        "Updates",
                    value: profile
                        .reportCount
                        .toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        color: Colors.white
            .withValues(
          alpha: 0.06,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                TextStyle(
              color:
                  Colors.grey[500],
              fontSize: 12,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.bolt_outlined,
              size: 36,
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              "No contributions yet",
              style:
                  TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              "Update a venue's vibe "
              "and your contributions "
              "will appear here.",
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionCard(
    UserContribution contribution,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    contribution
                            .venueName
                            .trim()
                            .isEmpty
                        ? "Unknown venue"
                        : contribution
                            .venueName,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        _statusColor(
                      contribution
                          .status,
                    ).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                  ),
                  child: Text(
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
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              "${_displayValue(contribution.yiyoStatus)}"
              " • "
              "${_displayValue(contribution.crowdLevel)}"
              " • "
              "${_displayValue(contribution.safetyLevel)}",
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              "Music: "
              "${_displayValue(contribution.musicType)}",
            ),

            Text(
              "Queue: "
              "${_displayValue(contribution.queueLength)}",
            ),

            if (contribution
                .comment
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: 6,
              ),

              Text(
                contribution.comment,
              ),
            ],

            const SizedBox(
              height: 8,
            ),

            Text(
              contribution
                  .freshnessLabel(),
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}