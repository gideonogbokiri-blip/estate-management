import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_base_url.dart';
import '../../../core/config/shared_session.dart';
import 'platform_application_repository.dart';

class PlatformApiException implements Exception {
  const PlatformApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PlatformApplicationApiClient implements PlatformApplicationApiRepository {
  PlatformApplicationApiClient({http.Client? client})
    : _client = client ?? http.Client();

  static const _compiledBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4100/api/v1',
  );
  static String get _baseUrl => runtimeApiBaseUrl() ?? _compiledBaseUrl;
  static const _accessKey = 'estate.platform.accessToken';
  static const _refreshKey = 'estate.platform.refreshToken';
  static const _storage = FlutterSecureStorage();

  final http.Client _client;
  String? _webAccessToken;
  String? _webRefreshToken;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{'Accept': 'application/json', ...?additionalHeaders};
    if (body != null) headers['Content-Type'] = 'application/json';
    final activeToken = token ?? await _accessToken();
    if (activeToken != null) headers['Authorization'] = 'Bearer $activeToken';
    final request = http.Request(method, _uri(path))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    return http.Response.fromStream(await _client.send(request));
  }

  Future<Map<String, dynamic>> _json(
    Future<http.Response> responseFuture,
  ) async {
    final response = await responseFuture;
    final Object? decoded = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'The estate service could not complete the request.';
      if (decoded is Map<String, dynamic>) {
        final raw = decoded['message'];
        if (raw is String) message = raw;
        if (raw is List && raw.isNotEmpty) message = raw.first.toString();
      }
      throw PlatformApiException(message, statusCode: response.statusCode);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Future<String?> _accessToken() async {
    if (!kIsWeb) return _storage.read(key: _accessKey);
    _webAccessToken ??= sharedAccessToken();
    return _webAccessToken;
  }

  Future<String?> _refreshToken() async {
    if (!kIsWeb) return _storage.read(key: _refreshKey);
    _webRefreshToken ??= sharedRefreshToken();
    return _webRefreshToken;
  }

  Future<void> _storeTokens(Map<String, dynamic> json) async {
    final access = json['accessToken'] as String?;
    final refresh = json['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw const PlatformApiException(
        'The service returned an invalid session.',
      );
    }
    if (kIsWeb) {
      _webAccessToken = access;
      _webRefreshToken = refresh;
    } else {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    }
  }

  Future<void> _clearTokens() async {
    if (kIsWeb) {
      _webAccessToken = null;
      _webRefreshToken = null;
      clearSharedSession();
    } else {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final json = await _json(
      _send(
        'POST',
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      ),
    );
    await _storeTokens(json);
  }

  @override
  Future<bool> restoreSession() async {
    final access = await _accessToken();
    if (access == null) return false;
    try {
      await _json(_send('GET', '/auth/me', token: access));
      return true;
    } on PlatformApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      final refresh = await _refreshToken();
      if (refresh == null) {
        await _clearTokens();
        return false;
      }
      try {
        final json = await _json(
          _send('POST', '/auth/refresh', body: {'refreshToken': refresh}),
        );
        await _storeTokens(json);
        return true;
      } on PlatformApiException {
        await _clearTokens();
        return false;
      }
    }
  }

  @override
  Future<void> signOut() async {
    final access = await _accessToken();
    try {
      if (access != null) {
        await _json(_send('POST', '/auth/logout', token: access));
      }
    } finally {
      await _clearTokens();
    }
  }

  @override
  Future<List<PlatformApplication>> loadApplications() async {
    final json = await _json(
      _send('GET', '/platform/applications?page=1&pageSize=100'),
    );
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PlatformApplicationApiParsing.fromApiJson)
        .toList(growable: false);
  }

  @override
  Future<PlatformApplication> loadApplication(String id) async =>
      PlatformApplicationApiParsing.fromApiJson(
        await _json(_send('GET', '/platform/applications/$id')),
      );

  @override
  Future<void> startReview(String id) async {
    await _json(_send('POST', '/platform/applications/$id/start-review'));
  }

  @override
  Future<List<PlatformAdministratorChoice>> loadInitialAdministrators() async {
    final json = await _json(
      _send('GET', '/platform/applications/initial-administrators'),
    );
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PlatformAdministratorChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> approve(String id, String initialAdministratorUserId) async {
    await _json(
      _send(
        'POST',
        '/platform/applications/$id/approve',
        body: {'initialAdministratorUserId': initialAdministratorUserId},
      ),
    );
  }

  @override
  Future<void> requestInformation(String id, String message) async {
    await _json(
      _send(
        'POST',
        '/platform/applications/$id/request-information',
        body: {'reason': message},
      ),
    );
  }

  @override
  Future<void> reject(String id, String reason) async {
    await _json(
      _send(
        'POST',
        '/platform/applications/$id/reject',
        body: {'reason': reason},
      ),
    );
  }

  @override
  Future<List<int>> downloadApplicationDocument(
    String applicationId,
    String documentId,
  ) async {
    final response = await _send(
      'GET',
      '/platform/applications/$applicationId/documents/$documentId/content',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlatformApiException(
        'The document could not be downloaded.',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<List<PlatformTeamMember>> loadPlatformTeam() async {
    final response = await _json(_send('GET', '/platform/admin/team'));
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlatformTeamMember.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<PlatformUserChoice>> loadPlatformUserCandidates(String search) async {
    final query = search.trim().isEmpty
        ? ''
        : '?search=${Uri.encodeQueryComponent(search.trim())}';
    final response = await _json(
      _send('GET', '/platform/admin/team/candidates$query'),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlatformUserChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> grantPlatformRole({
    required String userId,
    required String roleKey,
  }) async {
    await _json(
      _send(
        'POST',
        '/platform/admin/team/roles',
        body: {'userId': userId, 'roleKey': roleKey},
      ),
    );
  }

  @override
  Future<void> revokePlatformRole({
    required String userId,
    required String roleKey,
  }) async {
    await _json(
      _send(
        'DELETE',
        '/platform/admin/team/roles/$userId/$roleKey',
      ),
    );
  }

  @override
  Future<List<PlatformEstateRecord>> loadPlatformEstates({
    String? search,
    String? status,
  }) async {
    final query = <String, String>{
      'pageSize': '100',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final path = Uri(
      path: '/platform/admin/estates',
      queryParameters: query,
    ).toString();
    final response = await _json(_send('GET', path));
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlatformEstateRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<PlatformMoneyOverview> loadPlatformMoneyOverview() async {
    final response = await _json(
      _send('GET', '/platform/admin/money/overview'),
    );
    return PlatformMoneyOverview.fromJson(response);
  }

  @override
  Future<List<PlatformMoneyAccount>> loadPlatformMoneyAccounts(
    String estateId,
  ) async {
    final response = await _json(
      _send(
        'GET',
        '/platform/admin/money/estates/$estateId/accounts?pageSize=100',
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlatformMoneyAccount.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> adjustPlatformBalance({
    required String estateId,
    required String userId,
    required String amount,
    required String currency,
    required String direction,
    required String reason,
    required String idempotencyKey,
  }) async {
    await _json(
      _send(
        'POST',
        '/platform/admin/money/estates/$estateId/accounts/$userId/adjustments',
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: {
          'amount': amount,
          'currency': currency,
          'direction': direction,
          'reason': reason,
        },
      ),
    );
  }

  @override
  Future<List<PlatformBalanceAdjustment>> loadPlatformBalanceAdjustments(
    String estateId,
    String userId,
  ) async {
    final response = await _json(
      _send(
        'GET',
        '/platform/admin/money/estates/$estateId/accounts/$userId/adjustments?pageSize=50',
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlatformBalanceAdjustment.fromJson)
        .toList(growable: false);
  }
}

extension PlatformApplicationApiParsing on PlatformApplication {
  static PlatformApplication fromApiJson(Map<String, dynamic> json) {
    final applicant = json['applicant'];
    final name = applicant is Map<String, dynamic>
        ? (applicant['displayName'] as String? ?? '')
        : (json['applicantContactName'] as String? ?? '');
    final email = applicant is Map<String, dynamic>
        ? (applicant['emailNormalized'] as String? ?? '')
        : (json['applicantContactEmail'] as String? ?? '');
    final documents = json['documents'];
    final parsedDocuments = documents is List
        ? documents
              .whereType<Map<String, dynamic>>()
              .map((document) {
                return PlatformApplicationDocument(
                  id: document['id'] as String? ?? '',
                  label: document['displayName'] as String? ?? '',
                  category: document['category'] as String? ?? '',
                  reviewStatus: document['status'] as String? ?? 'pending',
                  uploadedAt:
                      DateTime.tryParse(
                        document['uploadedAt'] as String? ?? '',
                      ) ??
                      DateTime.now(),
                );
              })
              .toList(growable: false)
        : const <PlatformApplicationDocument>[];
    final homeCount = json['homeCount'];
    final phaseCount = json['phaseCount'];
    final submittedAt = DateTime.tryParse(json['submittedAt'] as String? ?? '');
    return PlatformApplication(
      id: json['id'] as String? ?? '',
      code: json['applicationCode'] as String? ?? '',
      estateName: json['proposedName'] as String? ?? '',
      estateType: json['estateType'] as String? ?? '',
      location: [
        json['lga'],
        json['state'],
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', '),
      applicantName: name,
      applicantUserId: applicant is Map<String, dynamic>
          ? applicant['id'] as String? ?? ''
          : '',
      applicantEmail: email,
      submittedAt: submittedAt ?? DateTime.now(),
      status: json['status'] as String? ?? 'submitted',
      documentCount:
          (json['documentCount'] as num?)?.toInt() ?? parsedDocuments.length,
      pendingDocumentCount:
          (json['pendingDocumentCount'] as num?)?.toInt() ??
          parsedDocuments
              .where((document) => document.reviewStatus == 'pending')
              .length,
      managementEntityName: json['managementEntityName'] as String?,
      registrationNumber: json['registrationNumber'] as String?,
      applicantRelationship: json['applicantRelationship'] as String?,
      homeCount: (homeCount as num?)?.toInt(),
      phaseCount: (phaseCount as num?)?.toInt(),
      structureSummary: json['structureSummary'] as String?,
      documents: parsedDocuments,
      reviewMessage: json['decisionReason'] as String?,
    );
  }
}
