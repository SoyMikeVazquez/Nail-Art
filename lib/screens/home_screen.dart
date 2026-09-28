import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import '../widgets/banner_section.dart';
import '../widgets/branches_section.dart';
import '../widgets/products_section.dart';
import '../widgets/services_section.dart';
import '../widgets/background_scaffold.dart';
import '../widgets/universal_footer_buttons.dart';
import 'login_screen.dart';
import 'home_logged_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showContactBtn = false;
  final String _contactPhone = '+521234567890';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<SessionProvider>(context, listen: false).checkAndRegisterVisit();
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final double progress =
          _scrollController.position.pixels /
          _scrollController.position.maxScrollExtent;
      if (progress >= 0.25 && !_showContactBtn) {
        setState(() => _showContactBtn = true);
      } else if (progress < 0.25 && _showContactBtn) {
        setState(() => _showContactBtn = false);
      }
    }
  }

  Future<void> _makeCall() async {
    final Uri url = Uri.parse('tel:$_contactPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede iniciar la llamada')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // iOS cleaner look
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.person, color: Colors.black),
              label: const Text(
                'Ingresar',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BannerSection(),
              const SizedBox(height: 20),
              const _DemoSelectorSection(),
              const SizedBox(height: 20),
              const BranchesSection(),
              const SizedBox(height: 20),
              const ProductsSection(),
              const SizedBox(height: 20),
              const ServicesSection(),
              const SizedBox(height: 40),
              const UniversalFooterButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: _showContactBtn
          ? FloatingActionButton.extended(
              onPressed: _makeCall,
              backgroundColor: Colors.black,
              icon: const Icon(Icons.phone, color: Colors.white),
              label: const Text(
                'Llámanos',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}

class _DemoSelectorSection extends StatelessWidget {
  const _DemoSelectorSection();

  void _loginAsDemo(BuildContext context, String role) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (role == 'cliente') {
      session.setClientSession(
        userId: 'demo-client-id',
        name: 'Demo Cliente',
        email: 'cliente@ailartmexico.io',
        branch: 'Sucursal Central',
      );
    } else if (role == 'recepcionista') {
      session.setStaffSession(
        userId: 'demo-recepcion-id',
        name: 'Demo Recepción',
        email: 'recepcion@ailartmexico.io',
        isRecepcion: true,
      );
    } else if (role == 'personal') {
      session.setStaffSession(
        userId: 'demo-personal-id',
        name: 'Demo Personal',
        email: 'personal@ailartmexico.io',
        isPersonal: true,
      );
    } else if (role == 'admin') {
      session.setStaffSession(
        userId: 'demo-super-admin-id',
        name: 'Demo Administrador',
        email: 'admin@ailartmexico.io',
        isAdmin: true,
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeLoggedScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Modo Demostración',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Explora cómo funciona Nail Art desde la perspectiva de cada rol del negocio sin necesidad de registrarte.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttonWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildRoleButton(
                    context: context,
                    width: buttonWidth,
                    label: 'Cliente',
                    subtitle: 'Ver cita y fidelidad',
                    icon: Icons.person_outline,
                    onTap: () => _loginAsDemo(context, 'cliente'),
                  ),
                  _buildRoleButton(
                    context: context,
                    width: buttonWidth,
                    label: 'Recepción',
                    subtitle: 'Control de citas/ventas',
                    icon: Icons.support_agent_rounded,
                    onTap: () => _loginAsDemo(context, 'recepcionista'),
                  ),
                  _buildRoleButton(
                    context: context,
                    width: buttonWidth,
                    label: 'Personal',
                    subtitle: 'Agenda e ingresos',
                    icon: Icons.cut_rounded,
                    onTap: () => _loginAsDemo(context, 'personal'),
                  ),
                  _buildRoleButton(
                    context: context,
                    width: buttonWidth,
                    label: 'Super Admin',
                    subtitle: 'Métricas y finanzas',
                    icon: Icons.admin_panel_settings_rounded,
                    onTap: () => _loginAsDemo(context, 'admin'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required double width,
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
