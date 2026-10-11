import 'package:flutter/material.dart';

import '../legal/legal_content.dart';


class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  const LegalDocumentScreen.privacy({
    super.key,
  })  : title = 'Privacy Policy',
        sections = LegalContent.privacyPolicy;

  const LegalDocumentScreen.terms({
    super.key,
  })  : title = 'Terms & Community Guidelines',
        sections = LegalContent.termsAndCommunityGuidelines;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFFFCFCFA,
      ),
      appBar:
          AppBar(
        backgroundColor:
            const Color(
          0xFFFCFCFA,
        ),
        foregroundColor:
            Colors.black,
        elevation:
            0,
        title:
            Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body:
          SafeArea(
        child:
            ListView(
          padding:
              const EdgeInsets.fromLTRB(
            22,
            12,
            22,
            36,
          ),
          children: [
            if (
                LegalContent
                    .isPreLaunchDraft) ...[
              Container(
                padding:
                    const EdgeInsets.all(
                  14,
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
                  'Please review this policy carefully. You can return to it at any time from your YIYO profile.',
                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF5F4B00,
                    ),
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w700,
                    height:
                        1.35,
                  ),
                ),
              ),
              const SizedBox(
                height:
                    18,
              ),
            ],
            Text(
              'Version ${LegalContent.version} • ${LegalContent.effectiveDate}',
              style:
                  TextStyle(
                color:
                    Colors.grey[600],
                fontSize:
                    12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(
              height:
                  22,
            ),
            for (
              final section
              in sections
            ) ...[
              Text(
                section.heading,
                style:
                    const TextStyle(
                  color:
                      Colors.black,
                  fontSize:
                      19,
                  fontWeight:
                      FontWeight.w900,
                  height:
                      1.2,
                ),
              ),
              const SizedBox(
                height:
                    9,
              ),
              for (
                final paragraph
                in section.paragraphs
              ) ...[
                Text(
                  paragraph,
                  style:
                      TextStyle(
                    color:
                        Colors.grey[850],
                    fontSize:
                        14.5,
                    height:
                        1.55,
                  ),
                ),
                const SizedBox(
                  height:
                      10,
                ),
              ],
              for (
                final bullet
                in section.bullets
              )
                Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom:
                        8,
                  ),
                  child:
                      Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          top:
                              7,
                        ),
                        child:
                            SizedBox(
                          width:
                              5,
                          height:
                              5,
                          child:
                              DecoratedBox(
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.black,
                              shape:
                                  BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width:
                            10,
                      ),
                      Expanded(
                        child:
                            Text(
                          bullet,
                          style:
                              TextStyle(
                            color:
                                Colors.grey[850],
                            fontSize:
                                14.5,
                            height:
                                1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(
                height:
                    20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
