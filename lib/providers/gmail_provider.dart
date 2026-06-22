import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/gmail_service.dart';

class GmailNotifier extends AsyncNotifier<GoogleSignInAccount?> {
  @override
  Future<GoogleSignInAccount?> build() async {
    return GmailService.signInSilently();
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    final account = await GmailService.signIn();
    state = AsyncData(account);
  }

  Future<void> signOut() async {
    await GmailService.signOut();
    state = const AsyncData(null);
  }

  bool get isConnected => state.valueOrNull != null;
}

final gmailProvider =
    AsyncNotifierProvider<GmailNotifier, GoogleSignInAccount?>(
  GmailNotifier.new,
);
