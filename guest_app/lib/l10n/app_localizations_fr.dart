// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'CrisisNet';

  @override
  String get sosButtonLabel => 'ENVOYER SOS';

  @override
  String get sosButtonHint => 'Appuyez pour alerter le personnel d\'urgence';

  @override
  String get sosRecordingLabel => 'Enregistrement...';

  @override
  String get sosTypeLabel => 'Type d\'urgence';

  @override
  String get sosRoomLabel => 'Chambre / Lieu';

  @override
  String get sosDescriptionHint => 'Décrivez ce qui se passe...';

  @override
  String get sosAttachPhoto => 'Joindre une photo';

  @override
  String get sosRemovePhoto => 'Supprimer';

  @override
  String get sosSending => 'Envoi du SOS...';

  @override
  String get sosSent => 'SOS Envoyé';

  @override
  String get statusTitle => 'Statut d\'urgence';

  @override
  String get statusWaiting => 'En attente de réponse...';

  @override
  String get statusTriaged => 'Trié par IA';

  @override
  String get statusAssigned => 'Personnel envoyé';

  @override
  String get statusEscalated => 'Transmis aux services d\'urgence';

  @override
  String get statusResolved => 'Résolu';

  @override
  String get statusContained => 'Maîtrisé';

  @override
  String get statusInstructions => 'Consignes de sécurité';

  @override
  String get statusRoom => 'Chambre';

  @override
  String get statusType => 'Type d\'urgence';

  @override
  String get typeFire => 'Incendie';

  @override
  String get typeMedical => 'Médical';

  @override
  String get typeSecurity => 'Sécurité';

  @override
  String get typeInfrastructure => 'Infrastructure';

  @override
  String get typeOther => 'Autre';

  @override
  String get statusOpenChat => 'Ouvrir le chat';

  @override
  String get statusBack => 'Signaler une autre urgence';

  @override
  String get chatTitle => 'Chat d\'urgence';

  @override
  String get chatPlaceholder => 'Tapez un message...';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatConnecting => 'Connexion...';

  @override
  String get offlineWarning => 'Pas d\'internet — guide hors ligne utilisé';

  @override
  String get offlineGuideTitle => 'Guide de sécurité d\'urgence';

  @override
  String get errorGeneric => 'Quelque chose s\'est mal passé. Réessayez.';

  @override
  String get errorNoLocation => 'Impossible de déterminer votre emplacement.';

  @override
  String get errorSendFailed =>
      'Échec de l\'envoi du SOS. Appelez la réception.';

  @override
  String get guideFire => 'Incendie';

  @override
  String get guideMedical => 'Médical / RCR';

  @override
  String get guideChoking => 'Étouffement (Heimlich)';

  @override
  String get guideCardiac => 'Arrêt cardiaque';

  @override
  String get guideWounds => 'Blessures graves';

  @override
  String get guideBurns => 'Brûlures';

  @override
  String get guideSecurity => 'Menace de sécurité';

  @override
  String get guideGasLeak => 'Fuite de gaz';

  @override
  String get guideEarthquake => 'Tremblement de terre';

  @override
  String get guideFlood => 'Inondation';
}
