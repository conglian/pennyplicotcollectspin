import 'package:flutter/material.dart';
import '../PCTool/PCAdaptiveLayout.dart';
import '../PCTool/PCAnalytics.dart';

import '../PCDialog/PCCash/PCAccountFeedbackDialog.dart';
import '../PCTool/PCWithdrawMethod.dart';
import '../PCTool/PCWithdrawValidation.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCDialog/PCOther/PCDialogTool.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_stroke_text.dart';
import '../PCTool/pc_text.dart';

export '../PCTool/PCWithdrawMethod.dart';

/// 当前表单提交值；完整账号只供本地收款资料使用。
class PCWithdrawDetails {
  const PCWithdrawDetails(this.method, this.account);
  final PCWithdrawMethod method;
  final String account;
}

class PCWithdrawPage extends StatefulWidget {
  final PCWithdrawMethod initialMethod;
  final ValueChanged<PCWithdrawMethod>? onConfirm;
  final ValueChanged<PCWithdrawDetails>? onSubmitted;

  /// 恢复为确认成功弹窗的背景时不算再次进入资料填写页。
  final bool trackExposure;
  final bool isGuide;

  /// 兼容调用方提供的地区；地区不再改变渠道列表。
  final String? countryCode;

  const PCWithdrawPage({
    super.key,
    this.initialMethod = PCWithdrawMethod.paypal,
    this.onConfirm,
    this.onSubmitted,
    this.trackExposure = true,
    this.isGuide = false,
    this.countryCode,
  });

  @override
  State<PCWithdrawPage> createState() => _PCWithdrawPageState();
}

class _PCWithdrawPageState extends State<PCWithdrawPage> {
  late PCWithdrawMethod _method;
  final _formKey = GlobalKey();
  final Set<TextEditingController> _invalidFields = {};
  bool _submitted = false;

  final Map<PCWithdrawMethod, TextEditingController> _accountControllers = {
    for (final method in PCWithdrawMethod.values)
      method: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.trackExposure &&
          ModalRoute.of(context)?.isCurrent == true) {
        PCAnalytics.event('input_account_page');
      }
    });
    _method = widget.initialMethod;
    for (final controller in _accountControllers.values) {
      controller.addListener(_formChanged);
    }
  }

  void _formChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit =>
      !_submitted && _accountControllers[_method]!.text.trim().isNotEmpty;

  @override
  void dispose() {
    for (final controller in _accountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = PCAdaptiveLayout.widthScale(constraints.maxWidth);
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
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = Padding(
              key: _formKey,
              padding: EdgeInsets.fromLTRB(s(16), s(24), s(16), s(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Payment Method', s),
                  SizedBox(height: s(12)),
                  _buildMethodPicker(s),
                  _buildSelectedForm(s),
                ],
              ),
            );
            final footer = Padding(
              padding: EdgeInsets.all(s(16)),
              child: Column(
                children: [
                  _buildPrivacyNote(s),
                  SizedBox(height: s(17)),
                  _buildConfirmButton(s),
                ],
              ),
            );
            // Scaffold 负责避开键盘，SafeArea 负责避开系统导航栏。
            // 可用高度过小时让表单和提交按钮一起滚动。
            if (constraints.maxHeight < s(132)) {
              return SingleChildScrollView(
                child: Column(children: [form, footer]),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SingleChildScrollView(child: form)),
                footer,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMethodPicker(double Function(double) s) => Row(
    children: [
      Expanded(child: _buildMethodItem(PCWithdrawMethod.paypal, s)),
      SizedBox(width: s(8)),
      Expanded(child: _buildMethodItem(PCWithdrawMethod.cashApp, s)),
    ],
  );

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
              name: method.formAsset,
              width: s(32),
              height: s(32),
              fit: BoxFit.contain,
            ),
            SizedBox(width: s(4)),
            Flexible(
              child: PCText(
                text: method.label,
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

  Widget _buildSelectedForm(double Function(double) s) => _buildSimpleForm(
    title: 'Email/Phone Number',
    hint: 'Please input your account ID',
    controller: _accountControllers[_method]!,
    keyboardType: _method == PCWithdrawMethod.cashApp
        ? TextInputType.phone
        : TextInputType.emailAddress,
    s: s,
  );

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
        onChanged: (_) => setState(() => _invalidFields.remove(controller)),
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
            borderSide: BorderSide(
              color: _invalidFields.contains(controller)
                  ? Colors.red
                  : const Color(0xFFECF3F6),
              width: s(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(s(12)),
            borderSide: BorderSide(
              color: _invalidFields.contains(controller)
                  ? Colors.red
                  : _methodColor(_method),
              width: s(1.5),
            ),
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
          Flexible(
            child: PCText(
              text: 'We’ll only use this for sending your withdrawal',
              size: s(12),
              color: Colors.black,
              weight: FontWeight.w400,
              maxLines: 2,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(double Function(double) s) {
    return SizedBox(
      width: double.infinity,
      height: s(52),
      child: Opacity(
        opacity: _canSubmit ? 1 : .45,
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
              onTap: _canSubmit ? _handleConfirm : null,
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
      ),
    );
  }

  void _reject(TextEditingController controller, String message) {
    controller.clear();
    setState(() => _invalidFields.add(controller));
    PCDialogTool.toast(context, message);
  }

  Future<void> _handleConfirm() async {
    if (!_canSubmit || ModalRoute.of(context)?.isCurrent != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = _accountControllers[_method]!;
    final account = controller.text.trim();
    const invalidFormat = 'The format you entered is incorrect.';
    if (PCWithdrawValidation.isLegacyMask(account) ||
        (_method == PCWithdrawMethod.cashApp
            ? !PCWithdrawValidation.cashPhone(account)
            : !PCWithdrawValidation.email(account))) {
      _reject(controller, invalidFormat);
      return;
    }
    PCAnalytics.event('input_account_page_c');
    final details = PCWithdrawDetails(_method, account);
    setState(() => _submitted = true);
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(details);
      return;
    }
    final local = PCLocalProvider.instance;
    try {
      if (!await local.updateint(
            local.pc_account_seled_indexName,
            details.method.storageIndex,
          ) ||
          !await local.updateString(local.pc_account_idName, details.account)) {
        throw StateError('Unable to save payment information');
      }
      await local.init();
    } catch (_) {
      if (mounted) {
        setState(() => _submitted = false);
        PCDialogTool.toast(
          context,
          'Unable to save progress. Please try again.',
        );
      }
      return;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    context.tipShow(
      PCAccountFeedbackDialog(
        account: details.account,
        onContinue: () => widget.onConfirm?.call(_method),
      ),
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

  Color _methodColor(PCWithdrawMethod method) => switch (method) {
    PCWithdrawMethod.paypal => const Color(0xFF009CDE),
    PCWithdrawMethod.cashApp => const Color(0xFF0ABE4D),
  };
}
