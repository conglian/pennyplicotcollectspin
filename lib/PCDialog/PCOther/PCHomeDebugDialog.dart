import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_text.dart';

typedef PCHomeDebugSubmit =
    Future<void> Function({
      double? cash,
      double? diamonds,
      double? gold,
      int? queueRank,
      int? wheelChances,
    });

/// 首页「调试数据」弹窗，仅供 Debug 构建使用。
/// 五项均可留空；提交立即保存已填写的数值并关闭，取消不修改本地数据。
class PCHomeDebugDialog extends StatefulWidget {
  const PCHomeDebugDialog({
    super.key,
    required this.cash,
    required this.diamonds,
    required this.gold,
    required this.queueRank,
    required this.queueTotal,
    required this.pigLevel,
    required this.wheelChances,
    required this.onSubmit,
  });

  final double cash, diamonds, gold;
  final int queueRank, queueTotal, pigLevel, wheelChances;
  final PCHomeDebugSubmit onSubmit;

  @override
  State<PCHomeDebugDialog> createState() => _PCHomeDebugDialogState();
}

class _PCHomeDebugDialogState extends State<PCHomeDebugDialog> {
  final _form = GlobalKey<FormState>();
  final _cash = TextEditingController();
  final _diamonds = TextEditingController();
  final _gold = TextEditingController();
  final _queueRank = TextEditingController();
  final _wheelChances = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final input in [_cash, _diamonds, _gold, _queueRank, _wheelChances]) {
      input.dispose();
    }
    super.dispose();
  }

  String? _validateAmount(String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value < 0) {
      return 'Enter a number greater than or equal to 0.';
    }
    if (!RegExp(r'^(?:\d+(?:\.\d{0,2})?|\.\d{1,2})$').hasMatch(text)) {
      return 'Use up to 2 decimal places.';
    }
    if (value > 999999999.99) return 'Maximum: 999999999.99';
    return null;
  }

  String? _validateRank(String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) return null;
    final rank = int.tryParse(text);
    if (rank == null || rank < 1 || rank > 1000000000) {
      return 'Enter a whole-number rank from 1 to 1000000000.';
    }
    return null;
  }

  String? _validateWheelChances(String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) return null;
    final count = int.tryParse(text);
    if (count == null || count < 0 || count > 1000000000) {
      return 'Enter a whole number from 0 to 1000000000.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!kDebugMode || _saving) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    if ([
      _cash,
      _diamonds,
      _gold,
      _queueRank,
      _wheelChances,
    ].every((input) => input.text.trim().isEmpty)) {
      setState(() => _error = 'Fill in at least one field.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    double? amount(TextEditingController input) =>
        input.text.trim().isEmpty ? null : double.parse(input.text.trim());
    try {
      await widget.onSubmit(
        cash: amount(_cash),
        diamonds: amount(_diamonds),
        gold: amount(_gold),
        queueRank: _queueRank.text.trim().isEmpty
            ? null
            : int.parse(_queueRank.text.trim()),
        wheelChances: _wheelChances.text.trim().isEmpty
            ? null
            : int.parse(_wheelChances.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is FormatException
            ? error.message
            : 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                color: const Color(0xFFFFFDF1),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PCText(
                          text: 'Debug data',
                          size: 20,
                          weight: FontWeight.w700,
                          color: Color(0xFF173600),
                        ),
                        const SizedBox(height: 8),
                        PCText(
                          text:
                              'Current stage: ${['Pink Pig', 'Diamond Pig', 'Gold Pig'][widget.pigLevel.clamp(0, 2)]}'
                              '\nFill in any field. Leave others blank to keep their values.',
                          size: 12,
                          color: const Color(0xFF63705A),
                          weight: FontWeight.w400,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 18),
                        _field(
                          key: 'pcDebugCash',
                          input: _cash,
                          label: 'Pink Pig · Cash balance (USD)',
                          current: widget.cash.toStringAsFixed(2),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          key: 'pcDebugDiamonds',
                          input: _diamonds,
                          label: 'Diamond Pig · Diamonds',
                          current: widget.diamonds.toStringAsFixed(2),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          key: 'pcDebugGold',
                          input: _gold,
                          label: 'Gold Pig · Gold bricks',
                          current: widget.gold.toStringAsFixed(2),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          key: 'pcDebugQueueRank',
                          input: _queueRank,
                          label: 'Withdrawal · Queue rank',
                          current: '${widget.queueRank} / ${widget.queueTotal}',
                          rank: true,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          key: 'pcDebugWheelChances',
                          input: _wheelChances,
                          label: 'Wheel · Remaining spins',
                          current: '${widget.wheelChances}',
                          wheel: true,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          PCText(
                            text: _error!,
                            size: 13,
                            color: const Color(0xFFB3261E),
                            maxLines: 3,
                            weight: FontWeight.w400,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _button(
                                key: 'pcDebugCancel',
                                text: 'Cancel',
                                primary: false,
                                onTap: () => Navigator.of(context).pop(false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _button(
                                key: 'pcDebugSubmit',
                                text: _saving ? 'Saving…' : 'Save',
                                primary: true,
                                onTap: _submit,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String key,
    required TextEditingController input,
    required String label,
    required String current,
    bool rank = false,
    bool wheel = false,
  }) => TextFormField(
    key: ValueKey(key),
    controller: input,
    enabled: !_saving,
    keyboardType: TextInputType.numberWithOptions(decimal: !rank && !wheel),
    textInputAction: wheel ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: wheel ? (_) => _submit() : null,
    validator: rank
        ? _validateRank
        : wheel
        ? _validateWheelChances
        : _validateAmount,
    style: const TextStyle(fontSize: 16, color: Color(0xFF173600)),
    decoration: InputDecoration(
      label: PCText(
        text: label,
        size: 13,
        color: const Color(0xFF173600),
        weight: FontWeight.w400,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: 'Current: $current',
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF7E8778)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      errorMaxLines: 2,
    ),
  );

  Widget _button({
    required String key,
    required String text,
    required bool primary,
    required VoidCallback onTap,
  }) => ParticleButton(
    key: ValueKey(key),
    enabled: !_saving,
    onTap: onTap,
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? const Color(0xFF277A13) : const Color(0xFFE4EAD8),
        borderRadius: BorderRadius.circular(23),
      ),
      child: PCText(
        text: text,
        size: 16,
        weight: FontWeight.w700,
        color: primary ? Colors.white : const Color(0xFF173600),
      ),
    ),
  );
}
