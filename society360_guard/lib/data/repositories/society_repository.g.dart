// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'society_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$societyRepositoryHash() => r'25d682b5dacb87ec7bc138e15eee92481edc3418';

/// Riverpod provider for SocietyRepository
///
/// Copied from [societyRepository].
@ProviderFor(societyRepository)
final societyRepositoryProvider =
    AutoDisposeProvider<SocietyRepository>.internal(
      societyRepository,
      name: r'societyRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$societyRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SocietyRepositoryRef = AutoDisposeProviderRef<SocietyRepository>;
String _$blocksHash() => r'dd3bfafc200d922b1978f1b4ab0db8a517c9a079';

/// Provider to fetch all blocks
///
/// Copied from [blocks].
@ProviderFor(blocks)
final blocksProvider = AutoDisposeFutureProvider<List<Block>>.internal(
  blocks,
  name: r'blocksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$blocksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BlocksRef = AutoDisposeFutureProviderRef<List<Block>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
