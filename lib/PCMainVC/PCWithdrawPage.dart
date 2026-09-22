import 'package:flutter/material.dart';

import '../PCDialog/PCCash/PCCashDialog.dart';
import '../PCDialog/PCOther/PCOtherDialog.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_stroke_text.dart';
import '../PCTool/pc_text.dart';

enum PCWithdrawMethod { paypal, cashApp, pix, pagBank }

class PCWithdrawPage extends StatefulWidget {
  final PCWithdrawMethod initialMethod;
  final ValueChanged<PCWithdrawMethod>? onConfirm;

  const PCWithdrawPage({
    super.key,
    this.initialMethod = PCWithdrawMethod.paypal,
    this.onConfirm,
  });

  @override
  State<PCWithdrawPage> createState() => _PCWithdrawPageState();
}

class _PCWithdrawPageState extends State<PCWithdrawPage> {
  late PCWithdrawMethod _method;
  String _pixAccountType = 'Email';
  String _pagBankAccountType = 'CPF';

  final Map<PCWithdrawMethod, TextEditingController> _accountControllers = {
    for (final method in PCWithdrawMethod.values)
      method: TextEditingController(),
  };
  final TextEditingController _pixNameController = TextEditingController();
  final TextEditingController _pagBankNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
  }

  @override
  void dispose() {
    for (final controller in _accountControllers.values) {
      controller.dispose();
    }
    _pixNameController.dispose();
    _pagBankNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / 360).clamp(0.85, 1.35);
          final safeTop = MediaQuery.paddingOf(context).top;
          final panelTop = safeTop + 64 * scale;

          double s(double value) => value * scale;

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildTopGlow(s(140)),
              _buildHeader(safeTop, s),
              Positioned(
                left: 0,
                right: 0,
                top: panelTop,
                bottom: 0,
                child: _buildPanel(s),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopGlow(double height) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFE2F3FF)],
            stops: [0.18, 1],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double safeTop, double Function(double) s) {
    return Positioned(
      left: 0,
      right: 0,
      top: safeTop,
      height: s(64),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: s(16),
            width: s(40),
            height: s(48),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: s(24),
                  color: Colors.black,
                ),
              ),
            ),
          ),
          PCText(
            text: 'Confirm Payment Information',
            size: s(18),
            color: Colors.black,
            weight: FontWeight.w600,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(double Function(double) s) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(s(16))),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F9FC), Color(0xFFE9F7FF)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(s(16), s(24), s(16), s(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - s(40)).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Payment Method', s),
                    SizedBox(height: s(12)),
                    _buildMethodPicker(s),
                    _buildSelectedForm(s),
                    const Spacer(),
                    SizedBox(height: s(28)),
                    _buildPrivacyNote(s),
                    SizedBox(height: s(17)),
                    _buildConfirmButton(s),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMethodPicker(double Function(double) s) {
    return SizedBox(
      height: s(56),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: PCWithdrawMethod.values.length,
        separatorBuilder: (context, index) => SizedBox(width: s(8)),
        itemBuilder: (context, index) {
          final method = PCWithdrawMethod.values[index];
          return _buildMethodItem(method, s);
        },
      ),
    );
  }

  Widget _buildMethodItem(PCWithdrawMethod method, double Function(double) s) {
    final selected = method == _method;
    return InkWell(
      borderRadius: BorderRadius.circular(s(12)),
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _method = method);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: s(160),
        height: s(56),
        padding: EdgeInsets.symmetric(horizontal: s(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(s(12)),
          border: Border.all(
            color: selected ? _methodColor(method) : const Color(0xFFE9F0F4),
            width: s(1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PCImg(
              name: _methodAsset(method),
              width: s(32),
              height: s(32),
              fit: BoxFit.contain,
            ),
            SizedBox(width: s(4)),
            Flexible(
              child: PCText(
                text: _methodName(method),
                size: s(20),
                color: Colors.black,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedForm(double Function(double) s) {
    switch (_method) {
      case PCWithdrawMethod.paypal:
        return _buildSimpleForm(
          title: 'Email/Phone Number',
          hint: 'Please input your account ID',
          controller: _accountControllers[_method]!,
          keyboardType: TextInputType.emailAddress,
          s: s,
        );
      case PCWithdrawMethod.cashApp:
        return _buildSimpleForm(
          title: 'Cash App ID/Phone Number',
          hint: 'Please input your \$Cashtag or phone',
          controller: _accountControllers[_method]!,
          keyboardType: TextInputType.text,
          s: s,
        );
      case PCWithdrawMethod.pix:
        return _buildExtendedForm(
          nameController: _pixNameController,
          accountTypes: const ['Email', 'Phone', 'CPF', 'EVP'],
          selectedType: _pixAccountType,
          onTypeChanged: (value) => setState(() => _pixAccountType = value),
          accountTitle: 'Email/Phone Number:',
          accountHint: 'Please input your account ID',
          accountController: _accountControllers[_method]!,
          s: s,
        );
      case PCWithdrawMethod.pagBank:
        return _buildExtendedForm(
          nameController: _pagBankNameController,
          accountTypes: const ['CPF', 'Email', 'Phone'],
          selectedType: _pagBankAccountType,
          onTypeChanged: (value) => setState(() => _pagBankAccountType = value),
          accountTitle: 'PagBank Account:',
          accountHint: 'Please input your PagBank account',
          accountController: _accountControllers[_method]!,
          s: s,
        );
    }
  }

  Widget _buildSimpleForm({
    required String title,
    required String hint,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required double Function(double) s,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: s(20)),
        _sectionTitle(title, s),
        SizedBox(height: s(12)),
        _buildInput(
          controller: controller,
          hint: hint,
          keyboardType: keyboardType,
          s: s,
        ),
      ],
    );
  }

  Widget _buildExtendedForm({
    required TextEditingController nameController,
    required List<String> accountTypes,
    required String selectedType,
    required ValueChanged<String> onTypeChanged,
    required String accountTitle,
    required String accountHint,
    required TextEditingController accountController,
    required double Function(double) s,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: s(8)),
        _buildInput(
          controller: nameController,
          hint: 'Name',
          keyboardType: TextInputType.name,
          s: s,
        ),
        SizedBox(height: s(28)),
        _sectionTitle('Account Type', s),
        SizedBox(height: s(12)),
        Wrap(
          spacing: s(8),
          runSpacing: s(8),
          children: accountTypes
              .map(
                (type) => _buildTypeChip(
                  type: type,
                  selected: type == selectedType,
                  onTap: () => onTypeChanged(type),
                  s: s,
                ),
              )
              .toList(),
        ),
        SizedBox(height: s(24)),
        _sectionTitle(accountTitle, s),
        SizedBox(height: s(12)),
        _buildInput(
          controller: accountController,
          hint: accountHint,
          keyboardType: TextInputType.text,
          s: s,
        ),
      ],
    );
  }

  Widget _buildTypeChip({
    required String type,
    required bool selected,
    required VoidCallback onTap,
    required double Function(double) s,
  }) {
    final chipWidth = switch (type) {
      'Phone' => 80.0,
      'Email' => 72.0,
      'CPF' => 68.0,
      'EVP' => 66.0,
      _ => 80.0,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(s(18)),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: s(chipWidth),
        height: s(36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(s(18)),
          border: Border.all(
            color: selected ? const Color(0xFF1486F8) : Colors.transparent,
            width: s(1.5),
          ),
        ),
        child: PCText(
          text: type,
          size: s(14),
          color: Colors.black,
          weight: FontWeight.w400,
          align: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required double Function(double) s,
  }) {
    return SizedBox(
      height: s(52),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: const Color(0xFF1486F8),
        style: TextStyle(
          fontFamily: text_fontName,
          fontSize: s(16),
          height: 1.2,
          color: Colors.black,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: text_fontName,
            fontSize: s(16),
            height: 1.2,
            color: const Color(0xFFB3B3B3),
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: s(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(s(12)),
            borderSide: BorderSide(color: const Color(0xFFECF3F6), width: s(1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(s(12)),
            borderSide: BorderSide(color: _methodColor(_method), width: s(1.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNote(double Function(double) s) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PCImg(
            name: 'pc_withdraw_safe_2x',
            width: s(12),
            height: s(12),
            fit: BoxFit.contain,
          ),
          SizedBox(width: s(4)),
          PCText(
            text: 'We’ll only use this for sending your withdrawal',
            size: s(12),
            color: Colors.black,
            weight: FontWeight.w400,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(double Function(double) s) {
    return SizedBox(
      width: double.infinity,
      height: s(52),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(s(26)),
          gradient: const LinearGradient(
            colors: [Color(0xFF1486F8), Color(0xFF2365EA)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(s(26)),
            onTap: _handleConfirm,
            child: Center(
              child: PCText(
                text: 'Confirm',
                size: s(16),
                color: Colors.white,
                weight: FontWeight.w700,
                align: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleConfirm() {
    FocusManager.instance.primaryFocus?.unfocus();

    if ((_method == PCWithdrawMethod.pix &&
            _pixNameController.text.trim().isEmpty) ||
        (_method == PCWithdrawMethod.pagBank &&
            _pagBankNameController.text.trim().isEmpty)) {
      PCDialogTool.toast(context, 'Please input your name');
      return;
    }

    if (_accountControllers[_method]!.text.trim().isEmpty) {
      PCDialogTool.toast(context, 'Please input your account ID');
      return;
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return PCAccountFeedbackDialog(
          onContinue: () => widget.onConfirm?.call(_method),
        );
      },
    );
  }

  Widget _sectionTitle(String text, double Function(double) s) {
    return PCText(
      text: text,
      size: s(16),
      color: const Color(0xFF13395F),
      weight: FontWeight.w600,
    );
  }

  String _methodName(PCWithdrawMethod method) => switch (method) {
    PCWithdrawMethod.paypal => 'PayPal',
    PCWithdrawMethod.cashApp => 'Cash App',
    PCWithdrawMethod.pix => 'PiX',
    PCWithdrawMethod.pagBank => 'PagBank',
  };

  String _methodAsset(PCWithdrawMethod method) => switch (method) {
    PCWithdrawMethod.paypal => 'pc_withdraw_paypal_2x',
    PCWithdrawMethod.cashApp => 'pc_withdraw_cashapp_2x',
    PCWithdrawMethod.pix => 'pc_withdraw_pix_2x',
    PCWithdrawMethod.pagBank => 'pc_withdraw_pagbank_2x',
  };

  Color _methodColor(PCWithdrawMethod method) => switch (method) {
    PCWithdrawMethod.paypal => const Color(0xFF009CDE),
    PCWithdrawMethod.cashApp => const Color(0xFF0ABE4D),
    PCWithdrawMethod.pix => const Color(0xFF2CBFA9),
    PCWithdrawMethod.pagBank => const Color(0xFFD7D936),
  };
}
