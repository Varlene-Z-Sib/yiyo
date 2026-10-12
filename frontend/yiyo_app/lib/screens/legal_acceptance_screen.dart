import 'package:flutter/material.dart';

import '../legal/legal_content.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'legal_document_screen.dart';


class LegalAcceptanceScreen
    extends StatefulWidget {
  final ValueChanged<UserProfile>
      onAccepted;

  const LegalAcceptanceScreen({
    super.key,
    required this.onAccepted,
  });

  @override
  State<LegalAcceptanceScreen>
      createState() =>
          _LegalAcceptanceScreenState();
}


class _LegalAcceptanceScreenState
    extends State<LegalAcceptanceScreen> {
  bool _accepted = false;
  bool _isSaving = false;
  String? _error;

  Future<void> _openPrivacy() async {
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) =>
            const LegalDocumentScreen
                .privacy(),
      ),
    );
  }

  Future<void> _openTerms() async {
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) =>
            const LegalDocumentScreen
                .terms(),
      ),
    );
  }

  Future<void> _continue() async {
    if (
        !_accepted ||
        _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final profile =
          await ApiService
              .acceptLegalPolicies();

      if (!mounted) {
        return;
      }

      widget.onAccepted(
        profile,
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
            "Couldn't save your acceptance. Try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
            Center(
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              24,
            ),
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth:
                    520,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Before you continue',
                    style:
                        TextStyle(
                      color:
                          Colors.black,
                      fontSize:
                          30,
                      fontWeight:
                          FontWeight.w900,
                      height:
                          1.05,
                    ),
                  ),
                  const SizedBox(
                    height:
                        10,
                  ),
                  Text(
                    'Review YIYO’s community rules and privacy information before using community features.',
                    style:
                        TextStyle(
                      color:
                          Colors.grey[700],
                      fontSize:
                          15,
                      height:
                          1.45,
                    ),
                  ),
                  const SizedBox(
                    height:
                        22,
                  ),
                  if (
                      LegalContent
                          .isPreLaunchDraft) ...[
                    Container(
                      padding:
                          const EdgeInsets.all(
                        13,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFFFF3CD,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child:
                          const Text(
                        'Please review YIYO’s Terms of Use, Community Guidelines and Privacy Policy before continuing.',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFF5F4B00,
                          ),
                          fontSize:
                              12.5,
                          fontWeight:
                              FontWeight.w700,
                          height:
                              1.35,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height:
                          16,
                    ),
                  ],
                  _LegalLinkCard(
                    icon:
                        Icons
                            .gavel_outlined,
                    title:
                        'Terms & Community Guidelines',
                    subtitle:
                        'Rules for contributions, events and responsible use.',
                    onTap:
                        _openTerms,
                  ),
                  const SizedBox(
                    height:
                        10,
                  ),
                  _LegalLinkCard(
                    icon:
                        Icons
                            .privacy_tip_outlined,
                    title:
                        'Privacy Policy',
                    subtitle:
                        'What YIYO processes and how account deletion works.',
                    onTap:
                        _openPrivacy,
                  ),
                  const SizedBox(
                    height:
                        18,
                  ),
                  Material(
                    color:
                        Colors.transparent,
                    child:
                        InkWell(
                      onTap:
                          _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _accepted =
                                        !_accepted;
                                  });
                                },
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      child:
                          Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical:
                              8,
                        ),
                        child:
                            Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value:
                                  _accepted,
                              onChanged:
                                  _isSaving
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _accepted =
                                                value ?? false;
                                          });
                                        },
                              activeColor:
                                  Colors.black,
                              checkColor:
                                  Colors.white,
                            ),
                            const SizedBox(
                              width:
                                  4,
                            ),
                            const Expanded(
                              child:
                                  Padding(
                                padding:
                                    EdgeInsets.only(
                                  top:
                                      10,
                                ),
                                child:
                                    Text(
                                  'I agree to YIYO’s Terms of Use and Community Guidelines and acknowledge the Privacy Policy.',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.black,
                                    fontSize:
                                        14,
                                    height:
                                        1.4,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (
                      _error != null) ...[
                    const SizedBox(
                      height:
                          10,
                    ),
                    Text(
                      _error!,
                      style:
                          const TextStyle(
                        color:
                            Colors.redAccent,
                        fontSize:
                            13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(
                    height:
                        18,
                  ),
                  SizedBox(
                    height:
                        54,
                    child:
                        FilledButton(
                      onPressed:
                          _accepted &&
                                  !_isSaving
                              ? _continue
                              : null,
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            Colors.black,
                        foregroundColor:
                            Colors.white,
                        disabledBackgroundColor:
                            Colors.grey[300],
                        disabledForegroundColor:
                            Colors.grey[600],
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
                                  'Agree and continue',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(
                    height:
                        8,
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
                      'Use another account',
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


class _LegalLinkCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LegalLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          const Color(
        0xFFF0F0EC,
      ),
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child:
          InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child:
              Row(
            children: [
              Icon(
                icon,
                color:
                    Colors.black,
              ),
              const SizedBox(
                width:
                    14,
              ),
              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            Colors.black,
                        fontWeight:
                            FontWeight.w800,
                        fontSize:
                            14.5,
                      ),
                    ),
                    const SizedBox(
                      height:
                          3,
                    ),
                    Text(
                      subtitle,
                      style:
                          TextStyle(
                        color:
                            Colors.grey[700],
                        fontSize:
                            12.5,
                        height:
                            1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color:
                    Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
