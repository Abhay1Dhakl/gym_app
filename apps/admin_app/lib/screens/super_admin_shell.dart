import 'package:coach_flow_core/coach_flow_core.dart';
import 'package:flutter/material.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({
    super.key,
    required this.session,
    required this.superAdminRepository,
    required this.authRepository,
    required this.onLogout,
  });

  final AuthSession session;
  final SuperAdminRepository superAdminRepository;
  final AuthRepository authRepository;
  final Future<void> Function() onLogout;

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _navIndex = 0;
  late Future<SuperAdminDashboardModel> _dashboardFuture;
  late Future<List<GymAdminSummary>> _adminsFuture;

  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController(text: 'owner12345');
  final _gymNameController = TextEditingController();
  final _gymLogoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _gymNameController.dispose();
    _gymLogoController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    _dashboardFuture = widget.superAdminRepository.fetchDashboard();
    _adminsFuture = widget.superAdminRepository.fetchAdmins();
  }

  Future<void> _createGymAdmin() async {
    try {
      final created = await widget.superAdminRepository.createGymAdmin(
        fullName: _ownerNameController.text.trim(),
        email: _ownerEmailController.text.trim(),
        password: _ownerPasswordController.text,
        gymName: _gymNameController.text.trim(),
        gymLogoUrl: _gymLogoController.text.trim().isEmpty
            ? null
            : _gymLogoController.text.trim(),
      );

      _ownerNameController.clear();
      _ownerEmailController.clear();
      _ownerPasswordController.text = 'owner12345';
      _gymNameController.clear();
      _gymLogoController.clear();

      _showMessage(
        'Created ${created.gymName} and owner account ${created.email}.',
      );
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
                            const BrandChip(
                              label: 'Super Admin',
                              icon: Icons.workspace_premium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.session.fullName ?? 'Platform Operator',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.space_dashboard_outlined),
                          selectedIcon: Icon(Icons.space_dashboard),
                          label: Text('Overview'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.business_outlined),
                          selectedIcon: Icon(Icons.business),
                          label: Text('Gyms'),
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
                      : _buildGymsWorkspace(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return FutureBuilder<SuperAdminDashboardModel>(
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
            const ScreenIntro(
              eyebrow: 'Platform',
              title: 'Launch beautifully branded gym workspaces.',
              subtitle:
                  'Spin up new gym-owner accounts, attach each gym’s visual identity, and keep every gym’s members, billing, and coaching data inside its own tenant.',
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(label: 'Gyms', value: '${data.totalGyms}'),
                _MetricCard(label: 'Gym owners', value: '${data.totalAdmins}'),
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
              ],
            ),
            const SizedBox(height: 20),
            GlassPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'The platform layer now uses the same premium visual language as the gym apps. It feels closer to a real SaaS control plane than a plain dashboard.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const BrandChip(
                    label: 'GymOS Cloud',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGymsWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScreenIntro(
          eyebrow: 'Gym Provisioning',
          title: 'Create a polished gym-owner workspace in minutes.',
          subtitle:
              'Each gym owner gets a separate branded console. Their clients, messages, programs, and billing stay inside that gym.',
        ),
        const SizedBox(height: 16),
        _PanelCard(
          title: 'New gym account',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _ownerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Gym owner name',
                  ),
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _ownerEmailController,
                  decoration: const InputDecoration(labelText: 'Owner email'),
                ),
              ),
              SizedBox(
                width: 190,
                child: TextField(
                  controller: _ownerPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                  ),
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _gymNameController,
                  decoration: const InputDecoration(labelText: 'Gym name'),
                ),
              ),
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _gymLogoController,
                  decoration: const InputDecoration(labelText: 'Gym logo URL'),
                ),
              ),
              FilledButton(
                onPressed: _createGymAdmin,
                child: const Text('Create gym owner'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<GymAdminSummary>>(
            future: _adminsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }

              final admins = snapshot.data!;
              return GlassPanel(
                padding: const EdgeInsets.all(18),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final admin = admins[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _BrandAvatar(
                        label: admin.gymName,
                        imageUrl: admin.gymLogoUrl,
                      ),
                      title: Text(admin.gymName),
                      subtitle: Text(
                        '${admin.fullName ?? 'Gym owner'} • ${admin.email}\n'
                        'Active clients: ${admin.activeClients} • Invited: ${admin.invitedClients}',
                      ),
                      isThreeLine: true,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Org ${admin.organizationId}'),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24),
                  itemCount: admins.length,
                ),
              );
            },
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
      backgroundColor: Colors.white.withValues(alpha: 0.82),
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
