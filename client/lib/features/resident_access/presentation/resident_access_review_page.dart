import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class ResidentAccessReviewPage extends StatefulWidget {
  const ResidentAccessReviewPage({super.key, required this.repository, this.initialEstateId, this.showSignOutAction = true});
  final EstateApplicationApiRepository repository;
  final String? initialEstateId;
  final bool showSignOutAction;

  @override
  State<ResidentAccessReviewPage> createState() => _ResidentAccessReviewPageState();
}

class _ResidentAccessReviewPageState extends State<ResidentAccessReviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  EstateAccount? _account;
  List<ManagedEstateChoice> _estates = const [];
  List<ResidentAccessRequest> _requests = const [];
  ManagedEstateChoice? _selectedEstate;
  String _filter = 'pending';
  bool _restoring = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final account = await widget.repository.restoreSession();
      if (account != null) {
        _account = account;
        await _loadEstates();
      }
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      _account = await widget.repository.signIn(email: _email.text, password: _password.text);
      await _loadEstates();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadEstates() async {
    _estates = await widget.repository.loadManagedEstates();
    _selectedEstate = _estates.where((item) => item.id == (_selectedEstate?.id ?? widget.initialEstateId)).firstOrNull
        ?? (_estates.isEmpty ? null : _estates.first);
    await _loadRequests();
  }

  Future<void> _loadRequests() async {
    final estate = _selectedEstate;
    if (estate == null) {
      _requests = const [];
      return;
    }
    _requests = await widget.repository.loadResidentAccessRequests(estate.id);
  }

  Future<void> _refresh() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _loadEstates();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _estates = const [];
      _requests = const [];
      _selectedEstate = null;
      _error = null;
    });
  }

  Future<void> _review(ResidentAccessRequest request) async {
    final decision = await showDialog<String>(context: context, builder: (context) => _ResidentRequestDialog(request: request));
    if (decision == null || !mounted) return;
    final estate = _selectedEstate;
    if (estate == null) return;
    String? reason;
    if (decision == 'reject') {
      reason = await showDialog<String>(context: context, builder: (context) => const _RejectionReasonDialog());
      if (reason == null || !mounted) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.repository.decideResidentAccessRequest(
        estateId: estate.id,
        requestId: request.id,
        decision: decision,
        reason: reason,
      );
      await _loadRequests();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is EstateApiException
      ? error.message : 'The estate service could not complete this request.';

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_account == null) return _buildSignIn();
    final visibleRequests = _requests.where((request) => _filter == 'all' || request.status == _filter).toList();
    final pendingCount = _requests.where((request) => request.status == 'pending').length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const _BrandTitle(),
        actions: [
          if (MediaQuery.sizeOf(context).width > 560)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text(_account!.displayName, style: const TextStyle(color: EstateColors.muted)))),
          IconButton(tooltip: 'Refresh', onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
          if (widget.showSignOutAction)
            PopupMenuButton<String>(onSelected: (_) => _signOut(), itemBuilder: (_) => const [PopupMenuItem(value: 'signout', child: Text('Sign out'))]),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Resident access', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: EstateColors.ink)),
                const SizedBox(height: 6),
                const Text('Review resident membership requests for the estates you manage.', style: TextStyle(color: EstateColors.muted)),
                const SizedBox(height: 24),
                if (_error != null) _ErrorCard(message: _error!, onClose: () => setState(() => _error = null)),
                if (_estates.isEmpty)
                  const _EmptyAccessCard()
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        const Icon(Icons.apartment_rounded, color: EstateColors.forest),
                        const SizedBox(width: 14),
                        Expanded(child: DropdownButtonFormField<ManagedEstateChoice>(
                          initialValue: _selectedEstate,
                          decoration: const InputDecoration(labelText: 'Estate', border: InputBorder.none, contentPadding: EdgeInsets.zero),
                          items: _estates.map((estate) => DropdownMenuItem(value: estate, child: Text(estate.name, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _busy ? null : (estate) async {
                            setState(() { _selectedEstate = estate; _busy = true; _error = null; });
                            try { await _loadRequests(); } catch (error) { _error = _message(error); }
                            if (mounted) setState(() => _busy = false);
                          },
                        )),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Text('$pendingCount pending request${pendingCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: EstateColors.ink))),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'pending', label: Text('Pending')),
                        ButtonSegment(value: 'all', label: Text('All')),
                      ],
                      selected: {_filter},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) => setState(() => _filter = selection.first),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (_busy) const LinearProgressIndicator(minHeight: 2),
                  if (visibleRequests.isEmpty)
                    const _NoRequestsCard()
                  else
                    ...visibleRequests.map((request) => _RequestCard(request: request, onTap: request.status == 'pending' && !_busy ? () => _review(request) : null)),
                ],
                const SizedBox(height: 24),
                const Text('Approvals create resident membership. If a property relationship was requested, it is recorded separately from ownership and billing privileges.', style: TextStyle(color: EstateColors.muted, height: 1.5, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignIn() => Scaffold(
    body: Stack(fit: StackFit.expand, children: [
      Image.asset('assets/images/onboarding_background.jpg', fit: BoxFit.cover),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99111F18), Color(0xCF09140F)]))),
      SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Card(color: Colors.white.withValues(alpha: .97), child: Padding(padding: const EdgeInsets.all(28), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_user_outlined, color: EstateColors.forest, size: 34),
          const SizedBox(height: 14),
          const Text('Estate access review', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: EstateColors.ink)),
          const SizedBox(height: 7),
          const Text('Sign in with an estate administrator or manager account.', textAlign: TextAlign.center, style: TextStyle(color: EstateColors.muted, height: 1.5)),
          const SizedBox(height: 24),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address.' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)), validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null, onFieldSubmitted: (_) => _signIn()),
          if (_error != null) ...[const SizedBox(height: 14), Text(_error!, style: const TextStyle(color: EstateColors.red))],
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _busy ? null : _signIn, icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded), label: Text(_busy ? 'Signing in…' : 'Sign in')),
        ])))),
      )))),
    ]),
  );
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFE9F2ED), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.domain_rounded, color: EstateColors.forest, size: 20)),
    const SizedBox(width: 10),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('Estate Management', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), Text('Resident access', style: TextStyle(fontSize: 11, color: EstateColors.muted))]),
  ]);
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});
  final ResidentAccessRequest request;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final pending = request.status == 'pending';
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: CircleAvatar(backgroundColor: const Color(0xFFE9F2ED), child: Text(request.applicantName.trim().isEmpty ? '?' : request.applicantName.trim()[0].toUpperCase(), style: const TextStyle(color: EstateColors.forest, fontWeight: FontWeight.w700))),
      title: Text(request.applicantName, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text([
        if (request.relationship != null) _pretty(request.relationship!),
        if (request.propertyCode != null) 'Property ${request.propertyCode}',
        _formatDate(request.submittedAt),
      ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _StatusPill(status: request.status),
        if (pending) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.chevron_right_rounded, color: EstateColors.muted)),
      ]),
    ));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    final approved = status == 'approved';
    final background = pending ? const Color(0xFFFFF5E5) : approved ? const Color(0xFFE9F2ED) : const Color(0xFFFFECEA);
    final foreground = pending ? EstateColors.amber : approved ? EstateColors.forest : EstateColors.red;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)), child: Text(_pretty(status), style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700)));
  }
}

class _ResidentRequestDialog extends StatelessWidget {
  const _ResidentRequestDialog({required this.request});
  final ResidentAccessRequest request;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Resident access request'),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _DetailLine(label: 'Applicant', value: request.applicantName),
      if (request.applicantEmail != null) _DetailLine(label: 'Email', value: request.applicantEmail!),
      if (request.applicantPhone != null) _DetailLine(label: 'Phone', value: request.applicantPhone!),
      if (request.relationship != null) _DetailLine(label: 'Relationship requested', value: _pretty(request.relationship!)),
      if (request.propertyCode != null) _DetailLine(label: 'Property', value: request.propertyCode!),
      _DetailLine(label: 'Submitted', value: _formatDate(request.submittedAt)),
      if (request.note != null && request.note!.trim().isNotEmpty) _DetailLine(label: 'Applicant note', value: request.note!),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      TextButton(onPressed: () => Navigator.pop(context, 'reject'), style: TextButton.styleFrom(foregroundColor: EstateColors.red), child: const Text('Reject')),
      FilledButton.icon(onPressed: () => Navigator.pop(context, 'approve'), icon: const Icon(Icons.check_rounded), label: const Text('Approve access')),
    ],
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(color: EstateColors.muted, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: .7)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: EstateColors.ink, height: 1.4))]));
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog();
  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final _controller = TextEditingController();
  final _key = GlobalKey<FormState>();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject access request'),
    content: Form(key: _key, child: TextFormField(controller: _controller, autofocus: true, maxLength: 1000, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true), validator: (value) => value == null || value.trim().isEmpty ? 'Enter a reason for the applicant.' : null)),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (_key.currentState!.validate()) Navigator.pop(context, _controller.text.trim()); }, child: const Text('Reject request'))],
  );
}

class _EmptyAccessCard extends StatelessWidget {
  const _EmptyAccessCard();
  @override
  Widget build(BuildContext context) => const _InfoCard(icon: Icons.lock_outline_rounded, title: 'No estate management access', detail: 'This account does not have an active administrator or manager role in an estate.');
}

class _NoRequestsCard extends StatelessWidget {
  const _NoRequestsCard();
  @override
  Widget build(BuildContext context) => const _InfoCard(icon: Icons.inbox_outlined, title: 'No requests in this view', detail: 'New resident access requests for this estate will appear here.');
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icon(icon, color: EstateColors.forest, size: 30), const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: EstateColors.muted, height: 1.5))])));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Card(color: const Color(0xFFFFF0EE), child: ListTile(leading: const Icon(Icons.error_outline_rounded, color: EstateColors.red), title: Text(message, style: const TextStyle(color: EstateColors.red)), trailing: IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded))));
}

String _pretty(String value) => value.split('_').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
String _formatDate(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return 'Submitted';
  return '${parsed.day.toString().padLeft(2, '0')} ${_month(parsed.month)} ${parsed.year}';
}
String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
