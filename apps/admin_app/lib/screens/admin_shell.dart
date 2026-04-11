import 'dart:async';

import 'package:coach_flow_core/coach_flow_core.dart';
import 'package:flutter/material.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.session,
    required this.adminRepository,
    required this.authRepository,
    required this.onLogout,
  });

  final AuthSession session;
  final AdminRepository adminRepository;
  final AuthRepository authRepository;
  final Future<void> Function() onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _navIndex = 0;
  late Future<AdminDashboardModel> _dashboardFuture;
  late Future<List<ClientSummary>> _clientsFuture;
  late Future<List<ProgramTemplateModel>> _templatesFuture;
  late Future<ChallengeModel?> _challengeFuture;
  Future<ClientDetailModel>? _clientDetailFuture;
  int? _selectedClientId;
  int? _selectedTemplateId;
  LiveConversationController? _conversationController;

  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  final _programStartController = TextEditingController();
  final _templateTitleController = TextEditingController();

  final _caloriesController = TextEditingController(text: '2100');
  final _proteinController = TextEditingController(text: '175');
  final _carbsController = TextEditingController(text: '210');
  final _fatsController = TextEditingController(text: '58');
  final _waterController = TextEditingController(text: '3.0');
  final _nutritionNotesController = TextEditingController();

  final _subscriptionPlanController = TextEditingController(
    text: 'Premium Coaching',
  );
  final _subscriptionPriceController = TextEditingController(text: '420');
  final _subscriptionStartController = TextEditingController();
  final _subscriptionNextInvoiceController = TextEditingController();
  final _subscriptionNotesController = TextEditingController();

  final _metricWeightController = TextEditingController();
  final _metricSquatController = TextEditingController();
  final _metricBenchController = TextEditingController();
  final _metricDeadliftController = TextEditingController();
  final _metricAdherenceController = TextEditingController(text: '90');
  final _metricEnergyController = TextEditingController(text: '4');
  final _metricNotesController = TextEditingController();

  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();

  final _invoiceTitleController = TextEditingController(
    text: 'Monthly Coaching',
  );
  final _invoiceAmountController = TextEditingController(text: '420');
  final _invoiceDueController = TextEditingController();
  final _invoicePeriodStartController = TextEditingController();
  final _invoicePeriodEndController = TextEditingController();

  final _challengeTitleController = TextEditingController(
    text: 'April Progress Push',
  );
  final _challengeDescriptionController = TextEditingController(
    text: 'A focused monthly challenge built to drive visible progress and daily engagement.',
  );
  final _challengeUnitController = TextEditingController(text: 'kg');
  final _challengeStartController = TextEditingController();
  final _challengeEndController = TextEditingController();

  final Map<int, TextEditingController> _formCheckFeedbackControllers =
      <int, TextEditingController>{};

  String _subscriptionStatus = 'active';
  String _challengeMetricType = 'body_weight';
  int _lastConversationLength = 0;
  int? _hydratedClientId;

  @override
  void initState() {
    super.initState();
    _seedDateControllers();
    _refreshDashboard();
    _refreshClients();
    _refreshLibrary();
  }

  @override
  void dispose() {
    _conversationController?.removeListener(_handleConversationUpdate);
    _conversationController?.dispose();
    _nameController.dispose();
    _goalController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _programStartController.dispose();
    _templateTitleController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _waterController.dispose();
    _nutritionNotesController.dispose();
    _subscriptionPlanController.dispose();
    _subscriptionPriceController.dispose();
    _subscriptionStartController.dispose();
    _subscriptionNextInvoiceController.dispose();
    _subscriptionNotesController.dispose();
    _metricWeightController.dispose();
    _metricSquatController.dispose();
    _metricBenchController.dispose();
    _metricDeadliftController.dispose();
    _metricAdherenceController.dispose();
    _metricEnergyController.dispose();
    _metricNotesController.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    _invoiceTitleController.dispose();
    _invoiceAmountController.dispose();
    _invoiceDueController.dispose();
    _invoicePeriodStartController.dispose();
    _invoicePeriodEndController.dispose();
    _challengeTitleController.dispose();
    _challengeDescriptionController.dispose();
    _challengeUnitController.dispose();
    _challengeStartController.dispose();
    _challengeEndController.dispose();
    for (final controller in _formCheckFeedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seedDateControllers() {
    final today = DateTime.now();
    _programStartController.text = formatDateForApi(today);
    _subscriptionStartController.text = formatDateForApi(today);
    _subscriptionNextInvoiceController.text = formatDateForApi(today);
    _invoiceDueController.text = formatDateForApi(today.add(const Duration(days: 7)));
    _invoicePeriodStartController.text = formatDateForApi(today);
    _invoicePeriodEndController.text = formatDateForApi(
      today.add(const Duration(days: 29)),
    );
    _challengeStartController.text = formatDateForApi(today);
    _challengeEndController.text = formatDateForApi(
      today.add(const Duration(days: 29)),
    );
  }

  void _refreshDashboard() {
    _dashboardFuture = widget.adminRepository.fetchDashboard();
  }

  void _refreshClients() {
    _clientsFuture = widget.adminRepository.fetchClients();
    if (_selectedClientId != null) {
      _clientDetailFuture = widget.adminRepository.fetchClientDetail(
        _selectedClientId!,
      );
    }
  }

  void _refreshLibrary() {
    _templatesFuture = widget.adminRepository.fetchTemplates();
    _challengeFuture = widget.adminRepository.fetchChallenge();
  }

  void _refreshAllData() {
    _refreshDashboard();
    _refreshClients();
    _refreshLibrary();
  }

  void _selectClient(int clientId) {
    setState(() {
      _selectedClientId = clientId;
      _hydratedClientId = null;
      _selectedTemplateId = null;
      _clientDetailFuture = widget.adminRepository.fetchClientDetail(clientId);
    });
    unawaited(_bindConversation(clientId));
  }

  Future<void> _bindConversation(int clientId) async {
    _conversationController?.removeListener(_handleConversationUpdate);
    _conversationController?.dispose();

    final controller = LiveConversationController(
      loadMessages: () => widget.adminRepository.fetchClientMessages(clientId),
      sendMessage: (body) =>
          widget.adminRepository.sendMessage(clientId: clientId, body: body),
      connect: () => widget.adminRepository.watchClientConversation(clientId),
    );
    controller.addListener(_handleConversationUpdate);

    if (!mounted) {
      controller.dispose();
      return;
    }

    setState(() {
      _conversationController = controller;
      _lastConversationLength = 0;
    });

    await controller.start();
  }

  void _handleConversationUpdate() {
    final controller = _conversationController;
    if (!mounted || controller == null) {
      return;
    }

    final count = controller.state.messages.length;
    if (count != _lastConversationLength) {
      _lastConversationLength = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_messageScrollController.hasClients) {
          return;
        }
        _messageScrollController.animateTo(
          _messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  TextEditingController _feedbackControllerFor(FormCheckModel formCheck) {
    return _formCheckFeedbackControllers.putIfAbsent(
      formCheck.id,
      () => TextEditingController(text: formCheck.coachFeedback ?? ''),
    );
  }

  void _hydrateClientEditors(ClientDetailModel detail) {
    if (_hydratedClientId == detail.id) {
      return;
    }

    _hydratedClientId = detail.id;
    final now = DateTime.now();
    final nutrition = detail.nutritionPlan;
    final subscription = detail.subscription;
    final latestMetric = detail.metrics.isNotEmpty ? detail.metrics.first : null;

    _programStartController.text = formatDateForApi(
      detail.program?.startDate ?? now,
    );
    _templateTitleController.text = detail.program == null
        ? '${detail.fullName} 4-Week Template'
        : '${detail.fullName} ${detail.program!.phase} Template';

    _caloriesController.text = '${nutrition?.calories ?? 2100}';
    _proteinController.text = '${nutrition?.protein ?? 175}';
    _carbsController.text = '${nutrition?.carbs ?? 210}';
    _fatsController.text = '${nutrition?.fats ?? 58}';
    _waterController.text = '${nutrition?.waterLiters ?? 3.0}';
    _nutritionNotesController.text = nutrition?.notes ?? '';

    _subscriptionPlanController.text =
        subscription?.planName ?? 'Premium Coaching';
    _subscriptionPriceController.text =
        '${((subscription?.monthlyPriceCents ?? 42000) / 100).round()}';
    _subscriptionStartController.text = formatDateForApi(
      subscription?.startedAt ?? now,
    );
    _subscriptionNextInvoiceController.text = formatDateForApi(
      subscription?.nextInvoiceDate ?? now,
    );
    _subscriptionNotesController.text = subscription?.notes ?? '';
    _subscriptionStatus = subscription?.status ?? 'active';

    _metricWeightController.text = latestMetric?.bodyWeight == null
        ? ''
        : latestMetric!.bodyWeight!.toStringAsFixed(1);
    _metricSquatController.text = latestMetric?.squat1rm == null
        ? ''
        : latestMetric!.squat1rm!.toStringAsFixed(1);
    _metricBenchController.text = latestMetric?.bench1rm == null
        ? ''
        : latestMetric!.bench1rm!.toStringAsFixed(1);
    _metricDeadliftController.text = latestMetric?.deadlift1rm == null
        ? ''
        : latestMetric!.deadlift1rm!.toStringAsFixed(1);
    _metricAdherenceController.text =
        '${latestMetric?.adherenceScore ?? 90}';
    _metricEnergyController.text = '${latestMetric?.energyScore ?? 4}';
    _metricNotesController.text = latestMetric?.notes ?? '';

    _invoiceTitleController.text = subscription == null
        ? 'Monthly Coaching'
        : '${subscription.planName} - ${_monthName(subscription.nextInvoiceDate.month)} ${subscription.nextInvoiceDate.year}';
    _invoiceAmountController.text =
        '${((subscription?.monthlyPriceCents ?? 42000) / 100).round()}';
    _invoiceDueController.text = formatDateForApi(
      subscription?.nextInvoiceDate ?? now.add(const Duration(days: 7)),
    );
    _invoicePeriodStartController.text = formatDateForApi(
      subscription?.nextInvoiceDate ?? now,
    );
    _invoicePeriodEndController.text = formatDateForApi(
      (subscription?.nextInvoiceDate ?? now).add(const Duration(days: 29)),
    );

    _messageController.clear();
  }

  Future<void> _createClient() async {
    try {
      final created = await widget.adminRepository.createClient(
        fullName: _nameController.text.trim(),
        goal: _goalController.text.trim(),
        email: _emptyToNull(_emailController.text),
        phone: _emptyToNull(_phoneController.text),
        notes: _emptyToNull(_notesController.text),
      );
      _nameController.clear();
      _goalController.clear();
      _emailController.clear();
      _phoneController.clear();
      _notesController.clear();

      _showMessage(
        'Created ${created.fullName}. Invite code: ${created.inviteCode}',
      );
      setState(() {
        _refreshAllData();
        _selectedClientId = created.id;
        _hydratedClientId = null;
        _clientDetailFuture = widget.adminRepository.fetchClientDetail(
          created.id,
        );
      });
      unawaited(_bindConversation(created.id));
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _publishProgram(ClientDetailModel detail) async {
    try {
      await widget.adminRepository.publishStarterProgram(
        clientId: detail.id,
        goal: detail.goal,
        startDate: _tryParseDate(_programStartController.text),
      );
      _showMessage('Published a dated 4-week starter program.');
      setState(_refreshAllData);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _createTemplateFromProgram(ClientDetailModel detail) async {
    if (detail.program == null) {
      _showMessage('Publish a program before saving it as a template.', error: true);
      return;
    }

    try {
      final template = await widget.adminRepository.createTemplateFromClient(
        clientId: detail.id,
        title: _emptyToNull(_templateTitleController.text),
      );
      _showMessage('Saved ${template.title} to the template library.');
      setState(() {
        _refreshDashboard();
        _refreshLibrary();
        _selectedTemplateId = template.id;
      });
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _applySelectedTemplate(ClientDetailModel detail) async {
    final templateId = _selectedTemplateId;
    if (templateId == null) {
      _showMessage('Select a template first.', error: true);
      return;
    }

    try {
      await widget.adminRepository.applyTemplate(
        templateId: templateId,
        clientId: detail.id,
        startDate: _tryParseDate(_programStartController.text),
      );
      _showMessage('Applied the selected template to ${detail.fullName}.');
      setState(_refreshAllData);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _saveNutrition(ClientDetailModel detail) async {
    try {
      await widget.adminRepository.saveNutrition(
        clientId: detail.id,
        calories: int.parse(_caloriesController.text),
        protein: int.parse(_proteinController.text),
        carbs: int.parse(_carbsController.text),
        fats: int.parse(_fatsController.text),
        waterLiters: double.tryParse(_waterController.text),
        notes: _emptyToNull(_nutritionNotesController.text),
      );
      _showMessage('Nutrition plan saved.');
      setState(_refreshClients);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _saveSubscription(ClientDetailModel detail) async {
    try {
      await widget.adminRepository.saveSubscription(
        clientId: detail.id,
        planName: _subscriptionPlanController.text.trim(),
        monthlyPriceCents: (_parseCurrency(_subscriptionPriceController.text) *
                100)
            .round(),
        status: _subscriptionStatus,
        startedAt: _tryParseDate(_subscriptionStartController.text),
        nextInvoiceDate: _tryParseDate(_subscriptionNextInvoiceController.text),
        notes: _emptyToNull(_subscriptionNotesController.text),
      );
      _showMessage(
        'Subscription updated. Monthly invoices will generate automatically from the next billing date.',
      );
      setState(_refreshAllData);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _logMetric(ClientDetailModel detail) async {
    try {
      await widget.adminRepository.createMetric(
        clientId: detail.id,
        bodyWeight: double.tryParse(_metricWeightController.text),
        squat1rm: double.tryParse(_metricSquatController.text),
        bench1rm: double.tryParse(_metricBenchController.text),
        deadlift1rm: double.tryParse(_metricDeadliftController.text),
        adherenceScore: int.tryParse(_metricAdherenceController.text),
        energyScore: int.tryParse(_metricEnergyController.text),
        notes: _emptyToNull(_metricNotesController.text),
      );
      _showMessage('Metric entry logged.');
      setState(_refreshAllData);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _createInvoice(ClientDetailModel detail) async {
    try {
      await widget.adminRepository.createInvoice(
        clientId: detail.id,
        title: _invoiceTitleController.text.trim(),
        amountCents: (_parseCurrency(_invoiceAmountController.text) * 100)
            .round(),
        dueDate: _tryParseDate(_invoiceDueController.text) ?? DateTime.now(),
        billingPeriodStart: _tryParseDate(_invoicePeriodStartController.text),
        billingPeriodEnd: _tryParseDate(_invoicePeriodEndController.text),
      );
      _showMessage('Invoice created.');
      setState(_refreshAllData);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _reviewFormCheck(
    ClientDetailModel detail,
    FormCheckModel formCheck,
  ) async {
    final controller = _feedbackControllerFor(formCheck);
    if (controller.text.trim().isEmpty) {
      _showMessage('Coach feedback cannot be empty.', error: true);
      return;
    }

    try {
      await widget.adminRepository.reviewFormCheck(
        clientId: detail.id,
        formCheckId: formCheck.id,
        coachFeedback: controller.text.trim(),
      );
      _showMessage('Form check reviewed.');
      setState(_refreshAllData);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _createChallenge() async {
    try {
      await widget.adminRepository.createChallenge(
        title: _challengeTitleController.text.trim(),
        description: _emptyToNull(_challengeDescriptionController.text),
        metricType: _challengeMetricType,
        startDate: _tryParseDate(_challengeStartController.text) ??
            DateTime.now(),
        endDate: _tryParseDate(_challengeEndController.text) ??
            DateTime.now().add(const Duration(days: 29)),
        unitLabel: _emptyToNull(_challengeUnitController.text),
      );
      _showMessage('Challenge created and leaderboard refreshed.');
      setState(() {
        _refreshDashboard();
        _refreshLibrary();
      });
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _sendMessage() async {
    final controller = _conversationController;
    if (controller == null) {
      _showMessage('Conversation is still loading.', error: true);
      return;
    }

    try {
      await controller.send(_messageController.text);
      _messageController.clear();
      _showMessage('Message sent live.');
      setState(_refreshDashboard);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        palette: AppTheme.adminPalette,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 18,
                  ),
                  child: SizedBox(
                    width: 152,
                    child: NavigationRail(
                      selectedIndex: _navIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _navIndex = index;
                        });
                      },
                      groupAlignment: -0.72,
                      leading: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BrandChip(
                              label: widget.session.organizationName ?? 'Gym',
                              imageUrl: widget.session.organizationLogoUrl,
                              icon: Icons.fitness_center_rounded,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.session.fullName ?? 'Gym Owner',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Overview'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.groups_outlined),
                          selectedIcon: Icon(Icons.groups),
                          label: Text('Clients'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.auto_awesome_motion_outlined),
                          selectedIcon: Icon(Icons.auto_awesome_motion),
                          label: Text('Library'),
                        ),
                      ],
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: IconButton(
                            onPressed: widget.onLogout,
                            icon: const Icon(Icons.logout),
                            tooltip: 'Log out',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: switch (_navIndex) {
                    0 => _buildOverview(),
                    1 => _buildClientsWorkspace(),
                    _ => _buildLibraryWorkspace(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return FutureBuilder<AdminDashboardModel>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final data = snapshot.data!;
        final challenge = data.activeChallenge;

        return ListView(
          children: [
            ScreenIntro(
              eyebrow: 'Gym Command Center',
              title:
                  '${data.organizationName ?? widget.session.organizationName ?? 'Gym'} performance operating system',
              subtitle:
                  'Programs now run on fixed cycles, subscriptions auto-generate invoices, missing check-ins create reminders, and challenge engagement stays visible in one professional workspace.',
              trailing: BrandChip(
                label:
                    data.organizationName ??
                    widget.session.organizationName ??
                    'Gym',
                imageUrl:
                    data.organizationLogoUrl ??
                    widget.session.organizationLogoUrl,
                icon: Icons.insights_rounded,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  label: 'Total clients',
                  value: '${data.totalClients}',
                  accent: const Color(0xFF2563EB),
                ),
                _MetricCard(
                  label: 'Active subscriptions',
                  value: '${data.activeSubscriptions}',
                  accent: const Color(0xFF0F766E),
                ),
                _MetricCard(
                  label: 'Template library',
                  value: '${data.templateCount}',
                  accent: const Color(0xFFB45309),
                ),
                _MetricCard(
                  label: 'Overdue invoices',
                  value: '${data.overdueInvoices}',
                  accent: const Color(0xFFDC2626),
                ),
                _MetricCard(
                  label: 'Missing check-in alerts',
                  value: '${data.missingCheckinNotifications}',
                  accent: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PanelCard(
              title: 'Active challenge',
              subtitle: challenge == null
                  ? 'No community challenge is live right now.'
                  : '${challenge.title} • ${_metricLabel(challenge.metricType)} • ${_formatDate(challenge.startDate)} to ${_formatDate(challenge.endDate)}',
              child: challenge == null
                  ? const Text(
                      'Open Library to launch a leaderboard-driven challenge and keep retention momentum high.',
                    )
                  : Column(
                      children: [
                        if (challenge.description != null) ...[
                          Text(challenge.description!),
                          const SizedBox(height: 16),
                        ],
                        ...challenge.leaderboard.take(3).map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFDCEAFE),
                              child: Text('#${entry.rank}'),
                            ),
                            title: Text(entry.clientName),
                            subtitle: Text(_metricLabel(challenge.metricType)),
                            trailing: Text(entry.displayScore),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1100;
                final latestCheckins = _PanelCard(
                  title: 'Latest check-ins',
                  subtitle:
                      'High-signal adherence and recovery snapshots from the floor.',
                  child: Column(
                    children: data.latestCheckins
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatDateTime(item.submittedAt)),
                            subtitle: Text(item.notes ?? 'No notes'),
                            trailing: Text('${item.adherenceScore ?? 0}%'),
                          ),
                        )
                        .toList(),
                  ),
                );
                final recentMessages = _PanelCard(
                  title: 'Recent messages',
                  subtitle:
                      'Live communication is active across coach and client threads.',
                  child: Column(
                    children: data.recentMessages
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.senderRole.toUpperCase()),
                            subtitle: Text(item.body),
                            trailing: Text(_formatTime(item.createdAt)),
                          ),
                        )
                        .toList(),
                  ),
                );

                if (!wide) {
                  return Column(
                    children: [
                      latestCheckins,
                      const SizedBox(height: 16),
                      recentMessages,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: latestCheckins),
                    const SizedBox(width: 16),
                    Expanded(child: recentMessages),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildClientsWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenIntro(
          eyebrow: 'Client Ops',
          title: '${widget.session.organizationName ?? 'Gym'} member workspace',
          subtitle:
              'Create members, run 4-week program cycles, monitor metrics, manage subscriptions, and review form checks without leaving the coaching console.',
          trailing: BrandChip(
            label: widget.session.organizationName ?? 'Gym',
            imageUrl: widget.session.organizationLogoUrl,
            icon: Icons.groups_rounded,
          ),
        ),
        const SizedBox(height: 16),
        _PanelCard(
          title: 'Create client',
          subtitle:
              'Every client inherits your organization context, branding, and automated billing workflows.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _goalController,
                  decoration: const InputDecoration(labelText: 'Primary goal'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Contact email'),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ),
              FilledButton(
                onPressed: _createClient,
                child: const Text('Create client'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 340,
                child: FutureBuilder<List<ClientSummary>>(
                  future: _clientsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    }

                    final clients = snapshot.data!;
                    return GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: clients.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final client = clients[index];
                          final selected = client.id == _selectedClientId;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE0EBFF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              selected: selected,
                              onTap: () => _selectClient(client.id),
                              title: Text(client.fullName),
                              subtitle: Text(
                                '${client.goal}\n${client.subscriptionStatus ?? 'no subscription'} • invite ${client.inviteCode}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    client.status,
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    client.invoiceStatus ?? 'no invoice',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _clientDetailFuture == null
                    ? const Center(
                        child: Text(
                          'Select a client to open the performance workspace.',
                        ),
                      )
                    : FutureBuilder<ClientDetailModel>(
                        future: _clientDetailFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(snapshot.error.toString()),
                            );
                          }

                          final detail = snapshot.data!;
                          _hydrateClientEditors(detail);
                          return _buildClientDetail(detail);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientDetail(ClientDetailModel detail) {
    final latestMetric = detail.metrics.isNotEmpty ? detail.metrics.first : null;
    final latestInvoice = detail.invoices.isNotEmpty ? detail.invoices.first : null;
    final pendingFormChecks = detail.formChecks
        .where((item) => !item.isReviewed)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;

        final programPanel = FutureBuilder<List<ProgramTemplateModel>>(
          future: _templatesFuture,
          builder: (context, snapshot) {
            final templates = snapshot.data ?? const <ProgramTemplateModel>[];
            final templateIds = templates.map((item) => item.id).toSet();
            final selectedValue = templateIds.contains(_selectedTemplateId)
                ? _selectedTemplateId
                : null;

            return _PanelCard(
              title: 'Program cycles and templates',
              subtitle:
                  'Run every training plan on a fixed 4-week cadence and promote strong programs into reusable templates.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _programStartController,
                          decoration: const InputDecoration(
                            labelText: 'Cycle start YYYY-MM-DD',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _templateTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Template title',
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _publishProgram(detail),
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: const Text('Publish 4-week starter'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _createTemplateFromProgram(detail),
                        icon: const Icon(Icons.bookmarks_outlined),
                        label: const Text('Save current program as template'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (templates.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      value: selectedValue,
                      items: templates
                          .map(
                            (template) => DropdownMenuItem<int>(
                              value: template.id,
                              child: Text(
                                '${template.title} • ${template.phase} • ${template.durationWeeks} weeks',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTemplateId = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Apply template to this client',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => _applySelectedTemplate(detail),
                        icon: const Icon(Icons.playlist_add_check_circle_rounded),
                        label: const Text('Apply selected template'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (detail.program == null)
                    const Text(
                      'No program is live yet. Publish a starter split or apply a library template.',
                    )
                  else ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Chip(label: Text(detail.program!.title)),
                        Chip(label: Text(detail.program!.phase)),
                        Chip(
                          label: Text(
                            '${_formatDate(detail.program!.startDate)} to ${_formatDate(detail.program!.endDate)}',
                          ),
                        ),
                      ],
                    ),
                    if (detail.program!.summary != null) ...[
                      const SizedBox(height: 12),
                      Text(detail.program!.summary!),
                    ],
                    const SizedBox(height: 16),
                    ...detail.program!.workoutDays.map(
                      (day) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Day ${day.dayIndex}: ${day.title}'),
                        subtitle: Text(
                          '${day.focus}\n${day.exercises.length} exercises',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );

        final nutritionPanel = _PanelCard(
          title: 'Nutrition',
          subtitle: 'Macro targets and hydration guidance for the current cycle.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _inputBox(_caloriesController, 'Calories', width: 120),
                  _inputBox(_proteinController, 'Protein', width: 120),
                  _inputBox(_carbsController, 'Carbs', width: 120),
                  _inputBox(_fatsController, 'Fats', width: 120),
                  _inputBox(_waterController, 'Water (L)', width: 120),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nutritionNotesController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Coach notes'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _saveNutrition(detail),
                child: const Text('Save nutrition'),
              ),
            ],
          ),
        );

        final subscriptionPanel = _PanelCard(
          title: 'Subscription and billing',
          subtitle:
              'Subscriptions gate access, drive invoice generation, and give the client app a live account state.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _subscriptionPlanController,
                      decoration: const InputDecoration(labelText: 'Plan name'),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _subscriptionPriceController,
                      decoration: const InputDecoration(labelText: 'Monthly price'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _subscriptionStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'trialing',
                          child: Text('trialing'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('active'),
                        ),
                        DropdownMenuItem(
                          value: 'past_due',
                          child: Text('past_due'),
                        ),
                        DropdownMenuItem(
                          value: 'paused',
                          child: Text('paused'),
                        ),
                        DropdownMenuItem(
                          value: 'canceled',
                          child: Text('canceled'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _subscriptionStatus = value;
                        });
                      },
                    ),
                  ),
                  _inputBox(
                    _subscriptionStartController,
                    'Started YYYY-MM-DD',
                    width: 180,
                  ),
                  _inputBox(
                    _subscriptionNextInvoiceController,
                    'Next invoice YYYY-MM-DD',
                    width: 190,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subscriptionNotesController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Subscription notes',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _saveSubscription(detail),
                child: const Text('Save subscription'),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              Text(
                'Manual invoice',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Use this for one-off charges. Monthly subscription invoices continue generating automatically.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _invoiceTitleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                  ),
                  _inputBox(_invoiceAmountController, 'Amount', width: 140),
                  _inputBox(
                    _invoiceDueController,
                    'Due YYYY-MM-DD',
                    width: 180,
                  ),
                  _inputBox(
                    _invoicePeriodStartController,
                    'Period start',
                    width: 180,
                  ),
                  _inputBox(
                    _invoicePeriodEndController,
                    'Period end',
                    width: 180,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _createInvoice(detail),
                child: const Text('Create invoice'),
              ),
            ],
          ),
        );

        final metricPanel = _PanelCard(
          title: 'Metrics',
          subtitle:
              'Track bodyweight and estimated strength to feed monthly reporting and leaderboard experiences.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _inputBox(_metricWeightController, 'Bodyweight', width: 130),
                  _inputBox(_metricSquatController, 'Squat 1RM', width: 130),
                  _inputBox(_metricBenchController, 'Bench 1RM', width: 130),
                  _inputBox(
                    _metricDeadliftController,
                    'Deadlift 1RM',
                    width: 140,
                  ),
                  _inputBox(
                    _metricAdherenceController,
                    'Adherence %',
                    width: 130,
                  ),
                  _inputBox(_metricEnergyController, 'Energy 1-5', width: 120),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _metricNotesController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Metric notes',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _logMetric(detail),
                child: const Text('Log metric entry'),
              ),
              const SizedBox(height: 16),
              ...detail.metrics.take(4).map(
                (metric) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatDateTime(metric.loggedAt)),
                  subtitle: Text(
                    'BW ${_formatNumber(metric.bodyWeight)} • SQ ${_formatNumber(metric.squat1rm)} • BP ${_formatNumber(metric.bench1rm)} • DL ${_formatNumber(metric.deadlift1rm)}',
                  ),
                  trailing: Text('${metric.adherenceScore ?? 0}%'),
                ),
              ),
            ],
          ),
        );

        final progressPanel = _PanelCard(
          title: 'Monthly progress report',
          subtitle:
              'Auto-computed from check-ins and metrics to give the client a clear retention-driving narrative each month.',
          child: detail.latestProgressReport == null
              ? const Text(
                  'No monthly report has been generated yet. Once metrics and check-ins accumulate, the report appears here automatically.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Chip(
                          label: Text(
                            '${_formatDate(detail.latestProgressReport!.periodStart)} to ${_formatDate(detail.latestProgressReport!.periodEnd)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Check-ins ${detail.latestProgressReport!.checkinsCompleted}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Adherence ${detail.latestProgressReport!.adherenceAverage?.toStringAsFixed(1) ?? 'n/a'}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(detail.latestProgressReport!.summary),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MiniMetric(
                          label: 'Bodyweight',
                          value: _formatDelta(
                            detail.latestProgressReport!.bodyWeightChange,
                          ),
                        ),
                        _MiniMetric(
                          label: 'Squat',
                          value: _formatDelta(
                            detail.latestProgressReport!.squatGain,
                          ),
                        ),
                        _MiniMetric(
                          label: 'Bench',
                          value: _formatDelta(
                            detail.latestProgressReport!.benchGain,
                          ),
                        ),
                        _MiniMetric(
                          label: 'Deadlift',
                          value: _formatDelta(
                            detail.latestProgressReport!.deadliftGain,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );

        final formCheckPanel = _PanelCard(
          title: 'Video form checks',
          subtitle:
              'Review member-submitted exercise videos and send coaching feedback back into their notification stream.',
          child: detail.formChecks.isEmpty
              ? const Text('No exercise videos have been submitted yet.')
              : Column(
                  children: detail.formChecks.map((formCheck) {
                    final feedbackController = _feedbackControllerFor(formCheck);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              Chip(label: Text(formCheck.exerciseName)),
                              Chip(label: Text(formCheck.status)),
                              Chip(
                                label: Text(
                                  _formatDateTime(formCheck.submittedAt),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SelectableText(formCheck.videoUrl),
                          if (formCheck.notes != null) ...[
                            const SizedBox(height: 8),
                            Text(formCheck.notes!),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: feedbackController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Coach feedback',
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _reviewFormCheck(detail, formCheck),
                            child: Text(
                              formCheck.isReviewed
                                  ? 'Update review'
                                  : 'Publish review',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        );

        final checkinPanel = _PanelCard(
          title: 'Check-ins',
          subtitle: 'Weekly readiness, adherence, and subjective recovery.',
          child: detail.checkins.isEmpty
              ? const Text('No check-ins submitted yet.')
              : Column(
                  children: detail.checkins.take(6).map((checkin) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_formatDateTime(checkin.submittedAt)),
                      subtitle: Text(checkin.notes ?? 'No notes'),
                      trailing: Text('${checkin.adherenceScore ?? 0}%'),
                    );
                  }).toList(),
                ),
        );

        return ListView(
          children: [
            _PanelCard(
              title: detail.fullName,
              subtitle:
                  '${detail.goal} • ${detail.contactEmail ?? 'No email'} • ${detail.phone ?? 'No phone'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Chip(label: Text(detail.status)),
                      Chip(
                        label: Text(detail.subscription?.status ?? 'no subscription'),
                      ),
                      Chip(label: Text('Invite ${detail.inviteCode}')),
                    ],
                  ),
                  if (detail.notes != null) ...[
                    const SizedBox(height: 12),
                    Text(detail.notes!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  label: 'Next invoice',
                  value: latestInvoice == null
                      ? 'n/a'
                      : _formatDate(latestInvoice.dueDate),
                  accent: const Color(0xFF2563EB),
                ),
                _MetricCard(
                  label: 'Latest weight',
                  value: latestMetric?.bodyWeight == null
                      ? 'n/a'
                      : '${latestMetric!.bodyWeight!.toStringAsFixed(1)} kg',
                  accent: const Color(0xFF0F766E),
                ),
                _MetricCard(
                  label: 'Latest squat 1RM',
                  value: latestMetric?.squat1rm == null
                      ? 'n/a'
                      : '${latestMetric!.squat1rm!.toStringAsFixed(0)} kg',
                  accent: const Color(0xFFB45309),
                ),
                _MetricCard(
                  label: 'Pending form reviews',
                  value: '$pendingFormChecks',
                  accent: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 16),
            programPanel,
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: nutritionPanel),
                  const SizedBox(width: 16),
                  Expanded(child: subscriptionPanel),
                ],
              )
            else
              Column(
                children: [
                  nutritionPanel,
                  const SizedBox(height: 16),
                  subscriptionPanel,
                ],
              ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: metricPanel),
                  const SizedBox(width: 16),
                  Expanded(child: progressPanel),
                ],
              )
            else
              Column(
                children: [
                  metricPanel,
                  const SizedBox(height: 16),
                  progressPanel,
                ],
              ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: formCheckPanel),
                  const SizedBox(width: 16),
                  Expanded(child: checkinPanel),
                ],
              )
            else
              Column(
                children: [
                  formCheckPanel,
                  const SizedBox(height: 16),
                  checkinPanel,
                ],
              ),
            const SizedBox(height: 16),
            _buildConversationStudio(detail),
          ],
        );
      },
    );
  }

  Widget _buildLibraryWorkspace() {
    return ListView(
      children: [
        ScreenIntro(
          eyebrow: 'Template Library',
          title: 'Reusable programming and retention systems',
          subtitle:
              'Promote high-performing 4-week cycles into templates and keep engagement moving with monthly challenges backed by leaderboard data.',
          trailing: BrandChip(
            label: widget.session.organizationName ?? 'Gym',
            imageUrl: widget.session.organizationLogoUrl,
            icon: Icons.layers_clear_rounded,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1180;
            final templatePanel = FutureBuilder<List<ProgramTemplateModel>>(
              future: _templatesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _PanelCard(
                    title: 'Program templates',
                    child: SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _PanelCard(
                    title: 'Program templates',
                    child: Text(snapshot.error.toString()),
                  );
                }

                final templates = snapshot.data!;
                return _PanelCard(
                  title: 'Program templates',
                  subtitle:
                      'Every saved template becomes instantly deployable to any client with a fresh cycle start date.',
                  child: templates.isEmpty
                      ? const Text(
                          'No templates yet. Save a published client program into the library from the client workspace.',
                        )
                      : Column(
                          children: templates.map((template) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      Chip(label: Text(template.title)),
                                      Chip(label: Text(template.phase)),
                                      Chip(
                                        label: Text(
                                          '${template.durationWeeks} weeks',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(template.goal),
                                  if (template.summary != null) ...[
                                    const SizedBox(height: 8),
                                    Text(template.summary!),
                                  ],
                                  const SizedBox(height: 12),
                                  ...template.workoutDays.map(
                                    (day) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        'Day ${day.dayIndex}: ${day.title}',
                                      ),
                                      subtitle: Text(
                                        '${day.focus} • ${day.exercises.length} exercises',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                );
              },
            );

            final challengePanel = FutureBuilder<ChallengeModel?>(
              future: _challengeFuture,
              builder: (context, snapshot) {
                final activeChallenge = snapshot.data;
                return _PanelCard(
                  title: 'Community challenge',
                  subtitle:
                      'Challenge-based engagement is one of the strongest retention loops in the product. Launch one cleanly and track the leaderboard in real time.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _challengeTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Challenge title',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              value: _challengeMetricType,
                              decoration: const InputDecoration(
                                labelText: 'Metric type',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'body_weight',
                                  child: Text('body_weight'),
                                ),
                                DropdownMenuItem(
                                  value: 'squat_1rm',
                                  child: Text('squat_1rm'),
                                ),
                                DropdownMenuItem(
                                  value: 'bench_1rm',
                                  child: Text('bench_1rm'),
                                ),
                                DropdownMenuItem(
                                  value: 'deadlift_1rm',
                                  child: Text('deadlift_1rm'),
                                ),
                                DropdownMenuItem(
                                  value: 'adherence_score',
                                  child: Text('adherence_score'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _challengeMetricType = value;
                                });
                              },
                            ),
                          ),
                          _inputBox(
                            _challengeUnitController,
                            'Unit label',
                            width: 140,
                          ),
                          _inputBox(
                            _challengeStartController,
                            'Start YYYY-MM-DD',
                            width: 180,
                          ),
                          _inputBox(
                            _challengeEndController,
                            'End YYYY-MM-DD',
                            width: 180,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _challengeDescriptionController,
                        minLines: 3,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Challenge description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _createChallenge,
                        icon: const Icon(Icons.emoji_events_rounded),
                        label: const Text('Launch challenge'),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      if (snapshot.connectionState != ConnectionState.done)
                        const Center(child: CircularProgressIndicator())
                      else if (snapshot.hasError)
                        Text(snapshot.error.toString())
                      else if (activeChallenge == null)
                        const Text(
                          'No challenge is active right now.',
                        )
                      else ...[
                        Text(
                          activeChallenge.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_metricLabel(activeChallenge.metricType)} • ${_formatDate(activeChallenge.startDate)} to ${_formatDate(activeChallenge.endDate)}',
                        ),
                        if (activeChallenge.description != null) ...[
                          const SizedBox(height: 10),
                          Text(activeChallenge.description!),
                        ],
                        const SizedBox(height: 16),
                        ...activeChallenge.leaderboard.map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFFDE68A),
                              child: Text('#${entry.rank}'),
                            ),
                            title: Text(entry.clientName),
                            subtitle: Text(_metricLabel(activeChallenge.metricType)),
                            trailing: Text(entry.displayScore),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );

            if (!wide) {
              return Column(
                children: [
                  templatePanel,
                  const SizedBox(height: 16),
                  challengePanel,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: templatePanel),
                const SizedBox(width: 16),
                Expanded(child: challengePanel),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildConversationStudio(ClientDetailModel detail) {
    final controller = _conversationController;
    if (controller == null) {
      return const _PanelCard(
        title: 'Live conversation',
        child: SizedBox(
          height: 420,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final state = controller.state;
        final error = state.error;

        return _PanelCard(
          title: 'Live conversation',
          subtitle:
              'No refreshes required. Coach replies and member messages stay synchronized inside the workspace.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Send precise updates, recovery instructions, billing clarifications, or form-check feedback directly into the client thread.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AdminLiveStatusChip(
                    label: state.isConnected ? 'Connected' : 'Reconnecting',
                    color: state.isConnected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFB45309),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                _AdminStatusBanner(message: error),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _messageController,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Send a live coaching update to ${detail.fullName}',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, child) {
                  final enabled = value.text.trim().isNotEmpty && !state.isSending;
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: enabled ? _sendMessage : null,
                      icon: state.isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        state.isSending ? 'Sending...' : 'Send live reply',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 340,
                child: state.isLoading && state.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.78),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This conversation is ready',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'As soon as either side sends a message, the thread updates here live.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _messageScrollController,
                        padding: const EdgeInsets.only(right: 4),
                        itemCount: state.messages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          return _AdminMessageBubble(
                            message: message,
                            isCurrentUser: message.isFromAdmin,
                            peerLabel: detail.fullName,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _AdminLiveStatusChip extends StatelessWidget {
  const _AdminLiveStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatusBanner extends StatelessWidget {
  const _AdminStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFAC898)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({
    required this.message,
    required this.isCurrentUser,
    required this.peerLabel,
  });

  final MessageItem message;
  final bool isCurrentUser;
  final String peerLabel;

  @override
  Widget build(BuildContext context) {
    final alignment = isCurrentUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = isCurrentUser
        ? const Color(0xFF0F172A)
        : Colors.white.withValues(alpha: 0.84);
    final textColor = isCurrentUser ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          isCurrentUser ? 'Coach' : peerLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCurrentUser
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Text(
            message.body,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: textColor, height: 1.5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatDateTime(message.createdAt),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

Widget _inputBox(
  TextEditingController controller,
  String label, {
  double width = 160,
}) {
  return SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _tryParseDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

double _parseCurrency(String raw) {
  return double.tryParse(raw.trim()) ?? 0;
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'n/a';
  }
  return formatDateForApi(value);
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _formatDateTime(DateTime value) {
  return '${_monthName(value.month)} ${value.day}, ${_formatTime(value)}';
}

String _formatNumber(double? value) {
  if (value == null) {
    return 'n/a';
  }
  if (value == value.roundToDouble()) {
    return '${value.round()}';
  }
  return value.toStringAsFixed(1);
}

String _formatDelta(double? value) {
  if (value == null) {
    return 'n/a';
  }
  final prefix = value >= 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)}';
}

String _metricLabel(String metricType) {
  switch (metricType) {
    case 'body_weight':
      return 'Bodyweight';
    case 'squat_1rm':
      return 'Squat 1RM';
    case 'bench_1rm':
      return 'Bench 1RM';
    case 'deadlift_1rm':
      return 'Deadlift 1RM';
    case 'adherence_score':
      return 'Adherence';
    default:
      return metricType;
  }
}

String _monthName(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
