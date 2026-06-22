import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../models/email_brief.dart';

// TODO: To enable Gmail integration:
// 1. Create a project at https://console.cloud.google.com
// 2. Enable the Gmail API
// 3. Create OAuth 2.0 credentials (iOS + Android)
// 4. For iOS: add REVERSED_CLIENT_ID to ios/Runner/Info.plist CFBundleURLTypes
// 5. For Android: place google-services.json in android/app/

class GmailService {
  static final _signIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
  );

  static GoogleSignInAccount? get currentAccount => _signIn.currentUser;

  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _signIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _signIn.signIn();
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    await _signIn.signOut();
  }

  static Future<List<EmailBrief>> getRecentEmails({int maxResults = 8}) async {
    try {
      final account = _signIn.currentUser ?? await _signIn.signInSilently();
      if (account == null) return [];

      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null) return [];

      final client = _AuthClient(token);
      final gmailApi = gmail.GmailApi(client);

      final listResponse = await gmailApi.users.messages.list(
        'me',
        labelIds: ['INBOX', 'UNREAD'],
        maxResults: maxResults,
      );

      final messages = listResponse.messages ?? [];
      final briefs = <EmailBrief>[];

      for (final msg in messages) {
        final full = await gmailApi.users.messages.get(
          'me',
          msg.id!,
          format: 'metadata',
          metadataHeaders: ['Subject', 'From', 'Date'],
        );

        String subject = '';
        String from = '';
        String dateStr = '';

        for (final header in full.payload?.headers ?? []) {
          switch (header.name) {
            case 'Subject':
              subject = header.value ?? '';
              break;
            case 'From':
              from = _cleanFrom(header.value ?? '');
              break;
            case 'Date':
              dateStr = header.value ?? '';
              break;
          }
        }

        if (subject.isEmpty) continue;

        briefs.add(EmailBrief(
          subject: subject,
          from: from,
          snippet: full.snippet ?? '',
          date: _parseDate(dateStr),
        ));
      }

      return briefs;
    } catch (_) {
      return [];
    }
  }

  static String _cleanFrom(String raw) {
    // "John Doe <john@example.com>" → "John Doe"
    final match = RegExp(r'^(.+?)\s*<').firstMatch(raw);
    if (match != null) return match.group(1)!.trim().replaceAll('"', '');
    return raw.split('@').first;
  }

  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.now();
    }
  }
}

class _AuthClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  _AuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
