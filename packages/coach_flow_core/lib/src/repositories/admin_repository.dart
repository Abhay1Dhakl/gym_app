import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';

class AdminRepository {
  const AdminRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<AdminDashboardModel> fetchDashboard() async {
    final response = await apiClient.getMap('/api/admin/dashboard');
    return AdminDashboardModel.fromJson(response);
  }

  Future<List<ClientSummary>> fetchClients() async {
    final response = await apiClient.getList('/api/admin/clients');
    return response.map((item) => ClientSummary.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ClientSummary> createClient({
    required String fullName,
    required String goal,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/clients',
      body: {
        'full_name': fullName,
        'goal': goal,
        'contact_email': email,
        'phone': phone,
        'notes': notes,
      },
    );
    return ClientSummary.fromJson(response);
  }

  Future<ClientDetailModel> fetchClientDetail(int clientId) async {
    final response = await apiClient.getMap('/api/admin/clients/$clientId');
    return ClientDetailModel.fromJson(response);
  }

  Future<ProgramModel> publishStarterProgram({
    required int clientId,
    required String goal,
  }) async {
    final response = await apiClient.putMap(
      '/api/admin/clients/$clientId/program',
      body: {
        'title': 'Starter Strength Split',
        'phase': 'Foundation',
        'goal': goal,
        'summary': 'A coach-published starter plan for onboarding and week one execution.',
        'workout_days': [
          {
            'day_index': 1,
            'title': 'Lower Strength',
            'focus': 'Squat + posterior chain',
            'notes': 'Leave one rep in reserve on the final set.',
            'exercises': [
              {
                'name': 'Front Squat',
                'sets': '5',
                'reps': '3',
                'rest_seconds': 180,
                'target': '82% 1RM',
              },
              {
                'name': 'Romanian Deadlift',
                'sets': '4',
                'reps': '6',
                'rest_seconds': 150,
                'target': 'RPE 7.5',
              },
            ],
          },
          {
            'day_index': 2,
            'title': 'Upper Push / Pull',
            'focus': 'Bench press + back volume',
            'notes': 'Track bar speed and stop before technical breakdown.',
            'exercises': [
              {
                'name': 'Bench Press',
                'sets': '4',
                'reps': '5',
                'rest_seconds': 150,
                'target': '78% 1RM',
              },
              {
                'name': 'Chest Supported Row',
                'sets': '4',
                'reps': '8',
                'rest_seconds': 120,
                'target': 'Controlled tempo',
              },
            ],
          },
        ],
      },
    );
    return ProgramModel.fromJson(response);
  }

  Future<NutritionPlanModel> saveNutrition({
    required int clientId,
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
    double? waterLiters,
    String? notes,
  }) async {
    final response = await apiClient.putMap(
      '/api/admin/clients/$clientId/nutrition',
      body: {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'water_liters': waterLiters,
        'notes': notes,
      },
    );
    return NutritionPlanModel.fromJson(response);
  }

  Future<MessageItem> sendMessage({
    required int clientId,
    required String body,
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/clients/$clientId/messages',
      body: {'body': body},
    );
    return MessageItem.fromJson(response);
  }

  Future<InvoiceItem> createInvoice({
    required int clientId,
    required String title,
    required int amountCents,
    required DateTime dueDate,
    String status = 'pending',
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/clients/$clientId/invoices',
      body: {
        'title': title,
        'amount_cents': amountCents,
        'due_date': '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
        'status': status,
      },
    );
    return InvoiceItem.fromJson(response);
  }
}
