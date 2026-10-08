import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';


class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
  });

  @override
  State<ProfileGate> createState() =>
      _ProfileGateState();
}


class _ProfileGateState
    extends State<ProfileGate> {
  bool _isLoading = true;

  String? _error;

  UserProfile? _profile;


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

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            error.toString();

        _isLoading =
            false;
      });
    }
  }


  void _profileCompleted(
    UserProfile profile,
  ) {
    setState(() {
      _profile =
          profile;
    });
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor:
            Color(
          0xFFFCFCFA,
        ),
        body: Center(
          child:
              CircularProgressIndicator(
            color:
                Colors.black,
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor:
            const Color(
          0xFFFCFCFA,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                24,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons
                        .cloud_off_outlined,
                    size:
                        44,
                    color:
                        Colors.black,
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  const Text(
                    "Couldn't load your YIYO profile.",
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.black,
                      fontSize:
                          18,
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
                        600
                      ],
                    ),
                  ),

                  const SizedBox(
                    height:
                        20,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        52,
                    child:
                        FilledButton(
                      onPressed:
                          _loadProfile,
                      style:
                          FilledButton
                              .styleFrom(
                        backgroundColor:
                            Colors.black,
                        foregroundColor:
                            Colors.white,
                      ),
                      child:
                          const Text(
                        "Try again",
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  TextButton(
                    onPressed: () =>
                        AuthService
                            .signOut(),
                    child:
                        const Text(
                      "Use another account",
                      style:
                          TextStyle(
                        color:
                            Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final profile =
        _profile;

    if (profile == null) {
      return const SizedBox();
    }

    if (profile.profileComplete) {
      return const MainNavigationScreen();
    }

    return CompleteProfileScreen(
      profile:
          profile,

      onCompleted:
          _profileCompleted,
    );
  }
}


class CompleteProfileScreen
    extends StatefulWidget {
  final UserProfile profile;

  final ValueChanged<UserProfile>
      onCompleted;

  const CompleteProfileScreen({
    super.key,
    required this.profile,
    required this.onCompleted,
  });

  @override
  State<CompleteProfileScreen>
      createState() =>
          _CompleteProfileScreenState();
}


class _CompleteProfileScreenState
    extends State<CompleteProfileScreen> {
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


  bool _usernameIsValid(
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

    if (!_usernameIsValid(
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

      widget.onCompleted(
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
            "Couldn't save your profile. "
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
          const Color(
        0xFFF3F3F3,
      ),

      labelStyle:
          const TextStyle(
        color:
            Color(
          0xFF555555,
        ),
      ),

      prefixIconColor:
          const Color(
        0xFF555555,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        borderSide:
            BorderSide.none,
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        borderSide:
            const BorderSide(
          color:
              Colors.black,
          width:
              1.5,
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
        0xFFFCFCFA,
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets
                  .fromLTRB(
            24,
            34,
            24,
            28,
          ),

          child:
              Center(
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth:
                    460,
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  const Text(
                    "Make YIYO yours.",
                    style:
                        TextStyle(
                      color:
                          Colors.black,
                      fontSize:
                          30,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          -1,
                    ),
                  ),

                  const SizedBox(
                    height:
                        10,
                  ),

                  Text(
                    "Choose the name people will "
                    "know you by on YIYO.",
                    style:
                        TextStyle(
                      color:
                          Colors.grey[
                        600
                      ],
                      fontSize:
                          15,
                      height:
                          1.45,
                    ),
                  ),

                  const SizedBox(
                    height:
                        34,
                  ),

                  const Text(
                    "Username",
                    style:
                        TextStyle(
                      color:
                          Colors.black,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        6,
                  ),

                  Text(
                    "Public and unique. You can "
                    "keep it personal.",
                    style:
                        TextStyle(
                      color:
                          Colors.grey[
                        600
                      ],
                      fontSize:
                          13,
                    ),
                  ),

                  const SizedBox(
                    height:
                        10,
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
                        TextCapitalization
                            .none,

                    textInputAction:
                        TextInputAction
                            .next,

                    style:
                        const TextStyle(
                      color:
                          Colors.black,
                    ),

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
                        24,
                  ),

                  const Text(
                    "Full name",
                    style:
                        TextStyle(
                      color:
                          Colors.black,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        6,
                  ),

                  Text(
                    "Optional for now. This is "
                    "account information, not your "
                    "public YIYO identity.",
                    style:
                        TextStyle(
                      color:
                          Colors.grey[
                        600
                      ],
                      fontSize:
                          13,
                      height:
                          1.35,
                    ),
                  ),

                  const SizedBox(
                    height:
                        10,
                  ),

                  TextField(
                    controller:
                        _fullNameController,

                    focusNode:
                        _fullNameFocus,

                    enabled:
                        !_isSaving,

                    textCapitalization:
                        TextCapitalization
                            .words,

                    textInputAction:
                        TextInputAction
                            .done,

                    style:
                        const TextStyle(
                      color:
                          Colors.black,
                    ),

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
                          const EdgeInsets
                              .all(
                        12,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red
                                .withValues(
                          alpha:
                              0.08,
                        ),

                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),

                      child:
                          Text(
                        _error!,
                        style:
                            const TextStyle(
                          color:
                              Colors.red,
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
                        56,
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
                            Colors.black,

                        foregroundColor:
                            Colors.white,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
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
                                        Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Continue to YIYO",
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight.w800,
                                    fontSize:
                                        16,
                                  ),
                                ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        10,
                  ),

                  TextButton(
                    onPressed:
                        _isSaving
                            ? null
                            : () =>
                                AuthService
                                    .signOut(),

                    child:
                        const Text(
                      "Use another account",
                      style:
                          TextStyle(
                        color:
                            Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}