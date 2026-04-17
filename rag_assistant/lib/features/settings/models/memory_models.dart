class UserProfileModel {
  final String? role;
  final String? team;
  final String? responsibilities;
  final String? workingHours;
  final String? timezone;
  final String? communicationStyle;

  const UserProfileModel({
    this.role,
    this.team,
    this.responsibilities,
    this.workingHours,
    this.timezone,
    this.communicationStyle,
  });

  factory UserProfileModel.empty() => const UserProfileModel();

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      role: json['role'] as String?,
      team: json['team'] as String?,
      responsibilities: json['responsibilities'] as String?,
      workingHours: json['working_hours'] as String?,
      timezone: json['timezone'] as String?,
      communicationStyle: json['communication_style'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'team': team,
        'responsibilities': responsibilities,
        'working_hours': workingHours,
        'timezone': timezone,
        'communication_style': communicationStyle,
      };

  UserProfileModel copyWith({
    String? role,
    String? team,
    String? responsibilities,
    String? workingHours,
    String? timezone,
    String? communicationStyle,
  }) {
    return UserProfileModel(
      role: role ?? this.role,
      team: team ?? this.team,
      responsibilities: responsibilities ?? this.responsibilities,
      workingHours: workingHours ?? this.workingHours,
      timezone: timezone ?? this.timezone,
      communicationStyle: communicationStyle ?? this.communicationStyle,
    );
  }
}

class OrgContextModel {
  final String? orgName;
  final String? mission;
  final String? currentQuarter;
  final String? quarterGoals;
  final String? leadershipPriorities;
  final String? teamOkrs;

  const OrgContextModel({
    this.orgName,
    this.mission,
    this.currentQuarter,
    this.quarterGoals,
    this.leadershipPriorities,
    this.teamOkrs,
  });

  factory OrgContextModel.empty() => const OrgContextModel();

  factory OrgContextModel.fromJson(Map<String, dynamic> json) {
    return OrgContextModel(
      orgName: json['org_name'] as String?,
      mission: json['mission'] as String?,
      currentQuarter: json['current_quarter'] as String?,
      quarterGoals: json['quarter_goals'] as String?,
      leadershipPriorities: json['leadership_priorities'] as String?,
      teamOkrs: json['team_okrs'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'org_name': orgName,
        'mission': mission,
        'current_quarter': currentQuarter,
        'quarter_goals': quarterGoals,
        'leadership_priorities': leadershipPriorities,
        'team_okrs': teamOkrs,
      };

  OrgContextModel copyWith({
    String? orgName,
    String? mission,
    String? currentQuarter,
    String? quarterGoals,
    String? leadershipPriorities,
    String? teamOkrs,
  }) {
    return OrgContextModel(
      orgName: orgName ?? this.orgName,
      mission: mission ?? this.mission,
      currentQuarter: currentQuarter ?? this.currentQuarter,
      quarterGoals: quarterGoals ?? this.quarterGoals,
      leadershipPriorities: leadershipPriorities ?? this.leadershipPriorities,
      teamOkrs: teamOkrs ?? this.teamOkrs,
    );
  }
}

class MemoryFactModel {
  final String id;
  final String fact;
  final String source;
  final double confidence;
  final int accessCount;
  final DateTime createdAt;
  final DateTime lastAccessed;

  const MemoryFactModel({
    required this.id,
    required this.fact,
    required this.source,
    required this.confidence,
    required this.accessCount,
    required this.createdAt,
    required this.lastAccessed,
  });

  factory MemoryFactModel.fromJson(Map<String, dynamic> json) {
    return MemoryFactModel(
      id: json['id'] as String,
      fact: json['fact'] as String,
      source: json['source'] as String? ?? 'chat',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      accessCount: (json['access_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      lastAccessed:
          DateTime.tryParse(json['last_accessed'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
