import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';

class ClientRepository {
  const ClientRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<ClientDashboardModel> fetchDashboard() async {
    final response = await apiClient.getMap('/api/client/dashboard');
    return ClientDashboardModel.fromJson(response);
  }

  Future<List<CheckInItem>> fetchCheckins() async {
    final response = await apiClient.getList('/api/client/checkins');
    return response.map((item) => CheckInItem.fromJson(item as Map<String, dynamic>)).toList();
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

  Future<List<MessageItem>> fetchMessages() async {
    final response = await apiClient.getList('/api/client/messages');
    return response.map((item) => MessageItem.fromJson(item as Map<String, dynamic>)).toList();
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
    return response.map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>)).toList();
  }
}
