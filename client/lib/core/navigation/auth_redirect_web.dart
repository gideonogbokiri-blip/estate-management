import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';

/// Every role dashboard uses the single sign-in page at `/login/`.
/// This widget sends unauthenticated users there instead of rendering another
/// sign-in form inside each dashboard.
void goToSingleSignIn() {
  html.window.location.href = '/login/';
}

/// Shows a brief hand-off screen while the browser navigates to /login/.
Widget singleSignInRedirect() {
  unawaited(Future<void>.delayed(Duration.zero, goToSingleSignIn));
  return const Directionality(
    textDirection: TextDirection.ltr,
    child: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening sign in…'),
          ],
        ),
      ),
    ),
  );
}
