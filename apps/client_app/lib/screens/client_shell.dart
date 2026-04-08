import 'package:coach_flow_core/coach_flow_core.dart';
import 'package:flutter/material.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.onLogout,
  });

  final AuthSession session;
  final ClientRepository clientRepository;
  final Future<void> Function() onLogout;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _navIndex = 0;
  late Future<ClientDashboardModel> _dashboardFuture;
  late Future<List<CheckInItem>> _checkinsFuture;
  late Future<List<MessageItem>> _messagesFuture;
  late Future<List<InvoiceItem>> _invoicesFuture;

  final _weightController = TextEditingController();
  final _sleepController = TextEditingController(text: '4');
  final _stressController = TextEditingController(text: '2');
  final _adherenceController = TextEditingController(text: '90');
  final _checkinNotesController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _sleepController.dispose();
    _stressController.dispose();
    _adherenceController.dispose();
    _checkinNotesController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    _dashboardFuture = widget.clientRepository.fetchDashboard();
    _checkinsFuture = widget.clientRepository.fetchCheckins();
    _messagesFuture = widget.clientRepository.fetchMessages();
    _invoicesFuture = widget.clientRepository.fetchInvoices();
  }

  Future<void> _submitCheckin() async {
    try {
      await widget.clientRepository.submitCheckin(
        bodyWeight: double.tryParse(_weightController.text),
        sleepScore: int.tryParse(_sleepController.text),
        stressScore: int.tryParse(_stressController.text),
        adherenceScore: int.tryParse(_adherenceController.text),
        notes: _checkinNotesController.text.trim().isEmpty
            ? null
            : _checkinNotesController.text.trim(),
      );
      _weightController.clear();
      _checkinNotesController.clear();
      _showMessage('Check-in submitted.');
      setState(_refreshAll);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _sendMessage() async {
    try {
      await widget.clientRepository.sendMessage(_messageController.text.trim());
      _messageController.clear();
      _showMessage('Message sent.');
      setState(_refreshAll);
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 84,
        title: Text(widget.session.organizationName ?? 'Gym Client App'),
        leadingWidth: 78,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: _BrandAvatar(
              label: widget.session.organizationName ?? 'Gym',
              imageUrl: widget.session.organizationLogoUrl,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          radius: 28,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _navIndex,
            onDestinationSelected: (index) {
              setState(() {
                _navIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Train',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_outlined),
                selectedIcon: Icon(Icons.restaurant),
                label: 'Nutrition',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Check-ins',
              ),
              NavigationDestination(
                icon: Icon(Icons.message_outlined),
                selectedIcon: Icon(Icons.message),
                label: 'Messages',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
      body: AuroraBackground(
        palette: AppTheme.clientPalette,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
            child: switch (_navIndex) {
              0 => _buildDashboard(),
              1 => _withDashboard((data) => _buildTraining(data)),
              2 => _withDashboard((data) => _buildNutrition(data)),
              3 => _buildCheckins(),
              4 => _buildMessages(),
              _ => _buildAccount(),
            },
          ),
        ),
      ),
    );
  }

  Widget _withDashboard(Widget Function(ClientDashboardModel data) builder) {
    return FutureBuilder<ClientDashboardModel>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        return builder(snapshot.data!);
      },
    );
  }

  Widget _buildDashboard() {
    return _withDashboard((data) {
      return ListView(
        children: [
          ScreenIntro(
            eyebrow: 'Member App',
            title:
                'Everything from ${data.organizationName ?? widget.session.organizationName ?? 'your gym'} in one polished place.',
            subtitle:
                'Training, nutrition, billing, and coach communication now live inside a more premium member experience.',
            trailing: BrandChip(
              label:
                  data.organizationName ??
                  widget.session.organizationName ??
                  'Gym',
              imageUrl:
                  data.organizationLogoUrl ??
                  widget.session.organizationLogoUrl,
              icon: Icons.wb_sunny_outlined,
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title:
                data.organizationName ??
                widget.session.organizationName ??
                'Your gym',
            child: Row(
              children: [
                _BrandAvatar(
                  label:
                      data.organizationName ??
                      widget.session.organizationName ??
                      'Gym',
                  imageUrl:
                      data.organizationLogoUrl ??
                      widget.session.organizationLogoUrl,
                  radius: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Your training, nutrition, billing, and coach communication are tied to this gym account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hello, ${data.clientName}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(data.goal),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(label: 'Status', value: data.status),
              _SummaryCard(
                label: 'Today',
                value: data.todayFocus ?? 'Rest / recovery',
              ),
              _SummaryCard(
                label: 'Upcoming invoices',
                value: '${data.upcomingInvoices.length}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Recent coach messages',
            child: Column(
              children: data.recentMessages
                  .map(
                    (message) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(message.senderRole.toUpperCase()),
                      subtitle: Text(message.body),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Recent check-ins',
            child: Column(
              children: data.recentCheckins
                  .map(
                    (checkin) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        checkin.submittedAt.toIso8601String().split('T').first,
                      ),
                      subtitle: Text(checkin.notes ?? 'No notes'),
                      trailing: Text('${checkin.adherenceScore ?? 0}%'),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTraining(ClientDashboardModel data) {
    final program = data.program;
    if (program == null) {
      return const Center(
        child: Text('Your coach has not published a program yet.'),
      );
    }

    return ListView(
      children: [
        Text(program.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('${program.phase} • ${program.goal}'),
        const SizedBox(height: 16),
        ...program.workoutDays.map(
          (day) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionCard(
              title: 'Day ${day.dayIndex}: ${day.title}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.focus),
                  const SizedBox(height: 8),
                  ...day.exercises.map(
                    (exercise) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(exercise.name),
                      subtitle: Text(
                        '${exercise.sets} sets x ${exercise.reps} reps',
                      ),
                      trailing: Text(exercise.target ?? ''),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrition(ClientDashboardModel data) {
    final nutrition = data.nutritionPlan;
    if (nutrition == null) {
      return const Center(
        child: Text('Your coach has not published nutrition targets yet.'),
      );
    }

    return ListView(
      children: [
        Text('Nutrition', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(label: 'Calories', value: '${nutrition.calories}'),
            _SummaryCard(label: 'Protein', value: '${nutrition.protein}g'),
            _SummaryCard(label: 'Carbs', value: '${nutrition.carbs}g'),
            _SummaryCard(label: 'Fats', value: '${nutrition.fats}g'),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Coach notes',
          child: Text(nutrition.notes ?? 'No extra notes yet.'),
        ),
      ],
    );
  }

  Widget _buildCheckins() {
    return FutureBuilder<List<CheckInItem>>(
      future: _checkinsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final checkins = snapshot.data!;
        return ListView(
          children: [
            _SectionCard(
              title: 'Submit weekly check-in',
              child: Column(
                children: [
                  TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Body weight (kg)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sleepController,
                          decoration: const InputDecoration(
                            labelText: 'Sleep 1-5',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _stressController,
                          decoration: const InputDecoration(
                            labelText: 'Stress 1-5',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _adherenceController,
                          decoration: const InputDecoration(
                            labelText: 'Adherence %',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _checkinNotesController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitCheckin,
                      child: const Text('Submit check-in'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Check-in history',
              child: Column(
                children: checkins
                    .map(
                      (checkin) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          checkin.submittedAt
                              .toIso8601String()
                              .split('T')
                              .first,
                        ),
                        subtitle: Text(checkin.notes ?? 'No notes'),
                        trailing: Text('${checkin.adherenceScore ?? 0}%'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessages() {
    return FutureBuilder<List<MessageItem>>(
      future: _messagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final messages = snapshot.data!;
        return ListView(
          children: [
            _SectionCard(
              title: 'Message your coach',
              child: Column(
                children: [
                  TextField(
                    controller: _messageController,
                    minLines: 4,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _sendMessage,
                      child: const Text('Send message'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Conversation',
              child: Column(
                children: messages
                    .map(
                      (message) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(message.senderRole.toUpperCase()),
                        subtitle: Text(message.body),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccount() {
    return FutureBuilder<List<InvoiceItem>>(
      future: _invoicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final invoices = snapshot.data!;
        return ListView(
          children: [
            _SectionCard(
              title: 'Gym account',
              child: Row(
                children: [
                  _BrandAvatar(
                    label: widget.session.organizationName ?? 'Gym',
                    imageUrl: widget.session.organizationLogoUrl,
                    radius: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.session.organizationName ?? 'Gym Client App',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Billing',
              child: Column(
                children: invoices
                    .map(
                      (invoice) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(invoice.title),
                        subtitle: Text(
                          invoice.dueDate.toIso8601String().split('T').first,
                        ),
                        trailing: Text(invoice.status),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.label, this.imageUrl, this.radius = 20});

  final String label;
  final String? imageUrl;
  final double radius;

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
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.82),
      foregroundImage: imageUrl == null || imageUrl!.isEmpty
          ? null
          : NetworkImage(imageUrl!),
      child: Text(initials.isEmpty ? 'GY' : initials),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
