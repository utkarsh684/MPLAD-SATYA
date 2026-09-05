import 'package:flutter/material.dart';

/// Custom localization delegate for MPLAD SATYA.
/// Supports 9 Indian languages with ~80+ translatable strings.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final List<Locale> supportedLocales = [
    const Locale('en'),
    const Locale('hi'),
    const Locale('bn'),
    const Locale('mr'),
    const Locale('ta'),
    const Locale('te'),
    const Locale('kn'),
    const Locale('gu'),
    const Locale('pa'),
  ];

  String get(String key) {
    final langStrings = _localizedStrings[locale.languageCode];
    return langStrings?[key] ?? _localizedStrings['en']![key] ?? key;
  }

  // ─── Convenience Getters ───

  // App
  String get appName => get('appName');
  String get appTagline => get('appTagline');
  String get appSubtitle => get('appSubtitle');
  String get demoMode => get('demoMode');
  String get demoData => get('demoData');

  // Auth
  String get signIn => get('signIn');
  String get officerId => get('officerId');
  String get password => get('password');
  String get continueAsDemo => get('continueAsDemo');

  // Navigation
  String get dashboard => get('dashboard');
  String get investigations => get('investigations');
  String get projects => get('projects');
  String get fieldVerification => get('fieldVerification');
  String get reports => get('reports');
  String get settings => get('settings');

  // Dashboard
  String get goodMorning => get('goodMorning');
  String get districtOverview => get('districtOverview');
  String get totalProjects => get('totalProjects');
  String get projectsScreened => get('projectsScreened');
  String get highRisk => get('highRisk');
  String get critical => get('critical');
  String get pendingVerification => get('pendingVerification');
  String get riskDistribution => get('riskDistribution');
  String get riskTrend => get('riskTrend');
  String get highPriorityInvestigations => get('highPriorityInvestigations');
  String get viewInvestigation => get('viewInvestigation');
  String get viewAll => get('viewAll');

  // Risk
  String get riskScore => get('riskScore');
  String get confidence => get('confidence');
  String get exposure => get('exposure');
  String get low => get('low');
  String get medium => get('medium');
  String get high => get('high');
  String get requiresVerification => get('requiresVerification');

  // Investigation
  String get investigationCenter => get('investigationCenter');
  String get searchPlaceholder => get('searchPlaceholder');
  String get primarySignal => get('primarySignal');
  String get whyFlagged => get('whyFlagged');
  String get evidenceCards => get('evidenceCards');
  String get riskContribution => get('riskContribution');
  String get evidenceSource => get('evidenceSource');
  String get sortByRisk => get('sortByRisk');
  String get sortByConfidence => get('sortByConfidence');
  String get sortByExposure => get('sortByExposure');
  String get sortByLatest => get('sortByLatest');

  // Evidence
  String get costAnomaly => get('costAnomaly');
  String get geoDuplicate => get('geoDuplicate');
  String get executionAnomaly => get('executionAnomaly');
  String get imageSimilarity => get('imageSimilarity');
  String get ruleViolation => get('ruleViolation');
  String get timelineAnomaly => get('timelineAnomaly');

  // Project Detail
  String get projectOverview => get('projectOverview');
  String get recommendedAmount => get('recommendedAmount');
  String get sanctionedAmount => get('sanctionedAmount');
  String get expenditure => get('expenditure');
  String get physicalProgress => get('physicalProgress');
  String get startDate => get('startDate');
  String get expectedCompletion => get('expectedCompletion');
  String get currentStatus => get('currentStatus');

  // Officer Decision
  String get officerDecision => get('officerDecision');
  String get verified => get('verified');
  String get needsFurtherInvestigation => get('needsFurtherInvestigation');
  String get falsePositive => get('falsePositive');
  String get escalate => get('escalate');
  String get aiDisclaimer => get('aiDisclaimer');
  String get officerReviewRequired => get('officerReviewRequired');
  String get confirmDecision => get('confirmDecision');

  // Audit Trail
  String get auditTrail => get('auditTrail');
  String get auditHash => get('auditHash');

  // Field Verification
  String get capturePhoto => get('capturePhoto');
  String get addEvidence => get('addEvidence');
  String get recordMeasurement => get('recordMeasurement');
  String get addNote => get('addNote');
  String get markLocation => get('markLocation');
  String get submitVerification => get('submitVerification');
  String get offlineMode => get('offlineMode');
  String get itemsWaitingSync => get('itemsWaitingSync');
  String get syncQueue => get('syncQueue');

  // AR
  String get arMeasurement => get('arMeasurement');
  String get startMeasurement => get('startMeasurement');
  String get reset => get('reset');
  String get saveMeasurement => get('saveMeasurement');
  String get distance => get('distance');
  String get area => get('area');

  // Reports
  String get districtRiskReport => get('districtRiskReport');
  String get highRiskProjects => get('highRiskProjects');
  String get fieldVerificationReport => get('fieldVerificationReport');
  String get investigationSummary => get('investigationSummary');
  String get monthlyAnomalyReport => get('monthlyAnomalyReport');
  String get exportPdf => get('exportPdf');
  String get share => get('share');
  String get view => get('view');

  // AI Assistant
  String get askSatya => get('askSatya');
  String get typeMessage => get('typeMessage');

  // Settings
  String get account => get('account');
  String get appearance => get('appearance');
  String get language => get('language');
  String get notifications => get('notifications');
  String get data => get('data');
  String get about => get('about');
  String get lightMode => get('lightMode');
  String get darkMode => get('darkMode');
  String get systemDefault => get('systemDefault');
  String get highRiskAlerts => get('highRiskAlerts');
  String get investigationReminders => get('investigationReminders');
  String get syncNotifications => get('syncNotifications');
  String get offlineData => get('offlineData');
  String get syncStatus => get('syncStatus');
  String get clearDemoData => get('clearDemoData');
  String get officerProfile => get('officerProfile');
  String get department => get('department');
  String get district => get('district');

  // Notifications
  String get notificationCenter => get('notificationCenter');

  // Map
  String get projectMap => get('projectMap');

  // Common
  String get filter => get('filter');
  String get sort => get('sort');
  String get search => get('search');
  String get cancel => get('cancel');
  String get confirm => get('confirm');
  String get close => get('close');
  String get apply => get('apply');
  String get noData => get('noData');
  String get loading => get('loading');

  // ─── All Strings Per Language ───
  static final Map<String, Map<String, String>> _localizedStrings = {
    'en': _en,
    'hi': _hi,
    'bn': _bn,
    'mr': _mr,
    'ta': _ta,
    'te': _te,
    'kn': _kn,
    'gu': _gu,
    'pa': _pa,
  };

  static const Map<String, String> _en = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'Evidence. Insight. Better Governance.',
    'appSubtitle': 'Evidence-Driven Risk Intelligence',
    'demoMode': 'Demo Mode',
    'demoData': 'DEMO DATA',
    'signIn': 'Sign In',
    'officerId': 'Officer ID',
    'password': 'Password',
    'continueAsDemo': 'Continue as Demo Officer',
    'dashboard': 'Dashboard',
    'investigations': 'Investigations',
    'projects': 'Projects',
    'fieldVerification': 'Field Verification',
    'reports': 'Reports',
    'settings': 'Settings',
    'goodMorning': 'Good morning, Officer',
    'districtOverview': 'District MPLADS Risk Overview',
    'totalProjects': 'Total Projects',
    'projectsScreened': 'Projects Screened',
    'highRisk': 'High Risk',
    'critical': 'Critical',
    'pendingVerification': 'Pending Verification',
    'riskDistribution': 'Risk Distribution',
    'riskTrend': 'Risk Trend',
    'highPriorityInvestigations': 'High Priority Investigations',
    'viewInvestigation': 'View Investigation',
    'viewAll': 'View All',
    'riskScore': 'Risk Score',
    'confidence': 'Confidence',
    'exposure': 'Exposure',
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'requiresVerification': 'Requires Verification',
    'investigationCenter': 'Investigation Center',
    'searchPlaceholder': 'Search project, village, agency...',
    'primarySignal': 'Primary Signal',
    'whyFlagged': 'Why Was This Flagged?',
    'evidenceCards': 'Evidence Cards',
    'riskContribution': 'Risk Contribution',
    'evidenceSource': 'Evidence Source',
    'sortByRisk': 'Highest Risk',
    'sortByConfidence': 'Highest Confidence',
    'sortByExposure': 'Highest Exposure',
    'sortByLatest': 'Latest Flagged',
    'costAnomaly': 'Cost Anomaly',
    'geoDuplicate': 'Geo-Duplicate',
    'executionAnomaly': 'Execution Anomaly',
    'imageSimilarity': 'Image Similarity',
    'ruleViolation': 'Rule Violation',
    'timelineAnomaly': 'Timeline Anomaly',
    'projectOverview': 'Project Overview',
    'recommendedAmount': 'Recommended Amount',
    'sanctionedAmount': 'Sanctioned Amount',
    'expenditure': 'Expenditure',
    'physicalProgress': 'Physical Progress',
    'startDate': 'Start Date',
    'expectedCompletion': 'Expected Completion',
    'currentStatus': 'Current Status',
    'officerDecision': 'Officer Decision',
    'verified': 'Verified',
    'needsFurtherInvestigation': 'Needs Further Investigation',
    'falsePositive': 'False Positive',
    'escalate': 'Escalate',
    'aiDisclaimer': 'AI does not make the final decision.',
    'officerReviewRequired': 'Officer Review Required',
    'confirmDecision': 'Confirm your decision',
    'auditTrail': 'Audit Trail',
    'auditHash': 'Audit Hash',
    'capturePhoto': 'Capture Photo',
    'addEvidence': 'Add Evidence',
    'recordMeasurement': 'Record Measurement',
    'addNote': 'Add Note',
    'markLocation': 'Mark Location',
    'submitVerification': 'Submit Verification',
    'offlineMode': 'Offline Mode',
    'itemsWaitingSync': 'items waiting to sync',
    'syncQueue': 'Sync Queue',
    'arMeasurement': 'AR Measurement',
    'startMeasurement': 'Start Measurement',
    'reset': 'Reset',
    'saveMeasurement': 'Save Measurement',
    'distance': 'Distance',
    'area': 'Area',
    'districtRiskReport': 'District Risk Report',
    'highRiskProjects': 'High-Risk Projects',
    'fieldVerificationReport': 'Field Verification Report',
    'investigationSummary': 'Investigation Summary',
    'monthlyAnomalyReport': 'Monthly Anomaly Report',
    'exportPdf': 'Export PDF',
    'share': 'Share',
    'view': 'View',
    'askSatya': 'Ask SATYA',
    'typeMessage': 'Type your question...',
    'account': 'Account',
    'appearance': 'Appearance',
    'language': 'Language',
    'notifications': 'Notifications',
    'data': 'Data',
    'about': 'About',
    'lightMode': 'Light',
    'darkMode': 'Dark',
    'systemDefault': 'System Default',
    'highRiskAlerts': 'High-risk alerts',
    'investigationReminders': 'Investigation reminders',
    'syncNotifications': 'Sync notifications',
    'offlineData': 'Offline data',
    'syncStatus': 'Sync status',
    'clearDemoData': 'Clear demo data',
    'officerProfile': 'Officer Profile',
    'department': 'Department',
    'district': 'District',
    'notificationCenter': 'Notification Center',
    'projectMap': 'Project Map',
    'filter': 'Filter',
    'sort': 'Sort',
    'search': 'Search',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'close': 'Close',
    'apply': 'Apply',
    'noData': 'No data available',
    'loading': 'Loading...',
  };

  static const Map<String, String> _hi = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'साक्ष्य। अंतर्दृष्टि। बेहतर शासन।',
    'appSubtitle': 'साक्ष्य-आधारित जोखिम बुद्धिमत्ता',
    'demoMode': 'डेमो मोड',
    'demoData': 'डेमो डेटा',
    'signIn': 'साइन इन',
    'officerId': 'अधिकारी आईडी',
    'password': 'पासवर्ड',
    'continueAsDemo': 'डेमो अधिकारी के रूप में जारी रखें',
    'dashboard': 'डैशबोर्ड',
    'investigations': 'जांच',
    'projects': 'परियोजनाएं',
    'fieldVerification': 'फील्ड सत्यापन',
    'reports': 'रिपोर्ट',
    'settings': 'सेटिंग्स',
    'goodMorning': 'शुभ प्रभात, अधिकारी',
    'districtOverview': 'जिला MPLADS जोखिम अवलोकन',
    'totalProjects': 'कुल परियोजनाएं',
    'projectsScreened': 'जांची गई परियोजनाएं',
    'highRisk': 'उच्च जोखिम',
    'critical': 'गंभीर',
    'pendingVerification': 'सत्यापन लंबित',
    'riskDistribution': 'जोखिम वितरण',
    'riskTrend': 'जोखिम प्रवृत्ति',
    'highPriorityInvestigations': 'उच्च प्राथमिकता जांच',
    'viewInvestigation': 'जांच देखें',
    'viewAll': 'सभी देखें',
    'riskScore': 'जोखिम स्कोर',
    'confidence': 'विश्वसनीयता',
    'exposure': 'एक्सपोज़र',
    'low': 'कम',
    'medium': 'मध्यम',
    'high': 'उच्च',
    'requiresVerification': 'सत्यापन आवश्यक',
    'investigationCenter': 'जांच केंद्र',
    'searchPlaceholder': 'परियोजना, गांव, एजेंसी खोजें...',
    'primarySignal': 'प्राथमिक संकेत',
    'whyFlagged': 'यह क्यों चिह्नित किया गया?',
    'evidenceCards': 'साक्ष्य कार्ड',
    'riskContribution': 'जोखिम योगदान',
    'evidenceSource': 'साक्ष्य स्रोत',
    'sortByRisk': 'सबसे अधिक जोखिम',
    'sortByConfidence': 'सबसे अधिक विश्वसनीयता',
    'sortByExposure': 'सबसे अधिक एक्सपोज़र',
    'sortByLatest': 'नवीनतम चिह्नित',
    'costAnomaly': 'लागत विसंगति',
    'geoDuplicate': 'भौगोलिक डुप्लिकेट',
    'executionAnomaly': 'निष्पादन विसंगति',
    'imageSimilarity': 'छवि समानता',
    'ruleViolation': 'नियम उल्लंघन',
    'timelineAnomaly': 'समयरेखा विसंगति',
    'projectOverview': 'परियोजना अवलोकन',
    'recommendedAmount': 'अनुशंसित राशि',
    'sanctionedAmount': 'स्वीकृत राशि',
    'expenditure': 'व्यय',
    'physicalProgress': 'भौतिक प्रगति',
    'startDate': 'प्रारंभ तिथि',
    'expectedCompletion': 'अपेक्षित पूर्णता',
    'currentStatus': 'वर्तमान स्थिति',
    'officerDecision': 'अधिकारी का निर्णय',
    'verified': 'सत्यापित',
    'needsFurtherInvestigation': 'आगे जांच आवश्यक',
    'falsePositive': 'गलत सकारात्मक',
    'escalate': 'आगे बढ़ाएं',
    'aiDisclaimer': 'AI अंतिम निर्णय नहीं लेता।',
    'officerReviewRequired': 'अधिकारी समीक्षा आवश्यक',
    'confirmDecision': 'अपना निर्णय पुष्टि करें',
    'auditTrail': 'ऑडिट ट्रेल',
    'auditHash': 'ऑडिट हैश',
    'capturePhoto': 'फोटो लें',
    'addEvidence': 'साक्ष्य जोड़ें',
    'recordMeasurement': 'माप रिकॉर्ड करें',
    'addNote': 'नोट जोड़ें',
    'markLocation': 'स्थान चिह्नित करें',
    'submitVerification': 'सत्यापन जमा करें',
    'offlineMode': 'ऑफ़लाइन मोड',
    'itemsWaitingSync': 'आइटम सिंक की प्रतीक्षा में',
    'syncQueue': 'सिंक कतार',
    'arMeasurement': 'AR माप',
    'startMeasurement': 'माप शुरू करें',
    'reset': 'रीसेट',
    'saveMeasurement': 'माप सहेजें',
    'distance': 'दूरी',
    'area': 'क्षेत्रफल',
    'districtRiskReport': 'जिला जोखिम रिपोर्ट',
    'highRiskProjects': 'उच्च जोखिम परियोजनाएं',
    'fieldVerificationReport': 'फील्ड सत्यापन रिपोर्ट',
    'investigationSummary': 'जांच सारांश',
    'monthlyAnomalyReport': 'मासिक विसंगति रिपोर्ट',
    'exportPdf': 'PDF निर्यात',
    'share': 'साझा करें',
    'view': 'देखें',
    'askSatya': 'SATYA से पूछें',
    'typeMessage': 'अपना प्रश्न लिखें...',
    'account': 'खाता',
    'appearance': 'दिखावट',
    'language': 'भाषा',
    'notifications': 'सूचनाएं',
    'data': 'डेटा',
    'about': 'के बारे में',
    'lightMode': 'लाइट',
    'darkMode': 'डार्क',
    'systemDefault': 'सिस्टम डिफ़ॉल्ट',
    'highRiskAlerts': 'उच्च जोखिम अलर्ट',
    'investigationReminders': 'जांच रिमाइंडर',
    'syncNotifications': 'सिंक सूचनाएं',
    'offlineData': 'ऑफ़लाइन डेटा',
    'syncStatus': 'सिंक स्थिति',
    'clearDemoData': 'डेमो डेटा हटाएं',
    'officerProfile': 'अधिकारी प्रोफ़ाइल',
    'department': 'विभाग',
    'district': 'जिला',
    'notificationCenter': 'अधिसूचना केंद्र',
    'projectMap': 'परियोजना मानचित्र',
    'filter': 'फ़िल्टर',
    'sort': 'क्रमबद्ध',
    'search': 'खोजें',
    'cancel': 'रद्द करें',
    'confirm': 'पुष्टि करें',
    'close': 'बंद करें',
    'apply': 'लागू करें',
    'noData': 'कोई डेटा उपलब्ध नहीं',
    'loading': 'लोड हो रहा है...',
  };

  static const Map<String, String> _bn = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'প্রমাণ। অন্তর্দৃষ্টি। উন্নত শাসন।',
    'appSubtitle': 'প্রমাণ-ভিত্তিক ঝুঁকি বুদ্ধিমত্তা',
    'demoMode': 'ডেমো মোড',
    'signIn': 'সাইন ইন',
    'officerId': 'অফিসার আইডি',
    'password': 'পাসওয়ার্ড',
    'continueAsDemo': 'ডেমো অফিসার হিসেবে চালিয়ে যান',
    'dashboard': 'ড্যাশবোর্ড',
    'investigations': 'তদন্ত',
    'projects': 'প্রকল্প',
    'fieldVerification': 'ক্ষেত্র যাচাই',
    'reports': 'রিপোর্ট',
    'settings': 'সেটিংস',
    'goodMorning': 'শুভ সকাল, অফিসার',
    'districtOverview': 'জেলা MPLADS ঝুঁকি পর্যালোচনা',
    'totalProjects': 'মোট প্রকল্প',
    'projectsScreened': 'যাচাইকৃত প্রকল্প',
    'highRisk': 'উচ্চ ঝুঁকি',
    'critical': 'গুরুতর',
    'pendingVerification': 'যাচাই মুলতুবি',
    'riskScore': 'ঝুঁকি স্কোর',
    'confidence': 'আস্থা',
    'officerDecision': 'অফিসারের সিদ্ধান্ত',
    'auditTrail': 'অডিট ট্রেইল',
    'filter': 'ফিল্টার',
    'search': 'অনুসন্ধান',
    'cancel': 'বাতিল',
    'confirm': 'নিশ্চিত',
    'language': 'ভাষা',
    'appearance': 'চেহারা',
    'notifications': 'বিজ্ঞপ্তি',
  };

  static const Map<String, String> _mr = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'पुरावे। अंतर्दृष्टी। चांगले शासन।',
    'appSubtitle': 'पुरावा-आधारित जोखीम बुद्धिमत्ता',
    'demoMode': 'डेमो मोड',
    'signIn': 'साइन इन',
    'officerId': 'अधिकारी आयडी',
    'password': 'पासवर्ड',
    'continueAsDemo': 'डेमो अधिकारी म्हणून सुरू ठेवा',
    'dashboard': 'डॅशबोर्ड',
    'investigations': 'तपास',
    'projects': 'प्रकल्प',
    'fieldVerification': 'फील्ड सत्यापन',
    'reports': 'अहवाल',
    'settings': 'सेटिंग्ज',
    'goodMorning': 'शुभ प्रभात, अधिकारी',
    'riskScore': 'जोखीम स्कोर',
    'confidence': 'विश्वसनीयता',
    'filter': 'फिल्टर',
    'search': 'शोधा',
    'cancel': 'रद्द करा',
    'confirm': 'पुष्टी करा',
    'language': 'भाषा',
  };

  static const Map<String, String> _ta = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'ஆதாரம். நுண்ணறிவு. சிறந்த ஆட்சி.',
    'appSubtitle': 'ஆதார அடிப்படையிலான இடர் நுண்ணறிவு',
    'demoMode': 'செயல்விளக்க முறை',
    'signIn': 'உள்நுழைக',
    'officerId': 'அதிகாரி அடையாளம்',
    'password': 'கடவுச்சொல்',
    'continueAsDemo': 'செயல்விளக்க அதிகாரியாக தொடரவும்',
    'dashboard': 'முகப்புப்பலகை',
    'investigations': 'விசாரணைகள்',
    'projects': 'திட்டங்கள்',
    'fieldVerification': 'களச் சரிபார்ப்பு',
    'reports': 'அறிக்கைகள்',
    'settings': 'அமைப்புகள்',
    'goodMorning': 'காலை வணக்கம், அதிகாரி',
    'riskScore': 'இடர் மதிப்பெண்',
    'confidence': 'நம்பகத்தன்மை',
    'filter': 'வடிகட்டி',
    'search': 'தேடு',
    'language': 'மொழி',
  };

  static const Map<String, String> _te = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'సాక్ష్యం. అంతర్దృష్టి. మెరుగైన పాలన.',
    'appSubtitle': 'సాక్ష్య-ఆధారిత రిస్క్ ఇంటెలిజెన్స్',
    'demoMode': 'డెమో మోడ్',
    'signIn': 'సైన్ ఇన్',
    'dashboard': 'డాష్‌బోర్డ్',
    'investigations': 'దర్యాప్తులు',
    'projects': 'ప్రాజెక్టులు',
    'fieldVerification': 'ఫీల్డ్ ధ్రువీకరణ',
    'reports': 'నివేదికలు',
    'settings': 'సెట్టింగ్‌లు',
    'goodMorning': 'శుభోదయం, అధికారి',
    'riskScore': 'రిస్క్ స్కోర్',
    'confidence': 'నమ్మకం',
    'language': 'భాష',
  };

  static const Map<String, String> _kn = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'ಸಾಕ್ಷ್ಯ. ಒಳನೋಟ. ಉತ್ತಮ ಆಡಳಿತ.',
    'appSubtitle': 'ಸಾಕ್ಷ್ಯ-ಆಧಾರಿತ ಅಪಾಯ ಬುದ್ಧಿಮತ್ತೆ',
    'demoMode': 'ಡೆಮೊ ಮೋಡ್',
    'signIn': 'ಸೈನ್ ಇನ್',
    'dashboard': 'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
    'investigations': 'ತನಿಖೆಗಳು',
    'projects': 'ಯೋಜನೆಗಳು',
    'settings': 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
    'goodMorning': 'ಶುಭೋದಯ, ಅಧಿಕಾರಿ',
    'riskScore': 'ಅಪಾಯ ಸ್ಕೋರ್',
    'confidence': 'ವಿಶ್ವಾಸ',
    'language': 'ಭಾಷೆ',
  };

  static const Map<String, String> _gu = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'પુરાવા. આંતરદૃષ્ટિ. વધુ સારું શાસન.',
    'appSubtitle': 'પુરાવા-આધારિત જોખમ બુદ્ધિમત્તા',
    'demoMode': 'ડેમો મોડ',
    'signIn': 'સાઇન ઇન',
    'dashboard': 'ડેશબોર્ડ',
    'investigations': 'તપાસ',
    'projects': 'પ્રોજેક્ટ',
    'settings': 'સેટિંગ્સ',
    'goodMorning': 'શુભ સવાર, અધિકારી',
    'riskScore': 'જોખમ સ્કોર',
    'confidence': 'વિશ્વસનીયતા',
    'language': 'ભાષા',
  };

  static const Map<String, String> _pa = {
    'appName': 'MPLAD SATYA',
    'appTagline': 'ਸਬੂਤ। ਸੂਝ। ਬਿਹਤਰ ਸ਼ਾਸਨ।',
    'appSubtitle': 'ਸਬੂਤ-ਅਧਾਰਤ ਜੋਖਮ ਬੁੱਧੀ',
    'demoMode': 'ਡੈਮੋ ਮੋਡ',
    'signIn': 'ਸਾਈਨ ਇਨ',
    'dashboard': 'ਡੈਸ਼ਬੋਰਡ',
    'investigations': 'ਜਾਂਚ',
    'projects': 'ਪ੍ਰੋਜੈਕਟ',
    'settings': 'ਸੈਟਿੰਗਜ਼',
    'goodMorning': 'ਸ਼ੁਭ ਸਵੇਰ, ਅਫ਼ਸਰ',
    'riskScore': 'ਜੋਖਮ ਸਕੋਰ',
    'confidence': 'ਭਰੋਸਾ',
    'language': 'ਭਾਸ਼ਾ',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi', 'bn', 'mr', 'ta', 'te', 'kn', 'gu', 'pa']
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
