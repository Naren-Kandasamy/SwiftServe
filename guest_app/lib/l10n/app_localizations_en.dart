// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CrisisNet';

  @override
  String get sosButtonLabel => 'SEND SOS';

  @override
  String get sosButtonHint => 'Press to alert emergency staff';

  @override
  String get sosRecordingLabel => 'Recording...';

  @override
  String get sosTypeLabel => 'Emergency Type';

  @override
  String get sosRoomLabel => 'Room / Location';

  @override
  String get sosDescriptionHint => 'Describe what is happening...';

  @override
  String get sosAttachPhoto => 'Attach Photo';

  @override
  String get sosRemovePhoto => 'Remove';

  @override
  String get sosSending => 'Sending SOS...';

  @override
  String get sosSent => 'SOS Sent';

  @override
  String get statusTitle => 'Emergency Status';

  @override
  String get statusWaiting => 'Waiting for response...';

  @override
  String get statusTriaged => 'Triaged by AI';

  @override
  String get statusAssigned => 'Staff Dispatched';

  @override
  String get statusEscalated => 'Escalated to Emergency Services';

  @override
  String get statusResolved => 'Resolved';

  @override
  String get statusContained => 'Contained';

  @override
  String get statusInstructions => 'Safety Instructions';

  @override
  String get statusRoom => 'Room';

  @override
  String get statusType => 'Emergency Type';

  @override
  String get typeFire => 'Fire';

  @override
  String get typeMedical => 'Medical';

  @override
  String get typeSecurity => 'Security';

  @override
  String get typeInfrastructure => 'Infrastructure';

  @override
  String get typeOther => 'Other';

  @override
  String get statusOpenChat => 'Open Chat';

  @override
  String get statusBack => 'Report Another Emergency';

  @override
  String get chatTitle => 'Emergency Chat';

  @override
  String get chatPlaceholder => 'Type a message...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatConnecting => 'Connecting...';

  @override
  String get offlineWarning => 'No internet — using offline safety guide';

  @override
  String get offlineGuideTitle => 'Emergency Safety Guide';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNoLocation => 'Could not determine your location.';

  @override
  String get errorSendFailed => 'Failed to send SOS. Please call reception.';
}
