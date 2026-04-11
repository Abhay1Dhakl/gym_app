DateTime _parseDate(String value) => DateTime.parse(value);

DateTime? _parseOptionalDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}

List<T> _parseItems<T>(
  dynamic value,
  T Function(Map<String, dynamic> json) builder,
) {
  final rawItems = value as List<dynamic>? ?? const <dynamic>[];
  return rawItems
      .map((item) => builder(Map<String, dynamic>.from(item as Map)))
      .toList();
}

String formatDateForApi(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.role,
    required this.userId,
    required this.fullName,
    required this.organizationId,
    required this.organizationName,
    required this.organizationLogoUrl,
  });

  final String accessToken;
  final String role;
  final int userId;
  final String? fullName;
  final int? organizationId;
  final String? organizationName;
  final String? organizationLogoUrl;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      role: json['role'] as String,
      userId: json['user_id'] as int,
      fullName: json['full_name'] as String?,
      organizationId: json['organization_id'] as int?,
      organizationName: json['organization_name'] as String?,
      organizationLogoUrl: json['organization_logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'role': role,
      'user_id': userId,
      'full_name': fullName,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'organization_logo_url': organizationLogoUrl,
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
      submittedAt: _parseDate(json['submitted_at'] as String),
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
      createdAt: _parseDate(json['created_at'] as String),
    );
  }

  bool get isFromAdmin => senderRole == 'admin';
  bool get isFromClient => senderRole == 'client';
}

class InvoiceItem {
  const InvoiceItem({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.dueDate,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.status,
  });

  final int id;
  final String title;
  final int amountCents;
  final DateTime dueDate;
  final DateTime? billingPeriodStart;
  final DateTime? billingPeriodEnd;
  final String status;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] as int,
      title: json['title'] as String,
      amountCents: json['amount_cents'] as int,
      dueDate: _parseDate(json['due_date'] as String),
      billingPeriodStart: _parseOptionalDate(json['billing_period_start']),
      billingPeriodEnd: _parseOptionalDate(json['billing_period_end']),
      status: json['status'] as String,
    );
  }

  double get amount => amountCents / 100;
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
      exercises: _parseItems(
        json['exercises'],
        WorkoutExerciseModel.fromJson,
      ),
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
    required this.startDate,
    required this.endDate,
    required this.workoutDays,
  });

  final int id;
  final String title;
  final String phase;
  final String goal;
  final String? summary;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<WorkoutDayModel> workoutDays;

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    return ProgramModel(
      id: json['id'] as int,
      title: json['title'] as String,
      phase: json['phase'] as String,
      goal: json['goal'] as String,
      summary: json['summary'] as String?,
      startDate: _parseOptionalDate(json['start_date']),
      endDate: _parseOptionalDate(json['end_date']),
      workoutDays: _parseItems(
        json['workout_days'],
        WorkoutDayModel.fromJson,
      ),
    );
  }
}

class ProgramTemplateExerciseModel {
  const ProgramTemplateExerciseModel({
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

  factory ProgramTemplateExerciseModel.fromJson(Map<String, dynamic> json) {
    return ProgramTemplateExerciseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      sets: json['sets'] as String,
      reps: json['reps'] as String,
      restSeconds: json['rest_seconds'] as int?,
      target: json['target'] as String?,
    );
  }
}

class ProgramTemplateDayModel {
  const ProgramTemplateDayModel({
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
  final List<ProgramTemplateExerciseModel> exercises;

  factory ProgramTemplateDayModel.fromJson(Map<String, dynamic> json) {
    return ProgramTemplateDayModel(
      id: json['id'] as int,
      dayIndex: json['day_index'] as int,
      title: json['title'] as String,
      focus: json['focus'] as String,
      notes: json['notes'] as String?,
      exercises: _parseItems(
        json['exercises'],
        ProgramTemplateExerciseModel.fromJson,
      ),
    );
  }
}

class ProgramTemplateModel {
  const ProgramTemplateModel({
    required this.id,
    required this.title,
    required this.phase,
    required this.goal,
    required this.summary,
    required this.durationWeeks,
    required this.workoutDays,
  });

  final int id;
  final String title;
  final String phase;
  final String goal;
  final String? summary;
  final int durationWeeks;
  final List<ProgramTemplateDayModel> workoutDays;

  factory ProgramTemplateModel.fromJson(Map<String, dynamic> json) {
    return ProgramTemplateModel(
      id: json['id'] as int,
      title: json['title'] as String,
      phase: json['phase'] as String,
      goal: json['goal'] as String,
      summary: json['summary'] as String?,
      durationWeeks: json['duration_weeks'] as int,
      workoutDays: _parseItems(
        json['workout_days'],
        ProgramTemplateDayModel.fromJson,
      ),
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

class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.planName,
    required this.monthlyPriceCents,
    required this.status,
    required this.startedAt,
    required this.nextInvoiceDate,
    required this.canceledAt,
    required this.notes,
  });

  final int id;
  final String planName;
  final int monthlyPriceCents;
  final String status;
  final DateTime startedAt;
  final DateTime nextInvoiceDate;
  final DateTime? canceledAt;
  final String? notes;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as int,
      planName: json['plan_name'] as String,
      monthlyPriceCents: json['monthly_price_cents'] as int,
      status: json['status'] as String,
      startedAt: _parseDate(json['started_at'] as String),
      nextInvoiceDate: _parseDate(json['next_invoice_date'] as String),
      canceledAt: _parseOptionalDate(json['canceled_at']),
      notes: json['notes'] as String?,
    );
  }

  double get monthlyPrice => monthlyPriceCents / 100;

  bool get isActiveLike => status == 'active' || status == 'trialing';

  bool get hasAccess => !const <String>{'past_due', 'paused', 'canceled'}.contains(status);
}

class MetricEntryModel {
  const MetricEntryModel({
    required this.id,
    required this.loggedAt,
    required this.bodyWeight,
    required this.squat1rm,
    required this.bench1rm,
    required this.deadlift1rm,
    required this.adherenceScore,
    required this.energyScore,
    required this.notes,
  });

  final int id;
  final DateTime loggedAt;
  final double? bodyWeight;
  final double? squat1rm;
  final double? bench1rm;
  final double? deadlift1rm;
  final int? adherenceScore;
  final int? energyScore;
  final String? notes;

  factory MetricEntryModel.fromJson(Map<String, dynamic> json) {
    return MetricEntryModel(
      id: json['id'] as int,
      loggedAt: _parseDate(json['logged_at'] as String),
      bodyWeight: (json['body_weight'] as num?)?.toDouble(),
      squat1rm: (json['squat_1rm'] as num?)?.toDouble(),
      bench1rm: (json['bench_1rm'] as num?)?.toDouble(),
      deadlift1rm: (json['deadlift_1rm'] as num?)?.toDouble(),
      adherenceScore: json['adherence_score'] as int?,
      energyScore: json['energy_score'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

class ProgressReportModel {
  const ProgressReportModel({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.summary,
    required this.bodyWeightChange,
    required this.squatGain,
    required this.benchGain,
    required this.deadliftGain,
    required this.adherenceAverage,
    required this.checkinsCompleted,
    required this.generatedAt,
  });

  final int id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String summary;
  final double? bodyWeightChange;
  final double? squatGain;
  final double? benchGain;
  final double? deadliftGain;
  final double? adherenceAverage;
  final int checkinsCompleted;
  final DateTime generatedAt;

  factory ProgressReportModel.fromJson(Map<String, dynamic> json) {
    return ProgressReportModel(
      id: json['id'] as int,
      periodStart: _parseDate(json['period_start'] as String),
      periodEnd: _parseDate(json['period_end'] as String),
      summary: json['summary'] as String,
      bodyWeightChange: (json['body_weight_change'] as num?)?.toDouble(),
      squatGain: (json['squat_gain'] as num?)?.toDouble(),
      benchGain: (json['bench_gain'] as num?)?.toDouble(),
      deadliftGain: (json['deadlift_gain'] as num?)?.toDouble(),
      adherenceAverage: (json['adherence_average'] as num?)?.toDouble(),
      checkinsCompleted: json['checkins_completed'] as int,
      generatedAt: _parseDate(json['generated_at'] as String),
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.readAt,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final String category;
  final DateTime? readAt;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String,
      readAt: _parseOptionalDate(json['read_at']),
      createdAt: _parseDate(json['created_at'] as String),
    );
  }

  bool get isRead => readAt != null;
}

class ChallengeLeaderboardEntryModel {
  const ChallengeLeaderboardEntryModel({
    required this.clientId,
    required this.clientName,
    required this.score,
    required this.displayScore,
    required this.rank,
  });

  final int clientId;
  final String clientName;
  final double score;
  final String displayScore;
  final int rank;

  factory ChallengeLeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return ChallengeLeaderboardEntryModel(
      clientId: json['client_id'] as int,
      clientName: json['client_name'] as String,
      score: (json['score'] as num).toDouble(),
      displayScore: json['display_score'] as String,
      rank: json['rank'] as int,
    );
  }
}

class ChallengeModel {
  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.metricType,
    required this.startDate,
    required this.endDate,
    required this.unitLabel,
    required this.leaderboard,
  });

  final int id;
  final String title;
  final String? description;
  final String metricType;
  final DateTime startDate;
  final DateTime endDate;
  final String? unitLabel;
  final List<ChallengeLeaderboardEntryModel> leaderboard;

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      metricType: json['metric_type'] as String,
      startDate: _parseDate(json['start_date'] as String),
      endDate: _parseDate(json['end_date'] as String),
      unitLabel: json['unit_label'] as String?,
      leaderboard: _parseItems(
        json['leaderboard'],
        ChallengeLeaderboardEntryModel.fromJson,
      ),
    );
  }
}

class FormCheckModel {
  const FormCheckModel({
    required this.id,
    required this.exerciseName,
    required this.videoUrl,
    required this.notes,
    required this.coachFeedback,
    required this.status,
    required this.reviewedAt,
    required this.submittedAt,
  });

  final int id;
  final String exerciseName;
  final String videoUrl;
  final String? notes;
  final String? coachFeedback;
  final String status;
  final DateTime? reviewedAt;
  final DateTime submittedAt;

  factory FormCheckModel.fromJson(Map<String, dynamic> json) {
    return FormCheckModel(
      id: json['id'] as int,
      exerciseName: json['exercise_name'] as String,
      videoUrl: json['video_url'] as String,
      notes: json['notes'] as String?,
      coachFeedback: json['coach_feedback'] as String?,
      status: json['status'] as String,
      reviewedAt: _parseOptionalDate(json['reviewed_at']),
      submittedAt: _parseDate(json['submitted_at'] as String),
    );
  }

  bool get isReviewed => status == 'reviewed';
}

class AdminDashboardModel {
  const AdminDashboardModel({
    required this.organizationName,
    required this.organizationLogoUrl,
    required this.totalClients,
    required this.activeClients,
    required this.invitedClients,
    required this.overdueInvoices,
    required this.activeSubscriptions,
    required this.missingCheckinNotifications,
    required this.templateCount,
    required this.latestCheckins,
    required this.recentMessages,
    required this.activeChallenge,
  });

  final String? organizationName;
  final String? organizationLogoUrl;
  final int totalClients;
  final int activeClients;
  final int invitedClients;
  final int overdueInvoices;
  final int activeSubscriptions;
  final int missingCheckinNotifications;
  final int templateCount;
  final List<CheckInItem> latestCheckins;
  final List<MessageItem> recentMessages;
  final ChallengeModel? activeChallenge;

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      organizationName: json['organization_name'] as String?,
      organizationLogoUrl: json['organization_logo_url'] as String?,
      totalClients: json['total_clients'] as int,
      activeClients: json['active_clients'] as int,
      invitedClients: json['invited_clients'] as int,
      overdueInvoices: json['overdue_invoices'] as int,
      activeSubscriptions: json['active_subscriptions'] as int,
      missingCheckinNotifications: json['missing_checkin_notifications'] as int,
      templateCount: json['template_count'] as int,
      latestCheckins: _parseItems(json['latest_checkins'], CheckInItem.fromJson),
      recentMessages: _parseItems(json['recent_messages'], MessageItem.fromJson),
      activeChallenge: json['active_challenge'] == null
          ? null
          : ChallengeModel.fromJson(
              Map<String, dynamic>.from(json['active_challenge'] as Map),
            ),
    );
  }
}

class SuperAdminDashboardModel {
  const SuperAdminDashboardModel({
    required this.totalGyms,
    required this.totalAdmins,
    required this.totalClients,
    required this.activeClients,
    required this.invitedClients,
  });

  final int totalGyms;
  final int totalAdmins;
  final int totalClients;
  final int activeClients;
  final int invitedClients;

  factory SuperAdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return SuperAdminDashboardModel(
      totalGyms: json['total_gyms'] as int,
      totalAdmins: json['total_admins'] as int,
      totalClients: json['total_clients'] as int,
      activeClients: json['active_clients'] as int,
      invitedClients: json['invited_clients'] as int,
    );
  }
}

class GymAdminSummary {
  const GymAdminSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.organizationId,
    required this.gymName,
    required this.gymLogoUrl,
    required this.activeClients,
    required this.invitedClients,
    required this.createdAt,
  });

  final int id;
  final String? fullName;
  final String email;
  final int organizationId;
  final String gymName;
  final String? gymLogoUrl;
  final int activeClients;
  final int invitedClients;
  final DateTime createdAt;

  factory GymAdminSummary.fromJson(Map<String, dynamic> json) {
    return GymAdminSummary(
      id: json['id'] as int,
      fullName: json['full_name'] as String?,
      email: json['email'] as String,
      organizationId: json['organization_id'] as int,
      gymName: json['gym_name'] as String,
      gymLogoUrl: json['gym_logo_url'] as String?,
      activeClients: json['active_clients'] as int,
      invitedClients: json['invited_clients'] as int,
      createdAt: _parseDate(json['created_at'] as String),
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
    required this.subscriptionStatus,
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
  final String? subscriptionStatus;

  factory ClientSummary.fromJson(Map<String, dynamic> json) {
    return ClientSummary(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      contactEmail: json['contact_email'] as String?,
      phone: json['phone'] as String?,
      goal: json['goal'] as String,
      status: json['status'] as String,
      inviteCode: json['invite_code'] as String,
      latestCheckinAt: _parseOptionalDate(json['latest_checkin_at']),
      invoiceStatus: json['invoice_status'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
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
    required this.subscription,
    required this.checkins,
    required this.metrics,
    required this.messages,
    required this.invoices,
    required this.latestProgressReport,
    required this.formChecks,
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
  final SubscriptionModel? subscription;
  final List<CheckInItem> checkins;
  final List<MetricEntryModel> metrics;
  final List<MessageItem> messages;
  final List<InvoiceItem> invoices;
  final ProgressReportModel? latestProgressReport;
  final List<FormCheckModel> formChecks;

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
      program: json['program'] == null
          ? null
          : ProgramModel.fromJson(Map<String, dynamic>.from(json['program'] as Map)),
      nutritionPlan: json['nutrition_plan'] == null
          ? null
          : NutritionPlanModel.fromJson(
              Map<String, dynamic>.from(json['nutrition_plan'] as Map),
            ),
      subscription: json['subscription'] == null
          ? null
          : SubscriptionModel.fromJson(
              Map<String, dynamic>.from(json['subscription'] as Map),
            ),
      checkins: _parseItems(json['checkins'], CheckInItem.fromJson),
      metrics: _parseItems(json['metrics'], MetricEntryModel.fromJson),
      messages: _parseItems(json['messages'], MessageItem.fromJson),
      invoices: _parseItems(json['invoices'], InvoiceItem.fromJson),
      latestProgressReport: json['latest_progress_report'] == null
          ? null
          : ProgressReportModel.fromJson(
              Map<String, dynamic>.from(json['latest_progress_report'] as Map),
            ),
      formChecks: _parseItems(json['form_checks'], FormCheckModel.fromJson),
    );
  }
}

class ClientDashboardModel {
  const ClientDashboardModel({
    required this.clientId,
    required this.clientName,
    required this.organizationName,
    required this.organizationLogoUrl,
    required this.goal,
    required this.status,
    required this.todayFocus,
    required this.program,
    required this.nutritionPlan,
    required this.subscription,
    required this.latestMetric,
    required this.monthlyProgressReport,
    required this.activeChallenge,
    required this.unreadNotifications,
    required this.recentCheckins,
    required this.recentMessages,
    required this.upcomingInvoices,
    required this.recentFormChecks,
  });

  final int clientId;
  final String clientName;
  final String? organizationName;
  final String? organizationLogoUrl;
  final String goal;
  final String status;
  final String? todayFocus;
  final ProgramModel? program;
  final NutritionPlanModel? nutritionPlan;
  final SubscriptionModel? subscription;
  final MetricEntryModel? latestMetric;
  final ProgressReportModel? monthlyProgressReport;
  final ChallengeModel? activeChallenge;
  final int unreadNotifications;
  final List<CheckInItem> recentCheckins;
  final List<MessageItem> recentMessages;
  final List<InvoiceItem> upcomingInvoices;
  final List<FormCheckModel> recentFormChecks;

  factory ClientDashboardModel.fromJson(Map<String, dynamic> json) {
    return ClientDashboardModel(
      clientId: json['client_id'] as int,
      clientName: json['client_name'] as String,
      organizationName: json['organization_name'] as String?,
      organizationLogoUrl: json['organization_logo_url'] as String?,
      goal: json['goal'] as String,
      status: json['status'] as String,
      todayFocus: json['today_focus'] as String?,
      program: json['program'] == null
          ? null
          : ProgramModel.fromJson(Map<String, dynamic>.from(json['program'] as Map)),
      nutritionPlan: json['nutrition_plan'] == null
          ? null
          : NutritionPlanModel.fromJson(
              Map<String, dynamic>.from(json['nutrition_plan'] as Map),
            ),
      subscription: json['subscription'] == null
          ? null
          : SubscriptionModel.fromJson(
              Map<String, dynamic>.from(json['subscription'] as Map),
            ),
      latestMetric: json['latest_metric'] == null
          ? null
          : MetricEntryModel.fromJson(
              Map<String, dynamic>.from(json['latest_metric'] as Map),
            ),
      monthlyProgressReport: json['monthly_progress_report'] == null
          ? null
          : ProgressReportModel.fromJson(
              Map<String, dynamic>.from(json['monthly_progress_report'] as Map),
            ),
      activeChallenge: json['active_challenge'] == null
          ? null
          : ChallengeModel.fromJson(
              Map<String, dynamic>.from(json['active_challenge'] as Map),
            ),
      unreadNotifications: json['unread_notifications'] as int? ?? 0,
      recentCheckins: _parseItems(json['recent_checkins'], CheckInItem.fromJson),
      recentMessages: _parseItems(json['recent_messages'], MessageItem.fromJson),
      upcomingInvoices: _parseItems(
        json['upcoming_invoices'],
        InvoiceItem.fromJson,
      ),
      recentFormChecks: _parseItems(
        json['recent_form_checks'],
        FormCheckModel.fromJson,
      ),
    );
  }
}
