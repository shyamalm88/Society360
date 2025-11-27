/// Metadata Models for Onboarding Cascading Dropdowns

class City {
  final String id;
  final String name;
  final String state;

  const City({
    required this.id,
    required this.name,
    required this.state,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Society {
  final String id;
  final String name;
  final String address;
  final String cityId;
  final int totalBlocks;
  final int totalFlats;

  const Society({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    required this.totalBlocks,
    required this.totalFlats,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Society && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Block {
  final String id;
  final String name;
  final String societyId;
  final int totalFlats;
  final int floors;

  const Block({
    required this.id,
    required this.name,
    required this.societyId,
    required this.totalFlats,
    required this.floors,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Flat {
  final String id;
  final String number;
  final String blockId;
  final int floor;
  final String type; // 1BHK, 2BHK, 3BHK, etc.
  final bool isOccupied;
  final String? ownerName;

  const Flat({
    required this.id,
    required this.number,
    required this.blockId,
    required this.floor,
    required this.type,
    this.isOccupied = false,
    this.ownerName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flat && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// User Profile Model
class ResidentProfile {
  final String userId;
  final String name;
  final String phone;
  final String email;
  final String flatId;
  final String flatNumber;
  final String blockName;
  final String societyName;
  final String cityName;
  final DateTime joinedDate;
  final bool isOwner;
  final String? profileImageUrl;

  const ResidentProfile({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
    required this.flatId,
    required this.flatNumber,
    required this.blockName,
    required this.societyName,
    required this.cityName,
    required this.joinedDate,
    this.isOwner = true,
    this.profileImageUrl,
  });
}

/// Visitor Model
class Visitor {
  final String id;
  final String name;
  final String phone;
  final String? vehicleNumber;
  final String purpose;
  final DateTime expectedArrival;
  final DateTime? expectedDeparture;
  final String status; // pending, approved, rejected, completed
  final DateTime createdAt;
  final String? guardNote;
  final String? qrCode;
  final DateTime? approvalDeadline;

  // Flat context information
  final String? flatId;
  final String? flatNumber;
  final String? blockName;
  final String? complexName;

  const Visitor({
    required this.id,
    required this.name,
    required this.phone,
    this.vehicleNumber,
    required this.purpose,
    required this.expectedArrival,
    this.expectedDeparture,
    required this.status,
    required this.createdAt,
    this.guardNote,
    this.qrCode,
    this.approvalDeadline,
    this.flatId,
    this.flatNumber,
    this.blockName,
    this.complexName,
  });

  /// Create Visitor from JSON (backend API response)
  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      id: json['id'] as String,
      name: json['visitor_name'] as String,
      phone: json['phone'] as String,
      vehicleNumber: json['vehicle_no'] as String?,
      purpose: json['purpose'] as String? ?? '',
      expectedArrival: DateTime.parse(json['expected_start'] as String),
      expectedDeparture: json['expected_end'] != null
          ? DateTime.parse(json['expected_end'] as String)
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      guardNote: json['guard_note'] as String?,
      qrCode: json['qr_code'] as String?,
      approvalDeadline: json['approval_deadline'] != null
          ? DateTime.parse(json['approval_deadline'] as String)
          : null,
      flatId: json['flat_id'] as String?,
      flatNumber: json['flat_number'] as String?,
      blockName: json['block_name'] as String?,
      complexName: json['complex_name'] as String?,
    );
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_name': name,
      'phone': phone,
      'vehicle_no': vehicleNumber,
      'purpose': purpose,
      'expected_start': expectedArrival.toIso8601String(),
      'expected_end': expectedDeparture?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'guard_note': guardNote,
      'qr_code': qrCode,
      'approval_deadline': approvalDeadline?.toIso8601String(),
      'flat_id': flatId,
      'flat_number': flatNumber,
      'block_name': blockName,
      'complex_name': complexName,
    };
  }

  /// Get display address for the visitor request
  String get displayAddress {
    final parts = <String>[];
    if (flatNumber != null) parts.add('Flat $flatNumber');
    if (blockName != null) parts.add(blockName!);
    if (complexName != null) parts.add(complexName!);
    return parts.join(', ');
  }

  /// Check if approval is about to expire (within 1 minute)
  bool get isApprovalExpiring {
    if (approvalDeadline == null) return false;
    final now = DateTime.now();
    final timeLeft = approvalDeadline!.difference(now);
    return timeLeft.inMinutes <= 1 && timeLeft.inSeconds > 0;
  }

  /// Get time remaining for approval in human-readable format
  String get timeRemaining {
    if (approvalDeadline == null) return '';
    final now = DateTime.now();
    final timeLeft = approvalDeadline!.difference(now);

    if (timeLeft.isNegative) return 'Expired';
    if (timeLeft.inMinutes < 1) return '${timeLeft.inSeconds}s left';
    return '${timeLeft.inMinutes}m ${timeLeft.inSeconds % 60}s left';
  }
}

/// Guest Access Model (for pre-approved visitors)
class GuestAccess {
  final String id;
  final String guestName;
  final String guestPhone;
  final String purpose;
  final DateTime validFrom;
  final DateTime validUntil;
  final String qrCode;
  final bool isActive;
  final int usageCount;
  final int? maxUsage;

  const GuestAccess({
    required this.id,
    required this.guestName,
    required this.guestPhone,
    required this.purpose,
    required this.validFrom,
    required this.validUntil,
    required this.qrCode,
    this.isActive = true,
    this.usageCount = 0,
    this.maxUsage,
  });
}
