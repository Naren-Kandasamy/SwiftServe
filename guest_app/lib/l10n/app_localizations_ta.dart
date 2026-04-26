// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appName => 'CrisisNet';

  @override
  String get sosButtonLabel => 'SOS அனுப்பு';

  @override
  String get sosButtonHint => 'அவசரகால பணியாளர்களை எச்சரிக்க அழுத்தவும்';

  @override
  String get sosRecordingLabel => 'பதிவு செய்கிறது...';

  @override
  String get sosTypeLabel => 'அவசரகாலத்தின் வகை';

  @override
  String get sosRoomLabel => 'அறை / இடம்';

  @override
  String get sosDescriptionHint => 'என்ன நடக்கிறது என்று விவரிக்கவும்...';

  @override
  String get sosAttachPhoto => 'புகைப்படம் இணைக்கவும்';

  @override
  String get sosRemovePhoto => 'நீக்கு';

  @override
  String get sosSending => 'SOS அனுப்புகிறது...';

  @override
  String get sosSent => 'SOS அனுப்பப்பட்டது';

  @override
  String get statusTitle => 'அவசரகால நிலை';

  @override
  String get statusWaiting => 'பதிலுக்காக காத்திருக்கிறோம்...';

  @override
  String get statusTriaged => 'AI மூலம் வகைப்படுத்தப்பட்டது';

  @override
  String get statusAssigned => 'பணியாளர்கள் அனுப்பப்பட்டனர்';

  @override
  String get statusEscalated => 'அவசரகால சேவைகளுக்கு அனுப்பப்பட்டது';

  @override
  String get statusResolved => 'தீர்க்கப்பட்டது';

  @override
  String get statusContained => 'கட்டுப்படுத்தப்பட்டது';

  @override
  String get statusInstructions => 'பாதுகாப்பு வழிமுறைகள்';

  @override
  String get statusRoom => 'அறை';

  @override
  String get statusType => 'அவசரகால வகை';

  @override
  String get typeFire => 'தீ';

  @override
  String get typeMedical => 'மருத்துவ';

  @override
  String get typeSecurity => 'பாதுகாப்பு';

  @override
  String get typeInfrastructure => 'உள்கட்டமைப்பு';

  @override
  String get typeOther => 'மற்றவை';

  @override
  String get statusOpenChat => 'அரட்டையை திறக்கவும்';

  @override
  String get statusBack => 'மற்றொரு அவசரகாலத்தை தெரிவிக்கவும்';

  @override
  String get chatTitle => 'அவசரகால அரட்டை';

  @override
  String get chatPlaceholder => 'செய்தி தட்டச்சு செய்யவும்...';

  @override
  String get chatSend => 'அனுப்பு';

  @override
  String get chatConnecting => 'இணைக்கிறது...';

  @override
  String get offlineWarning =>
      'இணையம் இல்லை — ஆஃப்லைன் வழிகாட்டி பயன்படுத்தப்படுகிறது';

  @override
  String get offlineGuideTitle => 'அவசரகால பாதுகாப்பு வழிகாட்டி';

  @override
  String get errorGeneric => 'ஏதோ தவறு நடந்தது. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorNoLocation => 'உங்கள் இடத்தை தீர்மானிக்க முடியவில்லை.';

  @override
  String get errorSendFailed => 'SOS அனுப்ப முடியவில்லை. வரவேற்பை அழைக்கவும்.';
}
