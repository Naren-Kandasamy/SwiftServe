import 'package:url_launcher/url_launcher.dart';
import 'package:shared/models/alert.dart';

class SmsFallbackService {
  // Mock staff emergency number as required by project spec
  static const String _emergencyStaffNumber = '+15550198000';

  static Future<bool> sendSmsAlert(Alert alert) async {
    final typeName = alert.type?.name.toUpperCase() ?? 'UNKNOWN';
    final severityStr = alert.severity != null ? 'Lvl \${alert.severity}' : 'Lvl ?';
    
    // Construct a compact SMS message (under 160 characters ideally)
    final String message = 
      'CRISISNET SOS: \$typeName (\$severityStr) '
      'ID: \${alert.id.substring(0, 8)} '
      'Loc: Rm \${alert.roomNumber}, Fl \${alert.floor} '
      'Desc: \${alert.description}';

    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: _emergencyStaffNumber,
        queryParameters: <String, String>{
          'body': message,
        },
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        print('[SmsFallbackService] SMS intent launched successfully.');
        return true;
      } else {
        print('[SmsFallbackService] Could not launch SMS intent.');
        return false;
      }
    } catch (e) {
      print('[SmsFallbackService] Error sending SMS: \$e');
      return false;
    }
  }
}
