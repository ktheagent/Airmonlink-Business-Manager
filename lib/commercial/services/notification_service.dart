import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/database_service.dart';

class NotificationService {
  const NotificationService(this._database);

  final DatabaseService _database;

  Future<void> openWhatsApp({
    required String phone,
    required String message,
    String documentType = '',
    int? documentId,
  }) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) throw ArgumentError('Customer phone number is required.');
    final uri = Uri.https('wa.me', '/$normalized', {'text': message});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    await _log(
      channel: 'whatsapp',
      recipient: normalized,
      documentType: documentType,
      documentId: documentId,
      status: opened ? 'opened' : 'failed',
      error: opened ? '' : 'WhatsApp could not be opened.',
    );
    if (!opened) throw StateError('WhatsApp could not be opened.');
  }

  Future<void> sendEmail({
    required String host,
    required int port,
    required bool ssl,
    required String username,
    required String password,
    required String senderName,
    required String recipient,
    required String subject,
    required String body,
    String? attachmentPath,
    String documentType = '',
    int? documentId,
  }) async {
    final server = SmtpServer(
      host,
      port: port,
      ssl: ssl,
      username: username,
      password: password,
      allowInsecure: false,
    );
    final message = Message()
      ..from = Address(username, senderName)
      ..recipients.add(recipient)
      ..subject = subject
      ..text = body;
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      final file = File(attachmentPath);
      if (!await file.exists()) throw StateError('Email attachment was not found.');
      message.attachments.add(FileAttachment(file));
    }
    try {
      await send(message, server, timeout: const Duration(seconds: 30));
      await _log(
        channel: 'email',
        recipient: recipient,
        documentType: documentType,
        documentId: documentId,
        status: 'sent',
      );
    } catch (error) {
      await _log(
        channel: 'email',
        recipient: recipient,
        documentType: documentType,
        documentId: documentId,
        status: 'failed',
        error: '$error',
      );
      rethrow;
    }
  }

  Future<void> _log({
    required String channel,
    required String recipient,
    required String documentType,
    required int? documentId,
    required String status,
    String error = '',
  }) async {
    final db = await _database.database;
    await db.insert('notification_logs', {
      'channel': channel,
      'recipient': recipient,
      'document_type': documentType,
      'document_id': documentId,
      'status': status,
      'error_message': error,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
