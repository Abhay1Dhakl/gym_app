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
  late Future<List<CheckInItem>> _checkinsFuture;
  late Future<List<InvoiceItem>> _invoicesFuture;
  LiveConversationController? _conversationController;

  final _weightController = TextEditingController();
  final _sleepController = TextEditingController(text: '4');
  final _stressController = TextEditingController(text: '2');
  final _adherenceController = TextEditingController(text: '90');
  final _checkinNotesController = TextEditingController();
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
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    _dashboardFuture = widget.clientRepository.fetchDashboard();
    _checkinsFuture = widget.clientRepository.fetchCheckins();
    _invoicesFuture = widget.clientRepository.fetchInvoices();
  }

  Future<void> _initializeConversation() async {
    try {
      final dashboard = await _dashboardFuture;
      if (!mounted) {
        return;
      }
      await _bindConversation(dashboard.clientId);
    } catch (_) {
      // The dashboard already surfaces this failure.
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
      final liveMessages = _conversationController?.state.messages;
      final recentMessages =
          liveMessages != null && liveMessages.isNotEmpty
          ? liveMessages.reversed.take(4).toList()
          : data.recentMessages;

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
              children: recentMessages
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
    final controller = _conversationController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
              subtitle:
                  'Send updates, questions, or form videos. New replies land instantly without a page refresh.',
              isSending: state.isSending,
              onSend: _sendMessage,
            );
            final timeline = _ConversationTimelineCard(
              title: 'Live conversation',
              subtitle:
                  state.isConnected
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

class _ConversationComposerCard extends StatelessWidget {
  const _ConversationComposerCard({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final String title;
  final String subtitle;
  final bool isSending;
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
              final enabled = value.text.trim().isNotEmpty && !isSending;
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
          _formatConversationTimestamp(message.createdAt),
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

String _formatConversationTimestamp(DateTime value) {
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
