import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_application_repository.dart';
import '../../admin/presentation/estate_manager_dashboard_api_page.dart';

class EstateApplicationShell extends StatefulWidget {
  const EstateApplicationShell({
    super.key,
    required this.repository,
    required this.onSignOut,
  });
  final EstateApplicationRepository repository;
  final VoidCallback onSignOut;

  @override
  State<EstateApplicationShell> createState() => _EstateApplicationShellState();
}

class _EstateApplicationShellState extends State<EstateApplicationShell> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _state = TextEditingController();
  final _lga = TextEditingController();
  final _contactName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _management = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _homeCount = TextEditingController();
  final _phaseCount = TextEditingController();
  final _structure = TextEditingController();
  String _type = 'Gated community';
  String _relationship = 'Estate owner';
  int _step = 0;
  bool _saving = false;
  bool _loading = true;
  String? _loadError;
  EstateApplicationDraft? _draft;
  List<EstateApplicationDocumentRecord> _documents = [];
  String _documentCategory = 'management_authorization';
  bool _uploadingDocument = false;
  String? _documentError;

  bool get _applicationIsEditable =>
      _draft == null ||
      const {'draft', 'more_information_required'}.contains(_draft!.status);

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _state,
      _lga,
      _contactName,
      _email,
      _phone,
      _management,
      _registrationNumber,
      _homeCount,
      _phaseCount,
      _structure,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final draft = await widget.repository.loadMyDraft();
      final api = widget.repository;
      final documents = api is EstateApplicationApiRepository
          ? await api.loadMyApplicationDocuments()
          : const <EstateApplicationDocumentRecord>[];
      if (!mounted) return;
      _documents = documents;
      if (draft != null) {
        _draft = draft;
        _name.text = draft.proposedName;
        _type = draft.estateType;
        _address.text = draft.address;
        _state.text = draft.state;
        _lga.text = draft.lga;
        _relationship = draft.applicantRelationship;
        _contactName.text = draft.applicantContactName;
        _email.text = draft.applicantContactEmail;
        _phone.text = draft.applicantContactPhone;
        _management.text = draft.managementEntityName;
        _registrationNumber.text = draft.registrationNumber;
        _homeCount.text = draft.homeCount;
        _phaseCount.text = draft.phaseCount;
        _structure.text = draft.structureSummary;
      }
    } catch (error) {
      _loadError = error is EstateApiException ? error.message : 'Your saved application could not be loaded. Check the service connection.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEstateTeamDashboard() {
    final repository = widget.repository;
    if (repository is! EstateApplicationApiRepository) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateManagerDashboardApiPage(repository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.forest,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/onboarding_background.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xA607150F), Color(0x54101A15), Color(0xB306110B)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _Header(
                hasDraft: _draft != null && _applicationIsEditable,
                onSignOut: widget.onSignOut,
                onOpenEstateTeam: _openEstateTeamDashboard,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 950;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 28 : 16,
                            24,
                            wide ? 28 : 16,
                            36,
                          ),
                          children: [
                            const _Intro(),
                            if (_loadError != null) ...[
                              const SizedBox(height: 14),
                              _LoadErrorBanner(
                                message: _loadError!,
                                loading: _loading,
                                onRetry: _restoreDraft,
                              ),
                            ],
                            if (_draft != null && !_applicationIsEditable) ...[
                              const SizedBox(height: 14),
                              _ApplicationStatusBanner(
                                status: _draft!.status,
                                reference: _draft!.reference,
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: IgnorePointer(
                                      ignoring: !_applicationIsEditable,
                                      child: Opacity(
                                        opacity: _applicationIsEditable
                                            ? 1
                                            : .78,
                                        child: _formContent(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 4, child: _sidePanel()),
                                ],
                              )
                            else ...[
                              _stepIndicator(),
                              const SizedBox(height: 14),
                              IgnorePointer(
                                ignoring: !_applicationIsEditable,
                                child: Opacity(
                                  opacity: _applicationIsEditable ? 1 : .78,
                                  child: _formContent(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _sidePanel(),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _BottomActions(
                step: _step,
                saving: _saving,
                onBack: _step == 0 ? null : () => setState(() => _step--),
                onSave: _saveDraft,
                onContinue: _continue,
                onSubmit: _submitApplication,
                editable: _applicationIsEditable,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _formContent() => Form(
    key: _formKey,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.sizeOf(context).width >= 950) _stepIndicator(),
            if (MediaQuery.sizeOf(context).width >= 950)
              const SizedBox(height: 21),
            if (_step == 0) _estateDetails(),
            if (_step == 1) _applicantDetails(),
            if (_step == 2) _structureDetails(),
          ],
        ),
      ),
    ),
  );

  Widget _stepIndicator() => Row(
    children: List.generate(3, (index) {
      final selected = _step == index;
      final completed = _step > index;
      final title = switch (index) {
        0 => 'Estate',
        1 => 'Applicant',
        _ => 'Structure',
      };
      return Expanded(
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: selected || completed
                  ? EstateColors.forest
                  : const Color(0xFFE7ECE8),
              child: completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : EstateColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? EstateColors.forest : EstateColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (index < 2)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7),
                  child: Divider(height: 1),
                ),
              ),
          ],
        ),
      );
    }),
  );

  Widget _estateDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeading(
        title: 'Tell us about the estate',
        description: 'Start with the estate’s proposed name and location.',
      ),
      const SizedBox(height: 20),
      _input(_name, 'Proposed estate name', required: true),
      const SizedBox(height: 13),
      DropdownButtonFormField<String>(
        initialValue: _type,
        decoration: const InputDecoration(labelText: 'Estate type'),
        items: const [
          DropdownMenuItem(
            value: 'Gated community',
            child: Text('Gated community'),
          ),
          DropdownMenuItem(
            value: 'Residential estate',
            child: Text('Residential estate'),
          ),
          DropdownMenuItem(
            value: 'Apartment complex',
            child: Text('Apartment complex'),
          ),
          DropdownMenuItem(
            value: 'Commercial property',
            child: Text('Commercial property'),
          ),
          DropdownMenuItem(value: 'Mixed use', child: Text('Mixed use')),
        ],
        onChanged: (value) => setState(() => _type = value ?? _type),
      ),
      const SizedBox(height: 13),
      _input(_address, 'Street address', required: true),
      const SizedBox(height: 13),
      Row(
        children: [
          Expanded(child: _input(_state, 'State', required: true)),
          const SizedBox(width: 12),
          Expanded(child: _input(_lga, 'LGA', required: true)),
        ],
      ),
      const SizedBox(height: 5),
      const _Hint(
        'Use the estate’s registered or commonly recognized address.',
      ),
    ],
  );

  Widget _applicantDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeading(
        title: 'Who is applying?',
        description:
            'Provide a contact person and their relationship to the estate.',
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
        initialValue: _relationship,
        decoration: const InputDecoration(labelText: 'Your relationship'),
        items: const [
          DropdownMenuItem(value: 'Estate owner', child: Text('Estate owner')),
          DropdownMenuItem(
            value: 'Management company',
            child: Text('Management company'),
          ),
          DropdownMenuItem(
            value: 'Estate administrator',
            child: Text('Estate administrator'),
          ),
          DropdownMenuItem(
            value: 'Residents association',
            child: Text('Residents association'),
          ),
        ],
        onChanged: (value) =>
            setState(() => _relationship = value ?? _relationship),
      ),
      const SizedBox(height: 13),
      _input(_contactName, 'Contact person full name', required: true),
      const SizedBox(height: 13),
      _input(
        _email,
        'Contact email',
        required: true,
        type: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Enter an email address.';
          }
          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
            return 'Enter a valid email address.';
          }
          return null;
        },
      ),
      const SizedBox(height: 13),
      _input(
        _phone,
        'Contact phone number',
        required: true,
        type: TextInputType.phone,
      ),
      const SizedBox(height: 13),
      _input(_management, 'Management entity name', required: true),
      const SizedBox(height: 13),
      _input(_registrationNumber, 'Management registration number (optional)'),
      const SizedBox(height: 5),
      const _Hint('Use your estate account to sign in and continue.'),
    ],
  );

  Widget _structureDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeading(
        title: 'Describe the property structure',
        description: 'These details help the review team understand the size and layout.',
      ),
      const SizedBox(height: 20),
      _input(
        _homeCount,
        'Approximate number of homes or units',
        required: true,
        type: TextInputType.number,
        validator: (value) {
          final number = int.tryParse(value ?? '');
          if (number == null || number < 1) {
            return 'Enter a whole number greater than zero.';
          }
          return null;
        },
      ),
      const SizedBox(height: 13),
      _input(
        _phaseCount,
        'Number of development phases (optional)',
        type: TextInputType.number,
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final number = int.tryParse(value.trim());
          if (number == null || number < 0) {
            return 'Enter a whole number of zero or more.';
          }
          return null;
        },
      ),
      const SizedBox(height: 13),
      TextFormField(
        controller: _structure,
        maxLines: 5,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Structure summary',
          hintText: 'For example: 4 zones, 12 streets, 186 residential units',
          alignLabelWithHint: true,
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Describe the estate structure.'
            : null,
      ),
      const SizedBox(height: 12),
      _supportingDocuments(),
      const SizedBox(height: 12),
      const _Hint(
        'Your application is checked by the estate service before it enters the review queue.',
      ),
    ],
  );

  Widget _supportingDocuments() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F8F5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE3EAE4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supporting documents',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const Text(
          'Attach relevant authorization, registration, ownership or address records. PDF, JPEG and PNG files up to 10 MB.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: EstateColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _documentCategory,
          decoration: const InputDecoration(labelText: 'Document type'),
          items: const [
            DropdownMenuItem(
              value: 'management_authorization',
              child: Text('Management authorization'),
            ),
            DropdownMenuItem(
              value: 'business_registration',
              child: Text('Business registration'),
            ),
            DropdownMenuItem(
              value: 'ownership_proof',
              child: Text('Ownership proof'),
            ),
            DropdownMenuItem(
              value: 'address_proof',
              child: Text('Address proof'),
            ),
            DropdownMenuItem(
              value: 'other',
              child: Text('Other supporting record'),
            ),
          ],
          onChanged: _uploadingDocument
              ? null
              : (value) {
                  if (value != null) setState(() => _documentCategory = value);
                },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _uploadingDocument ? null : _pickAndUploadDocument,
          icon: _uploadingDocument
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined),
          label: Text(_uploadingDocument ? 'Uploading…' : 'Choose a document'),
        ),
        if (_documentError != null) ...[
          const SizedBox(height: 7),
          Text(
            _documentError!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        if (_documents.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._documents.map(
            (document) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                Icons.description_outlined,
                color: EstateColors.forest,
              ),
              title: Text(
                document.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_documentCategoryLabel(document.category)} · ${_formatDocumentSize(document.byteSize)} · ${document.status}',
              ),
              trailing: IconButton(
                tooltip: 'Download document',
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _downloadDocument(document),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _pickAndUploadDocument() async {
    final api = widget.repository;
    if (api is! EstateApplicationApiRepository) {
      setState(
        () => _documentError = 'Document uploads require the estate service.',
      );
      return;
    }
    try {
      final selection = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (selection == null) return;
      final selectedLength = await selection.length();
      if (selectedLength == null ||
          selectedLength <= 0 ||
          selectedLength > 10 * 1024 * 1024) {
        setState(() => _documentError = 'Choose a file up to 10 MB.');
        return;
      }
      setState(() {
        _uploadingDocument = true;
        _documentError = null;
      });
      final bytes = await selection.readAsBytes();
      if (!_formKey.currentState!.validate())
        throw const EstateApiException(
          'Complete the required application details before uploading a document.',
        );
      final draft = await widget.repository.saveMyDraft(_collectDraft());
      final document = await api.uploadMyApplicationDocument(
        category: _documentCategory,
        fileName: selection.name,
        bytes: bytes,
        idempotencyKey: List<int>.generate(
          24,
          (_) => Random.secure().nextInt(256),
        ).map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _documents = [..._documents, document];
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _documentError = error is EstateApiException
              ? error.message
              : 'The document could not be uploaded.',
        );
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
    }
  }

  Future<void> _downloadDocument(
    EstateApplicationDocumentRecord document,
  ) async {
    final api = widget.repository;
    if (api is! EstateApplicationApiRepository) return;
    try {
      final bytes = await api.downloadMyApplicationDocument(document.id);
      await FilePicker.saveFile(fileName: document.displayName, bytes: bytes);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is EstateApiException
                  ? error.message
                  : 'The document could not be downloaded.',
            ),
          ),
        );
    }
  }

  EstateApplicationDraft _collectDraft() => EstateApplicationDraft(
    reference: _draft?.reference ?? '',
    proposedName: _name.text.trim(),
    estateType: _type,
    address: _address.text.trim(),
    state: _state.text.trim(),
    lga: _lga.text.trim(),
    applicantRelationship: _relationship,
    applicantContactName: _contactName.text.trim(),
    applicantContactEmail: _email.text.trim(),
    applicantContactPhone: _phone.text.trim(),
    managementEntityName: _management.text.trim(),
    registrationNumber: _registrationNumber.text.trim(),
    homeCount: _homeCount.text.trim(),
    phaseCount: _phaseCount.text.trim(),
    structureSummary: _structure.text.trim(),
    updatedAt: DateTime.now(),
  );

  String _documentCategoryLabel(String category) => switch (category) {
    'management_authorization' => 'Management authorization',
    'business_registration' => 'Business registration',
    'ownership_proof' => 'Ownership proof',
    'address_proof' => 'Address proof',
    _ => 'Other',
  };

  String _formatDocumentSize(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Widget _input(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? type,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: type,
    textCapitalization: type == TextInputType.emailAddress
        ? TextCapitalization.none
        : TextCapitalization.words,
    decoration: InputDecoration(labelText: label),
    validator:
        validator ??
        (value) => required && (value == null || value.trim().isEmpty)
            ? 'This field is required.'
            : null,
  );

  Widget _sidePanel() => Column(
    children: [
      _ProgressCard(draft: _draft, step: _step),
      const SizedBox(height: 13),
      const _ReviewStepsCard(),
    ],
  );

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    if (_step < 2) setState(() => _step++);
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final draft = _collectDraft();
      final saved = await widget.repository.saveMyDraft(draft);
      if (!mounted) return;
      setState(() => _draft = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application draft saved to your account.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is EstateApiException
          ? error.message
          : 'The application draft could not be saved. Check your connection and try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.repository is! EstateApplicationApiRepository) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submission requires the connected estate service.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = _collectDraft();
      final saved = await widget.repository.saveMyDraft(draft);
      final code = await (widget.repository as EstateApplicationApiRepository)
          .submitMyApplication();
      if (!mounted) return;
      setState(() => _draft = saved.copyWith(status: 'submitted'));
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: EstateColors.forest,
          ),
          title: const Text('Application submitted'),
          content: Text(
            'Your application ${code.isEmpty ? saved.reference : code} is now in the review queue.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is EstateApiException
          ? error.message
          : 'The application could not be submitted. Check your connection and try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({
    required this.message,
    required this.loading,
    required this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: EstateColors.amber),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        TextButton(
          onPressed: loading ? null : onRetry,
          child: Text(loading ? 'Loading…' : 'Retry'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasDraft,
    required this.onSignOut,
    required this.onOpenEstateTeam,
  });
  final bool hasDraft;
  final VoidCallback onSignOut;
  final VoidCallback onOpenEstateTeam;
  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: EstateColors.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F2ED),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.domain_rounded, color: EstateColors.forest),
        ),
        const SizedBox(width: 10),
        const Text(
          'Estate Management',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width > 720)
          TextButton.icon(
            onPressed: onOpenEstateTeam,
            icon: const Icon(Icons.domain_outlined),
            label: const Text('Estate team dashboard'),
          )
        else
          IconButton(
            tooltip: 'Estate team dashboard',
            onPressed: onOpenEstateTeam,
            icon: const Icon(Icons.domain_outlined),
          ),
        if (hasDraft) const _PreviewTag(label: 'Saved draft'),
        IconButton(
          tooltip: 'Sign out',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFFE9F2ED),
          child: Icon(
            Icons.person_outline,
            size: 18,
            color: EstateColors.forest,
          ),
        ),
      ],
    ),
  );
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'ESTATE ONBOARDING',
        style: TextStyle(
          color: Color(0xFFC4E6D0),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Register an estate',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      const Text(
        'Share a few details to start the estate review process.',
        style: TextStyle(color: Color(0xD1FFFFFF), fontSize: 13),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.description});
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      Text(
        description,
        style: const TextStyle(fontSize: 12, color: EstateColors.muted),
      ),
    ],
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.draft, required this.step});
  final EstateApplicationDraft? draft;
  final int step;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application progress',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          LinearProgressIndicator(
            value: (step + 1) / 3,
            minHeight: 7,
            borderRadius: BorderRadius.circular(5),
            color: EstateColors.leaf,
            backgroundColor: const Color(0xFFE9EEEA),
          ),
          const SizedBox(height: 9),
          Text(
            'Step ${step + 1} of 3 · ${((step + 1) / 3 * 100).round()}% complete',
            style: const TextStyle(fontSize: 11, color: EstateColors.muted),
          ),
          if (draft != null) ...[
            const Divider(height: 25),
            const Text(
              'Saved draft',
              style: TextStyle(fontSize: 11, color: EstateColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              draft!.reference,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              _relative(draft!.updatedAt),
              style: const TextStyle(fontSize: 10, color: EstateColors.muted),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ReviewStepsCard extends StatelessWidget {
  const _ReviewStepsCard();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What happens next',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          const _ReviewRow(
            number: '1',
            title: 'Complete the details',
            detail: 'Estate, applicant and structure',
          ),
          const _ReviewRow(
            number: '2',
            title: 'Provide documents',
            detail: 'Verified through private storage',
          ),
          const _ReviewRow(
            number: '3',
            title: 'Submit for review',
            detail: 'Reviewed by platform operations',
          ),
          const Divider(height: 25),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 17, color: EstateColors.forest),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estate activation follows platform verification.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: EstateColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.number,
    required this.title,
    required this.detail,
  });
  final String number;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFE9F2ED),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              color: EstateColors.forest,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(fontSize: 10, color: EstateColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.step,
    required this.saving,
    required this.onBack,
    required this.onSave,
    required this.onContinue,
    required this.onSubmit,
    required this.editable,
  });
  final int step;
  final bool saving;
  final VoidCallback? onBack;
  final VoidCallback onSave;
  final VoidCallback onContinue;
  final VoidCallback onSubmit;
  final bool editable;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: EstateColors.line)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Row(
          children: editable
              ? [
                  if (onBack != null)
                    OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: Text(saving ? 'Saving…' : 'Save draft'),
                  ),
                  const SizedBox(width: 9),
                  FilledButton.icon(
                    onPressed: step < 2 ? onContinue : onSubmit,
                    icon: Icon(
                      step < 2
                          ? Icons.arrow_forward_rounded
                          : Icons.lock_outline,
                      size: 17,
                    ),
                    label: Text(step < 2 ? 'Continue' : 'Submit for review'),
                  ),
                ]
              : [
                  const Icon(
                    Icons.verified_outlined,
                    color: EstateColors.forest,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'This application is read-only while it is being reviewed or after a decision.',
                      style: TextStyle(fontSize: 12, color: EstateColors.muted),
                    ),
                  ),
                ],
        ),
      ),
    ),
  );
}

class _ApplicationStatusBanner extends StatelessWidget {
  const _ApplicationStatusBanner({
    required this.status,
    required this.reference,
  });
  final String status;
  final String reference;

  @override
  Widget build(BuildContext context) {
    final (title, detail, icon) = switch (status) {
      'submitted' || 'under_review' => (
        'Application under review',
        'Your application has been submitted. The estate service will update its status after review.',
        Icons.hourglass_top_rounded,
      ),
      'approved' => (
        'Estate application approved',
        'This application is complete. Continue to the estate team dashboard to manage the activated estate.',
        Icons.check_circle_outline_rounded,
      ),
      'rejected' => (
        'Application not approved',
        'This application has a final decision. Contact platform support if you need help.',
        Icons.info_outline_rounded,
      ),
      _ => (
        'Application status: ${status.replaceAll('_', ' ')}',
        'This application is currently read-only.',
        Icons.info_outline_rounded,
      ),
    };
    return Card(
      color: const Color(0xFFF2F7F3),
      child: ListTile(
        leading: Icon(icon, color: EstateColors.forest),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$detail\nReference: $reference'),
        isThreeLine: true,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      color: EstateColors.muted,
      height: 1.4,
    ),
  );
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE9F2ED),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: EstateColors.forest,
      ),
    ),
  );
}

String _relative(DateTime date) {
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return 'Updated just now';
  if (elapsed.inHours < 1) return 'Updated ${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return 'Updated ${elapsed.inHours} hr ago';
  return 'Updated ${elapsed.inDays} days ago';
}
