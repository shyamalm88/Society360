// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visitor_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$visitorFormControllerHash() =>
    r'4f5d2838be4d87e84fc10792cf00aea5b38387ce';

/// Visitor Form Controller
/// Manages the state of the multi-step visitor entry wizard
///
/// Copied from [VisitorFormController].
@ProviderFor(VisitorFormController)
final visitorFormControllerProvider =
    AutoDisposeNotifierProvider<
      VisitorFormController,
      VisitorFormData
    >.internal(
      VisitorFormController.new,
      name: r'visitorFormControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visitorFormControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$VisitorFormController = AutoDisposeNotifier<VisitorFormData>;
String _$currentStepHash() => r'af0a5e80f575e16c028072f241e78ad02128a2a3';

/// Provider for current step in the wizard
///
/// Copied from [CurrentStep].
@ProviderFor(CurrentStep)
final currentStepProvider =
    AutoDisposeNotifierProvider<CurrentStep, int>.internal(
      CurrentStep.new,
      name: r'currentStepProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentStepHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentStep = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
