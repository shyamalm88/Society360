/// Visitor Form Data Model
/// Contains all the data collected during the visitor entry wizard
class VisitorFormData {
  // Step 1: Visitor Details
  String? mobileNumber;
  String? name;

  // Step 2: Purpose
  String? purpose;

  // Step 3: Destination
  String? blockId;
  String? flatId;
  String? flatNumber;

  VisitorFormData({
    this.mobileNumber,
    this.name,
    this.purpose,
    this.blockId,
    this.flatId,
    this.flatNumber,
  });

  /// Validate if step 1 is complete
  bool get isStep1Valid {
    return mobileNumber != null &&
        mobileNumber!.length == 10 &&
        name != null &&
        name!.length >= 3;
  }

  /// Validate if step 2 is complete
  bool get isStep2Valid {
    return purpose != null && purpose!.isNotEmpty;
  }

  /// Validate if step 3 is complete
  bool get isStep3Valid {
    return blockId != null && flatId != null;
  }

  /// Validate if all steps are complete
  bool get isFormComplete {
    return isStep1Valid && isStep2Valid && isStep3Valid;
  }

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'visitor_name': name,
      'phone': '+91$mobileNumber',
      'purpose': purpose?.toLowerCase(),
      'flat_id': flatId,
      'expected_start': DateTime.now().toIso8601String(),
      'expected_end': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      // invited_by removed - backend will use req.user.id (mock guard user in development mode)
      'idempotency_key': 'guard_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Clear all data
  void clear() {
    mobileNumber = null;
    name = null;
    purpose = null;
    blockId = null;
    flatId = null;
    flatNumber = null;
  }

  VisitorFormData copyWith({
    String? mobileNumber,
    String? name,
    String? purpose,
    String? blockId,
    String? flatId,
    String? flatNumber,
  }) {
    return VisitorFormData(
      mobileNumber: mobileNumber ?? this.mobileNumber,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      blockId: blockId ?? this.blockId,
      flatId: flatId ?? this.flatId,
      flatNumber: flatNumber ?? this.flatNumber,
    );
  }
}

/// Society Structure Models
class Block {
  final String id;
  final String name;
  final List<Flat> flats;

  Block({
    required this.id,
    required this.name,
    required this.flats,
  });
}

class Flat {
  final String id;
  final String number;
  final String? residentName;

  Flat({
    required this.id,
    required this.number,
    this.residentName,
  });
}
