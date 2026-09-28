import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  Chart Painter  (línea blanca sobre bg oscuro)
// ─────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels; // etiquetas para el eje X (primer y úiltimo punto)
  final TextDirection textDirection;

  _LineChartPainter(
    this.values, {
    required this.labels,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Guard: necesitamos al menos 2 puntos para trazar la línea
    if (values.isEmpty) return;

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final n = values.length;

    List<Offset> points = [];
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : (i / (n - 1)) * size.width;
      final y = maxVal > 0
          ? size.height - 20 - (values[i] / maxVal) * (size.height - 40)
          : size.height - 20;
      points.add(Offset(x, y));
    }

    // --- Gradiente de relleno bajo la línea ---
    // Usa las mismas curvas bezier que la línea para que el fill sea preciso
    if (points.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height - 20); // base izquierda
      fillPath.lineTo(points.first.dx, points.first.dy);  // sube al primer punto
      for (var i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cpX = (prev.dx + curr.dx) / 2;
        fillPath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      fillPath.lineTo(points.last.dx, size.height - 20);  // baja a base derecha
      fillPath.lineTo(points.first.dx, size.height - 20); // cierra por la base

      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
      );
      final fillPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // --- Línea principal ---
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        // Curva suave entre puntos
        final prev = points[i - 1];
        final curr = points[i];
        final cpX = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // --- Puntos en cada día ---
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (final p in points) {
      canvas.drawCircle(p, 5, dotBorderPaint);
      canvas.drawCircle(p, 3, dotPaint);
    }

    // --- Etiquetas de fecha (sólo primera y última) ---
    final labelStyle = TextStyle(
      color: Colors.white60,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    void drawLabel(String text, double x, {bool rightAlign = false}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: textDirection,
      );
      tp.layout();
      double dx = x - (rightAlign ? tp.width : 0);
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - 16));
    }

    if (n >= 1 && labels.isNotEmpty) {
      drawLabel(labels.first, 0);
    }
    if (n >= 2 && labels.length >= 2) {
      drawLabel(labels.last, size.width, rightAlign: true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class FinanzasRecepcionDashboardScreen extends StatefulWidget {
  
  const FinanzasRecepcionDashboardScreen({super.key});

  @override
  State<FinanzasRecepcionDashboardScreen> createState() =>
      _FinanzasRecepcionDashboardScreenState();
}

enum _Period { today, week, month, custom }

/// Granularidad de la gráfica según el rango de fechas
enum _ChartGranularity { daily, monthly, yearly }

/// Resultado de agrupación para la gráfica
class _ChartData {
  final List<double> values;
  final List<String> labels; // etiqueta por cada nodo
  final _ChartGranularity granularity;
  const _ChartData(this.values, this.labels, this.granularity);
}

class _FinanzasRecepcionDashboardScreenState extends State<FinanzasRecepcionDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  int _selectedTabIndex = 0; // 0 = Servicios, 1 = Productos

  double _globalServicesSum = 0.0;
  double _globalExtrasSum = 0.0;
  double _globalProductsSum = 0.0;

  late DateTime _start;
  late DateTime _end;
  _Period _activePeriod = _Period.week;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _applyPeriod(_Period.week);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Periodo ──────────────────────────────────
  void _applyPeriod(_Period period) {
    final now = DateTime.now();
    setState(() {
      _activePeriod = period;
      _end = now;
      switch (period) {
        case _Period.today:
          _start = DateTime(now.year, now.month, now.day);
          break;
        case _Period.week:
          _start = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 6));
          break;
        case _Period.month:
          _start = DateTime(now.year, now.month, 1);
          break;
        case _Period.custom:
          break; // manejado en _pickRange
      }
    });
    _fetchRecords();
  }

  // ── Data ─────────────────────────────────────
  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    _fadeCtrl.reset();
    try {
      final startStr = _start.toIso8601String();
      final endStr = _end.toIso8601String();

      final futures = await Future.wait([
        _supabase
            .from('FinanzasPersonal')
            .select()
            .eq('QuienRegistro', 'recepcion')
            .gte('fecha', startStr)
            .lte('fecha', endStr)
            .order('fecha', ascending: false),
        _supabase
            .from('OrdenesProductos')
            .select()
            .eq('QuienRegistro', 'recepcion')
            .gte('fecha', startStr)
            .lte('fecha', endStr)
            .order('fecha', ascending: false),
      ]);

      final finanzasResp = List<Map<String, dynamic>>.from(futures[0]);
      final ordenesResp = List<Map<String, dynamic>>.from(futures[1]);

      double sumServ = 0.0;
      double sumExt = 0.0;
      for (var r in finanzasResp) {
        sumServ += double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
        sumExt += double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
      }

      double sumProd = 0.0;
      for (var r in ordenesResp) {
        sumProd += double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
      }

      setState(() {
        _globalServicesSum = sumServ;
        _globalExtrasSum = sumExt;
        _globalProductsSum = sumProd;

        if (_selectedTabIndex == 0) {
          _records = finanzasResp;
        } else {
          _records = ordenesResp;
        }
      });
    } catch (e) {
      debugPrint('Error fetching finanzas: $e');
      setState(() {
        _records = [];
        _globalServicesSum = 0.0;
        _globalExtrasSum = 0.0;
        _globalProductsSum = 0.0;
      });
    } finally {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  // ── Cómputos ──────────────────────────────────
  double get _leftSum {
    if (_selectedTabIndex == 0) {
      return _globalServicesSum;
    } else {
      return _globalProductsSum;
    }
  }

  double get _totalEverything {
    return _globalServicesSum + _globalProductsSum + _globalExtrasSum;
  }

  double get _totalSum {
    double s = 0;
    for (var r in _records) {
      if (_selectedTabIndex == 0) {
        s += double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
      } else {
        s += double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
      }
    }
    return s;
  }

  double get _sumServicios {
    double s = 0;
    for (var r in _records) {
      s += double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
    }
    return s;
  }

  double get _sumMontosExtras {
    double s = 0;
    for (var r in _records) {
      s += double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
    }
    return s;
  }

  int get _totalUnidadesProductos {
    int total = 0;
    for (var r in _records) {
      final list = r['productos_detalle'] as List? ?? [];
      for (var p in list) {
        total += int.tryParse((p['cantidad'] ?? 0).toString()) ?? 0;
      }
    }
    return total;
  }

  // ── Granularidad dinámica de la gráfica ────────────
  _ChartGranularity get _granularity {
    final diff = _end.difference(_start).inDays;
    if (diff > 730) return _ChartGranularity.yearly;
    if (diff > 90) return _ChartGranularity.monthly;
    return _ChartGranularity.daily;
  }

  /// Agrupa los registros según la granularidad activa
  /// y retorna valores + etiquetas para cada nodo de la gráfica.
  _ChartData _chartDataPoints() {
    final gran = _granularity;
    switch (gran) {
      case _ChartGranularity.daily:
        return _groupDaily();
      case _ChartGranularity.monthly:
        return _groupMonthly();
      case _ChartGranularity.yearly:
        return _groupYearly();
    }
  }

  _ChartData _groupDaily() {
    final startDate = DateTime(_start.year, _start.month, _start.day);
    final endDate = DateTime(_end.year, _end.month, _end.day);
    final days = <DateTime>[];
    for (var d = startDate; !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    final values = days.map((day) {
      double s = 0;
      for (final r in _records) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == day.year && f.month == day.month && f.day == day.day) {
            final val = _selectedTabIndex == 0 ? (r['total'] ?? 0) : (r['suma_productos'] ?? 0);
            s += double.tryParse(val.toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = days.map((d) => intl.DateFormat('d/MM').format(d)).toList();
    return _ChartData(values, labels, _ChartGranularity.daily);
  }

  _ChartData _groupMonthly() {
    // Genera una lista de primeros días de mes en el rango
    final months = <DateTime>[];
    var cur = DateTime(_start.year, _start.month, 1);
    final endMonth = DateTime(_end.year, _end.month, 1);
    while (!cur.isAfter(endMonth)) {
      months.add(cur);
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
    final values = months.map((m) {
      double s = 0;
      for (final r in _records) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == m.year && f.month == m.month) {
            final val = _selectedTabIndex == 0 ? (r['total'] ?? 0) : (r['suma_productos'] ?? 0);
            s += double.tryParse(val.toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = months.map((m) => intl.DateFormat('MM/yy').format(m)).toList();
    return _ChartData(values, labels, _ChartGranularity.monthly);
  }

  _ChartData _groupYearly() {
    final years = <int>[];
    for (var y = _start.year; y <= _end.year; y++) {
      years.add(y);
    }
    final values = years.map((y) {
      double s = 0;
      for (final r in _records) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == y) {
            final val = _selectedTabIndex == 0 ? (r['total'] ?? 0) : (r['suma_productos'] ?? 0);
            s += double.tryParse(val.toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = years.map((y) => y.toString()).toList();
    return _ChartData(values, labels, _ChartGranularity.yearly);
  }

  void _showDetails(Map<String, dynamic> rec) {
    final fecha =
        rec['fecha'] != null ? DateTime.parse(rec['fecha']) : null;
    final formaPago = rec['formadepago'] as String? ?? '';
    final sucursal = rec['sucursal'] ?? '';

    final isService = _selectedTabIndex == 0;
    final isGasto = isService && rec['Gasto'] != null && rec['Gasto'].toString().trim().isNotEmpty;

    final total = isGasto
        ? (double.tryParse(rec['Gasto'].toString()) ?? 0.0)
        : (isService
            ? (double.tryParse((rec['total'] ?? 0).toString()) ?? 0.0)
            : (double.tryParse((rec['suma_productos'] ?? 0).toString()) ?? 0.0));

    final servicios = isService ? (rec['servicios_detalle'] as List? ?? []) : [];
    final productos = !isService ? (rec['productos_detalle'] as List? ?? []) : [];
    final extras = isService
        ? (double.tryParse((rec['montos_extras'] ?? 0).toString()) ?? 0.0)
        : 0.0;
    final serviciosSum = isService
        ? (double.tryParse((rec['suma_servicios'] ?? 0).toString()) ?? 0.0)
        : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 12,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isGasto ? Colors.red : Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isGasto ? Icons.arrow_outward_rounded : _paymentIcon(formaPago),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fecha != null
                                ? intl.DateFormat(
                                    'EEEE d \' de \' MMMM · HH:mm',
                                  ).format(fecha)
                                : 'Sin fecha',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sucursal,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isGasto ? '-\$${total.toStringAsFixed(2)}' : '\$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isGasto ? Colors.red : Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Desglose
                if (isGasto) ...[
                  _detailRow('Monto del gasto', '\$${total.toStringAsFixed(2)}'),
                ] else if (isService) ...[
                  _detailRow('Servicios', '\$${serviciosSum.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Montos extras',
                    '\$${extras.toStringAsFixed(2)}',
                  ),
                ] else ...[
                  _detailRow('Venta de productos', '\$${total.toStringAsFixed(2)}'),
                ],
                const SizedBox(height: 8),
                _detailRow(
                  'Forma de pago',
                  formaPago,
                  isLabel: true,
                ),

                if (rec['QuienRegistro'] != null) ...[
                  const SizedBox(height: 8),
                  _detailRow(
                    'Registrado por',
                    rec['QuienRegistro'] as String,
                  ),
                ],

                if (isService && !isGasto && rec['descripcion_extras'] != null &&
                    (rec['descripcion_extras'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailRow('Descripción extras', rec['descripcion_extras']),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Detalle de Items
                if (isGasto) ...[
                  const Text(
                    'Detalle del gasto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rec['descripcion_extras'] as String? ?? 'Gasto registrado',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isService) ...[
                  if (servicios.isNotEmpty) ...[
                    const Text(
                      'Servicios realizados',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...servicios.map((s) {
                      final name = s['name'] ?? s['nombre'] ?? 'Servicio';
                      final price = s['price'] ?? s['precio'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '\$${price.toString()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else
                    const Text(
                      'Sin servicios registrados',
                      style: TextStyle(color: Colors.black38, fontSize: 14),
                    ),
                ] else ...[
                  if (productos.isNotEmpty) ...[
                    const Text(
                      'Productos vendidos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...productos.map((p) {
                      final name = p['nombre'] ?? 'Producto';
                      final price = p['precio_unitario'] ?? 0.0;
                      final qty = p['cantidad'] ?? 1;
                      final sub = p['subtotal'] ?? (price * qty);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$name (x$qty)',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '\$${sub.toString()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else
                    const Text(
                      'Sin productos registrados',
                      style: TextStyle(color: Colors.black38, fontSize: 14),
                    ),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool isLabel = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const Spacer(),
        if (isLabel)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────
  IconData _paymentIcon(String forma) {
    switch (forma.toLowerCase()) {
      case 'tarjeta':
        return Icons.credit_card_rounded;
      case 'transferencia':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _periodLabel() {
    switch (_activePeriod) {
      case _Period.today:
        return 'Hoy';
      case _Period.week:
        return 'Últimos 7 días';
      case _Period.month:
        return 'Este mes';
      case _Period.custom:
        return '${intl.DateFormat('d/MM').format(_start)} – '
            '${intl.DateFormat('d/MM').format(_end)}';
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ──────────────────────
          SliverToBoxAdapter(child: _buildHeroHeader(mq)),

          // ── Periodo Pills ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildPeriodPills(),
            ),
          ),

          // ── Métricas Cards ────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMetricCards(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Gráfica ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildChartCard(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Lista de registros ────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedTabIndex == 0 ? 'Registros' : 'Órdenes',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _selectedTabIndex == 0
                        ? '${_records.length} total'
                        : '${_records.length} orden${_records.length != 1 ? 'es' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              ),
            )
          else if (_records.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildRecordCard(_records[i]),
                  ),
                ),
                childCount: _records.length,
              ),
            ),

          SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 24)),
        ],
      ),
    );
  }

  // ── Hero Header ────────────────────────────────
  Widget _buildHeroHeader(MediaQueryData mq) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
        ),
      ),
      padding: EdgeInsets.only(
        top: mq.padding.top + 8,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _fetchRecords,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Label periodo
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _periodLabel(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Totales (Izquierda: Activa, Derecha: General)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoading
                          ? '—'
                          : '\$${_leftSum.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedTabIndex == 0
                          ? 'Total de servicios'
                          : 'Total productos',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: Colors.white.withValues(alpha: 0.15),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _isLoading
                          ? '—'
                          : '\$${_totalEverything.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total en general (Todo)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Selector de pestaña (Servicios / Productos)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedTabIndex != 0) {
                        setState(() {
                          _selectedTabIndex = 0;
                        });
                        _fetchRecords();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Servicios',
                          style: TextStyle(
                            color: _selectedTabIndex == 0 ? Colors.white : Colors.white60,
                            fontWeight: _selectedTabIndex == 0 ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedTabIndex != 1) {
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                        _fetchRecords();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Productos',
                          style: TextStyle(
                            color: _selectedTabIndex == 1 ? Colors.white : Colors.white60,
                            fontWeight: _selectedTabIndex == 1 ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Period Pills ────────────────────────────────
  Widget _buildPeriodPills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila de pills (scrollable horizontal para pantallas pequeñas)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _PeriodPill(
                label: 'Hoy',
                active: _activePeriod == _Period.today,
                onTap: () => _applyPeriod(_Period.today),
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: '7 días',
                active: _activePeriod == _Period.week,
                onTap: () => _applyPeriod(_Period.week),
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: 'Mes',
                active: _activePeriod == _Period.month,
                onTap: () => _applyPeriod(_Period.month),
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: 'Personalizado',
                active: _activePeriod == _Period.custom,
                onTap: () {
                  if (_activePeriod != _Period.custom) {
                    // Al activar, default: 7 días atrás → ahora
                    final now = DateTime.now();
                    setState(() {
                      _activePeriod = _Period.custom;
                      _start = DateTime(now.year, now.month, now.day)
                          .subtract(const Duration(days: 7));
                      _end = now;
                    });
                    _fetchRecords();
                  }
                },
                icon: Icons.tune_rounded,
              ),
            ],
          ),
        ),

        // Selectores inline — aparecen con animación cuando "Personalizado" está activo
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _activePeriod == _Period.custom
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rango personalizado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _DateTimePickerButton(
                                label: 'Inicio',
                                dateTime: _start,
                                onPick: (dt) {
                                  setState(() => _start = dt);
                                  _fetchRecords();
                                },
                                maxDate: DateTime.now(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DateTimePickerButton(
                                label: 'Fin',
                                dateTime: _end,
                                onPick: (dt) {
                                  setState(() => _end = dt);
                                  _fetchRecords();
                                },
                                minDate: _start,
                                maxDate: DateTime.now(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Métric Cards ────────────────────────────────
  Widget _buildMetricCards() {
    if (_selectedTabIndex == 0) {
      return Row(
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.receipt_long_rounded,
              label: 'Registros',
              value: '${_records.length}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.design_services_rounded,
              label: 'Servicios',
              value: '\$${_sumServicios.toStringAsFixed(0)}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.add_circle_outline_rounded,
              label: 'Extras',
              value: '\$${_sumMontosExtras.toStringAsFixed(0)}',
              isLoading: _isLoading,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.shopping_bag_outlined,
              label: 'Órdenes',
              value: '${_records.length}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.sell_outlined,
              label: 'Venta Total',
              value: '\$${_totalSum.toStringAsFixed(0)}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.grid_view_rounded,
              label: 'Unidades',
              value: '$_totalUnidadesProductos',
              isLoading: _isLoading,
            ),
          ),
        ],
      );
    }
  }

  // ── Chart Card ──────────────────────────────────
  Widget _buildChartCard() {
    final chartData = _chartDataPoints();
    final hasTotals = chartData.values.isNotEmpty && chartData.values.any((v) => v > 0);

    // Etiqueta de granularidad para mostrar en la card
    final String granLabel;
    switch (chartData.granularity) {
      case _ChartGranularity.daily:
        granLabel = 'Vista diaria';
        break;
      case _ChartGranularity.monthly:
        granLabel = 'Vista mensual';
        break;
      case _ChartGranularity.yearly:
        granLabel = 'Vista anual';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tendencia de ingresos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Badge de granularidad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  granLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                intl.DateFormat('d/MM').format(_start),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Text(
                ' → ',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
              Text(
                intl.DateFormat('d/MM').format(_end),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const SizedBox(
              height: 140,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white38,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (!hasTotals)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Sin datos para mostrar',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _LineChartPainter(
                  chartData.values,
                  labels: chartData.labels,
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Record Card ─────────────────────────────────
  Widget _buildRecordCard(Map<String, dynamic> r) {
    final fecha =
        r['fecha'] != null ? DateTime.parse(r['fecha']) : null;
    final isService = _selectedTabIndex == 0;
    final isGasto = isService && r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty;
    final total = isGasto
        ? (double.tryParse(r['Gasto'].toString()) ?? 0.0)
        : (isService
            ? (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0)
            : (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0));
    final formaPago = r['formadepago'] as String? ?? '';
    final sucursal = r['sucursal'] as String? ?? '';
    
    final itemsCount = isService
        ? (r['servicios_detalle'] as List? ?? []).length
        : (r['productos_detalle'] as List? ?? []).length;
    final itemLabel = isGasto
        ? 'Gasto'
        : (isService
            ? '$itemsCount servicio${itemsCount != 1 ? 's' : ''}'
            : '$itemsCount producto${itemsCount != 1 ? 's' : ''}');

    return GestureDetector(
      onTap: () => _showDetails(r),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono de pago
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isGasto ? const Color(0xFFFBF2F2) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGasto
                    ? Icons.arrow_outward_rounded
                    : (isService ? _paymentIcon(formaPago) : Icons.shopping_bag_outlined),
                size: 20,
                color: isGasto ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fecha != null
                        ? intl.DateFormat('dd/MM · HH:mm').format(fecha)
                        : 'Sin fecha',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (sucursal.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sucursal,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        itemLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isGasto ? Colors.red.withValues(alpha: 0.7) : Colors.black38,
                          fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isGasto ? '-\$${total.toStringAsFixed(2)}' : '\$${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isGasto ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formaPago,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black26,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: Colors.black26,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin registros en este periodo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cambia el periodo o agrega nuevos registros',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────

class _PeriodPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: active ? Colors.white : Colors.black54,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLoading;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
          const SizedBox(height: 2),
          isLoading
              ? Container(
                  width: 40,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _DateTimePickerButton
//  Botón compacto que muestra fecha+hora y abre
//  un date picker seguido de un time picker.
// ─────────────────────────────────────────────
class _DateTimePickerButton extends StatelessWidget {
  final String label;
  final DateTime dateTime;
  final ValueChanged<DateTime> onPick;
  final DateTime? minDate;
  final DateTime? maxDate;

  const _DateTimePickerButton({
    required this.label,
    required this.dateTime,
    required this.onPick,
    this.minDate,
    this.maxDate,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = minDate ?? DateTime(2020);
    final last = maxDate ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: dateTime.isAfter(last)
          ? last
          : (dateTime.isBefore(first) ? first : dateTime),
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Colors.black,
            surface: Color(0xFF1C1C1E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dateTime),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Colors.black,
            surface: Color(0xFF1C1C1E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !context.mounted) return;

    onPick(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = intl.DateFormat('dd/MM/yy');
    final timeFmt = intl.DateFormat('HH:mm');

    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black38,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: Colors.black54,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFmt.format(dateTime),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Colors.black38,
                ),
                const SizedBox(width: 4),
                Text(
                  timeFmt.format(dateTime),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
