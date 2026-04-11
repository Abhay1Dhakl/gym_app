import 'dart:async';

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
  late Future<_ClientWorkspaceBundle> _workspaceFuture;
  LiveConversationController? _conversationController;

  final _weightController = TextEditingController();
  final _sleepController = TextEditingController(text: '4');
  final _stressController = TextEditingController(text: '2');
  final _adherenceController = TextEditingController(text: '90');
  final _checkinNotesController = TextEditingController();

  final _metricWeightController = TextEditingController();
  final _metricSquatController = TextEditingController();
  final _metricBenchController = TextEditingController();
  final _metricDeadliftController = TextEditingController();
  final _metricAdherenceController = TextEditingController(text: '90');
  final _metricEnergyController = TextEditingController(text: '4');
  final _metricNotesController = TextEditingController();

  final _formExerciseController = TextEditingController();
  final _formVideoUrlController = TextEditingController();
  final _formNotesController = TextEditingController();

  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();

  int _lastConversationLength = 0;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    unawaited(_initializeConversation());
  }

  @override
  void dispose() {
    _conversationController?.removeListener(_handleConversationUpdate);
    _conversationController?.dispose();
    _weightController.dispose();
    _sleepController.dispose();
    _stressController.dispose();
    _adherenceController.dispose();
    _checkinNotesController.dispose();
    _metricWeightController.dispose();
    _metricSquatController.dispose();
    _metricBenchController.dispose();
    _metricDeadliftController.dispose();
    _metricAdherenceController.dispose();
    _metricEnergyController.dispose();
    _metricNotesController.dispose();
    _formExerciseController.dispose();
    _formVideoUrlController.dispose();
    _formNotesController.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    _dashboardFuture = widget.clientRepository.fetchDashboard();
    _workspaceFuture = _loadWorkspaceBundle();
  }

  Future<_ClientWorkspaceBundle> _loadWorkspaceBundle() async {
    final results = await Future.wait<dynamic>([
      widget.clientRepository.fetchCheckins(),
      widget.clientRepository.fetchMetrics(),
      widget.clientRepository.fetchInvoices(),
      widget.clientRepository.fetchNotifications(),
      widget.clientRepository.fetchFormChecks(),
    ]);

    return _ClientWorkspaceBundle(
      checkins: results[0] as List<CheckInItem>,
      metrics: results[1] as List<MetricEntryModel>,
      invoices: results[2] as List<InvoiceItem>,
      notifications: results[3] as List<NotificationItem>,
      formChecks: results[4] as List<FormCheckModel>,
    );
  }

  Future<void> _initializeConversation() async {
    try {
      final dashboard = await _dashboardFuture;
      if (!mounted) {
        return;
      }
      await _bindConversation(dashboard.clientId);
    } catch (_) {
      // Dashboard surface already handles this.
    }
  }

  Future<void> _bindConversation(int clientId) async {
    _conversationController?.removeListener(_handleConversationUpdate);
    _conversationController?.dispose();

    final controller = LiveConversationController(
      loadMessages: widget.clientRepository.fetchMessages,
      sendMessage: widget.clientRepository.sendMessage,
      connect: () => widget.clientRepository.watchConversation(clientId),
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

    if (_navIndex == 0) {
      setState(() {});
    }
  }

  bool _hasAccess(ClientDashboardModel data) {
    return data.subscription?.hasAccess ?? false;
  }

  Future<void> _submitCheckin(ClientDashboardModel data) async {
    if (!_hasAccess(data)) {
      _showMessage(
        'Your subscription is not active. Resolve billing to submit new coaching data.',
        error: true,
      );
      return;
    }

    try {
      await widget.clientRepository.submitCheckin(
        bodyWeight: double.tryParse(_weightController.text),
        sleepScore: int.tryParse(_sleepController.text),
        stressScore: int.tryParse(_stressController.text),
        adherenceScore: int.tryParse(_adherenceController.text),
        notes: _emptyToNull(_checkinNotesController.text),
      );
      _weightController.clear();
      _checkinNotesController.clear();
      _showMessage('Check-in submitted.');
      setState(_refreshAll);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _submitMetric(ClientDashboardModel data) async {
    if (!_hasAccess(data)) {
      _showMessage(
        'Your subscription is not active. Resolve billing to log new progress data.',
        error: true,
      );
      return;
    }

    try {
      await widget.clientRepository.submitMetric(
        bodyWeight: double.tryParse(_metricWeightController.text),
        squat1rm: double.tryParse(_metricSquatController.text),
        bench1rm: double.tryParse(_metricBenchController.text),
        deadlift1rm: double.tryParse(_metricDeadliftController.text),
        adherenceScore: int.tryParse(_metricAdherenceController.text),
        energyScore: int.tryParse(_metricEnergyController.text),
        notes: _emptyToNull(_metricNotesController.text),
      );
      _showMessage('Metric logged.');
      setState(_refreshAll);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _submitFormCheck(ClientDashboardModel data) async {
    if (!_hasAccess(data)) {
      _showMessage(
        'Your subscription is not active. Resolve billing to request a form review.',
        error: true,
      );
      return;
    }

    try {
      await widget.clientRepository.submitFormCheck(
        exerciseName: _formExerciseController.text.trim(),
        videoUrl: _formVideoUrlController.text.trim(),
        notes: _emptyToNull(_formNotesController.text),
      );
      _formExerciseController.clear();
      _formVideoUrlController.clear();
      _formNotesController.clear();
      _showMessage('Video form check submitted.');
      setState(_refreshAll);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _markNotificationRead(NotificationItem notification) async {
    if (notification.isRead) {
      return;
    }

    try {
      await widget.clientRepository.markNotificationRead(notification.id);
      setState(_refreshAll);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _sendMessage(ClientDashboardModel data) async {
    if (!_hasAccess(data)) {
      _showMessage(
        'Your subscription is not active. Resolve billing to send new coaching messages.',
        error: true,
      );
      return;
    }

    final controller = _conversationController;
    if (controller == null) {
      _showMessage('Conversation is still loading.', error: true);
      return;
    }

    try {
      await controller.send(_messageController.text);
      _messageController.clear();
      _showMessage('Message sent.');
      setState(() {
        _dashboardFuture = widget.clientRepository.fetchDashboard();
      });
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
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up),
                label: 'Progress',
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
              0 => _buildHome(),
              1 => _withDashboard((data) => _buildPlan(data)),
              2 => _buildProgress(),
              3 => _buildMessages(),
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

  Widget _buildHome() {
    return _withDashboard((data) {
      final access = _hasAccess(data);
      final liveMessages = _conversationController?.state.messages;
      final recentMessages = liveMessages != null && liveMessages.isNotEmpty
          ? liveMessages.reversed.take(4).toList()
          : data.recentMessages;
      final nextInvoice = data.upcomingInvoices.isNotEmpty
          ? data.upcomingInvoices.first
          : null;

      return ListView(
        children: [
          ScreenIntro(
            eyebrow: 'Member Experience',
            title:
                'Everything from ${data.organizationName ?? widget.session.organizationName ?? 'your gym'} in one premium flow.',
            subtitle:
                'Training, nutrition, metrics, reports, billing, notifications, and coach communication all stay current without reloading the page.',
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
          _SubscriptionBanner(subscription: data.subscription),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(
                label: 'Subscription',
                value: data.subscription?.status ?? 'not set',
                accent: access ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
              ),
              _SummaryCard(
                label: 'Today',
                value: data.todayFocus ?? 'Recovery',
                accent: const Color(0xFF2563EB),
              ),
              _SummaryCard(
                label: 'Unread alerts',
                value: '${data.unreadNotifications}',
                accent: const Color(0xFFB45309),
              ),
              _SummaryCard(
                label: 'Next invoice',
                value: nextInvoice == null ? 'n/a' : _formatDate(nextInvoice.dueDate),
                accent: const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1050;
              final overviewPanel = _SectionCard(
                title: 'Member snapshot',
                subtitle:
                    '${data.clientName} • ${data.goal} • ${data.organizationName ?? widget.session.organizationName ?? 'Gym'}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.latestMetric != null)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Chip(
                            label: Text(
                              'Bodyweight ${_formatNumber(data.latestMetric!.bodyWeight)}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Squat ${_formatNumber(data.latestMetric!.squat1rm)}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Bench ${_formatNumber(data.latestMetric!.bench1rm)}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Deadlift ${_formatNumber(data.latestMetric!.deadlift1rm)}',
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'No metrics logged yet. Visit Progress to add bodyweight and strength data.',
                      ),
                    if (data.monthlyProgressReport != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        data.monthlyProgressReport!.summary,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              );

              final challengePanel = _SectionCard(
                title: 'Challenge pulse',
                subtitle: data.activeChallenge == null
                    ? 'No live challenge right now.'
                    : '${data.activeChallenge!.title} • ${_metricLabel(data.activeChallenge!.metricType)}',
                child: data.activeChallenge == null
                    ? const Text(
                        'When your gym launches a challenge, the live leaderboard shows up here.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data.activeChallenge!.description != null)
                            Text(data.activeChallenge!.description!),
                          const SizedBox(height: 12),
                          ...data.activeChallenge!.leaderboard.take(3).map(
                            (entry) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFDE68A),
                                child: Text('#${entry.rank}'),
                              ),
                              title: Text(entry.clientName),
                              trailing: Text(entry.displayScore),
                            ),
                          ),
                        ],
                      ),
              );

              if (!wide) {
                return Column(
                  children: [
                    overviewPanel,
                    const SizedBox(height: 16),
                    challengePanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: overviewPanel),
                  const SizedBox(width: 16),
                  Expanded(child: challengePanel),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Recent coach messages',
            subtitle: 'Your conversation stays live and synchronized.',
            child: Column(
              children: recentMessages
                  .map(
                    (message) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(message.isFromClient ? 'You' : 'Coach'),
                      subtitle: Text(message.body),
                      trailing: Text(_formatTime(message.createdAt)),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Recent form checks',
            subtitle:
                'Exercise videos and coach reviews land here as soon as they are processed.',
            child: data.recentFormChecks.isEmpty
                ? const Text('No form checks yet.')
                : Column(
                    children: data.recentFormChecks
                        .map(
                          (formCheck) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(formCheck.exerciseName),
                            subtitle: Text(
                              formCheck.coachFeedback ?? 'Awaiting coach review',
                            ),
                            trailing: Text(formCheck.status),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildPlan(ClientDashboardModel data) {
    final program = data.program;
    final nutrition = data.nutritionPlan;

    return ListView(
      children: [
        _SubscriptionBanner(subscription: data.subscription),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Training cycle',
          subtitle: program == null
              ? 'Your coach has not assigned a program yet.'
              : '${program.title} • ${program.phase} • ${_formatDate(program.startDate)} to ${_formatDate(program.endDate)}',
          child: program == null
              ? const Text(
                  'Once your coach publishes a program, your 4-week cycle and day-by-day sessions will appear here.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.goal),
                    if (program.summary != null) ...[
                      const SizedBox(height: 8),
                      Text(program.summary!),
                    ],
                    const SizedBox(height: 16),
                    ...program.workoutDays.map(
                      (day) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day ${day.dayIndex}: ${day.title}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(day.focus),
                            if (day.notes != null) ...[
                              const SizedBox(height: 8),
                              Text(day.notes!),
                            ],
                            const SizedBox(height: 12),
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
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Nutrition targets',
          subtitle: nutrition == null
              ? 'No nutrition targets are assigned yet.'
              : '${nutrition.calories} calories • ${nutrition.protein}g protein • ${nutrition.carbs}g carbs • ${nutrition.fats}g fats',
          child: nutrition == null
              ? const Text(
                  'Your coach has not published nutrition guidance yet.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _PlanMetric(label: 'Calories', value: '${nutrition.calories}'),
                        _PlanMetric(label: 'Protein', value: '${nutrition.protein}g'),
                        _PlanMetric(label: 'Carbs', value: '${nutrition.carbs}g'),
                        _PlanMetric(label: 'Fats', value: '${nutrition.fats}g'),
                        _PlanMetric(
                          label: 'Water',
                          value: '${nutrition.waterLiters ?? 0} L',
                        ),
                      ],
                    ),
                    if (nutrition.notes != null) ...[
                      const SizedBox(height: 16),
                      Text(nutrition.notes!),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return _withDashboard((data) {
      return FutureBuilder<_ClientWorkspaceBundle>(
        future: _workspaceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final workspace = snapshot.data!;
          final access = _hasAccess(data);

          return ListView(
            children: [
              _SubscriptionBanner(subscription: data.subscription),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1080;
                  final checkinCard = _SectionCard(
                    title: 'Weekly check-in',
                    subtitle:
                        'Keep your coach updated on recovery, stress, adherence, and bodyweight.',
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
                            onPressed: access ? () => _submitCheckin(data) : null,
                            child: const Text('Submit check-in'),
                          ),
                        ),
                      ],
                    ),
                  );

                  final metricCard = _SectionCard(
                    title: 'Metrics lab',
                    subtitle:
                        'Log bodyweight and strength progress to drive your monthly report and gym leaderboard placement.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _metricField(
                              _metricWeightController,
                              'Bodyweight',
                              width: 130,
                            ),
                            _metricField(
                              _metricSquatController,
                              'Squat 1RM',
                              width: 130,
                            ),
                            _metricField(
                              _metricBenchController,
                              'Bench 1RM',
                              width: 130,
                            ),
                            _metricField(
                              _metricDeadliftController,
                              'Deadlift 1RM',
                              width: 140,
                            ),
                            _metricField(
                              _metricAdherenceController,
                              'Adherence %',
                              width: 130,
                            ),
                            _metricField(
                              _metricEnergyController,
                              'Energy 1-5',
                              width: 120,
                            ),
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
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: access ? () => _submitMetric(data) : null,
                            child: const Text('Log metric'),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        checkinCard,
                        const SizedBox(height: 16),
                        metricCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: checkinCard),
                      const SizedBox(width: 16),
                      Expanded(child: metricCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1080;
                  final reportCard = _SectionCard(
                    title: 'Monthly progress report',
                    subtitle:
                        'Auto-generated from the data you log across the month.',
                    child: data.monthlyProgressReport == null
                        ? const Text(
                            'No report yet. Keep logging check-ins and metrics this month.',
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
                                      '${_formatDate(data.monthlyProgressReport!.periodStart)} to ${_formatDate(data.monthlyProgressReport!.periodEnd)}',
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      'Check-ins ${data.monthlyProgressReport!.checkinsCompleted}',
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      'Adherence ${data.monthlyProgressReport!.adherenceAverage?.toStringAsFixed(1) ?? 'n/a'}%',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(data.monthlyProgressReport!.summary),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _MiniTrend(
                                    label: 'Bodyweight',
                                    value: _formatDelta(
                                      data.monthlyProgressReport!.bodyWeightChange,
                                    ),
                                  ),
                                  _MiniTrend(
                                    label: 'Squat',
                                    value: _formatDelta(
                                      data.monthlyProgressReport!.squatGain,
                                    ),
                                  ),
                                  _MiniTrend(
                                    label: 'Bench',
                                    value: _formatDelta(
                                      data.monthlyProgressReport!.benchGain,
                                    ),
                                  ),
                                  _MiniTrend(
                                    label: 'Deadlift',
                                    value: _formatDelta(
                                      data.monthlyProgressReport!.deadliftGain,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  );

                  final challengeCard = _SectionCard(
                    title: 'Community challenge',
                    subtitle: data.activeChallenge == null
                        ? 'No challenge is active right now.'
                        : '${data.activeChallenge!.title} • ${_metricLabel(data.activeChallenge!.metricType)}',
                    child: data.activeChallenge == null
                        ? const Text(
                            'Your gym will surface leaderboard challenges here when a monthly event goes live.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data.activeChallenge!.description != null)
                                Text(data.activeChallenge!.description!),
                              const SizedBox(height: 12),
                              ...data.activeChallenge!.leaderboard.map(
                                (entry) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFFDE68A),
                                    child: Text('#${entry.rank}'),
                                  ),
                                  title: Text(entry.clientName),
                                  trailing: Text(entry.displayScore),
                                ),
                              ),
                            ],
                          ),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        reportCard,
                        const SizedBox(height: 16),
                        challengeCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: reportCard),
                      const SizedBox(width: 16),
                      Expanded(child: challengeCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1080;
                  final historyCard = _SectionCard(
                    title: 'History',
                    subtitle:
                        'Your last check-ins and metric entries in one place.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent check-ins',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...workspace.checkins.take(5).map(
                          (checkin) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatDateTime(checkin.submittedAt)),
                            subtitle: Text(checkin.notes ?? 'No notes'),
                            trailing: Text('${checkin.adherenceScore ?? 0}%'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Recent metrics',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...workspace.metrics.take(5).map(
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

                  final formCheckCard = _SectionCard(
                    title: 'Video form checks',
                    subtitle:
                        'Submit a lift video for coaching review and track review status.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _formExerciseController,
                          decoration: const InputDecoration(
                            labelText: 'Exercise name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _formVideoUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Video URL',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _formNotesController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'What should your coach look for?',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: access ? () => _submitFormCheck(data) : null,
                            child: const Text('Submit form check'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...workspace.formChecks.take(5).map(
                          (formCheck) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(formCheck.exerciseName),
                            subtitle: Text(
                              formCheck.coachFeedback ?? 'Awaiting coach review',
                            ),
                            trailing: Text(formCheck.status),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        historyCard,
                        const SizedBox(height: 16),
                        formCheckCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: historyCard),
                      const SizedBox(width: 16),
                      Expanded(child: formCheckCard),
                    ],
                  );
                },
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildMessages() {
    return _withDashboard((data) {
      final controller = _conversationController;
      if (controller == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final access = _hasAccess(data);

      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final state = controller.state;
          final error = state.error;

          return LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 980;
              final composer = _ConversationComposerCard(
                controller: _messageController,
                title: 'Message your coach',
                subtitle: access
                    ? 'Send updates, questions, recovery notes, or video links. Replies land instantly without a page refresh.'
                    : 'Your subscription is not active. Messaging is temporarily locked until billing is resolved.',
                isSending: state.isSending,
                canSend: access,
                onSend: () => _sendMessage(data),
              );
              final timeline = _ConversationTimelineCard(
                title: 'Live conversation',
                subtitle: state.isConnected
                    ? 'Connected to your coach now.'
                    : 'Reconnecting to live replies.',
                messages: state.messages,
                scrollController: _messageScrollController,
                isLoading: state.isLoading,
                currentUserRole: 'client',
                emptyTitle: 'Your coach thread is ready',
                emptySubtitle:
                    'Start the conversation once and every new reply will appear here live.',
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenIntro(
                    eyebrow: 'Live Messaging',
                    title: 'Coach communication that feels immediate.',
                    subtitle:
                        'No refreshes, no stale thread. Your updates and your coach’s replies stay synced in real time.',
                    trailing: _LiveStatusChip(
                      label: state.isConnected ? 'Live now' : 'Reconnecting',
                      color: state.isConnected
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SubscriptionBanner(subscription: data.subscription),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    _StatusBanner(message: error),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: wideLayout
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 320, child: composer),
                              const SizedBox(width: 16),
                              Expanded(child: timeline),
                            ],
                          )
                        : Column(
                            children: [
                              composer,
                              const SizedBox(height: 16),
                              Expanded(child: timeline),
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  Widget _buildAccount() {
    return _withDashboard((data) {
      return FutureBuilder<_ClientWorkspaceBundle>(
        future: _workspaceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final workspace = snapshot.data!;

          return ListView(
            children: [
              _SubscriptionBanner(subscription: data.subscription),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Gym account',
                subtitle:
                    '${widget.session.organizationName ?? 'Gym'} • ${widget.session.fullName ?? data.clientName}',
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
                        'Your training, billing, metrics, and communication are tied to this gym account.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Billing',
                subtitle:
                    'Upcoming and past invoices generated from your subscription cycle.',
                child: workspace.invoices.isEmpty
                    ? const Text('No invoices yet.')
                    : Column(
                        children: workspace.invoices
                            .map(
                              (invoice) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(invoice.title),
                                subtitle: Text(
                                  '${_formatDate(invoice.dueDate)}${invoice.billingPeriodStart == null ? '' : ' • ${_formatDate(invoice.billingPeriodStart)} to ${_formatDate(invoice.billingPeriodEnd)}'}',
                                ),
                                trailing: Text(invoice.status),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Notification inbox',
                subtitle:
                    'Check-in reminders, report availability, and form review updates all surface here.',
                child: workspace.notifications.isEmpty
                    ? const Text('No notifications yet.')
                    : Column(
                        children: workspace.notifications
                            .map(
                              (notification) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(notification.title),
                                subtitle: Text(notification.body),
                                trailing: notification.isRead
                                    ? const Text('Read')
                                    : TextButton(
                                        onPressed: () =>
                                            _markNotificationRead(notification),
                                        child: const Text('Mark read'),
                                      ),
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
    });
  }
}

class _ClientWorkspaceBundle {
  const _ClientWorkspaceBundle({
    required this.checkins,
    required this.metrics,
    required this.invoices,
    required this.notifications,
    required this.formChecks,
  });

  final List<CheckInItem> checkins;
  final List<MetricEntryModel> metrics;
  final List<InvoiceItem> invoices;
  final List<NotificationItem> notifications;
  final List<FormCheckModel> formChecks;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      width: 160,
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 10),
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
  const _SectionCard({
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
      padding: const EdgeInsets.all(16),
      radius: 28,
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner({required this.subscription});

  final SubscriptionModel? subscription;

  @override
  Widget build(BuildContext context) {
    final currentSubscription = subscription;
    final status = currentSubscription?.status ?? 'not_set';
    final hasAccess = currentSubscription?.hasAccess ?? false;
    final background = hasAccess
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFEF2F2);
    final border = hasAccess
        ? const Color(0xFF6EE7B7)
        : const Color(0xFFFCA5A5);
    final foreground = hasAccess
        ? const Color(0xFF065F46)
        : const Color(0xFF991B1B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasAccess ? Icons.verified_rounded : Icons.error_outline_rounded,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentSubscription == null
                      ? 'Subscription not configured'
                      : '${currentSubscription.planName} • $status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentSubscription == null
                      ? 'Your coach has not configured billing access yet.'
                      : hasAccess
                          ? 'Access is active. Your next billing date is ${_formatDate(currentSubscription.nextInvoiceDate)}.'
                          : 'Access is restricted. Resolve billing to unlock messaging, metric logging, and form checks.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _MiniTrend extends StatelessWidget {
  const _MiniTrend({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

Widget _metricField(
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

class _ConversationComposerCard extends StatelessWidget {
  const _ConversationComposerCard({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.isSending,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final String title;
  final String subtitle;
  final bool isSending;
  final bool canSend;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            minLines: 7,
            maxLines: 10,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'What do you want your coach to see?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final enabled = value.text.trim().isNotEmpty && !isSending && canSend;
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: enabled ? onSend : null,
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(isSending ? 'Sending...' : 'Send live update'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConversationTimelineCard extends StatelessWidget {
  const _ConversationTimelineCard({
    required this.title,
    required this.subtitle,
    required this.messages,
    required this.scrollController,
    required this.isLoading,
    required this.currentUserRole,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final String title;
  final String subtitle;
  final List<MessageItem> messages;
  final ScrollController scrollController;
  final bool isLoading;
  final String currentUserRole;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
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
                            Icons.mark_chat_read_outlined,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          emptyTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptySubtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: messages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageBubble(
                        message: message,
                        isCurrentUser: message.senderRole == currentUserRole,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isCurrentUser,
  });

  final MessageItem message;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final alignment = isCurrentUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = isCurrentUser
        ? const Color(0xFF0F172A)
        : Colors.white.withValues(alpha: 0.82);
    final textColor = isCurrentUser ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          isCurrentUser ? 'You' : 'Coach',
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

class _LiveStatusChip extends StatelessWidget {
  const _LiveStatusChip({
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
        color: Colors.white.withValues(alpha: 0.8),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

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

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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
