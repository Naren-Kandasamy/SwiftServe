// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'CrisisNet';

  @override
  String get sosButtonLabel => 'ENVIAR SOS';

  @override
  String get sosButtonHint => 'Presione para alertar al personal de emergencia';

  @override
  String get sosRecordingLabel => 'Grabando...';

  @override
  String get sosTypeLabel => 'Tipo de emergencia';

  @override
  String get sosRoomLabel => 'Habitación / Ubicación';

  @override
  String get sosDescriptionHint => 'Describa lo que está pasando...';

  @override
  String get sosAttachPhoto => 'Adjuntar foto';

  @override
  String get sosRemovePhoto => 'Eliminar';

  @override
  String get sosSending => 'Enviando SOS...';

  @override
  String get sosSent => 'SOS Enviado';

  @override
  String get statusTitle => 'Estado de emergencia';

  @override
  String get statusWaiting => 'Esperando respuesta...';

  @override
  String get statusTriaged => 'Clasificado por IA';

  @override
  String get statusAssigned => 'Personal enviado';

  @override
  String get statusEscalated => 'Derivado a servicios de emergencia';

  @override
  String get statusResolved => 'Resuelto';

  @override
  String get statusContained => 'Contenido';

  @override
  String get statusInstructions => 'Instrucciones de seguridad';

  @override
  String get statusRoom => 'Habitación';

  @override
  String get statusType => 'Tipo de emergencia';

  @override
  String get typeFire => 'Incendio';

  @override
  String get typeMedical => 'Médica';

  @override
  String get typeSecurity => 'Seguridad';

  @override
  String get typeInfrastructure => 'Infraestructura';

  @override
  String get typeOther => 'Otro';

  @override
  String get statusOpenChat => 'Abrir chat';

  @override
  String get statusBack => 'Reportar otra emergencia';

  @override
  String get chatTitle => 'Chat de emergencia';

  @override
  String get chatPlaceholder => 'Escribe un mensaje...';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatConnecting => 'Conectando...';

  @override
  String get offlineWarning => 'Sin internet — usando guía offline';

  @override
  String get offlineGuideTitle => 'Guía de seguridad de emergencia';

  @override
  String get errorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get errorNoLocation => 'No se pudo determinar tu ubicación.';

  @override
  String get errorSendFailed => 'Error al enviar SOS. Llama a recepción.';
}
