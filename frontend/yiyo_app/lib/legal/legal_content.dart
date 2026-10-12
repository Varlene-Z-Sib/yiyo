class LegalSection {
  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;

  const LegalSection({
    required this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

class LegalContent {
  static const String operatorName =
      'Coded Partners (Pty) Ltd';

  static const String version = '1.0';

  static const String effectiveDate =
      '11 October 2026';

  static const bool isPreLaunchDraft = false;

  static const String supportEmail =
      'yiyo.support.sa@gmail.com';

  static const String informationOfficer =
      'Siphesihle Ngcobo';

  static const String operatorLocation =
      'Johannesburg, Gauteng, South Africa';

  static const List<LegalSection> privacyPolicy = [
    LegalSection(
      heading: 'About this policy',
      paragraphs: [
        'This Privacy Policy explains how YIYO collects, uses, stores, shares and protects personal information when you use the YIYO app and related services.',
        'YIYO is operated by Coded Partners (Pty) Ltd, based in Johannesburg, Gauteng, South Africa.',
        'By using YIYO, you acknowledge the practices described in this Privacy Policy. Where consent is required, YIYO will ask for it separately.',
      ],
    ),

    LegalSection(
      heading: 'Information YIYO processes',
      bullets: [
        'Account information such as your email address, YIYO username, optional full name, Firebase user ID and authentication provider.',
        'Precise foreground location when you grant location permission, so YIYO can identify nearby venues and perform location-based searches.',
        'Community contributions such as vibe status, crowd level, safety responses, music, queue information, parking information, optional comments and contribution timestamps.',
        'Event information submitted by authorised promoters or venue managers, including event descriptions and related information.',
        'Your Hype and Going interactions with events.',
        'Role and access information such as promoter permissions, venue-manager permissions and assigned venues.',
        'Moderation and safety information such as reports, flags and account-blocking preferences used to hide content from accounts you choose to block',
        'Unfinished event and vibe-report drafts that may be stored locally on your device.',
      ],
    ),

    LegalSection(
      heading: 'How YIYO uses information',
      bullets: [
        'To create, authenticate and maintain your YIYO account.',
        'To provide nearby nightlife discovery and location-based venue searches.',
        'To publish, aggregate and display community vibe information.',
        'To operate events, Hype and Going interactions and role-based features.',
        'To enforce contribution limits and reduce spam or abuse.',
        'To investigate reports and moderate community content.',
        'To protect the security and integrity of YIYO.',
        'To maintain, troubleshoot and improve the service.',
        'To comply with applicable legal obligations.',
      ],
    ),

    LegalSection(
      heading: 'Location information',
      paragraphs: [
        'YIYO requests foreground location access when location-based features are used. If you grant permission, your device may provide precise coordinates to YIYO.',
        'Your coordinates may be sent to YIYO\'s backend when requesting nearby venues or performing location-based searches.',
        'YIYO does not display your precise device location to other YIYO users.',
        'You can deny or revoke location permission through your Android device settings. Some nearby-discovery functionality may then be limited.',
      ],
    ),

    LegalSection(
      heading: 'Community content',
      paragraphs: [
        'Vibe reports and other community contributions may be used to create public information about venues.',
        'Public vibe-report responses are designed not to expose your Firebase user ID, email address or account display name to other users.',
        'YIYO may retain internal account and moderation information where reasonably necessary to enforce contribution limits, investigate abuse and operate its moderation systems.',
      ],
    ),

    LegalSection(
      heading: 'Events and business access',
      paragraphs: [
        'Users with approved promoter or venue-management access may submit or manage event information. YIYO stores the permissions and venue assignments necessary to provide those features.',
        'Event interactions such as Hype and Going may be linked internally to your account so that YIYO can maintain accurate counts and prevent duplicate interactions.',
      ],
    ),

    LegalSection(
      heading: 'Service providers and sharing',
      paragraphs: [
        'YIYO uses third-party technology providers where necessary to operate the service. These currently include Google and Firebase services for authentication, cloud data storage, maps and place or venue information.',
        'YIYO may provide information to service providers only where reasonably necessary for them to perform services on YIYO\'s behalf or where otherwise permitted by law.',
        'YIYO may also disclose information where reasonably necessary to comply with law, respond to lawful requests, investigate fraud or abuse, protect users, or protect the rights and security of YIYO and Coded Partners (Pty) Ltd.',
      ],
    ),

    LegalSection(
      heading: 'International processing',
      paragraphs: [
        'Some technology providers used by YIYO operate infrastructure outside South Africa. As a result, information may be processed or stored in other countries where those services operate.',
        'Where applicable, YIYO will take reasonable steps to use providers and safeguards appropriate to the protection of personal information.',
      ],
    ),

    LegalSection(
      heading: 'Advertising and sale of data',
      paragraphs: [
        'At launch, YIYO does not sell users\' personal information and does not use personal information for behavioural advertising.',
        'If YIYO introduces advertising or materially changes how personal information is used in the future, this Privacy Policy and relevant user disclosures will be updated.',
      ],
    ),

    LegalSection(
      heading: 'Retention and account deletion',
      paragraphs: [
        'You can permanently delete your YIYO account from the Profile section of the app.',
        'When an account is deleted, YIYO deletes the account profile and Firebase authentication account, releases the reserved username, removes applicable role memberships and removes the user\'s event reactions.',
        'Account-blocking relationships involving the deleted account are also removed.',
        'Community vibe reports may remain after account deletion in anonymised form so that aggregated venue information and community history are not unnecessarily corrupted. Direct account identifiers associated with those retained reports are removed.',
        'Moderation flags may also be retained in anonymised form where reasonably necessary to preserve moderation evidence.',
        'Published event history may remain after the organiser deletes an account, but identifying organiser account information is removed. Pending events belonging to a deleted organiser may be cancelled.',
        'Certain information may be retained where reasonably necessary to comply with law, resolve disputes, prevent fraud or abuse, or establish or defend legal claims.',
        'YIYO will also provide an external web resource through which users can request deletion of their account without needing to reinstall the app.',
      ],
    ),

    LegalSection(
      heading: 'Security',
      paragraphs: [
        'YIYO uses measures including Firebase authentication, authenticated backend requests and access controls intended to protect account and role information.',
        'No internet or electronic storage system can guarantee absolute security. YIYO will continue reviewing and improving safeguards as the service develops.',
      ],
    ),

    LegalSection(
      heading: 'Your rights and choices',
      paragraphs: [
        'Subject to applicable law, you may have rights concerning the personal information YIYO holds about you.',
      ],
      bullets: [
        'Request access to personal information associated with your account.',
        'Request correction of inaccurate or incomplete personal information.',
        'Request deletion of your YIYO account and associated personal information, subject to lawful retention requirements.',
        'Object to certain processing where applicable.',
        'Withdraw consent where processing is specifically based on your consent.',
        'Disable location permission through your device settings.',
        'Report objectionable community content through YIYO\'s reporting tools.',
        'Lodge a complaint with South Africa\'s Information Regulator where applicable.',
      ],
    ),

    LegalSection(
      heading: 'Children',
      paragraphs: [
        'YIYO is intended for an adult nightlife audience and is intended for users aged 18 years and older.',
        'YIYO is not designed or directed for use by children.',
      ],
    ),

    LegalSection(
      heading: 'Changes to this policy',
      paragraphs: [
        'YIYO may update this Privacy Policy when its services, legal obligations or data practices change.',
        'Where a material change requires renewed acknowledgement or acceptance, YIYO may require users to review the updated policy before continuing to use relevant features.',
      ],
    ),

    LegalSection(
      heading: 'Contact and Information Officer',
      paragraphs: [
        'YIYO is operated by Coded Partners (Pty) Ltd, Johannesburg, Gauteng, South Africa.',
        'Information Officer: Siphesihle Ngcobo.',
        'Privacy and support enquiries: yiyo.support.sa@gmail.com.',
        'You may also lodge an appropriate complaint with the Information Regulator of South Africa.',
      ],
    ),
  ];

  static const List<LegalSection>
      termsAndCommunityGuidelines = [
    LegalSection(
      heading: 'Using YIYO',
      paragraphs: [
        'These Terms of Use and Community Guidelines govern your access to and use of YIYO.',
        'By accepting these Terms, you agree to use YIYO responsibly and comply with the rules below.',
        'YIYO is a nightlife discovery platform. Venue activity, crowd information, safety reports, events and community contributions can change quickly and should not be treated as guarantees of real-world conditions.',
      ],
    ),

    LegalSection(
      heading: 'Age requirement',
      paragraphs: [
        'YIYO is intended for users aged 18 years and older.',
        'By using YIYO, you confirm that you meet the minimum age requirement applicable to the service.',
      ],
    ),

    LegalSection(
      heading: 'Your account',
      bullets: [
        'Provide accurate information when creating or maintaining an account.',
        'Keep access to your account reasonably secure.',
        'Do not impersonate another person, venue, promoter, organiser or business.',
        'Do not create or use accounts to evade moderation, access restrictions, contribution limits or enforcement action.',
        'You are responsible for activity carried out through your account unless the activity resulted from circumstances outside your reasonable control.',
      ],
    ),

    LegalSection(
      heading: 'Community contributions',
      paragraphs: [
        'Only submit information that you reasonably believe is accurate and based on a genuine experience, observation or legitimate source.',
        'Community information, including safety-related information, is provided for general informational purposes. It is not professional safety advice and is not a guarantee that a venue or surrounding area is safe.',
      ],
      bullets: [
        'Do not knowingly submit false or misleading information.',
        'Do not manipulate crowd, vibe, queue, parking or safety signals.',
        'Do not harass, threaten, bully, intimidate or target another person.',
        'Do not post hateful, discriminatory, sexually explicit, exploitative or otherwise seriously objectionable content.',
        'Do not post content that promotes or facilitates illegal activity.',
        'Do not spam, repeatedly submit duplicate material or attempt to manipulate YIYO\'s contribution systems.',
        'Do not publish another person\'s private or sensitive information without a lawful basis or permission where required.',
        'Do not knowingly submit content that infringes another person\'s intellectual-property or other legal rights.',
      ],
    ),

    LegalSection(
      heading: 'Events and business tools',
      bullets: [
        'Only submit or manage events you are genuinely authorised to promote, organise or manage.',
        'Do not impersonate a venue, promoter or event organiser.',
        'Event dates, venues, pricing and other material details should be reasonably accurate.',
        'Do not use event tools for spam, scams, unlawful activity or deceptive promotions.',
        'YIYO may require approval before an event becomes public.',
        'YIYO may reject, cancel, hide or remove events that violate these Terms or create a material risk to users or the service.',
      ],
    ),

    LegalSection(
      heading: 'Reporting and moderation',
      paragraphs: [
        'YIYO provides tools for users to report objectionable community content or events and to block contributors or event organisers whose content they no longer want to see.',
        'YIYO may review, restrict, hide, reject or remove content where reasonably necessary to enforce these Terms, respond to reports, comply with law or protect users and the service.',
        'Automated thresholds may temporarily hide heavily reported content or otherwise treat it as a moderation concern.',
        'YIYO may restrict or suspend account features where an account repeatedly or seriously violates these Terms.',
      ],
    ),

    LegalSection(
      heading: 'Your content',
      paragraphs: [
        'You remain responsible for content you submit to YIYO.',
        'You retain any rights you legally hold in your content.',
        'By submitting content, you give YIYO a non-exclusive, worldwide, royalty-free permission to host, store, process, reproduce, display, aggregate and moderate that content to the extent reasonably necessary to operate, secure, promote and improve the YIYO service.',
        'If you delete your account, certain community content or published event history may remain in anonymised form as described in the Privacy Policy.',
      ],
    ),

    LegalSection(
      heading: 'Third-party information and services',
      paragraphs: [
        'YIYO relies on third-party services including mapping, place information, authentication and cloud infrastructure.',
        'Venue information, third-party place data, event details and community information may occasionally be incomplete, delayed or inaccurate.',
        'YIYO is not responsible for the independent services, actions or policies of third-party providers, venues, promoters or event organisers.',
      ],
    ),

    LegalSection(
      heading: 'Safety and personal responsibility',
      paragraphs: [
        'Use your own judgement when visiting venues, travelling, parking, attending events or making nightlife decisions.',
        'Do not rely solely on YIYO community information when making decisions affecting your safety.',
        'If you are in immediate danger or require emergency assistance, contact the appropriate emergency services rather than relying on YIYO.',
      ],
    ),

    LegalSection(
      heading: 'Service availability',
      paragraphs: [
        'YIYO may change, add, suspend or remove features as the service develops.',
        'YIYO does not guarantee that every feature, venue, event or third-party service will always be available, accurate or uninterrupted.',
      ],
    ),

    LegalSection(
      heading: 'Suspension and termination',
      paragraphs: [
        'YIYO may restrict, suspend or terminate access where reasonably necessary because of serious or repeated violations of these Terms, fraud, abuse, security threats, unlawful conduct or risks to other users or the service.',
        'You may stop using YIYO at any time and may permanently delete your account through the Profile section.',
      ],
    ),

    LegalSection(
      heading: 'Disclaimer and liability',
      paragraphs: [
        'To the extent permitted by applicable law, YIYO is provided on an as-available basis and community or third-party information is not guaranteed to be complete, accurate or current.',
        'Nothing in these Terms excludes or limits rights or remedies that cannot lawfully be excluded under South African law.',
      ],
    ),

    LegalSection(
      heading: 'Changes to these Terms',
      paragraphs: [
        'YIYO may update these Terms or the Community Guidelines as the service develops or legal requirements change.',
        'Where a material new version requires renewed acceptance, YIYO may require you to review and accept the new version before continuing to contribute content or use affected features.',
      ],
    ),

    LegalSection(
      heading: 'Governing law',
      paragraphs: [
        'These Terms are governed by the laws of the Republic of South Africa, subject to any mandatory consumer or other legal protections that apply.',
      ],
    ),

    LegalSection(
      heading: 'Operator and contact',
      paragraphs: [
        'YIYO is operated by Coded Partners (Pty) Ltd, Johannesburg, Gauteng, South Africa.',
        'Support and policy enquiries: yiyo.support.sa@gmail.com.',
      ],
    ),
  ];
}