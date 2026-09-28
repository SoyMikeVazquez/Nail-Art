import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  // System default fallback loaded safely from environment variables
  static String get _defaultApiKey => dotenv.env['RESEND_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.resend.com/emails';

  /// Retrieves the Resend API Key dynamically from the Secrets table.
  /// If resend_use_default is true or no key is found, falls back to the default API Key.
  static Future<String> getResendApiKey() async {
    try {
      final response = await Supabase.instance.client
          .from('Secrets')
          .select('key, value')
          .inFilter('key', ['resend_api_key', 'resend_use_default']);
      
      String? customKey;
      bool useDefault = true;

      for (var row in response) {
        final key = row['key'] as String;
        final val = row['value'] as String? ?? '';
        if (key == 'resend_use_default') {
          useDefault = val == 'true';
        } else if (key == 'resend_api_key') {
          customKey = val;
        }
      }

      if (useDefault || customKey == null || customKey.trim().isEmpty) {
        return _defaultApiKey;
      }
      return customKey.trim();
    } catch (e) {
      debugPrint('EmailService: Error loading Resend API key: $e');
      return _defaultApiKey;
    }
  }

  /// Sends a raw email via Resend API
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
    String? from,
  }) async {
    try {
      // 1. Fetch dynamic business name from the General table
      String companyName = 'Nail Art';
      try {
        final generalData = await Supabase.instance.client
            .from('General')
            .select('NombreDeLaEmpresa')
            .limit(1)
            .maybeSingle();
        if (generalData != null && generalData['NombreDeLaEmpresa'] != null) {
          final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
          if (dbName.isNotEmpty) {
            companyName = dbName;
          }
        }
      } catch (e) {
        debugPrint('EmailService: Error fetching company name from DB: $e');
      }

      // If no 'from' address is provided, use the verified domain to allow sending to any email
      final String finalFrom = from ?? '$companyName <notificaciones-nailart@soymikevazquez.com>';

      final uri = Uri.parse(_baseUrl);
      final body = {
        'from': finalFrom,
        'to': [to],
        'subject': subject,
        'html': htmlContent,
      };

      final apiKey = await getResendApiKey();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('EmailService: Email successfully sent to $to');
        return true;
      } else {
        debugPrint('EmailService: Failed to send email (status: ${response.statusCode}) - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('EmailService: Exception during sendEmail: $e');
      return false;
    }
  }

  /// Sends a premium Welcome Email to a newly registered user
  static Future<bool> sendWelcomeEmail({
    required String toEmail,
    required String clientName,
  }) async {
    // Fetch company name dynamically
    String companyName = 'Nail Art';
    try {
      final generalData = await Supabase.instance.client
          .from('General')
          .select('NombreDeLaEmpresa')
          .limit(1)
          .maybeSingle();
      if (generalData != null && generalData['NombreDeLaEmpresa'] != null) {
        final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
        if (dbName.isNotEmpty) {
          companyName = dbName;
        }
      }
    } catch (_) {}

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>¡Te damos la bienvenida a $companyName!</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #FAFAFA;
      color: #1A1A1A;
      margin: 0;
      padding: 0;
    }
    .wrapper {
      width: 100%;
      background-color: #FAFAFA;
      padding: 40px 0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      border: 1px solid #EEEEEE;
    }
    .header {
      background-color: #000000;
      color: #FFFFFF;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 26px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .content {
      padding: 40px 30px;
      line-height: 1.6;
    }
    .content h2 {
      font-size: 20px;
      font-weight: 700;
      color: #000000;
      margin-top: 0;
      margin-bottom: 16px;
      letter-spacing: -0.3px;
    }
    .content p {
      font-size: 15px;
      color: #4A4A4A;
      margin-bottom: 24px;
    }
    .button-container {
      text-align: center;
      margin: 35px 0;
    }
    .button {
      background-color: #000000;
      color: #FFFFFF !important;
      padding: 16px 32px;
      text-decoration: none;
      font-weight: bold;
      border-radius: 12px;
      font-size: 15px;
      display: inline-block;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }
    .footer {
      background-color: #F5F5F5;
      padding: 24px 30px;
      text-align: center;
      font-size: 12px;
      color: #888888;
      border-top: 1px solid #EEEEEE;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <h1>$companyName</h1>
      </div>
      <div class="content">
        <h2>¡Te damos la bienvenida, $clientName! 👋</h2>
        <p>Estamos muy entusiasmados de tenerte con nosotros. A partir de este momento, puedes comenzar a disfrutar de los beneficios exclusivos de nuestra plataforma:</p>
        <p>✔️ Agendar y gestionar tus citas en segundos.<br>
           ✔️ Acumular estrellas en tu tarjeta digital de fidelidad para obtener recompensas.<br>
           ✔️ Mantenerte informado sobre nuestras promociones y lanzamientos exclusivos.</p>
        <p>Para agendar tu primera cita o ver tu perfil de fidelidad, presiona el botón de abajo:</p>
        
        <div class="button-container">
          <a href="https://ailartmexico.io" target="_blank" class="button">Comenzar Ahora</a>
        </div>
        
        <p>Si tienes alguna duda o sugerencia, no dudes en ponerte en contacto con nuestro equipo de soporte directamente a través de la aplicación.</p>
        <p>¡Esperamos verte muy pronto!</p>
        <p>Atentamente,<br><strong>El equipo de $companyName</strong></p>
      </div>
      <div class="footer">
        Este es un mensaje de correo automático enviado por $companyName. Por favor, no respondas directamente a este remitente.
      </div>
    </div>
  </div>
</body>
</html>
''';

    return sendEmail(
      to: toEmail,
      subject: '¡Te damos la bienvenida a $companyName! 🎉',
      htmlContent: html,
    );
  }

  /// Sends a gorgeous, professional Appointment Confirmation Email
  static Future<bool> sendBookingEmail({
    required String toEmail,
    required String clientName,
    required String serviceName,
    required String staffName,
    required String appointmentDate,
    required String appointmentTime,
    required String price,
  }) async {
    // Fetch company name dynamically
    String companyName = 'Nail Art';
    try {
      final generalData = await Supabase.instance.client
          .from('General')
          .select('NombreDeLaEmpresa')
          .limit(1)
          .maybeSingle();
      if (generalData != null && generalData['NombreDeLaEmpresa'] != null) {
        final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
        if (dbName.isNotEmpty) {
          companyName = dbName;
        }
      }
    } catch (_) {}

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Confirmación de Reserva - $companyName</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #FAFAFA;
      color: #1A1A1A;
      margin: 0;
      padding: 0;
    }
    .wrapper {
      width: 100%;
      background-color: #FAFAFA;
      padding: 40px 0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      border: 1px solid #EEEEEE;
    }
    .header {
      background-color: #000000;
      color: #FFFFFF;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .content {
      padding: 40px 30px;
      line-height: 1.6;
    }
    .content h2 {
      font-size: 20px;
      font-weight: 700;
      color: #000000;
      margin-top: 0;
      margin-bottom: 16px;
      letter-spacing: -0.3px;
    }
    .content p {
      font-size: 15px;
      color: #4A4A4A;
      margin-bottom: 24px;
    }
    .details-box {
      background-color: #F9F9F9;
      border-left: 4px solid #000000;
      padding: 24px;
      margin: 24px 0;
      border-radius: 0 12px 12px 0;
    }
    .details-title {
      font-size: 15px;
      font-weight: 700;
      color: #000000;
      margin-bottom: 16px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .details-row {
      margin-bottom: 12px;
      font-size: 14.5px;
      color: #333333;
      display: flex;
    }
    .details-label {
      font-weight: 700;
      color: #000000;
      width: 110px;
      flex-shrink: 0;
    }
    .details-val {
      color: #4A4A4A;
    }
    .footer {
      background-color: #F5F5F5;
      padding: 24px 30px;
      text-align: center;
      font-size: 12px;
      color: #888888;
      border-top: 1px solid #EEEEEE;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <h1>Reserva Confirmada</h1>
      </div>
      <div class="content">
        <h2>¡Hola, $clientName!</h2>
        <p>Tu cita ha sido agendada con éxito. A continuación te presentamos el resumen completo de tu reservación:</p>
        
        <div class="details-box">
          <div class="details-title">Detalles de la Cita</div>
          
          <table border="0" cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Servicio:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$serviceName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Especialista:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$staffName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Fecha:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentDate</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Hora:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentTime hs</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Precio Final:</td>
              <td style="padding: 6px 0; color: #000000; font-weight: bold; font-size: 14.5px;">$price</td>
            </tr>
          </table>
        </div>

        <p>Te recomendamos asistir con 5 minutos de anticipación. Si requieres cancelar o reprogramar tu reservación, recuerda que puedes gestionarlo directamente desde el apartado de Citas de la app.</p>
        <p>¡Muchas gracias por elegirnos!</p>
        <p>Atentamente,<br><strong>El equipo de $companyName</strong></p>
      </div>
      <div class="footer">
        Este es un mensaje de correo automático enviado por $companyName. Por favor, no respondas directamente a este remitente.
      </div>
    </div>
  </div>
</body>
</html>
''';

    return sendEmail(
      to: toEmail,
      subject: 'Confirmación de tu Cita - $companyName 📅',
      htmlContent: html,
    );
  }

  /// Sends a notification email to the staff member with the booking details
  static Future<bool> sendStaffBookingEmail({
    required String staffEmail,
    required String staffName,
    required String clientName,
    required String clientPhone,
    required String clientEmail,
    required String serviceName,
    required String appointmentDate,
    required String appointmentTime,
    required String price,
  }) async {
    // Fetch company name dynamically
    String companyName = 'Nail Art';
    try {
      final generalData = await Supabase.instance.client
          .from('General')
          .select('NombreDeLaEmpresa')
          .limit(1)
          .maybeSingle();
      if (generalData != null && generalData['NombreDeLaEmpresa'] != null) {
        final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
        if (dbName.isNotEmpty) {
          companyName = dbName;
        }
      }
    } catch (_) {}

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Nueva Cita Asignada - $companyName</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #FAFAFA;
      color: #1A1A1A;
      margin: 0;
      padding: 0;
    }
    .wrapper {
      width: 100%;
      background-color: #FAFAFA;
      padding: 40px 0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      border: 1px solid #EEEEEE;
    }
    .header {
      background-color: #000000;
      color: #FFFFFF;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .content {
      padding: 40px 30px;
      line-height: 1.6;
    }
    .content h2 {
      font-size: 20px;
      font-weight: 700;
      color: #000000;
      margin-top: 0;
      margin-bottom: 16px;
      letter-spacing: -0.3px;
    }
    .content p {
      font-size: 15px;
      color: #4A4A4A;
      margin-bottom: 24px;
    }
    .details-box {
      background-color: #F9F9F9;
      border-left: 4px solid #FF9800;
      padding: 24px;
      margin: 24px 0;
      border-radius: 0 12px 12px 0;
    }
    .details-title {
      font-size: 15px;
      font-weight: 700;
      color: #000000;
      margin-bottom: 16px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .footer {
      background-color: #F5F5F5;
      padding: 24px 30px;
      text-align: center;
      font-size: 12px;
      color: #888888;
      border-top: 1px solid #EEEEEE;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <h1>Nueva Cita Asignada</h1>
      </div>
      <div class="content">
        <h2>¡Hola, $staffName! 👋</h2>
        <p>Se ha reservado una nueva cita en la plataforma para ti. A continuación tienes los detalles completos de la cita y del cliente:</p>
        
        <div class="details-box">
          <div class="details-title">Resumen de la Cita</div>
          
          <table border="0" cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Cliente:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$clientName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Teléfono:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$clientPhone</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Correo:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$clientEmail</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Servicio(s):</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$serviceName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Fecha:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentDate</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Hora:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentTime hs</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Precio Cobrado:</td>
              <td style="padding: 6px 0; color: #000000; font-weight: bold; font-size: 14.5px;">$price</td>
            </tr>
          </table>
        </div>

        <p>Por favor asegúrate de estar listo a la hora indicada. Puedes consultar la agenda completa de tus citas ingresando al panel de personal en la aplicación.</p>
        <p>¡Buen servicio!</p>
        <p>Atentamente,<br><strong>El sistema de $companyName</strong></p>
      </div>
      <div class="footer">
        Este es un mensaje automático de control interno para el personal de $companyName.
      </div>
    </div>
  </div>
</body>
</html>
''';

    return sendEmail(
      to: staffEmail,
      subject: 'Nueva Cita Asignada - $clientName 📅',
      htmlContent: html,
    );
  }

  /// Sends a notification email to the master/general email address with all booking details.
  /// It automatically queries the single row of table 'General' to find 'correoNotificacionesGeneral'.
  static Future<bool> sendGeneralBookingNotificationEmail({
    required String clientName,
    required String clientPhone,
    required String clientEmail,
    required String serviceName,
    required String staffName,
    required String appointmentDate,
    required String appointmentTime,
    required String price,
  }) async {
    try {
      // 1. Fetch correoNotificacionesGeneral dynamically from General table
      String? generalNotificationEmail;
      String companyName = 'Nail Art';
      try {
        final generalData = await Supabase.instance.client
            .from('General')
            .select('correoNotificacionesGeneral, NombreDeLaEmpresa')
            .limit(1)
            .maybeSingle();
        if (generalData != null) {
          if (generalData['correoNotificacionesGeneral'] != null) {
            generalNotificationEmail = generalData['correoNotificacionesGeneral'].toString().trim();
          }
          if (generalData['NombreDeLaEmpresa'] != null) {
            final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
            if (dbName.isNotEmpty) {
              companyName = dbName;
            }
          }
        }
      } catch (e) {
        debugPrint('EmailService: Error fetching general email from DB: $e');
      }

      // If no general email is configured, print log and return false (silent)
      if (generalNotificationEmail == null || generalNotificationEmail.isEmpty) {
        debugPrint('EmailService: No master notification email configured in General table.');
        return false;
      }

      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Notificación Master - Nueva Cita - $companyName</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #FAFAFA;
      color: #1A1A1A;
      margin: 0;
      padding: 0;
    }
    .wrapper {
      width: 100%;
      background-color: #FAFAFA;
      padding: 40px 0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      border: 1px solid #EEEEEE;
    }
    .header {
      background-color: #000000;
      color: #FFFFFF;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .content {
      padding: 40px 30px;
      line-height: 1.6;
    }
    .content h2 {
      font-size: 20px;
      font-weight: 700;
      color: #000000;
      margin-top: 0;
      margin-bottom: 16px;
      letter-spacing: -0.3px;
    }
    .content p {
      font-size: 15px;
      color: #4A4A4A;
      margin-bottom: 24px;
    }
    .details-box {
      background-color: #F9F9F9;
      border-left: 4px solid #9C27B0;
      padding: 24px;
      margin: 24px 0;
      border-radius: 0 12px 12px 0;
    }
    .details-title {
      font-size: 15px;
      font-weight: 700;
      color: #000000;
      margin-bottom: 16px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .footer {
      background-color: #F5F5F5;
      padding: 24px 30px;
      text-align: center;
      font-size: 12px;
      color: #888888;
      border-top: 1px solid #EEEEEE;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <h1>Control Global de Citas</h1>
      </div>
      <div class="content">
        <h2>Notificación de Nueva Reserva 🚀</h2>
        <p>Se ha registrado una nueva cita en la plataforma. A continuación tienes los detalles logísticos completos para supervisión general:</p>
        
        <div class="details-box">
          <div class="details-title">Detalles de la Cita</div>
          
          <table border="0" cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Cliente:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$clientName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Teléfono:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$clientPhone</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Correo Cliente:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$clientEmail</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Servicio(s):</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$serviceName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Especialista:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$staffName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Fecha:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentDate</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Hora:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentTime hs</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 130px; font-size: 14.5px;">Precio Cobrado:</td>
              <td style="padding: 6px 0; color: #000000; font-weight: bold; font-size: 14.5px;">$price</td>
            </tr>
          </table>
        </div>

        <p>Esta es una alerta de control administrativo automático de la aplicación.</p>
        <p>Atentamente,<br><strong>El sistema de $companyName</strong></p>
      </div>
      <div class="footer">
        Este es un correo administrativo automático enviado por la plataforma de $companyName.
      </div>
    </div>
  </div>
</body>
</html>
''';

      return sendEmail(
        to: generalNotificationEmail,
        subject: 'Notificación Master: Nueva Cita - $clientName 🚀',
        htmlContent: html,
      );
    } catch (e) {
      debugPrint('EmailService: Exception in sendGeneralBookingNotificationEmail: $e');
      return false;
    }
  }

  /// Sends a gorgeous, professional Appointment Cancellation Email
  static Future<bool> sendCancellationEmail({
    required String toEmail,
    required String clientName,
    required String serviceName,
    required String staffName,
    required String appointmentDate,
    required String appointmentTime,
  }) async {
    // Fetch company name dynamically
    String companyName = 'Nail Art';
    try {
      final generalData = await Supabase.instance.client
          .from('General')
          .select('NombreDeLaEmpresa')
          .limit(1)
          .maybeSingle();
      if (generalData != null && generalData['NombreDeLaEmpresa'] != null) {
        final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
        if (dbName.isNotEmpty) {
          companyName = dbName;
        }
      }
    } catch (_) {}

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cancelación de Reserva - $companyName</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #FAFAFA;
      color: #1A1A1A;
      margin: 0;
      padding: 0;
    }
    .wrapper {
      width: 100%;
      background-color: #FAFAFA;
      padding: 40px 0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      border: 1px solid #EEEEEE;
    }
    .header {
      background-color: #D32F2F;
      color: #FFFFFF;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .content {
      padding: 40px 30px;
      line-height: 1.6;
    }
    .content h2 {
      font-size: 20px;
      font-weight: 700;
      color: #000000;
      margin-top: 0;
      margin-bottom: 16px;
      letter-spacing: -0.3px;
    }
    .content p {
      font-size: 15px;
      color: #4A4A4A;
      margin-bottom: 24px;
    }
    .details-box {
      background-color: #F9F9F9;
      border-left: 4px solid #D32F2F;
      padding: 24px;
      margin: 24px 0;
      border-radius: 0 12px 12px 0;
    }
    .details-title {
      font-size: 15px;
      font-weight: 700;
      color: #000000;
      margin-bottom: 16px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .footer {
      background-color: #F5F5F5;
      padding: 24px 30px;
      text-align: center;
      font-size: 12px;
      color: #888888;
      border-top: 1px solid #EEEEEE;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <h1>Cita Cancelada</h1>
      </div>
      <div class="content">
        <h2>Hola, $clientName</h2>
        <p>Te informamos que tu cita ha sido cancelada. A continuación se presentan los detalles del servicio cancelado:</p>
        
        <div class="details-box">
          <div class="details-title">Detalles de la Cita Cancelada</div>
          
          <table border="0" cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Servicio:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$serviceName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Especialista:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$staffName</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Fecha:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentDate</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; font-weight: bold; width: 110px; font-size: 14.5px;">Hora:</td>
              <td style="padding: 6px 0; color: #4A4A4A; font-size: 14.5px;">$appointmentTime hs</td>
            </tr>
          </table>
        </div>

        <p>Si consideras que esto es un error o deseas programar una nueva cita, por favor ponte en contacto con nosotros o reserva directamente desde nuestra app.</p>
        <p>Atentamente,<br><strong>El equipo de $companyName</strong></p>
      </div>
      <div class="footer">
        Este es un mensaje de correo automático enviado por $companyName. Por favor, no respondas directamente a este remitente.
      </div>
    </div>
  </div>
</body>
</html>
''';

    return sendEmail(
      to: toEmail,
      subject: 'Cancelación de tu Cita - $companyName ❌',
      htmlContent: html,
    );
  }

  /// Sends a beautiful, professional Digital Purchase Ticket Email
  static Future<bool> sendPurchaseTicketEmail({
    required String toEmail,
    required String clientName,
    required double total,
    required String sucursal,
    required String formaPago,
    required List<Map<String, dynamic>> items,
  }) async {
    String companyName = 'Nail Art';
    try {
      final generalData = await Supabase.instance.client
          .from('General')
          .select('NombreDeLaEmpresa')
          .limit(1)
          .maybeSingle();
      if (generalData != null && generalData['NombreDeLaEmpresa'] != null) {
        final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
        if (dbName.isNotEmpty) {
          companyName = dbName;
        }
      }
    } catch (_) {}

    final dateStr = DateTime.now().toLocal().toString().substring(0, 16);

    // Build items table rows
    final StringBuffer itemsHtml = StringBuffer();
    for (var item in items) {
      final name = item['name'] ?? item['nombre'] ?? 'Concepto';
      final price = double.tryParse((item['price'] ?? item['precio'] ?? '0').toString()) ?? 0.0;
      final qty = int.tryParse((item['qty'] ?? item['cantidad'] ?? '1').toString()) ?? 1;
      final subtotal = price * qty;

      itemsHtml.write('''
        <tr style="border-bottom: 1px solid #EEEEEE;">
          <td style="padding: 10px 0; font-size: 14px; color: #1A1A1A;">$name <span style="color: #888888; font-size: 12px;">x$qty</span></td>
          <td style="padding: 10px 0; text-align: right; font-size: 14px; color: #1A1A1A;">\$${price.toStringAsFixed(2)}</td>
          <td style="padding: 10px 0; text-align: right; font-size: 14px; font-weight: bold; color: #000000;">\$${subtotal.toStringAsFixed(2)}</td>
        </tr>
      ''');
    }

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Ticket de Compra - $companyName</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #FAFAFA;
      color: #1A1A1A;
      margin: 0;
      padding: 0;
    }
    .wrapper {
      width: 100%;
      background-color: #FAFAFA;
      padding: 40px 0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      border: 1px solid #EEEEEE;
    }
    .header {
      background-color: #000000;
      color: #FFFFFF;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .content {
      padding: 40px 30px;
      line-height: 1.6;
    }
    .content h2 {
      font-size: 20px;
      font-weight: 700;
      color: #000000;
      margin-top: 0;
      margin-bottom: 16px;
      letter-spacing: -0.3px;
    }
    .content p {
      font-size: 15px;
      color: #4A4A4A;
      margin-bottom: 24px;
    }
    .ticket-box {
      border: 1px dashed #CCCCCC;
      padding: 24px;
      margin: 24px 0;
      border-radius: 12px;
      background-color: #FCFCFC;
    }
    .ticket-title {
      font-size: 15px;
      font-weight: 800;
      color: #000000;
      margin-bottom: 16px;
      text-align: center;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .ticket-meta {
      font-size: 12px;
      color: #666666;
      margin-bottom: 20px;
      line-height: 1.5;
      border-bottom: 1px solid #EEEEEE;
      padding-bottom: 12px;
    }
    .footer {
      background-color: #F5F5F5;
      padding: 24px 30px;
      text-align: center;
      font-size: 12px;
      color: #888888;
      border-top: 1px solid #EEEEEE;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <h1>Ticket de Compra</h1>
      </div>
      <div class="content">
        <h2>¡Gracias por tu compra, ${clientName.isNotEmpty ? clientName : 'Cliente'}! 👋</h2>
        <p>A continuación te enviamos el resumen de tu transacción realizada en nuestra sucursal:</p>
        
        <div class="ticket-box">
          <div class="ticket-title">Comprobante de Pago</div>
          
          <div class="ticket-meta">
            <strong>Establecimiento:</strong> $companyName<br>
            <strong>Sucursal:</strong> $sucursal<br>
            <strong>Fecha:</strong> $dateStr<br>
            <strong>Forma de Pago:</strong> $formaPago
          </div>

          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse: collapse;">
            <thead>
              <tr style="border-bottom: 2px solid #000000; font-weight: bold; font-size: 13px; color: #000000;">
                <th style="padding: 10px 0; text-align: left;">Detalle</th>
                <th style="padding: 10px 0; text-align: right; width: 80px;">Unitario</th>
                <th style="padding: 10px 0; text-align: right; width: 80px;">Total</th>
              </tr>
            </thead>
            <tbody>
              ${itemsHtml.toString()}
              <tr style="border-top: 2px solid #000000;">
                <td colspan="2" style="padding: 16px 0 10px; font-size: 16px; font-weight: bold; color: #000000; text-align: right;">Total Pagado:</td>
                <td style="padding: 16px 0 10px; font-size: 18px; font-weight: 900; color: #000000; text-align: right;">\$${total.toStringAsFixed(2)}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <p>Esperamos que tu experiencia haya sido excelente. ¡Vuelve pronto!</p>
        <p>Atentamente,<br><strong>El equipo de $companyName</strong></p>
      </div>
      <div class="footer">
        Este es un comprobante de pago digital automático enviado por $companyName.
      </div>
    </div>
  </div>
</body>
</html>
''';

    return sendEmail(
      to: toEmail,
      subject: 'Tu Comprobante de Compra - $companyName 🧾',
      htmlContent: html,
    );
  }
}

