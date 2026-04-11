import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';
import 'package:coach_flow_core/src/services/message_stream_connection.dart';

class AdminRepository {
  const AdminRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<AdminDashboardModel> fetchDashboard() async {
    final response = await apiClient.getMap('/api/admin/dashboard');
    return AdminDashboardModel.fromJson(response);
  }

  Future<List<ClientSummary>> fetchClients() async {
    final response = await apiClient.getList('/api/admin/clients');
    return response
        .map((item) => ClientSummary.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
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

  Future<List<MessageItem>> fetchClientMessages(int clientId) async {
    final response = await apiClient.getList('/api/admin/clients/$clientId/messages');
    return response
        .map((item) => MessageItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<ProgressReportModel?> fetchClientProgressReport(int clientId) async {
    final response = await apiClient.getOptionalMap(
      '/api/admin/clients/$clientId/progress-report',
    );
    if (response == null) {
      return null;
    }
    return ProgressReportModel.fromJson(response);
  }

  Future<List<ProgramTemplateModel>> fetchTemplates() async {
    final response = await apiClient.getList('/api/admin/templates');
    return response
        .map(
          (item) => ProgramTemplateModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<ProgramTemplateModel> createTemplateFromClient({
    required int clientId,
    String? title,
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/templates/from-client',
      body: {
        'client_id': clientId,
        'title': title,
      },
    );
    return ProgramTemplateModel.fromJson(response);
  }

  Future<ProgramModel> applyTemplate({
    required int templateId,
    required int clientId,
    DateTime? startDate,
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/templates/$templateId/apply',
      body: {
        'client_id': clientId,
        'start_date': startDate == null ? null : formatDateForApi(startDate),
      },
    );
    return ProgramModel.fromJson(response);
  }

  Future<MessageStreamConnection> watchClientConversation(int clientId) {
    return MessageStreamConnection.connect(
      apiClient: apiClient,
      path: '/api/realtime/messages/$clientId',
    );
  }

  Future<ProgramModel> publishStarterProgram({
    required int clientId,
    required String goal,
    DateTime? startDate,
  }) async {
    final response = await apiClient.putMap(
      '/api/admin/clients/$clientId/program',
      body: {
        'title': 'Starter Strength Split',
        'phase': 'Foundation',
        'goal': goal,
        'summary': 'A coach-published starter plan for onboarding and week one execution.',
        'start_date': startDate == null ? null : formatDateForApi(startDate),
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
          {
            'day_index': 3,
            'title': 'Lower Hypertrophy',
            'focus': 'Deadlift pattern + unilateral volume',
            'notes': 'Move fast on concentrics and own the eccentric.',
            'exercises': [
              {
                'name': 'Trap Bar Deadlift',
                'sets': '4',
                'reps': '5',
                'rest_seconds': 180,
                'target': 'RPE 7',
              },
              {
                'name': 'Rear Foot Elevated Split Squat',
                'sets': '3',
                'reps': '8 / side',
                'rest_seconds': 120,
                'target': 'Full ROM',
              },
            ],
          },
          {
            'day_index': 4,
            'title': 'Upper Volume',
            'focus': 'Pressing capacity + shoulder health',
            'notes': 'Leave shoulder-friendly reps in reserve.',
            'exercises': [
              {
                'name': 'Incline Dumbbell Press',
                'sets': '4',
                'reps': '8',
                'rest_seconds': 120,
                'target': 'Smooth tempo',
              },
              {
                'name': 'Lat Pulldown',
                'sets': '4',
                'reps': '10',
                'rest_seconds': 90,
                'target': '2 second squeeze',
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

  Future<SubscriptionModel> saveSubscription({
    required int clientId,
    required String planName,
    required int monthlyPriceCents,
    required String status,
    DateTime? startedAt,
    DateTime? nextInvoiceDate,
    String? notes,
  }) async {
    final response = await apiClient.putMap(
      '/api/admin/clients/$clientId/subscription',
      body: {
        'plan_name': planName,
        'monthly_price_cents': monthlyPriceCents,
        'status': status,
        'started_at': startedAt == null ? null : formatDateForApi(startedAt),
        'next_invoice_date': nextInvoiceDate == null
            ? null
            : formatDateForApi(nextInvoiceDate),
        'notes': notes,
      },
    );
    return SubscriptionModel.fromJson(response);
  }

  Future<MetricEntryModel> createMetric({
    required int clientId,
    double? bodyWeight,
    double? squat1rm,
    double? bench1rm,
    double? deadlift1rm,
    int? adherenceScore,
    int? energyScore,
    String? notes,
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/clients/$clientId/metrics',
      body: {
        'body_weight': bodyWeight,
        'squat_1rm': squat1rm,
        'bench_1rm': bench1rm,
        'deadlift_1rm': deadlift1rm,
        'adherence_score': adherenceScore,
        'energy_score': energyScore,
        'notes': notes,
      },
    );
    return MetricEntryModel.fromJson(response);
  }

  Future<List<FormCheckModel>> fetchClientFormChecks(int clientId) async {
    final response = await apiClient.getList(
      '/api/admin/clients/$clientId/form-checks',
    );
    return response
        .map((item) => FormCheckModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<FormCheckModel> reviewFormCheck({
    required int clientId,
    required int formCheckId,
    required String coachFeedback,
  }) async {
    final response = await apiClient.putMap(
      '/api/admin/clients/$clientId/form-checks/$formCheckId',
      body: {'coach_feedback': coachFeedback},
    );
    return FormCheckModel.fromJson(response);
  }

  Future<ChallengeModel?> fetchChallenge() async {
    final response = await apiClient.getOptionalMap('/api/admin/challenge');
    if (response == null) {
      return null;
    }
    return ChallengeModel.fromJson(response);
  }

  Future<ChallengeModel> createChallenge({
    required String title,
    String? description,
    required String metricType,
    required DateTime startDate,
    required DateTime endDate,
    String? unitLabel,
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/challenge',
      body: {
        'title': title,
        'description': description,
        'metric_type': metricType,
        'start_date': formatDateForApi(startDate),
        'end_date': formatDateForApi(endDate),
        'unit_label': unitLabel,
      },
    );
    return ChallengeModel.fromJson(response);
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
    DateTime? billingPeriodStart,
    DateTime? billingPeriodEnd,
  }) async {
    final response = await apiClient.postMap(
      '/api/admin/clients/$clientId/invoices',
      body: {
        'title': title,
        'amount_cents': amountCents,
        'due_date': formatDateForApi(dueDate),
        'billing_period_start': billingPeriodStart == null
            ? null
            : formatDateForApi(billingPeriodStart),
        'billing_period_end': billingPeriodEnd == null
            ? null
            : formatDateForApi(billingPeriodEnd),
        'status': status,
      },
    );
    return InvoiceItem.fromJson(response);
  }
}
