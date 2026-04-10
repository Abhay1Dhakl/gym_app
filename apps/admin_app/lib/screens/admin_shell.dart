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
  Future<ClientDetailModel>? _clientDetailFuture;
  int? _selectedClientId;
  LiveConversationController? _conversationController;

  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  final _caloriesController = TextEditingController(text: '2100');
  final _proteinController = TextEditingController(text: '175');
  final _carbsController = TextEditingController(text: '210');
  final _fatsController = TextEditingController(text: '58');
  final _waterController = TextEditingController(text: '3.0');
  final _nutritionNotesController = TextEditingController();

  final _messageController = TextEditingController();
  final _invoiceTitleController = TextEditingController(
    text: 'Monthly Coaching',
  );
  final _invoiceAmountController = TextEditingController(text: '420');
  final _invoiceDueController = TextEditingController(text: '2026-04-21');
  final _messageScrollController = ScrollController();

  int _lastConversationLength = 0;
  int? _hydratedClientId;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    _refreshClients();
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
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _waterController.dispose();
    _nutritionNotesController.dispose();
    _messageController.dispose();
    _invoiceTitleController.dispose();
    _invoiceAmountController.dispose();
    _invoiceDueController.dispose();
    _messageScrollController.dispose();
    super.dispose();
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

  void _selectClient(int clientId) {
    setState(() {
      _selectedClientId = clientId;
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

  void _hydrateClientEditors(ClientDetailModel detail) {
    if (_hydratedClientId == detail.id) {
      return;
    }

    _hydratedClientId = detail.id;
    final nutrition = detail.nutritionPlan;
    _caloriesController.text = '${nutrition?.calories ?? 2100}';
    _proteinController.text = '${nutrition?.protein ?? 175}';
    _carbsController.text = '${nutrition?.carbs ?? 210}';
    _fatsController.text = '${nutrition?.fats ?? 58}';
    _waterController.text = '${nutrition?.waterLiters ?? 3.0}';
    _nutritionNotesController.text = nutrition?.notes ?? '';
    _messageController.clear();
  }

  Future<void> _createClient() async {
    try {
      final created = await widget.adminRepository.createClient(
        fullName: _nameController.text.trim(),
        goal: _goalController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
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
        _refreshDashboard();
        _refreshClients();
        _selectedClientId = created.id;
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
      );
      _showMessage('Starter program published.');
      setState(_refreshClients);
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
        notes: _nutritionNotesController.text.trim().isEmpty
            ? null
            : _nutritionNotesController.text.trim(),
      );
      _showMessage('Nutrition plan saved.');
      setState(_refreshClients);
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
      _showMessage('Message sent.');
      setState(_refreshDashboard);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _createInvoice(ClientDetailModel detail) async {
    try {
      await widget.adminRepository.createInvoice(
        clientId: detail.id,
        title: _invoiceTitleController.text.trim(),
        amountCents: (double.parse(_invoiceAmountController.text) * 100)
            .round(),
        dueDate: DateTime.parse(_invoiceDueController.text),
      );
      _showMessage('Invoice created.');
      setState(_refreshClients);
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
                    width: 140,
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
                  child: _navIndex == 0
                      ? _buildOverview()
                      : _buildClientsWorkspace(),
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
        return ListView(
          children: [
            ScreenIntro(
              eyebrow: 'Gym Workspace',
              title:
                  '${data.organizationName ?? widget.session.organizationName ?? 'Gym'} operating system',
              subtitle:
                  'Manage members, billing, programs, nutrition, and client communication from one branded control center.',
              trailing: BrandChip(
                label:
                    data.organizationName ??
                    widget.session.organizationName ??
                    'Gym',
                imageUrl:
                    data.organizationLogoUrl ??
                    widget.session.organizationLogoUrl,
                icon: Icons.auto_awesome_rounded,
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
                ),
                _MetricCard(
                  label: 'Active clients',
                  value: '${data.activeClients}',
                ),
                _MetricCard(
                  label: 'Invited clients',
                  value: '${data.invitedClients}',
                ),
                _MetricCard(
                  label: 'Overdue invoices',
                  value: '${data.overdueInvoices}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PanelCard(
                    title: 'Latest check-ins',
                    child: Column(
                      children: data.latestCheckins
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Check-in #${item.id}'),
                              subtitle: Text(item.notes ?? 'No notes'),
                              trailing: Text('${item.adherenceScore ?? 0}%'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PanelCard(
                    title: 'Recent messages',
                    child: Column(
                      children: data.recentMessages
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.senderRole.toUpperCase()),
                              subtitle: Text(item.body),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
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
          eyebrow: 'Members',
          title: '${widget.session.organizationName ?? 'Gym'} client workspace',
          subtitle:
              'New members created here stay inside your gym account and inherit your gym branding.',
          trailing: BrandChip(
            label: widget.session.organizationName ?? 'Gym',
            imageUrl: widget.session.organizationLogoUrl,
            icon: Icons.groups_rounded,
          ),
        ),
        const SizedBox(height: 16),
        _PanelCard(
          title: 'Create gym client',
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
                width: 330,
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
                        itemBuilder: (context, index) {
                          final client = clients[index];
                          final selected = client.id == _selectedClientId;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE0EBFF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              selected: selected,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: Text(client.fullName),
                              subtitle: Text(
                                '${client.goal}\nInvite: ${client.inviteCode}',
                              ),
                              isThreeLine: true,
                              trailing: Text(client.status),
                              onTap: () => _selectClient(client.id),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) => const Divider(
                          height: 10,
                          color: Colors.transparent,
                        ),
                        itemCount: clients.length,
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
                          'Select a client to open the detail workspace.',
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
                          return ListView(
                            children: [
                              _PanelCard(
                                title: detail.fullName,
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    Chip(label: Text(detail.status)),
                                    Chip(label: Text(detail.goal)),
                                    Chip(
                                      label: Text(
                                        'Invite ${detail.inviteCode}',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _publishProgram(detail),
                                      icon: const Icon(Icons.fitness_center),
                                      label: const Text(
                                        'Publish starter program',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _PanelCard(
                                      title: 'Nutrition',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: [
                                              SizedBox(
                                                width: 120,
                                                child: TextField(
                                                  controller:
                                                      _caloriesController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Calories',
                                                      ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: TextField(
                                                  controller:
                                                      _proteinController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Protein',
                                                      ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: TextField(
                                                  controller: _carbsController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Carbs',
                                                      ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: TextField(
                                                  controller: _fatsController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Fats',
                                                      ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: TextField(
                                                  controller: _waterController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Water (L)',
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller:
                                                _nutritionNotesController,
                                            minLines: 2,
                                            maxLines: 3,
                                            decoration: const InputDecoration(
                                              labelText: 'Nutrition notes',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          FilledButton(
                                            onPressed: () =>
                                                _saveNutrition(detail),
                                            child: const Text('Save nutrition'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildConversationStudio(detail),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _PanelCard(
                                title: 'Create invoice',
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: 220,
                                      child: TextField(
                                        controller: _invoiceTitleController,
                                        decoration: const InputDecoration(
                                          labelText: 'Title',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 160,
                                      child: TextField(
                                        controller: _invoiceAmountController,
                                        decoration: const InputDecoration(
                                          labelText: 'Amount',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 180,
                                      child: TextField(
                                        controller: _invoiceDueController,
                                        decoration: const InputDecoration(
                                          labelText: 'Due date YYYY-MM-DD',
                                        ),
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () => _createInvoice(detail),
                                      child: const Text('Create invoice'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _PanelCard(
                                      title: 'Program',
                                      child: Column(
                                        children:
                                            (detail.program?.workoutDays ??
                                                    const <WorkoutDayModel>[])
                                                .map(
                                                  (day) => ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      'Day ${day.dayIndex}: ${day.title}',
                                                    ),
                                                    subtitle: Text(day.focus),
                                                  ),
                                                )
                                                .toList(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _PanelCard(
                                      title: 'Invoices',
                                      child: Column(
                                        children: detail.invoices
                                            .map(
                                              (invoice) => ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(invoice.title),
                                                subtitle: Text(
                                                  invoice.dueDate
                                                      .toIso8601String()
                                                      .split('T')
                                                      .first,
                                                ),
                                                trailing: Text(invoice.status),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildClientProfilePanel(detail),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _PanelCard(
                                      title: 'Check-ins',
                                      child: Column(
                                        children: detail.checkins
                                            .map(
                                              (checkin) => ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  checkin.submittedAt
                                                      .toIso8601String()
                                                      .split('T')
                                                      .first,
                                                ),
                                                subtitle: Text(
                                                  checkin.notes ?? 'No notes',
                                                ),
                                                trailing: Text(
                                                  '${checkin.adherenceScore ?? 0}%',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Coach feedback, questions, and client replies stay synced instantly inside this workspace.',
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
                  labelText: 'Send a precise coaching update to ${detail.fullName}',
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
                height: 320,
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
                              'Once you or ${detail.fullName} sends a message, the thread updates here live.',
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

  Widget _buildClientProfilePanel(ClientDetailModel detail) {
    return _PanelCard(
      title: 'Client profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(label: Text(detail.status)),
              Chip(label: Text(detail.goal)),
              Chip(label: Text('Invite ${detail.inviteCode}')),
            ],
          ),
          const SizedBox(height: 16),
          _DetailLine(
            label: 'Email',
            value: detail.contactEmail ?? 'Not added yet',
          ),
          const SizedBox(height: 10),
          _DetailLine(
            label: 'Phone',
            value: detail.phone ?? 'Not added yet',
          ),
          const SizedBox(height: 10),
          _DetailLine(
            label: 'Notes',
            value: detail.notes ?? 'No coaching notes saved yet.',
            multiLine: true,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
  const _PanelCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          child,
        ],
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
          const Icon(Icons.wifi_tethering_error_rounded, color: Color(0xFFB45309)),
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
          _formatTimestamp(message.createdAt),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  final String label;
  final String value;
  final bool multiLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: multiLine ? null : 1,
          overflow: multiLine ? null : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${_monthName(local.month)} ${local.day}, $hour:$minute $suffix';
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
