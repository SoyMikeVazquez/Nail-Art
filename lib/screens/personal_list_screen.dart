import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_staff_screen.dart';

class PersonalListScreen extends StatefulWidget {
  const PersonalListScreen({super.key});

  @override
  State<PersonalListScreen> createState() => _PersonalListScreenState();
}

class _PersonalListScreenState extends State<PersonalListScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Personal')
          .select()
          .order('nombre', ascending: true);
      setState(() => _staffList = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar personal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStaff(String? userId) async {
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de usuario inválido para eliminar.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Personal'),
        content: const Text('¿Estás seguro de que deseas eliminar este miembro del personal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Delete using the main relationship column 'userID' instead of redundant 'id'
      await _supabase.from('Personal').delete().eq('userID', userId);
      // Clean up the users table account as well
      await _supabase.from('users').delete().eq('IDUser', userId);
      _fetchStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _fetchStaff,
              color: Colors.black,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Registrado',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Gestiona los miembros de tu equipo',
                                style: TextStyle(color: Colors.black54, fontSize: 14),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddStaffScreen()),
                              ).then((_) => _fetchStaff());
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_staffList.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No hay personal registrado')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final staff = _staffList[index];
                            return _StaffCard(
                              staff: staff,
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddStaffScreen(editStaff: staff),
                                  ),
                                ).then((_) => _fetchStaff());
                              },
                              onDelete: () => _deleteStaff(staff['userID']),
                            );
                          },
                          childCount: _staffList.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCard({required this.staff, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = staff['foto_perfil'] != null && staff['foto_perfil'].toString().isNotEmpty;
    final mostrarFoto = staff['mostrar_foto'] ?? true;
    final sucursal = staff['sucursal'] ?? 'Sin Sucursal';
    final hasCert = staff['tiene_certificado'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile image
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 70,
                height: 70,
                color: Colors.grey[100],
                child: (hasPhoto && mostrarFoto)
                    ? Image.network(staff['foto_perfil'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _iconPlaceholder())
                    : _iconPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff['nombre'] ?? 'Sin Nombre',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        sucursal,
                        style: const TextStyle(fontSize: 13, color: Colors.black45),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                   Row(
                     children: [
                       if (hasCert)
                         _badge('Certificado', Colors.blue.withOpacity(0.1), Colors.blue[700]!),
                       if (hasCert) const SizedBox(width: 6),
                       _badge(staff['TipoPersonal'] ?? 'Personal', Colors.black.withOpacity(0.05), Colors.black54),
                     ],
                   ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _iconPlaceholder() => const Icon(Icons.person_outline, size: 30, color: Colors.black26);
}
