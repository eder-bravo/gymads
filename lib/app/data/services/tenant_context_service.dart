import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:get_storage/get_storage.dart';
import '../models/staff_profile_model.dart';
import 'gym_settings_service.dart';

/// Service that manages the current tenant context (gym/branch)
///
/// This service is responsible for:
/// - Storing the current staff profile and tenant info
/// - Providing easy access to gym_id and branch_id
/// - Persisting context locally for offline access
class TenantContextService extends GetxService {
  static TenantContextService get to => Get.find<TenantContextService>();

  final _storage = GetStorage();
  static const String _profileKey = 'staff_profile';

  final Rx<StaffProfileModel?> _staffProfile = Rx(null);

  // ============================================
  // EXPOSED GETTERS
  // ============================================

  /// Current gym ID
  String? get currentGymId => _staffProfile.value?.gymId;

  /// Current branch ID
  String? get currentBranchId => _staffProfile.value?.branchId;

  /// Current user role ('owner_admin' or 'branch_staff')
  String? get currentRole => _staffProfile.value?.role;

  /// Display name of current staff
  String? get displayName => _staffProfile.value?.displayName;

  /// First name only (for welcome greeting)
  String? get firstName => _staffProfile.value?.firstName;

  /// User ID of current staff
  String? get userId => _staffProfile.value?.userId;

  /// Check if user is authenticated (has valid staff profile)
  bool get isAuthenticated => _staffProfile.value != null;

  /// Check if current user is owner_admin
  bool get isOwnerAdmin => _staffProfile.value?.isOwnerAdmin ?? false;

  /// Check if current user is branch_staff
  bool get isBranchStaff => _staffProfile.value?.isBranchStaff ?? false;

  /// Gym name
  String? get gymName => _staffProfile.value?.gymName;

  /// Fecha de creación de la cuenta (gimnasio). Si no está disponible la
  /// fecha del gimnasio, se usa la del perfil de staff como respaldo.
  DateTime? get accountCreatedAt =>
      _staffProfile.value?.gymCreatedAt ?? _staffProfile.value?.createdAt;

  /// Get the full staff profile
  StaffProfileModel? get staffProfile => _staffProfile.value;

  /// Reactive staff profile (for UI binding)
  Rx<StaffProfileModel?> get staffProfileRx => _staffProfile;

  // ============================================
  // METHODS
  // ============================================

  /// Initialize the service
  Future<TenantContextService> init() async {
    await loadCachedProfile();
    return this;
  }

  /// Set the current staff profile (called after successful login)
  Future<void> setProfile(StaffProfileModel profile) async {
    _staffProfile.value = profile;
    // Cache for offline access
    await _storage.write(_profileKey, profile.toJson());
  }

  /// Clear the current profile (called on logout)
  Future<void> clearProfile() async {
    _staffProfile.value = null;
    await _storage.remove(_profileKey);

    // Punto único por el que pasan todos los cierres de sesión: si no se
    // limpia aquí, el siguiente gimnasio heredaría el horario y el modo de
    // salidas del anterior.
    if (Get.isRegistered<GymSettingsService>()) {
      GymSettingsService.to.clear();
    }
  }

  /// Load cached profile from local storage
  Future<StaffProfileModel?> loadCachedProfile() async {
    try {
      final cached = _storage.read(_profileKey);
      if (cached != null && cached is Map<String, dynamic>) {
        _staffProfile.value = StaffProfileModel.fromJson(cached);
      }
    } catch (e) {
      AppLogger.warning('TenantContextService', 'Error loading cached profile');
      await clearProfile();
    }
    return _staffProfile.value;
  }

  /// Check if cached profile exists
  bool get hasCachedProfile {
    return _storage.hasData(_profileKey);
  }

  @override
  void onClose() {
    _staffProfile.close();
    super.onClose();
  }
}
