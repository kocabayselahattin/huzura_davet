import 'package:flutter/material.dart';
import 'dart:async';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../pages/esmaul_husna_sayfa.dart';

class EsmaulHusnaWidget extends StatefulWidget {
  const EsmaulHusnaWidget({super.key});

  @override
  State<EsmaulHusnaWidget> createState() => _EsmaulHusnaWidgetState();
}

class _EsmaulHusnaWidgetState extends State<EsmaulHusnaWidget> 
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _midnightTimer;
  DateTime? _lastDate;

  late Map<String, String> _gununIsmi;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _gununIsmi = _getGununIsmi();
    _lastDate = DateTime.now();
    _scheduleMidnightRefresh();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _controller.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _gununIsmi = _getGununIsmi();
        _lastDate = DateTime.now();
      });
      _scheduleMidnightRefresh();
    });
  }

  Map<String, String> _getGununIsmi() {
    final now = DateTime.now();
    // Pick the name based on day of year (rotates daily).
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final esmaList = _getEsmaList();
    if (esmaList.isEmpty) {
      return {'arabic': '', 'name': '', 'meaning': ''};
    }
    final index = dayOfYear % esmaList.length;
    return esmaList[index];
  }

  List<Map<String, String>> _getEsmaList() {
    final data = _languageService['esmaul_husna_list'];
    if (data is! List) return [];
    return data.map<Map<String, String>>((item) {
      if (item is Map) {
        return {
          'arabic': item['arabic']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'meaning': item['meaning']?.toString() ?? '',
        };
      }
      return {'arabic': '', 'name': '', 'meaning': ''};
    }).toList();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final now = DateTime.now();
    if (_lastDate == null ||
        now.year != _lastDate!.year ||
        now.month != _lastDate!.month ||
        now.day != _lastDate!.day) {
      _gununIsmi = _getGununIsmi();
      _lastDate = now;
    }
    
    return GestureDetector(
      onTap: _toggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              renkler.kartArkaPlan,
              renkler.kartArkaPlan.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: renkler.vurgu.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: renkler.vurgu.withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Main content.
            Row(
              children: [
                // Left - Arabic name.
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        renkler.vurgu.withValues(alpha: 0.2),
                        renkler.vurgu.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: renkler.vurgu.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _gununIsmi['arabic'] ?? '',
                      style: TextStyle(
                        color: renkler.vurgu,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Arial',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Right - localized name and title.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _languageService['esmaul_husna_of_day'].toUpperCase(),
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _gununIsmi['name'] ?? '',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: renkler.vurgu,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpanded
                                ? _languageService['hide_meaning']
                                : _languageService['show_meaning'],
                            style: TextStyle(
                              color: renkler.vurgu,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Full list button.
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EsmaulHusnaSayfa()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: renkler.vurgu.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.list,
                      color: renkler.vurgu,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            
            // Expandable meaning section.
            SizeTransition(
              sizeFactor: _animation,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: renkler.vurgu.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: renkler.vurgu.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: renkler.vurgu,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['meaning'].toUpperCase(),
                              style: TextStyle(
                                color: renkler.vurgu,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _gununIsmi['meaning'] ?? '',
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
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
