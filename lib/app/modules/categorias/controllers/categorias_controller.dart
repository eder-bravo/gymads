import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/services/tenant_context_service.dart';

/// Gestión de las categorías de producto del gimnasio.
///
/// Las categorías son a nivel gimnasio (compartidas entre sucursales),
/// mientras que los productos son por sucursal. Por eso el conteo de
/// productos es el de la sucursal actual.
class CategoriasController extends GetxController {
  final ProductRepository _repository = ProductRepository();

  final RxList<ProductCategory> categories = <ProductCategory>[].obs;
  final RxMap<String, int> productCounts = <String, int>{}.obs;

  // Banderas separadas: si se compartieran, guardar una categoría congelaría
  // la lista entera y al revés.
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isReordering = false.obs;

  /// Solo el dueño puede borrar (política RLS de la tabla).
  bool get isOwner => TenantContextService.to.isOwnerAdmin;

  int countFor(String categoryId) => productCounts[categoryId] ?? 0;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _repository.getAllCategories(),
        _repository.countProductsByCategory(),
      ]);
      categories.assignAll(results[0] as List<ProductCategory>);
      productCounts.assignAll(results[1] as Map<String, int>);
    } catch (e) {
      AppLogger.error('CategoriasController', 'Error al cargar categorías', e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Crea una categoría y la devuelve, o null si falló (ya se avisó al
  /// usuario). El llamador la usa para autoseleccionarla.
  Future<ProductCategory?> create({
    required String name,
    required String description,
    required String icon,
  }) async {
    if (isSaving.value) return null;
    isSaving.value = true;
    try {
      final created = await _repository.createCategory(ProductCategory(
        id: '',
        name: name.trim(),
        description: description.trim(),
        icon: icon,
        // Al final de la lista.
        sortOrder: categories.length + 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      categories.add(created);
      _sort();
      SnackbarHelper.success('Listo', 'Categoría creada');
      return created;
    } on CategoryException catch (e) {
      SnackbarHelper.error('No se pudo crear', e.message());
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  /// Se llama `edit` y no `update` porque `GetxController` ya define `update`.
  Future<bool> edit(
    ProductCategory original, {
    required String name,
    required String description,
    required String icon,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final saved = await _repository.updateCategory(original.copyWith(
        name: name.trim(),
        description: description.trim(),
        icon: icon,
      ));
      _replace(saved);
      SnackbarHelper.success('Listo', 'Categoría actualizada');
      return true;
    } on CategoryException catch (e) {
      SnackbarHelper.error('No se pudo guardar', e.message());
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Desactivar es la alternativa segura a borrar: deja de ofrecerse al crear
  /// productos, pero los que ya la usan conservan el nombre.
  Future<void> toggleActive(ProductCategory category) async {
    isSaving.value = true;
    try {
      final saved = await _repository
          .updateCategory(category.copyWith(isActive: !category.isActive));
      _replace(saved);
      SnackbarHelper.success(
        'Listo',
        saved.isActive ? 'Categoría reactivada' : 'Categoría desactivada',
      );
    } on CategoryException catch (e) {
      SnackbarHelper.error('No se pudo guardar', e.message());
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> delete(ProductCategory category) async {
    isSaving.value = true;
    try {
      await _repository.deleteCategory(category.id);
      categories.removeWhere((c) => c.id == category.id);
      productCounts.remove(category.id);
      SnackbarHelper.success('Listo', 'Categoría eliminada');
    } on CategoryException catch (e) {
      // El conteo del cliente puede estar desfasado (otro dispositivo pudo
      // añadir un producto), así que la base es la que manda.
      SnackbarHelper.error(
        'No se pudo eliminar',
        e.message(
          categoryName: category.name,
          productCount: countFor(category.id),
        ),
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (isReordering.value) return;
    // ReorderableListView cuenta el destino con el elemento aún en su sitio.
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final previous = List<ProductCategory>.from(categories);
    final moved = categories.removeAt(oldIndex);
    categories.insert(newIndex, moved);

    isReordering.value = true;
    try {
      await _repository.reorderCategories(categories.map((c) => c.id).toList());
    } catch (e) {
      // Se revierte para no mentir sobre lo que quedó guardado.
      categories.assignAll(previous);
      SnackbarHelper.error('Error', 'No se pudo guardar el nuevo orden');
    } finally {
      isReordering.value = false;
    }
  }

  void _replace(ProductCategory saved) {
    final index = categories.indexWhere((c) => c.id == saved.id);
    if (index != -1) categories[index] = saved;
    _sort();
  }

  void _sort() {
    categories.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    categories.refresh();
  }
}
