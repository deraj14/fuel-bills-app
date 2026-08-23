import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/fuel_entry.dart';
import '../theme/app_theme.dart';

class FuelTab extends StatefulWidget {
  const FuelTab({super.key});

  @override
  State<FuelTab> createState() => _FuelTabState();
}

class _FuelTabState extends State<FuelTab> {
  final _db = DatabaseHelper.instance;
  List<FuelEntry> _entries = [];

  DateTime _date = DateTime.now();
  final _odoCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _db.getFuelEntries();
    setState(() => _entries = entries);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addEntry() async {
    final odo = double.tryParse(_odoCtrl.text);
    if (odo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid odometer reading.')),
      );
      return;
    }
    final liters = double.tryParse(_litersCtrl.text);
    final price = double.tryParse(_priceCtrl.text);

    await _db.insertFuelEntry(FuelEntry(
      date: _date,
      odometer: odo,
      liters: liters,
      pricePerLiter: price,
    ));

    _odoCtrl.clear();
    _litersCtrl.clear();
    _priceCtrl.clear();
    setState(() => _date = DateTime.now());
    await _load();
  }

  Future<void> _deleteEntry(int id) async {
    await _db.deleteFuelEntry(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._entries]..sort((a, b) => a.date.compareTo(b.date));
    FuelEntry? last = sorted.isNotEmpty ? sorted.last : null;
    FuelEntry? prev = sorted.length >= 2 ? sorted[sorted.length - 2] : null;

    double? lastDist;
    double? lastEff;
    if (last != null && prev != null) {
      lastDist = last.odometer - prev.odometer;
      if (last.liters != null && last.liters! > 0 && lastDist > 0) {
        lastEff = lastDist / last.liters!;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dashCard(lastDist, lastEff, prev, last),
        const SizedBox(height: 16),
        _addCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HISTORY', style: _sectionTitle()),
                const SizedBox(height: 12),
                if (sorted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No entries yet. Log your first fill-up above.',
                        style: TextStyle(color: AppColors.inkFaint),
                      ),
                    ),
                  )
                else
                  ...sorted.reversed.toList().asMap().entries.map((e) {
                    final idx = sorted.length - 1 - e.key;
                    final entry = e.value;
                    final hasPrev = idx > 0;
                    final prevEntry = hasPrev ? sorted[idx - 1] : null;
                    final dist = prevEntry != null ? entry.odometer - prevEntry.odometer : null;
                    double? eff;
                    if (dist != null && entry.liters != null && entry.liters! > 0 && dist > 0) {
                      eff = dist / entry.liters!;
                    }
                    return _entryRow(entry, dist, eff);
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashCard(double? dist, double? eff, FuelEntry? prev, FuelEntry? last) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(child: _gauge('LAST TRIP', dist != null ? '${dist.toStringAsFixed(0)}' : '—', 'km', AppColors.amber,
              sub: prev != null && last != null ? '${_dateFmt.format(prev.date)} → ${_dateFmt.format(last.date)}' : 'No entries yet')),
          const SizedBox(width: 12),
          Expanded(child: _gauge('EFFICIENCY', eff != null ? eff.toStringAsFixed(1) : '—', 'km/L', AppColors.mint,
              sub: eff != null ? 'calculated' : 'Add liters to calc')),
        ],
      ),
    );
  }

  Widget _gauge(String label, String value, String unit, Color color, {required String sub}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1114),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2F38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.inkFaint, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
                TextSpan(text: ' $unit', style: const TextStyle(fontSize: 12, color: AppColors.inkDim)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
        ],
      ),
    );
  }

  Widget _addCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NEW FILL-UP', style: _sectionTitle()),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(_dateFmt.format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _odoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _litersCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Fuel Added (L)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price / L (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _addEntry, child: const Text('ADD ENTRY')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryRow(FuelEntry entry, double? dist, double? eff) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateFmt.format(entry.date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${entry.odometer.toStringAsFixed(0)} km'
                  '${entry.liters != null ? ' · ${entry.liters!.toStringAsFixed(1)} L' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dist != null ? '${dist >= 0 ? '+' : ''}${dist.toStringAsFixed(0)} km' : 'baseline',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.amber, fontFamily: 'monospace'),
              ),
              if (eff != null)
                Text('${eff.toStringAsFixed(1)} km/L', style: const TextStyle(fontSize: 11, color: AppColors.mint, fontFamily: 'monospace')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.inkFaint),
            onPressed: entry.id == null ? null : () => _deleteEntry(entry.id!),
          ),
        ],
      ),
    );
  }

  TextStyle _sectionTitle() => const TextStyle(fontSize: 12.5, letterSpacing: 1.0, color: AppColors.inkDim, fontWeight: FontWeight.w600);
}
