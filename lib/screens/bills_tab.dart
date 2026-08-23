import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/bill.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class BillsTab extends StatefulWidget {
  const BillsTab({super.key});

  @override
  State<BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends State<BillsTab> {
  final _db = DatabaseHelper.instance;
  final _notif = NotificationService.instance;
  List<Bill> _bills = [];

  BillType _type = BillType.creditCard;
  final _nameCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  final _dateFmt = DateFormat('MMM d');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bills = await _db.getBills();
    setState(() => _bills = bills);
    await _notif.rescheduleAll(bills);
  }

  Future<void> _addBill() async {
    final name = _nameCtrl.text.trim();
    final dueDay = int.tryParse(_dueDayCtrl.text);
    if (name.isEmpty || dueDay == null || dueDay < 1 || dueDay > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and a valid due day (1–31).')),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);

    final bill = Bill(
      name: name,
      type: _type,
      dueDay: dueDay,
      amount: amount,
      // Stable-ish id derived from time; used as the OS notification id.
      notificationId: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
    );
    final id = await _db.insertBill(bill);
    await _notif.scheduleBillReminder(Bill(
      id: id,
      name: bill.name,
      type: bill.type,
      dueDay: bill.dueDay,
      amount: bill.amount,
      notificationId: bill.notificationId,
    ));

    _nameCtrl.clear();
    _dueDayCtrl.clear();
    _amountCtrl.clear();
    await _load();
  }

  Future<void> _deleteBill(Bill bill) async {
    if (bill.id == null) return;
    await _notif.cancelBillReminder(bill.notificationId);
    await _db.deleteBill(bill.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final withDates = _bills.map((b) {
      final due = b.nextDueDate();
      final days = _daysUntil(due);
      return (bill: b, due: due, days: days);
    }).toList()
      ..sort((a, b) => a.days.compareTo(b.days));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stubCard(withDates.isNotEmpty ? withDates.first : null),
        const SizedBox(height: 16),
        _addCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ALL BILLS', style: _sectionTitle()),
                const SizedBox(height: 12),
                if (withDates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No bills yet. Add your credit cards and utilities above.',
                        style: TextStyle(color: AppColors.inkFaint),
                      ),
                    ),
                  )
                else
                  ...withDates.map((e) => _billRow(e.bill, e.due, e.days)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Reminders are scheduled at the OS level and fire at 9:00 AM the day '
          'before each due date — even if the app is closed. Open the app at '
          'least once a month so next month\'s reminder gets scheduled.',
          style: TextStyle(fontSize: 11, color: AppColors.inkFaint, height: 1.5),
        ),
      ],
    );
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.difference(today).inDays;
  }

  Widget _stubCard(({Bill bill, DateTime due, int days})? soonest) {
    Color color = AppColors.ink;
    if (soonest != null) {
      if (soonest.days <= 0) {
        color = AppColors.red;
      } else if (soonest.days == 1) {
        color = AppColors.amber;
      }
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEXT DUE', style: TextStyle(fontSize: 10.5, letterSpacing: 1.4, color: AppColors.inkFaint, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (soonest == null)
            const Text('No bills added yet', style: TextStyle(color: AppColors.inkFaint))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(soonest.bill.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(soonest.bill.type == BillType.creditCard ? 'Credit Card' : 'Utility',
                        style: const TextStyle(fontSize: 11, color: AppColors.inkDim)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      soonest.days < 0 ? '${soonest.days.abs()}' : '${soonest.days}',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace'),
                    ),
                    Text(
                      soonest.days < 0 ? 'days overdue' : (soonest.days == 1 ? 'day left' : 'days left'),
                      style: const TextStyle(fontSize: 10, color: AppColors.inkFaint, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: AppColors.line, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Due ${_dateFmt.format(soonest.due)}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkDim, fontFamily: 'monospace')),
                if (soonest.bill.amount != null)
                  Text('₱${soonest.bill.amount!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkDim, fontFamily: 'monospace')),
              ],
            ),
          ],
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
            Text('ADD BILL', style: _sectionTitle()),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _typeButton('Credit Card', BillType.creditCard, AppColors.cardAccent)),
                const SizedBox(width: 8),
                Expanded(child: _typeButton('Utility', BillType.utility, AppColors.amber)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name (e.g. BPI Visa, Meralco)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dueDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Due day of month'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _addBill, child: const Text('ADD BILL')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String label, BillType type, Color accent) {
    final selected = _type == type;
    return OutlinedButton(
      onPressed: () => setState(() => _type = type),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? accent : AppColors.inkDim,
        backgroundColor: selected ? accent.withOpacity(0.08) : Colors.transparent,
        side: BorderSide(color: selected ? accent : AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _billRow(Bill bill, DateTime due, int days) {
    String statusLabel;
    Color statusColor;
    Color statusBg;
    if (days < 0) {
      statusLabel = 'OVERDUE';
      statusColor = AppColors.red;
      statusBg = AppColors.red.withOpacity(0.14);
    } else if (days == 0) {
      statusLabel = 'DUE TODAY';
      statusColor = AppColors.red;
      statusBg = AppColors.red.withOpacity(0.14);
    } else if (days == 1) {
      statusLabel = 'DUE TOMORROW';
      statusColor = AppColors.amber;
      statusBg = AppColors.amber.withOpacity(0.12);
    } else {
      statusLabel = 'in ${days}d';
      statusColor = AppColors.inkDim;
      statusBg = Colors.white.withOpacity(0.04);
    }

    final dotColor = bill.type == BillType.creditCard ? AppColors.cardAccent : AppColors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'Due day ${bill.dueDay}${bill.amount != null ? ' · ₱${bill.amount!.toStringAsFixed(2)}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(5)),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.inkFaint),
            onPressed: () => _deleteBill(bill),
          ),
        ],
      ),
    );
  }

  TextStyle _sectionTitle() => const TextStyle(fontSize: 12.5, letterSpacing: 1.0, color: AppColors.inkDim, fontWeight: FontWeight.w600);
}
