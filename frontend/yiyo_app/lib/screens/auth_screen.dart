import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
  });

  @override
  State<AuthScreen> createState() =>
      _AuthScreenState();
}

class _AuthScreenState
    extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _isSendingReset = false;
  bool _isGoogleLoading = false;

  final TextEditingController
      _emailController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  final TextEditingController
      _usernameController =
      TextEditingController();

  final FocusNode _usernameFocus =
      FocusNode();

  final FocusNode _emailFocus =
      FocusNode();

  final FocusNode _passwordFocus =
      FocusNode();

  @override
  void dispose() {
    _emailController.dispose();

    _passwordController.dispose();

    _usernameController.dispose();

    _usernameFocus.dispose();

    _emailFocus.dispose();

    _passwordFocus.dispose();

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
            Text(
          message,
        ),
      ),
    );
  }

  String _friendlyAuthMessage(
    Object error,
  ) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return "That email address doesn't look right.";

        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';

        case 'email-already-in-use':
          return 'An account already uses this email.';

        case 'weak-password':
          return 'Use at least 8 characters '
              'with a letter and a number.';

        case 'too-many-requests':
          return 'Too many attempts. '
              'Try again shortly.';

        case 'network-request-failed':
          return 'Check your internet connection '
              'and try again.';

        case 'user-disabled':
          return 'This account is currently disabled.';

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

    return _isLogin
        ? "Couldn't sign you in. Try again."
        : "Couldn't create your account. "
            "Try again.";
  }

  bool get _passwordHasMinLength =>
      _passwordController.text.length >= 8;

  bool get _passwordHasLetter =>
      RegExp(
        r'[A-Za-z]',
      ).hasMatch(
        _passwordController.text,
      );

  bool get _passwordHasNumber =>
      RegExp(
        r'[0-9]',
      ).hasMatch(
        _passwordController.text,
      );

  bool get _passwordIsValid =>
      _passwordHasMinLength &&
      _passwordHasLetter &&
      _passwordHasNumber;

  Widget _buildPasswordRequirement({
    required String label,
    required bool met,
  }) {
    return Row(
      children: [
        Icon(
          met
              ? Icons.check_circle
              : Icons.circle_outlined,

          size: 16,

          color:
              met
                  ? Colors.green
                  : Colors.grey[500],
        ),

        const SizedBox(
          width: 7,
        ),

        Text(
          label,

          style:
              TextStyle(
            fontSize: 12,

            color:
                met
                    ? Colors.green[700]
                    : Colors.grey[600],

            fontWeight:
                met
                    ? FontWeight.w700
                    : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordGuidance() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _buildPasswordRequirement(
          label:
              'At least 8 characters',

          met:
              _passwordHasMinLength,
        ),

        const SizedBox(
          height: 5,
        ),

        _buildPasswordRequirement(
          label:
              'At least 1 letter',

          met:
              _passwordHasLetter,
        ),

        const SizedBox(
          height: 5,
        ),

        _buildPasswordRequirement(
          label:
              'At least 1 number',

          met:
              _passwordHasNumber,
        ),
      ],
    );
  }

  bool _validate() {
    final email =
        _emailController.text
            .trim();

    final password =
        _passwordController.text;

    final username =
        _usernameController.text
            .trim();

    if (
        !_isLogin &&
        username.isEmpty) {
      _showMessage(
        'Choose a username.',
      );

      _usernameFocus
          .requestFocus();

      return false;
    }

    if (
        !_isLogin &&
        username.length < 3) {
      _showMessage(
        'Username must be at least '
        '3 characters.',
      );

      _usernameFocus
          .requestFocus();

      return false;
    }

    if (email.isEmpty) {
      _showMessage(
        'Enter your email address.',
      );

      _emailFocus
          .requestFocus();

      return false;
    }

    if (
        !email.contains('@') ||
        !email.contains('.')) {
      _showMessage(
        'Enter a valid email address.',
      );

      _emailFocus
          .requestFocus();

      return false;
    }

    if (password.isEmpty) {
      _showMessage(
        'Enter your password.',
      );

      _passwordFocus
          .requestFocus();

      return false;
    }

    if (
        !_isLogin &&
        !_passwordIsValid) {
      _showMessage(
        'Use at least 8 characters '
        'with a letter and a number.',
      );

      _passwordFocus
          .requestFocus();

      return false;
    }

    return true;
  }

  Future<void>
      _continueWithGoogle() async {
    if (
        _isLoading ||
        _isGoogleLoading) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _isGoogleLoading =
          true;
    });

    try {
      await AuthService
          .signInWithGoogle();
    } on GoogleSignInException catch (
        error) {
      if (!mounted) {
        return;
      }

      if (
          error.code ==
          GoogleSignInExceptionCode
              .canceled) {
        return;
      }

      _showMessage(
        "Google sign-in couldn't be completed.",
      );
    } on FirebaseAuthException catch (
        error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _friendlyAuthMessage(
          error,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        "Google sign-in couldn't be completed.",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading =
              false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    if (!_validate()) {
      return;
    }

    final email =
        _emailController.text
            .trim();

    final password =
        _passwordController.text;

    final username =
        _usernameController.text
            .trim();

    setState(() {
      _isLoading =
          true;
    });

    try {
      if (_isLogin) {
        await AuthService.signIn(
          email:
              email,

          password:
              password,
        );
      } else {
        await AuthService.signUp(
          email:
              email,

          password:
              password,

          username:
              username,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _friendlyAuthMessage(
          error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading =
              false;
        });
      }
    }
  }

  Future<void>
      _forgotPassword() async {
    if (_isSendingReset) {
      return;
    }

    final email =
        _emailController.text
            .trim();

    if (email.isEmpty) {
      _showMessage(
        'Enter your email first, '
        'then tap Forgot password.',
      );

      _emailFocus
          .requestFocus();

      return;
    }

    if (
        !email.contains('@') ||
        !email.contains('.')) {
      _showMessage(
        'Enter a valid email address first.',
      );

      _emailFocus
          .requestFocus();

      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _isSendingReset =
          true;
    });

    try {
      await AuthService
          .sendPasswordResetEmail(
        email:
            email,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Password reset email sent. '
        'Check your inbox.',
      );
    } on FirebaseAuthException catch (
        error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _friendlyAuthMessage(
          error,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        "Couldn't send the reset email. "
        "Try again.",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReset =
              false;
        });
      }
    }
  }

  void _switchMode() {
    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _isLogin =
          !_isLogin;

      _passwordVisible =
          false;
    });
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? prefixText,
    Widget? suffixIcon,
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

      suffixIcon:
          suffixIcon,

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

      hintStyle:
          TextStyle(
        color:
            Colors.grey[
          500
        ],
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

      enabledBorder:
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

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal:
            16,

        vertical:
            18,
      ),
    );
  }

  Widget _buildYiyoMark() {
    return Row(
      mainAxisSize:
          MainAxisSize.min,

      crossAxisAlignment:
          CrossAxisAlignment.end,

      children: [
        const Text(
          'y',

          style:
              TextStyle(
            fontSize:
                58,

            fontWeight:
                FontWeight.w900,

            color:
                Colors.black,

            height:
                1,

            letterSpacing:
                -4,
          ),
        ),

        const SizedBox(
          width:
              4,
        ),

        SizedBox(
          width:
              34,

          height:
              54,

          child:
              Column(
            mainAxisAlignment:
                MainAxisAlignment.end,

            children: [
              Container(
                width:
                    15,

                height:
                    33,

                decoration:
                    const BoxDecoration(
                  color:
                      Colors.black,

                  borderRadius:
                      BorderRadius.all(
                    Radius.circular(
                      10,
                    ),
                  ),
                ),

                child:
                    Center(
                  child:
                      Container(
                    width:
                        4,

                    height:
                        15,

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,

                      borderRadius:
                          BorderRadius.circular(
                        4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                    4,
              ),

              Container(
                width:
                    9,

                height:
                    9,

                decoration:
                    const BoxDecoration(
                  color:
                      Colors.black,

                  shape:
                      BoxShape.circle,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width:
              2,
        ),

        const Text(
          'yo',

          style:
              TextStyle(
            fontSize:
                58,

            fontWeight:
                FontWeight.w900,

            color:
                Colors.black,

            height:
                1,

            letterSpacing:
                -4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final bottomInset =
        MediaQuery.of(
      context,
    ).viewInsets.bottom;

    return Scaffold(
      backgroundColor:
          const Color(
        0xFFFCFCFA,
      ),

      resizeToAvoidBottomInset:
          true,

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,

          padding:
              EdgeInsets.fromLTRB(
            22,
            26,
            22,
            26 + bottomInset,
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
                  AutofillGroup(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    const SizedBox(
                      height:
                          18,
                    ),

                    Center(
                      child:
                          _buildYiyoMark(),
                    ),

                    const SizedBox(
                      height:
                          18,
                    ),

                    Text(
                      _isLogin
                          ? 'Know where the vibe is.'
                          : 'Join the nightlife.',

                      textAlign:
                          TextAlign.center,

                      style:
                          const TextStyle(
                        color:
                            Colors.black,

                        fontSize:
                            24,

                        fontWeight:
                            FontWeight.w800,

                        letterSpacing:
                            -0.7,
                      ),
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    Text(
                      _isLogin
                          ? "Sign in and see what's happening around you."
                          : 'Create your YIYO account '
                              'and start exploring.',

                      textAlign:
                          TextAlign.center,

                      style:
                          TextStyle(
                        color:
                            Colors.grey[
                          600
                        ],

                        fontSize:
                            14,

                        height:
                            1.4,
                      ),
                    ),

                    const SizedBox(
                      height:
                          34,
                    ),

                    SizedBox(
                      height:
                          56,

                      child:
                          OutlinedButton(
                        onPressed:
                            _isLoading ||
                                    _isGoogleLoading
                                ? null
                                : _continueWithGoogle,

                        style:
                            OutlinedButton
                                .styleFrom(
                          foregroundColor:
                              Colors.black,

                          backgroundColor:
                              Colors.white,

                          side:
                              const BorderSide(
                            color:
                                Color(
                              0xFFD6D6D6,
                            ),
                          ),

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
                            _isGoogleLoading
                                ? const SizedBox(
                                    width:
                                        22,

                                    height:
                                        22,

                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.3,

                                      color:
                                          Colors.black,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,

                                    children: [
                                      Text(
                                        'G',

                                        style:
                                            TextStyle(
                                          fontSize:
                                              20,

                                          fontWeight:
                                              FontWeight.w900,

                                          color:
                                              Colors.black,
                                        ),
                                      ),

                                      SizedBox(
                                        width:
                                            12,
                                      ),

                                      Text(
                                        'Continue with Google',

                                        style:
                                            TextStyle(
                                          fontSize:
                                              15,

                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          22,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              Divider(
                            color:
                                Colors.grey[
                              300
                            ],
                          ),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                14,
                          ),

                          child:
                              Text(
                            'or',

                            style:
                                TextStyle(
                              color:
                                  Colors.grey[
                                500
                              ],

                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),

                        Expanded(
                          child:
                              Divider(
                            color:
                                Colors.grey[
                              300
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          22,
                    ),

                    if (!_isLogin) ...[
                      TextField(
                        controller:
                            _usernameController,

                        focusNode:
                            _usernameFocus,

                        enabled:
                            !_isLoading,

                        keyboardType:
                            TextInputType.text,

                        textInputAction:
                            TextInputAction.next,

                        textCapitalization:
                            TextCapitalization.none,

                        autocorrect:
                            false,

                        enableSuggestions:
                            false,

                        autofillHints:
                            const [
                          AutofillHints.username,
                        ],

                        style:
                            const TextStyle(
                          color:
                              Colors.black,
                        ),

                        onSubmitted:
                            (_) {
                          _emailFocus
                              .requestFocus();
                        },

                        decoration:
                            _inputDecoration(
                          label:
                              'Username',

                          hint:
                              'yourname',

                          prefixText:
                              '@',

                          icon:
                              Icons
                                  .alternate_email,
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),
                    ],

                    TextField(
                      controller:
                          _emailController,

                      focusNode:
                          _emailFocus,

                      enabled:
                          !_isLoading,

                      keyboardType:
                          TextInputType
                              .emailAddress,

                      textInputAction:
                          TextInputAction.next,

                      autofillHints:
                          const [
                        AutofillHints.email,
                      ],

                      autocorrect:
                          false,

                      style:
                          const TextStyle(
                        color:
                            Colors.black,
                      ),

                      onSubmitted:
                          (_) {
                        _passwordFocus
                            .requestFocus();
                      },

                      decoration:
                          _inputDecoration(
                        label:
                            'Email',

                        hint:
                            'you@example.com',

                        icon:
                            Icons
                                .mail_outline,
                      ),
                    ),

                    const SizedBox(
                      height:
                          14,
                    ),

                    TextField(
                      controller:
                          _passwordController,

                      focusNode:
                          _passwordFocus,

                      enabled:
                          !_isLoading,

                      obscureText:
                          !_passwordVisible,

                      keyboardType:
                          TextInputType
                              .visiblePassword,

                      textInputAction:
                          TextInputAction.done,

                      autofillHints:
                          _isLogin
                              ? const [
                                  AutofillHints
                                      .password,
                                ]
                              : const [
                                  AutofillHints
                                      .newPassword,
                                ],

                      autocorrect:
                          false,

                      enableSuggestions:
                          false,

                      style:
                          const TextStyle(
                        color:
                            Colors.black,
                      ),

                      onChanged:
                          (_) {
                        if (!_isLogin) {
                          setState(() {});
                        }
                      },

                      onSubmitted:
                          (_) =>
                              _submit(),

                      decoration:
                          _inputDecoration(
                        label:
                            'Password',

                        icon:
                            Icons
                                .lock_outline,

                        suffixIcon:
                            IconButton(
                          tooltip:
                              _passwordVisible
                                  ? 'Hide password'
                                  : 'Show password',

                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _passwordVisible =
                                            !_passwordVisible;
                                      });
                                    },

                          icon:
                              Icon(
                            _passwordVisible
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,

                            color:
                                const Color(
                              0xFF555555,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (!_isLogin) ...[
                      const SizedBox(
                        height:
                            10,
                      ),

                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              4,
                        ),

                        child:
                            _buildPasswordGuidance(),
                      ),

                      const SizedBox(
                        height:
                            10,
                      ),
                    ],

                    if (_isLogin) ...[
                      const SizedBox(
                        height:
                            4,
                      ),

                      Align(
                        alignment:
                            Alignment
                                .centerRight,

                        child:
                            TextButton(
                          onPressed:
                              _isLoading ||
                                      _isSendingReset
                                  ? null
                                  : _forgotPassword,

                          child:
                              Text(
                            _isSendingReset
                                ? 'Sending...'
                                : 'Forgot password?',

                            style:
                                const TextStyle(
                              color:
                                  Colors.black,

                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      const SizedBox(
                        height:
                            20,
                      ),

                    SizedBox(
                      height:
                          56,

                      child:
                          FilledButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _submit,

                        style:
                            FilledButton
                                .styleFrom(
                          backgroundColor:
                              Colors.black,

                          foregroundColor:
                              Colors.white,

                          disabledBackgroundColor:
                              Colors.black38,

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
                            _isLoading
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
                                : Text(
                                    _isLogin
                                        ? 'Sign in'
                                        : 'Create account',

                                    style:
                                        const TextStyle(
                                      fontSize:
                                          16,

                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          22,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              Divider(
                            color:
                                Colors.grey[
                              300
                            ],
                          ),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                12,
                          ),

                          child:
                              Text(
                            _isLogin
                                ? 'New to YIYO?'
                                : 'Already on YIYO?',

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
                        ),

                        Expanded(
                          child:
                              Divider(
                            color:
                                Colors.grey[
                              300
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          14,
                    ),

                    SizedBox(
                      height:
                          52,

                      child:
                          OutlinedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _switchMode,

                        style:
                            OutlinedButton
                                .styleFrom(
                          foregroundColor:
                              Colors.black,

                          side:
                              const BorderSide(
                            color:
                                Color(
                              0xFFD6D6D6,
                            ),
                          ),

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
                            Text(
                          _isLogin
                              ? 'Create an account'
                              : 'Sign in instead',

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          20,
                    ),

                    Text(
                      'Real people. Real places. '
                      'Know the vibe before you go.',

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

                    const SizedBox(
                      height:
                          10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}