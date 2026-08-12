class SystemUser {
  final String uid;
  final String email;
  final String username;
  final String name;
  final String role;
  final String createdAt;
  final bool isOnline;
  final bool canViewCustomers;

  SystemUser({
    required this.uid,
    required this.email,
    required this.username,
    required this.name,
    required this.role,
    required this.createdAt,
    this.isOnline = false,
    this.canViewCustomers = true,
  });

  factory SystemUser.fromJson(Map<String, dynamic> json) {
    return SystemUser(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
      canViewCustomers: json['canViewCustomers'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'name': name,
      'role': role,
      'created_at': createdAt,
      'canViewCustomers': canViewCustomers,
    };
  }
}

class Attachment {
  final String name;
  final String url;
  final String size;
  final String uploadedAt;

  Attachment({
    required this.name,
    required this.url,
    required this.size,
    required this.uploadedAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      size: json['size'] ?? '',
      uploadedAt: json['uploadedAt'] ?? json['uploaded_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'size': size,
      'uploadedAt': uploadedAt,
    };
  }
}

class Customer {
  final String id;
  final int customerNumber;
  final String name;
  final String phone;
  final String? email;
  final String service;
  final String status;
  final String? notes;
  final String receptionistId;
  final String receptionistName;
  final List<Attachment> attachments;
  final String? caseType;
  final String? assignedLawyerId;
  final String? assignedLawyerName;
  final String? priority;
  final double? estimatedFee;
  final String? referralSource;
  final String createdAt;
  final String updatedAt;

  Customer({
    required this.id,
    required this.customerNumber,
    required this.name,
    required this.phone,
    this.email,
    required this.service,
    required this.status,
    this.notes,
    required this.receptionistId,
    required this.receptionistName,
    required this.attachments,
    this.caseType,
    this.assignedLawyerId,
    this.assignedLawyerName,
    this.priority,
    this.estimatedFee,
    this.referralSource,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    var attachmentsList = json['attachments'] as List? ?? [];
    List<Attachment> parsedAttachments = attachmentsList.map((i) => Attachment.fromJson(i)).toList();

    return Customer(
      id: json['id'] ?? '',
      customerNumber: json['customerNumber'] ?? json['customer_number'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      service: json['service'] ?? '',
      status: json['status'] ?? '',
      notes: json['notes'],
      receptionistId: json['receptionistId'] ?? json['receptionist_id'] ?? '',
      receptionistName: json['receptionistName'] ?? json['receptionist_name'] ?? '',
      attachments: parsedAttachments,
      caseType: json['caseType'] ?? json['case_type'],
      assignedLawyerId: json['assignedLawyerId'] ?? json['assigned_lawyer_id'],
      assignedLawyerName: json['assignedLawyerName'] ?? json['assigned_lawyer_name'],
      priority: json['priority'],
      estimatedFee: json['estimatedFee'] != null ? double.tryParse(json['estimatedFee'].toString()) : null,
      referralSource: json['referralSource'] ?? json['referral_source'],
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      updatedAt: json['updatedAt'] ?? json['updated_at'] ?? '',
    );
  }
}

class Case {
  final String id;
  final String caseNumber;
  final String title;
  final String customerId;
  final String customerName;
  final String description;
  final String status;
  final String? priority;
  final String archivedById;
  final String archivedByName;
  final String court;
  final String caseType;
  final String? hearingDate;
  final String? lawyerId;
  final String? lawyerName;
  final String? traineeId;
  final String? traineeName;
  final String? traineeAccess;
  final List<String> actionHistory;
  final List<String> notesHistory;
  final List<Attachment> attachments;
  final double? estimatedFee;
  final String createdAt;
  final String updatedAt;
  final String? ruling;
  final String? clientType;

  Case({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.customerId,
    required this.customerName,
    required this.description,
    required this.status,
    this.priority,
    required this.archivedById,
    required this.archivedByName,
    required this.court,
    required this.caseType,
    this.hearingDate,
    this.lawyerId,
    this.lawyerName,
    this.traineeId,
    this.traineeName,
    this.traineeAccess,
    required this.actionHistory,
    required this.notesHistory,
    required this.attachments,
    this.estimatedFee,
    required this.createdAt,
    required this.updatedAt,
    this.ruling,
    this.clientType,
  });

  factory Case.fromJson(Map<String, dynamic> json) {
    var actionsList = json['actionHistory'] as List? ?? [];
    List<String> parsedActions = actionsList.map((i) => i.toString()).toList();

    var notesList = json['notesHistory'] as List? ?? [];
    List<String> parsedNotes = notesList.map((i) => i.toString()).toList();

    var attachmentsList = json['attachments'] as List? ?? [];
    List<Attachment> parsedAttachments = attachmentsList.map((i) => Attachment.fromJson(i)).toList();

    return Case(
      id: json['id'] ?? '',
      caseNumber: json['caseNumber'] ?? json['case_number'] ?? '',
      title: json['title'] ?? '',
      customerId: json['customerId'] ?? json['customer_id'] ?? '',
      customerName: json['customerName'] ?? json['customer_name'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      priority: json['priority'],
      archivedById: json['archivedById'] ?? json['archived_by_id'] ?? '',
      archivedByName: json['archivedByName'] ?? json['archived_by_name'] ?? '',
      court: json['court'] ?? '',
      caseType: json['caseType'] ?? json['case_type'] ?? '',
      hearingDate: json['hearingDate'] ?? json['hearing_date'],
      lawyerId: json['lawyerId'] ?? json['lawyer_id'],
      lawyerName: json['lawyerName'] ?? json['lawyer_name'],
      traineeId: json['traineeId'] ?? json['trainee_id'],
      traineeName: json['traineeName'] ?? json['trainee_name'],
      traineeAccess: json['traineeAccess'] ?? json['trainee_access'] ?? 'none',
      actionHistory: parsedActions,
      notesHistory: parsedNotes,
      attachments: parsedAttachments,
      estimatedFee: json['estimatedFee'] != null ? double.tryParse(json['estimatedFee'].toString()) : null,
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      updatedAt: json['updatedAt'] ?? json['updated_at'] ?? '',
      ruling: json['ruling'],
      clientType: json['clientType'] ?? json['client_type'] ?? 'موكّل',
    );
  }
}

class Appointment {
  final String id;
  final String caseId;
  final String? caseNumber;
  final String? caseTitle;
  final String title;
  final String court;
  final String date;
  final String lawyerId;
  final String? lawyerName;
  final String? notes;
  final String status;
  final bool requiresReply;
  final String? clientName;
  final String? clientRole;
  final String? opposingName;
  final String? opposingRole;
  final String? caseSubject;
  final String? postponeReason;
  final String? sessionResult;
  final String? deedNumber;
  final String? deedDate;
  final String? deedCourt;
  final String? deedObjectionDeadline;
  final String createdAt;

  Appointment({
    required this.id,
    required this.caseId,
    this.caseNumber,
    this.caseTitle,
    required this.title,
    required this.court,
    required this.date,
    required this.lawyerId,
    this.lawyerName,
    this.notes,
    required this.status,
    this.requiresReply = false,
    this.clientName,
    this.clientRole,
    this.opposingName,
    this.opposingRole,
    this.caseSubject,
    this.postponeReason,
    this.sessionResult,
    this.deedNumber,
    this.deedDate,
    this.deedCourt,
    this.deedObjectionDeadline,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      caseId: json['caseId'] ?? json['case_id'] ?? '',
      caseNumber: json['caseNumber'] ?? json['case_number'],
      caseTitle: json['caseTitle'] ?? json['case_title'],
      title: json['title'] ?? '',
      court: json['court'] ?? '',
      date: json['date'] ?? json['date_time'] ?? '',
      lawyerId: json['lawyerId'] ?? json['lawyer_id'] ?? '',
      lawyerName: json['lawyerName'] ?? json['lawyer_name'],
      notes: json['notes'],
      status: json['status'] ?? '',
      requiresReply: json['requiresReply'] ?? json['requires_reply'] ?? false,
      clientName: json['clientName'] ?? json['client_name'],
      clientRole: json['clientRole'] ?? json['client_role'],
      opposingName: json['opposingName'] ?? json['opposing_name'],
      opposingRole: json['opposingRole'] ?? json['opposing_role'],
      caseSubject: json['caseSubject'] ?? json['case_subject'],
      postponeReason: json['postponeReason'] ?? json['postpone_reason'],
      sessionResult: json['sessionResult'] ?? json['session_result'],
      deedNumber: json['deedNumber'] ?? json['deed_number'],
      deedDate: json['deedDate'] ?? json['deed_date'],
      deedCourt: json['deedCourt'] ?? json['deed_court'],
      deedObjectionDeadline: json['deedObjectionDeadline'] ?? json['deed_objection_deadline'],
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
    );
  }

}

class ChatRoomParticipant {
  final String id;
  final String name;
  final String role;

  ChatRoomParticipant({required this.id, required this.name, required this.role});

  factory ChatRoomParticipant.fromJson(Map<String, dynamic> json) {
    return ChatRoomParticipant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class ChatRoom {
  final String id;
  final String type;
  final String? name;
  final List<String> participantIds;
  final List<ChatRoomParticipant>? participants;
  final String createdAt;
  final String lastMessageAt;

  ChatRoom({
    required this.id,
    required this.type,
    this.name,
    required this.participantIds,
    this.participants,
    required this.createdAt,
    required this.lastMessageAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    var pList = json['participantIds'] as List? ?? [];
    List<String> parsedParticipants = pList.map((i) => i.toString()).toList();

    var partsList = json['participants'] as List? ?? [];
    List<ChatRoomParticipant> parsedPartDetails = partsList.map((i) => ChatRoomParticipant.fromJson(i)).toList();

    return ChatRoom(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      name: json['name'],
      participantIds: parsedParticipants,
      participants: parsedPartDetails,
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      lastMessageAt: json['lastMessageAt'] ?? json['last_message_at'] ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String text;
  final String createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      roomId: json['roomId'] ?? json['room_id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      senderName: json['senderName'] ?? json['sender_name'] ?? '',
      text: json['text'] ?? '',
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      isRead: json['isRead'] ?? json['is_read'] ?? false,
    );
  }
}

class AuditLog {
  final String id;
  final String action;
  final String category;
  final String performedByName;
  final String performedByEmail;
  final String details;
  final String timestamp;

  AuditLog({
    required this.id,
    required this.action,
    required this.category,
    required this.performedByName,
    required this.performedByEmail,
    required this.details,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      category: json['category'] ?? 'system',
      performedByName: json['performedByName'] ?? json['performed_by_name'] ?? '',
      performedByEmail: json['performedByEmail'] ?? json['performed_by_email'] ?? '',
      details: json['details'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}
