import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

class DailyAuxiliaryService {
  DailyAuxiliaryService._();
  static final instance = DailyAuxiliaryService._();

  String _getTodayString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<String> _getKeyPrefix() async {
    final user = await AuthService.instance.getCurrentUser();
    final id = user?.id ?? 0;
    return 'tech_${id}_daily_aux';
  }

  /// Verifica si el técnico ya definió su auxiliar (o indicó que trabaja solo) para la jornada de hoy.
  Future<bool> isSetForToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = await _getKeyPrefix();
      final savedDate = prefs.getString('${prefix}_date');
      final isSet = prefs.getBool('${prefix}_is_set') ?? false;
      return isSet && savedDate == _getTodayString();
    } catch (e) {
      debugPrint('Error comprobando auxiliar del día: $e');
      return false;
    }
  }

  /// Retorna los datos del auxiliar guardados para hoy.
  /// Si id == null significa que trabaja solo / sin auxiliar.
  /// Retorna null si aún no se ha definido para hoy.
  Future<Map<String, dynamic>?> getDailyAuxiliary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = await _getKeyPrefix();
      final savedDate = prefs.getString('${prefix}_date');
      final isSet = prefs.getBool('${prefix}_is_set') ?? false;

      if (!isSet || savedDate != _getTodayString()) {
        return null;
      }

      final id = prefs.getInt('${prefix}_id');
      final name = prefs.getString('${prefix}_name');
      return {
        'id': id,
        'name': name ?? (id != null ? 'Técnico #$id' : 'Sin auxiliar (Solo)'),
        'is_solo': id == null,
      };
    } catch (e) {
      debugPrint('Error obteniendo auxiliar del día: $e');
      return null;
    }
  }

  /// Guarda el auxiliar para hoy (id: null para "trabajo solo").
  Future<void> setDailyAuxiliary({int? id, String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _getKeyPrefix();
    final today = _getTodayString();

    await prefs.setString('${prefix}_date', today);
    await prefs.setBool('${prefix}_is_set', true);

    if (id != null) {
      await prefs.setInt('${prefix}_id', id);
    } else {
      await prefs.remove('${prefix}_id');
    }

    if (name != null && name.isNotEmpty) {
      await prefs.setString('${prefix}_name', name);
    } else {
      await prefs.remove('${prefix}_name');
    }
  }

  /// Obtiene la lista de técnicos de la sede (con caché local offline).
  Future<List<Map<String, dynamic>>> fetchTechnicians({String? orderNumber}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _getKeyPrefix();

    try {
      final remoteTechs = await ApiService().getAuxiliaryTechnicians(orderNumber);
      if (remoteTechs.isNotEmpty) {
        await prefs.setString('${prefix}_cached_techs', jsonEncode(remoteTechs));
        return remoteTechs;
      }
    } catch (e) {
      debugPrint('Fallo al obtener técnicos remotos, usando caché: $e');
    }

    // Fallback a caché local si está offline
    final cached = prefs.getString('${prefix}_cached_techs');
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (e) {
        debugPrint('Error decodificando técnicos en caché: $e');
      }
    }

    return [];
  }

  /// Asegura que el auxiliar del día esté seleccionado. Si no lo está, abre el modal.
  /// Retorna true si ya estaba configurado o si el usuario completó la selección.
  Future<bool> ensureDailyAuxiliarySet(
    BuildContext context, {
    String? orderNumber,
    bool forceChange = false,
    bool canDismissWithoutChoice = true,
  }) async {
    if (!forceChange && await isSetForToday()) {
      return true;
    }

    final result = await showDailyAuxiliaryPicker(
      context,
      orderNumber: orderNumber,
      canDismissWithoutChoice: canDismissWithoutChoice,
    );

    return result != null;
  }

  /// Muestra el modal para seleccionar el auxiliar del día.
  /// Retorna `{ 'id': int?, 'name': String? }` si seleccionó, o null si canceló.
  Future<Map<String, dynamic>?> showDailyAuxiliaryPicker(
    BuildContext context, {
    String? orderNumber,
    int? currentAuxiliaryId,
    bool canDismissWithoutChoice = true,
  }) async {
    final technicians = await fetchTechnicians(orderNumber: orderNumber);

    if (!context.mounted) return null;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      isDismissible: canDismissWithoutChoice,
      enableDrag: canDismissWithoutChoice,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return WillPopScope(
          onWillPop: () async => canDismissWithoutChoice,
          child: StatefulBuilder(
            builder: (modalCtx, setModalState) {
              final filtered = technicians.where((t) {
                final name = (t['name'] ?? '').toString().toLowerCase();
                final email = (t['email'] ?? '').toString().toLowerCase();
                final q = searchQuery.toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList();

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalCtx).size.height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle superior
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Encabezado
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10447E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.people_alt, color: Color(0xFF10447E), size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Inicio de Jornada',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  '¿Con qué auxiliar trabajas hoy?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canDismissWithoutChoice)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(modalCtx),
                            ),
                        ],
                      ),
                    ),

                    // Banner informativo
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Se guardará para todas tus órdenes del día. No tendrás que seleccionarlo cada vez.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Opción de "Trabajo solo / Sin auxiliar hoy"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(modalCtx, {
                            'id': null,
                            'name': 'Sin auxiliar (Trabajo solo)',
                            'is_solo': true,
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: currentAuxiliaryId == null
                                ? const Color(0xFF10447E).withOpacity(0.08)
                                : Colors.grey.shade50,
                            border: Border.all(
                              color: currentAuxiliaryId == null
                                  ? const Color(0xFF10447E)
                                  : Colors.grey.shade300,
                              width: currentAuxiliaryId == null ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: currentAuxiliaryId == null
                                    ? const Color(0xFF10447E)
                                    : Colors.grey.shade400,
                                radius: 18,
                                child: const Icon(Icons.person, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Trabajo Solo / Sin Auxiliar',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: currentAuxiliaryId == null
                                            ? const Color(0xFF10447E)
                                            : Colors.grey.shade900,
                                      ),
                                    ),
                                    Text(
                                      'Atenderé las órdenes sin compañero hoy',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              if (currentAuxiliaryId == null)
                                const Icon(Icons.check_circle, color: Color(0xFF10447E)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Buscador
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar técnico de tu sede...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setModalState(() => searchQuery = ''),
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) => setModalState(() => searchQuery = val),
                      ),
                    ),

                    const Divider(height: 12),

                    // Lista de técnicos
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_off, size: 40, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      technicians.isEmpty
                                          ? 'No se encontraron otros técnicos en tu sede'
                                          : 'Sin resultados para la búsqueda',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (listCtx, idx) {
                                final tech = filtered[idx];
                                final id = tech['id'] as int?;
                                final name = tech['name']?.toString() ?? 'Técnico';
                                final email = tech['email']?.toString() ?? '';
                                final isSelected = id == currentAuxiliaryId;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? const Color(0xFF10447E)
                                        : Colors.grey.shade200,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF10447E),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF10447E) : Colors.black87,
                                    ),
                                  ),
                                  subtitle: email.isNotEmpty
                                      ? Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Color(0xFF10447E))
                                      : null,
                                  onTap: () {
                                    Navigator.pop(modalCtx, {
                                      'id': id,
                                      'name': name,
                                      'is_solo': false,
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      await setDailyAuxiliary(
        id: result['id'],
        name: result['name'],
      );

      if (context.mounted) {
        final label = result['id'] != null ? result['name'] : 'Trabajo solo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auxiliar del día registrado: $label'),
            backgroundColor: const Color(0xFF10447E),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    return result;
  }
}
