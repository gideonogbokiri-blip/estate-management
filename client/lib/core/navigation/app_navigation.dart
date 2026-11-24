import 'package:flutter/material.dart';

/// Central page navigation for LANCON.
///
/// All role dashboards push pages through this helper so transitions and
/// argument passing stay consistent as features are reorganised.
abstract final class AppNavigation {
  static Future<T?> push<T extends Object?>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    TO? result,
  }) =>
      Navigator.of(context).pushReplacement<T, TO>(
        MaterialPageRoute<T>(builder: (_) => page),
        result: result,
      );

  static void pop<T extends Object?>(BuildContext context, [T? result]) =>
      Navigator.of(context).pop<T>(result);
}

/// Stable identifiers for cross-feature navigation and future deep links.
abstract final class AppRoute {
  static const residentHome = '/resident';
  static const estateManagerHome = '/estate-manager';
  static const landlordHome = '/landlord';
  static const platformHome = '/platform';
  static const securityHome = '/security';
  static const signIn = '/login';

  static const wallet = '/resident/wallet';
  static const levies = '/resident/levies';
  static const rent = '/resident/rent';
  static const gatePass = '/resident/gate-pass';
  static const maintenance = '/resident/maintenance';
  static const facilities = '/resident/facilities';
  static const emergency = '/resident/emergency';
  static const documents = '/resident/documents';
  static const services = '/resident/services';

  static const treasury = '/estate/treasury';
  static const payouts = '/estate/payouts';
  static const propertyMap = '/estate/property-map';
  static const reports = '/estate/reports';
}
