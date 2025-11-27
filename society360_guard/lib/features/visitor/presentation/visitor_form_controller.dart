import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/visitor_form_data.dart';
import '../../../data/repositories/society_repository.dart';

part 'visitor_form_controller.g.dart';

/// Visitor Form Controller
/// Manages the state of the multi-step visitor entry wizard
@riverpod
class VisitorFormController extends _$VisitorFormController {
  @override
  VisitorFormData build() {
    return VisitorFormData();
  }

  /// Update visitor details (Step 1)
  void updateVisitorDetails({
    String? mobileNumber,
    String? name,
  }) {
    state = state.copyWith(
      mobileNumber: mobileNumber ?? state.mobileNumber,
      name: name ?? state.name,
    );
  }

  /// Update purpose (Step 2)
  void updatePurpose(String purpose) {
    state = state.copyWith(purpose: purpose);
  }

  /// Update destination (Step 3)
  void updateDestination({
    String? blockId,
    String? flatId,
    String? flatNumber,
  }) {
    state = state.copyWith(
      blockId: blockId ?? state.blockId,
      flatId: flatId ?? state.flatId,
      flatNumber: flatNumber ?? state.flatNumber,
    );
  }

  /// Clear form data
  void clearForm() {
    state = VisitorFormData();
  }

  /// Submit form
  Future<bool> submitForm() async {
    if (!state.isFormComplete) {
      return false;
    }

    try {
      // Prepare the JSON payload
      final jsonPayload = state.toJson();
      print('=== Visitor Entry Submitted ===');
      print('Payload: $jsonPayload');
      print('==============================');

      // Submit to backend API
      final repo = ref.read(societyRepositoryProvider);
      final success = await repo.submitVisitor(jsonPayload);

      if (success) {
        // Clear form after successful submission
        clearForm();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Form submission error: $e');
      return false;
    }
  }
}

/// Provider for current step in the wizard
@riverpod
class CurrentStep extends _$CurrentStep {
  @override
  int build() {
    return 0;
  }

  void nextStep() {
    if (state < 3) {
      state++;
    }
  }

  void previousStep() {
    if (state > 0) {
      state--;
    }
  }

  void resetStep() {
    state = 0;
  }
}
