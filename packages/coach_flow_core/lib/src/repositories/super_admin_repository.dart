import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';

class SuperAdminRepository {
  const SuperAdminRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<SuperAdminDashboardModel> fetchDashboard() async {
    final response = await apiClient.getMap('/api/super-admin/dashboard');
    return SuperAdminDashboardModel.fromJson(response);
  }

  Future<List<GymAdminSummary>> fetchAdmins() async {
    final response = await apiClient.getList('/api/super-admin/admins');
    return response
        .map((item) => GymAdminSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GymAdminSummary> createGymAdmin({
    required String fullName,
    required String email,
    required String password,
    required String gymName,
    String? gymLogoUrl,
  }) async {
    final response = await apiClient.postMap(
      '/api/super-admin/admins',
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'gym_name': gymName,
        'gym_logo_url': gymLogoUrl,
      },
    );
    return GymAdminSummary.fromJson(response);
  }
}
