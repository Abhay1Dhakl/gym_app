import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';
import 'package:coach_flow_core/src/services/message_stream_connection.dart';

class ClientRepository {
  const ClientRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<ClientDashboardModel> fetchDashboard() async {
    final response = await apiClient.getMap('/api/client/dashboard');
    return ClientDashboardModel.fromJson(response);
  }

  Future<List<CheckInItem>> fetchCheckins() async {
    final response = await apiClient.getList('/api/client/checkins');
    return response
        .map((item) => CheckInItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<CheckInItem> submitCheckin({
    double? bodyWeight,
    int? sleepScore,
    int? stressScore,
    int? adherenceScore,
    String? notes,
  }) async {
    final response = await apiClient.postMap(
      '/api/client/checkins',
      body: {
        'body_weight': bodyWeight,
        'sleep_score': sleepScore,
        'stress_score': stressScore,
        'adherence_score': adherenceScore,
        'notes': notes,
      },
    );
    return CheckInItem.fromJson(response);
  }

  Future<SubscriptionModel?> fetchSubscription() async {
    final response = await apiClient.getOptionalMap('/api/client/subscription');
    if (response == null) {
      return null;
    }
    return SubscriptionModel.fromJson(response);
  }

  Future<List<MetricEntryModel>> fetchMetrics() async {
    final response = await apiClient.getList('/api/client/metrics');
    return response
        .map(
          (item) => MetricEntryModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<MetricEntryModel> submitMetric({
    double? bodyWeight,
    double? squat1rm,
    double? bench1rm,
    double? deadlift1rm,
    int? adherenceScore,
    int? energyScore,
    String? notes,
  }) async {
    final response = await apiClient.postMap(
      '/api/client/metrics',
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

  Future<List<MessageItem>> fetchMessages() async {
    final response = await apiClient.getList('/api/client/messages');
    return response
        .map((item) => MessageItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<MessageStreamConnection> watchConversation(int clientId) {
    return MessageStreamConnection.connect(
      apiClient: apiClient,
      path: '/api/realtime/messages/$clientId',
    );
  }

  Future<MessageItem> sendMessage(String body) async {
    final response = await apiClient.postMap(
      '/api/client/messages',
      body: {'body': body},
    );
    return MessageItem.fromJson(response);
  }

  Future<List<InvoiceItem>> fetchInvoices() async {
    final response = await apiClient.getList('/api/client/invoices');
    return response
        .map((item) => InvoiceItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<ProgressReportModel?> fetchProgressReport() async {
    final response = await apiClient.getOptionalMap('/api/client/progress-report');
    if (response == null) {
      return null;
    }
    return ProgressReportModel.fromJson(response);
  }

  Future<List<NotificationItem>> fetchNotifications() async {
    final response = await apiClient.getList('/api/client/notifications');
    return response
        .map(
          (item) => NotificationItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<NotificationItem> markNotificationRead(int notificationId) async {
    final response = await apiClient.putMap(
      '/api/client/notifications/$notificationId/read',
    );
    return NotificationItem.fromJson(response);
  }

  Future<ChallengeModel?> fetchChallenge() async {
    final response = await apiClient.getOptionalMap('/api/client/challenge');
    if (response == null) {
      return null;
    }
    return ChallengeModel.fromJson(response);
  }

  Future<List<FormCheckModel>> fetchFormChecks() async {
    final response = await apiClient.getList('/api/client/form-checks');
    return response
        .map((item) => FormCheckModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<FormCheckModel> submitFormCheck({
    required String exerciseName,
    required String videoUrl,
    String? notes,
  }) async {
    final response = await apiClient.postMap(
      '/api/client/form-checks',
      body: {
        'exercise_name': exerciseName,
        'video_url': videoUrl,
        'notes': notes,
      },
    );
    return FormCheckModel.fromJson(response);
  }
}
