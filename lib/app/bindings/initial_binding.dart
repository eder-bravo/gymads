import 'package:get/get.dart';
import '../controllers/navigation_controller.dart';
import '../data/providers/storage_provider.dart';
import '../data/providers/supabase/supabase_storage_provider.dart';
import '../data/providers/supabase/supabase_api_provider.dart';
import '../data/repositories/user_repository.dart';

/// Binding inicial para registrar todas las dependencias necesarias
/// 
/// Este binding se ejecuta al inicio de la aplicación y registra todas
/// las dependencias que serán usadas en toda la aplicación
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Controladores globales
    Get.put<NavigationController>(NavigationController(), permanent: true);
    
    // Proveedores
    Get.lazyPut<StorageProvider>(() => StorageProvider(), fenix: true);
    Get.lazyPut<SupabaseStorageProvider>(() => SupabaseStorageProvider(), fenix: true);
    
    // Proveedores API específicos por tabla
    Get.lazyPut<SupabaseApiProvider>(
      () => SupabaseApiProvider(table: 'users'),
      tag: 'users_provider',
      fenix: true
    );
    
    Get.lazyPut<SupabaseApiProvider>(
      () => SupabaseApiProvider(table: 'memberships'),
      tag: 'memberships_provider',
      fenix: true
    );
    
    Get.lazyPut<SupabaseApiProvider>(
      () => SupabaseApiProvider(table: 'check_ins'),
      tag: 'check_ins_provider',
      fenix: true
    );
    
    // Repositorios globales
    Get.lazyPut<UserRepository>(
      () => UserRepository(Get.find<SupabaseApiProvider>(tag: 'users_provider')),
      fenix: true
    );
  }
}
