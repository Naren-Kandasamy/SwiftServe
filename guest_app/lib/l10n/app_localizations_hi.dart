// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'CrisisNet';

  @override
  String get sosButtonLabel => 'SOS भेजें';

  @override
  String get sosButtonHint =>
      'आपातकालीन कर्मचारियों को सूचित करने के लिए दबाएं';

  @override
  String get sosRecordingLabel => 'रिकॉर्डिंग...';

  @override
  String get sosTypeLabel => 'आपातकाल का प्रकार';

  @override
  String get sosRoomLabel => 'कमरा / स्थान';

  @override
  String get sosDescriptionHint => 'क्या हो रहा है, बताएं...';

  @override
  String get sosAttachPhoto => 'फ़ोटो संलग्न करें';

  @override
  String get sosRemovePhoto => 'हटाएं';

  @override
  String get sosSending => 'SOS भेज रहे हैं...';

  @override
  String get sosSent => 'SOS भेजा गया';

  @override
  String get statusTitle => 'आपातकाल स्थिति';

  @override
  String get statusWaiting => 'प्रतिक्रिया की प्रतीक्षा...';

  @override
  String get statusTriaged => 'AI द्वारा वर्गीकृत';

  @override
  String get statusAssigned => 'कर्मचारी भेजे गए';

  @override
  String get statusEscalated => 'आपातकालीन सेवाओं को भेजा गया';

  @override
  String get statusResolved => 'हल किया गया';

  @override
  String get statusContained => 'नियंत्रित';

  @override
  String get statusInstructions => 'सुरक्षा निर्देश';

  @override
  String get statusRoom => 'कमरा';

  @override
  String get statusType => 'आपातकाल का प्रकार';

  @override
  String get typeFire => 'आग';

  @override
  String get typeMedical => 'चिकित्सा';

  @override
  String get typeSecurity => 'सुरक्षा';

  @override
  String get typeInfrastructure => 'बुनियादी ढांचा';

  @override
  String get typeOther => 'अन्य';

  @override
  String get statusOpenChat => 'चैट खोलें';

  @override
  String get statusBack => 'दूसरी आपात स्थिति रिपोर्ट करें';

  @override
  String get chatTitle => 'आपातकाल चैट';

  @override
  String get chatPlaceholder => 'संदेश लिखें...';

  @override
  String get chatSend => 'भेजें';

  @override
  String get chatConnecting => 'कनेक्ट हो रहे हैं...';

  @override
  String get offlineWarning => 'इंटरनेट नहीं — ऑफ़लाइन गाइड उपयोग हो रही है';

  @override
  String get offlineGuideTitle => 'आपातकालीन सुरक्षा गाइड';

  @override
  String get errorGeneric => 'कुछ गलत हो गया। कृपया पुनः प्रयास करें।';

  @override
  String get errorNoLocation => 'आपका स्थान निर्धारित नहीं हो सका।';

  @override
  String get errorSendFailed => 'SOS भेजने में विफल। रिसेप्शन को कॉल करें।';

  @override
  String get guideFire => 'आग आपातकाल';

  @override
  String get guideMedical => 'चिकित्सा / सीपीआर';

  @override
  String get guideChoking => 'दम घुटना (हेमलिच)';

  @override
  String get guideCardiac => 'हृदय गति रुकना';

  @override
  String get guideWounds => 'गंभीर घाव';

  @override
  String get guideBurns => 'जलन';

  @override
  String get guideSecurity => 'सुरक्षा खतरा';

  @override
  String get guideGasLeak => 'गैस रिसाव';

  @override
  String get guideEarthquake => 'भूकंप';

  @override
  String get guideFlood => 'बाढ़';
}
