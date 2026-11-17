import '../../admin/data/estate_admin_repository.dart';

class LandlordPropertyDocument {
  const LandlordPropertyDocument({
    required this.accessId,
    required this.propertyId,
    required this.propertyLabel,
    required this.name,
    required this.category,
    required this.contentType,
    required this.updatedAt,
  });

  /// Non-sensitive access identifier only. Never a storage key or public URL.
  final String accessId;
  final String propertyId;
  final String propertyLabel;
  final String name;
  final String category;
  final String contentType;
  final DateTime updatedAt;
}

class LandlordMaintenanceUpdate {
  const LandlordMaintenanceUpdate({
    required this.body,
    required this.occurredAt,
  });
  final String body;
  final DateTime occurredAt;
}

class LandlordMaintenanceRequest {
  const LandlordMaintenanceRequest({
    required this.id,
    required this.reference,
    required this.propertyLabel,
    required this.category,
    required this.priority,
    required this.description,
    required this.status,
    required this.submittedAt,
    required this.updates,
  });
  final String id,
      reference,
      propertyLabel,
      category,
      priority,
      description,
      status;
  final DateTime submittedAt;
  final List<LandlordMaintenanceUpdate> updates;
}

abstract interface class LandlordRepository {
  Future<List<LandlordPortfolioItem>> loadMyProperties();
  Future<List<EstateInvoiceSummary>> loadMyRentInvoices();
  Future<List<EstateInvoiceSummary>> loadMyPropertyChargeInvoices();
  Future<List<LandlordPropertyDocument>> loadMyPropertyDocuments();
  Future<List<LandlordMaintenanceRequest>> loadMyPropertyMaintenance();
}

/// Illustrative adapter for the verified landlord portfolio read model.
/// Replace with this product's authenticated API call when that route is available.
class PreviewLandlordRepository implements LandlordRepository {
  PreviewLandlordRepository({EstateAdminRepository? source})
    : _source = source ?? PreviewEstateAdminRepository();

  final EstateAdminRepository _source;

  @override
  Future<List<LandlordPortfolioItem>> loadMyProperties() =>
      _source.loadLandlordPortfolio();

  @override
  Future<List<EstateInvoiceSummary>> loadMyRentInvoices() async =>
      List.unmodifiable(_rentInvoices);

  @override
  Future<List<EstateInvoiceSummary>> loadMyPropertyChargeInvoices() async =>
      List.unmodifiable(_propertyChargeInvoices);

  @override
  Future<List<LandlordPropertyDocument>> loadMyPropertyDocuments() async =>
      List.unmodifiable(_propertyDocuments);

  @override
  Future<List<LandlordMaintenanceRequest>> loadMyPropertyMaintenance() async =>
      List.unmodifiable(_maintenanceRequests);

  // Illustrative, relationship-scoped rent invoices; not estate admin invoices.
  static const _rentInvoices = <EstateInvoiceSummary>[
    EstateInvoiceSummary(
      id: 'landlord-inv-2108',
      invoiceNumber: 'OAK-RENT-2108',
      category: 'Monthly rent',
      status: 'paid',
      dueAt: '2026-10-05T23:59:00+01:00',
      total: '1850000',
      allocated: '1850000',
      balance: '0',
      currency: 'NGN',
      overdue: false,
      disputed: false,
      payerDisplayName: 'Ada Okafor',
      propertyCode: 'A-12B',
      tenancyLabel: 'Monthly tenancy',
    ),
    EstateInvoiceSummary(
      id: 'landlord-inv-2109',
      invoiceNumber: 'OAK-RENT-2109',
      category: 'Monthly rent',
      status: 'partially_paid',
      dueAt: '2026-11-01T23:59:00+01:00',
      total: '2400000',
      allocated: '1200000',
      balance: '1200000',
      currency: 'NGN',
      overdue: true,
      disputed: false,
      payerDisplayName: 'Tunde Bello',
      propertyCode: 'C-04A',
      tenancyLabel: 'Monthly tenancy',
    ),
    EstateInvoiceSummary(
      id: 'landlord-inv-2114',
      invoiceNumber: 'OAK-RENT-2114',
      category: 'Monthly rent',
      status: 'issued',
      dueAt: '2026-11-10T23:59:00+01:00',
      total: '1850000',
      allocated: '0',
      balance: '1850000',
      currency: 'NGN',
      overdue: false,
      disputed: false,
      payerDisplayName: 'Ada Okafor',
      propertyCode: 'A-12B',
      tenancyLabel: 'Monthly tenancy',
    ),
  ];

  static const _propertyChargeInvoices = <EstateInvoiceSummary>[
    EstateInvoiceSummary(
      id: 'landlord-charge-3108',
      invoiceNumber: 'OAK-CHG-3108',
      category: 'Estate service charge',
      status: 'issued',
      dueAt: '2026-11-20T23:59:00+01:00',
      total: '85000',
      allocated: '0',
      balance: '85000',
      currency: 'NGN',
      overdue: false,
      disputed: false,
      payerDisplayName: 'Amara Okafor',
      propertyCode: 'A-12B',
    ),
    EstateInvoiceSummary(
      id: 'landlord-charge-3087',
      invoiceNumber: 'OAK-CHG-3087',
      category: 'Water charge',
      status: 'paid',
      dueAt: '2026-10-10T23:59:00+01:00',
      total: '18000',
      allocated: '18000',
      balance: '0',
      currency: 'NGN',
      overdue: false,
      disputed: false,
      payerDisplayName: 'Amara Okafor',
      propertyCode: 'A-12B',
    ),
    EstateInvoiceSummary(
      id: 'landlord-charge-3099',
      invoiceNumber: 'OAK-CHG-3099',
      category: 'Estate service charge',
      status: 'issued',
      dueAt: '2026-10-31T23:59:00+01:00',
      total: '96000',
      allocated: '0',
      balance: '96000',
      currency: 'NGN',
      overdue: true,
      disputed: false,
      payerDisplayName: 'Amara Okafor',
      propertyCode: 'A-12B',
    ),
  ];

  static final _propertyDocuments = <LandlordPropertyDocument>[
    LandlordPropertyDocument(
      accessId: 'preview_doc_owner_0182_001',
      propertyId: 'prop-0182',
      propertyLabel: 'Block A · 12B',
      name: 'Ownership certificate',
      category: 'ownership',
      contentType: 'application/pdf',
      updatedAt: DateTime(2026, 3, 8),
    ),
    LandlordPropertyDocument(
      accessId: 'preview_doc_lease_0182_002',
      propertyId: 'prop-0182',
      propertyLabel: 'Block A · 12B',
      name: 'Tenancy agreement',
      category: 'tenancy_agreement',
      contentType: 'application/pdf',
      updatedAt: DateTime(2026, 2, 21),
    ),
    LandlordPropertyDocument(
      accessId: 'preview_doc_inspect_0220_003',
      propertyId: 'prop-0220',
      propertyLabel: 'Block C · 04A',
      name: 'Move-in inspection report',
      category: 'inspection',
      contentType: 'application/pdf',
      updatedAt: DateTime(2025, 11, 28),
    ),
    LandlordPropertyDocument(
      accessId: 'preview_doc_repair_0301_004',
      propertyId: 'prop-0301',
      propertyLabel: 'Garden Flat 03',
      name: 'Kitchen maintenance photos',
      category: 'maintenance',
      contentType: 'image/jpeg',
      updatedAt: DateTime(2026, 10, 19),
    ),
  ];

  static final _maintenanceRequests = <LandlordMaintenanceRequest>[
    LandlordMaintenanceRequest(
      id: 'preview-maint-1008',
      reference: 'OAK-MNT-1008',
      propertyLabel: 'Block A · 12B',
      category: 'plumbing',
      priority: 'high',
      description: 'Water pressure is low in the kitchen tap.',
      status: 'in_progress',
      submittedAt: DateTime(2026, 11, 2),
      updates: [
        LandlordMaintenanceUpdate(
          body:
              'A technician has been assigned and will visit tomorrow morning.',
          occurredAt: DateTime(2026, 11, 4),
        ),
      ],
    ),
    LandlordMaintenanceRequest(
      id: 'preview-maint-1003',
      reference: 'OAK-MNT-1003',
      propertyLabel: 'Block C · 04A',
      category: 'electrical',
      priority: 'normal',
      description: 'The corridor light near the unit is not working.',
      status: 'resolved',
      submittedAt: DateTime(2026, 10, 21),
      updates: [
        LandlordMaintenanceUpdate(
          body: 'The light has been replaced and checked.',
          occurredAt: DateTime(2026, 10, 24),
        ),
      ],
    ),
  ];
}
