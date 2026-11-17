import 'dart:html' as html;

/// Written by the single sign-in page at /login/ so all Flutter web apps can
/// start with the same session without asking the user to sign in again.
String? sharedAccessToken() => html.window.localStorage['estate_shared_accessToken'];
String? sharedRefreshToken() => html.window.localStorage['estate_shared_refreshToken'];

void clearSharedSession() {
  html.window.localStorage.remove('estate_shared_accessToken');
  html.window.localStorage.remove('estate_shared_refreshToken');
}
