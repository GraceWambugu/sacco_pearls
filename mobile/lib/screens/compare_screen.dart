import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sacco.dart';
import '../services/api_service.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _searchController = TextEditingController();
  late Future<List<SaccoRecord>> _directory;
  Timer? _debounce;
  final Set<int> _selectedIds = {};
  String _query = '';
  Future<Map<String, dynamic>>? _comparison;

  @override
  void initState() {
    super.initState();
    _directory = ApiService.searchSaccos('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _directory = ApiService.searchSaccos(_query);
      });
    });
  }

  void _toggle(SaccoRecord sacco, bool selected) {
    if (selected && _selectedIds.length == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compare up to three SACCOs at a time.')),
      );
      return;
    }
    setState(() {
      if (selected) {
        _selectedIds.add(sacco.id);
      } else {
        _selectedIds.remove(sacco.id);
      }
      _comparison = null;
    });
  }

  void _compare() {
    setState(() {
      _comparison = ApiService.compareSaccos(_selectedIds.toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare SACCOs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Find SACCOs to compare',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SaccoRecord>>(
              future: _directory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Directory unavailable: ${snapshot.error}'));
                }
                final saccos = snapshot.data ?? const <SaccoRecord>[];
                if (saccos.isEmpty) return const Center(child: Text('No SACCOs found.'));
                return ListView.builder(
                  itemCount: saccos.length,
                  itemBuilder: (context, index) {
                    final sacco = saccos[index];
                    final selected = _selectedIds.contains(sacco.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: const Color(0xFF235C48),
                      title: Text(sacco.name),
                      subtitle: Text(sacco.county ?? 'County not listed'),
                      onChanged: (value) => _toggle(sacco, value ?? false),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_comparison != null) _ComparisonResult(future: _comparison!),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _selectedIds.length < 2 ? null : _compare,
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: Text('Compare ${_selectedIds.length} selected'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonResult extends StatelessWidget {
  const _ComparisonResult({required this.future});

  final Future<Map<String, dynamic>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(color: Color(0xFF126B5B)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              snapshot.error.toString(),
              style: const TextStyle(color: Color(0xFFAD4539), fontSize: 12),
            ),
          );
        }
        final results = snapshot.data?['results'] as List<dynamic>? ?? const [];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 190),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in results)
                ListTile(
                  dense: true,
                  title: Text(item['sacco']['name'] as String),
                  subtitle: Text('Composite ${item['composite'] ?? '—'}  ·  ${item['rating'] ?? 'Unrated'}'),
                  trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF24866B)),
                ),
            ],
          ),
        );
      },
    );
  }
}