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

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    _refreshClients();
  }

  @override
  void dispose() {
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
        _selectClient(created.id);
      });
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

  Future<void> _sendMessage(ClientDetailModel detail) async {
    try {
      await widget.adminRepository.sendMessage(
        clientId: detail.id,
        body: _messageController.text.trim(),
      );
      _messageController.clear();
      _showMessage('Message sent.');
      setState(_refreshClients);
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
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _navIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _navIndex = index;
                });
              },
              leading: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BrandAvatar(
                      label: widget.session.organizationName ?? 'Gym',
                      imageUrl: widget.session.organizationLogoUrl,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 92,
                      child: Text(
                        widget.session.organizationName ?? 'Gym Admin',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _navIndex == 0
                    ? _buildOverview()
                    : _buildClientsWorkspace(),
              ),
            ),
          ],
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
            Text(
              data.organizationName ??
                  widget.session.organizationName ??
                  'Gym Admin Overview',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your gym members, billing, programming, and coach communication.',
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
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
        Text(
          '${widget.session.organizationName ?? 'Gym'} Client Workspace',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'New members created here stay inside your gym account and inherit your gym branding.',
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
                width: 320,
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
                    return Card(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final client = clients[index];
                          return ListTile(
                            selected: client.id == _selectedClientId,
                            title: Text(client.fullName),
                            subtitle: Text(
                              '${client.goal}\nInvite: ${client.inviteCode}',
                            ),
                            isThreeLine: true,
                            trailing: Text(client.status),
                            onTap: () => _selectClient(client.id),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
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
                                    child: _PanelCard(
                                      title: 'Message client',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            controller: _messageController,
                                            minLines: 4,
                                            maxLines: 6,
                                            decoration: const InputDecoration(
                                              labelText: 'Message body',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          FilledButton(
                                            onPressed: () =>
                                                _sendMessage(detail),
                                            child: const Text('Send message'),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                      width: 160,
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
                                    child: _PanelCard(
                                      title: 'Messages',
                                      child: Column(
                                        children: detail.messages
                                            .map(
                                              (message) => ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  message.senderRole
                                                      .toUpperCase(),
                                                ),
                                                subtitle: Text(message.body),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.label, this.imageUrl});

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initials = label.trim().isEmpty
        ? 'GY'
        : label
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
              .join();

    return CircleAvatar(
      radius: 24,
      foregroundImage: imageUrl == null || imageUrl!.isEmpty
          ? null
          : NetworkImage(imageUrl!),
      child: Text(initials.isEmpty ? 'GY' : initials),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
