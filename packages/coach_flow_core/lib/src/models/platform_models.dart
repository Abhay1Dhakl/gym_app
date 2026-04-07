class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.role,
    required this.userId,
  });

  final String accessToken;
  final String role;
  final int userId;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      role: json['role'] as String,
      userId: json['user_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'role': role,
      'user_id': userId,
    };
  }
}

class CheckInItem {
  const CheckInItem({
    required this.id,
    required this.submittedAt,
    required this.bodyWeight,
    required this.sleepScore,
    required this.stressScore,
    required this.adherenceScore,
    required this.notes,
  });

  final int id;
  final DateTime submittedAt;
  final double? bodyWeight;
  final int? sleepScore;
  final int? stressScore;
  final int? adherenceScore;
  final String? notes;

  factory CheckInItem.fromJson(Map<String, dynamic> json) {
    return CheckInItem(
      id: json['id'] as int,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      bodyWeight: (json['body_weight'] as num?)?.toDouble(),
      sleepScore: json['sleep_score'] as int?,
      stressScore: json['stress_score'] as int?,
      adherenceScore: json['adherence_score'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

class MessageItem {
  const MessageItem({
    required this.id,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String senderRole;
  final String body;
  final DateTime createdAt;

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] as int,
      senderRole: json['sender_role'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class InvoiceItem {
  const InvoiceItem({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.dueDate,
    required this.status,
  });

  final int id;
  final String title;
  final int amountCents;
  final DateTime dueDate;
  final String status;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] as int,
      title: json['title'] as String,
      amountCents: json['amount_cents'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String,
    );
  }
}

class WorkoutExerciseModel {
  const WorkoutExerciseModel({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.target,
  });

  final int id;
  final String name;
  final String sets;
  final String reps;
  final int? restSeconds;
  final String? target;

  factory WorkoutExerciseModel.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      sets: json['sets'] as String,
      reps: json['reps'] as String,
      restSeconds: json['rest_seconds'] as int?,
      target: json['target'] as String?,
    );
  }
}

class WorkoutDayModel {
  const WorkoutDayModel({
    required this.id,
    required this.dayIndex,
    required this.title,
    required this.focus,
    required this.notes,
    required this.exercises,
  });

  final int id;
  final int dayIndex;
  final String title;
  final String focus;
  final String? notes;
  final List<WorkoutExerciseModel> exercises;

  factory WorkoutDayModel.fromJson(Map<String, dynamic> json) {
    return WorkoutDayModel(
      id: json['id'] as int,
      dayIndex: json['day_index'] as int,
      title: json['title'] as String,
      focus: json['focus'] as String,
      notes: json['notes'] as String?,
      exercises: ((json['exercises'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => WorkoutExerciseModel.fromJson(item as Map<String, dynamic>))
          .toList()),
    );
  }
}

class ProgramModel {
  const ProgramModel({
    required this.id,
    required this.title,
    required this.phase,
    required this.goal,
    required this.summary,
    required this.workoutDays,
  });

  final int id;
  final String title;
  final String phase;
  final String goal;
  final String? summary;
  final List<WorkoutDayModel> workoutDays;

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    return ProgramModel(
      id: json['id'] as int,
      title: json['title'] as String,
      phase: json['phase'] as String,
      goal: json['goal'] as String,
      summary: json['summary'] as String?,
      workoutDays: ((json['workout_days'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => WorkoutDayModel.fromJson(item as Map<String, dynamic>))
          .toList()),
    );
  }
}

class NutritionPlanModel {
  const NutritionPlanModel({
    required this.id,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.waterLiters,
    required this.notes,
  });

  final int id;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final double? waterLiters;
  final String? notes;

  factory NutritionPlanModel.fromJson(Map<String, dynamic> json) {
    return NutritionPlanModel(
      id: json['id'] as int,
      calories: json['calories'] as int,
      protein: json['protein'] as int,
      carbs: json['carbs'] as int,
      fats: json['fats'] as int,
      waterLiters: (json['water_liters'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }
}

class AdminDashboardModel {
  const AdminDashboardModel({
    required this.totalClients,
    required this.activeClients,
    required this.invitedClients,
    required this.overdueInvoices,
    required this.latestCheckins,
    required this.recentMessages,
  });

  final int totalClients;
  final int activeClients;
  final int invitedClients;
  final int overdueInvoices;
  final List<CheckInItem> latestCheckins;
  final List<MessageItem> recentMessages;

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      totalClients: json['total_clients'] as int,
      activeClients: json['active_clients'] as int,
      invitedClients: json['invited_clients'] as int,
      overdueInvoices: json['overdue_invoices'] as int,
      latestCheckins: ((json['latest_checkins'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => CheckInItem.fromJson(item as Map<String, dynamic>))
          .toList()),
      recentMessages: ((json['recent_messages'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => MessageItem.fromJson(item as Map<String, dynamic>))
          .toList()),
    );
  }
}

class ClientSummary {
  const ClientSummary({
    required this.id,
    required this.fullName,
    required this.contactEmail,
    required this.phone,
    required this.goal,
    required this.status,
    required this.inviteCode,
    required this.latestCheckinAt,
    required this.invoiceStatus,
  });

  final int id;
  final String fullName;
  final String? contactEmail;
  final String? phone;
  final String goal;
  final String status;
  final String inviteCode;
  final DateTime? latestCheckinAt;
  final String? invoiceStatus;

  factory ClientSummary.fromJson(Map<String, dynamic> json) {
    return ClientSummary(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      contactEmail: json['contact_email'] as String?,
      phone: json['phone'] as String?,
      goal: json['goal'] as String,
      status: json['status'] as String,
      inviteCode: json['invite_code'] as String,
      latestCheckinAt: json['latest_checkin_at'] == null
          ? null
          : DateTime.parse(json['latest_checkin_at'] as String),
      invoiceStatus: json['invoice_status'] as String?,
    );
  }
}

class ClientDetailModel {
  const ClientDetailModel({
    required this.id,
    required this.fullName,
    required this.contactEmail,
    required this.phone,
    required this.goal,
    required this.notes,
    required this.status,
    required this.inviteCode,
    required this.program,
    required this.nutritionPlan,
    required this.checkins,
    required this.messages,
    required this.invoices,
  });

  final int id;
  final String fullName;
  final String? contactEmail;
  final String? phone;
  final String goal;
  final String? notes;
  final String status;
  final String inviteCode;
  final ProgramModel? program;
  final NutritionPlanModel? nutritionPlan;
  final List<CheckInItem> checkins;
  final List<MessageItem> messages;
  final List<InvoiceItem> invoices;

  factory ClientDetailModel.fromJson(Map<String, dynamic> json) {
    return ClientDetailModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      contactEmail: json['contact_email'] as String?,
      phone: json['phone'] as String?,
      goal: json['goal'] as String,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      inviteCode: json['invite_code'] as String,
      program: json['program'] == null ? null : ProgramModel.fromJson(json['program'] as Map<String, dynamic>),
      nutritionPlan: json['nutrition_plan'] == null
          ? null
          : NutritionPlanModel.fromJson(json['nutrition_plan'] as Map<String, dynamic>),
      checkins: ((json['checkins'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => CheckInItem.fromJson(item as Map<String, dynamic>))
          .toList()),
      messages: ((json['messages'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => MessageItem.fromJson(item as Map<String, dynamic>))
          .toList()),
      invoices: ((json['invoices'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
          .toList()),
    );
  }
}

class ClientDashboardModel {
  const ClientDashboardModel({
    required this.clientId,
    required this.clientName,
    required this.goal,
    required this.status,
    required this.todayFocus,
    required this.program,
    required this.nutritionPlan,
    required this.recentCheckins,
    required this.recentMessages,
    required this.upcomingInvoices,
  });

  final int clientId;
  final String clientName;
  final String goal;
  final String status;
  final String? todayFocus;
  final ProgramModel? program;
  final NutritionPlanModel? nutritionPlan;
  final List<CheckInItem> recentCheckins;
  final List<MessageItem> recentMessages;
  final List<InvoiceItem> upcomingInvoices;

  factory ClientDashboardModel.fromJson(Map<String, dynamic> json) {
    return ClientDashboardModel(
      clientId: json['client_id'] as int,
      clientName: json['client_name'] as String,
      goal: json['goal'] as String,
      status: json['status'] as String,
      todayFocus: json['today_focus'] as String?,
      program: json['program'] == null ? null : ProgramModel.fromJson(json['program'] as Map<String, dynamic>),
      nutritionPlan: json['nutrition_plan'] == null
          ? null
          : NutritionPlanModel.fromJson(json['nutrition_plan'] as Map<String, dynamic>),
      recentCheckins: ((json['recent_checkins'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => CheckInItem.fromJson(item as Map<String, dynamic>))
          .toList()),
      recentMessages: ((json['recent_messages'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => MessageItem.fromJson(item as Map<String, dynamic>))
          .toList()),
      upcomingInvoices: ((json['upcoming_invoices'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
          .toList()),
    );
  }
}
