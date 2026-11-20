import '../../PCTool/PCAnalytics.dart';
import 'package:flutter/material.dart';

import '../../PCMainVC/PCWithdrawPage.dart';
import '../../PCTool/PCWithdrawValidation.dart';
import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCDialogTool.dart';

/// 3.7收款资料表单（Apply For Payout，Figma 210:678）。
/// 支持 PayPal 和 Cash App；渠道仍有效且账号完整时才回填。
/// 主按钮校验后返回PCWithdrawDetails，关闭返回null；此弹窗不保存或上传资料。
class PCProcessAccountDialog extends StatefulWidget {
  const PCProcessAccountDialog({
    super.key,
    this.initialAccount = '',
    this.initialPaymentIndex = 0,
    this.hasSavedAccount = false,
  });
  final String initialAccount;
  final int initialPaymentIndex;
  final bool hasSavedAccount;

  @override
  State<PCProcessAccountDialog> createState() => _PCProcessAccountDialogState();
}

class _PCProcessAccountDialogState extends State<PCProcessAccountDialog> {
  late PCWithdrawMethod _method;
  final _accounts = {
    for (final method in PCWithdrawMethod.values)
      method: TextEditingController(),
  };
  TextEditingController get _account => _accounts[_method]!;
  bool _invalid = false;
  bool _submitted = false;
  static const _error = 'Please enter the correct withdrawal account number';

  @override
  void initState() {
    super.initState();
    final savedMethod = PCWithdrawMethod.fromStorageIndex(
      widget.initialPaymentIndex,
    );
    _method = widget.hasSavedAccount
        ? savedMethod ?? PCWithdrawMethod.paypal
        : PCWithdrawMethod.paypal;
    if (widget.hasSavedAccount && savedMethod != null) {
      _account.text = PCWithdrawValidation.fullAccount(widget.initialAccount);
    }
  }

  @override
  void dispose() {
    for (final account in _accounts.values) {
      account.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    final value = _account.text.trim();
    final validFormat = switch (_method) {
      PCWithdrawMethod.paypal => PCWithdrawValidation.email(value),
      PCWithdrawMethod.cashApp => PCWithdrawValidation.cashPhone(value),
    };
    if (value.length < 10 ||
        !validFormat ||
        PCWithdrawValidation.isLegacyMask(value)) {
      setState(() => _invalid = true);
      PCDialogTool.toast(context, _error);
      return;
    }
    _submitted = true;
    PCAnalytics.event('input_account_page_c');
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(PCWithdrawDetails(_method, value));
  }

  @override
  Widget build(BuildContext context) => PCAnalyticsExposure(
    event: 'input_account_page',
    child: _buildDialog(context),
  );

  Widget _buildDialog(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 小屏沿用可用卡宽和原字号；大屏将输入、图标、间距一起放大，避免二次缩放。
              final canvasWidth = constraints.maxWidth
                  .clamp(0.0, 304.0)
                  .toDouble();
              final scale = PCAdaptiveLayout.fitScale(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                designWidth: 328,
                designHeight: 404,
              ).clamp(1.0, PCAdaptiveLayout.maxCanvasScale).toDouble();
              return Center(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: canvasWidth * scale,
                    height: 404 * scale,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: canvasWidth,
                        height: 404,
                        child: _accountCard(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _accountCard() => Container(
    height: 404,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            children: [
              const Positioned(
                left: 24,
                right: 24,
                top: 0,
                child: PCText(
                  text: 'Confirm Payment\nInformation',
                  size: 18,
                  color: Colors.black,
                  weight: FontWeight.w600,
                  maxLines: 2,
                  align: TextAlign.center,
                  height: 24 / 18,
                ),
              ),
              Positioned(
                right: -8,
                top: -8,
                child: IconButton(
                  key: const ValueKey('pcProcessAccountClose'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    size: 24,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _label('Payment Method'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(child: _methodItem(PCWithdrawMethod.paypal)),
              const SizedBox(width: 8),
              Expanded(child: _methodItem(PCWithdrawMethod.cashApp)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _label('Email/Phone Number'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            key: const ValueKey('pcProcessAccountInput'),
            controller: _account,
            maxLines: 1,
            keyboardType: _method == PCWithdrawMethod.cashApp
                ? TextInputType.phone
                : TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(
              fontFamily: text_fontName,
              fontSize: 16,
              color: const Color(0xFF393939),
            ),
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Please input your account ID',
              hintStyle: TextStyle(
                fontFamily: text_fontName,
                fontSize: 15,
                color: const Color(0xFFB3B3B3),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFECF3F6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _invalid ? Colors.red : const Color(0xFFECF3F6),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _invalid ? Colors.red : const Color(0xFF009CDE),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(
          height: 16,
          child: Row(
            children: [
              Icon(Icons.verified_user, size: 12, color: Color(0xFF00A900)),
              SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: PCText(
                    text: 'We’ll only use this for sending your withdrawal',
                    size: 12,
                    color: Colors.black,
                    weight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ParticleButton(
          key: const ValueKey('pcProcessAccountApply'),
          onTap: _submit,
          child: Container(
            height: 52,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF1486F8), Color(0xFF2365EA)],
              ),
            ),
            child: const PCText(
              text: 'Apply For Payout',
              size: 16,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _label(String text) => SizedBox(
    height: 20,
    child: PCText(
      text: text,
      size: 16,
      color: const Color(0xFF13395F),
      weight: FontWeight.w600,
    ),
  );

  Widget _methodItem(PCWithdrawMethod method) {
    final selected = method == _method;
    return ParticleButton(
      key: ValueKey('pcProcessMethod${method.index}'),
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _method = method;
          _invalid = false;
        });
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF009CDE) : const Color(0xFFE9F0F4),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PCImg(
              name: method.formAsset,
              width: 25,
              height: 25,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: PCText(
                text: method.label,
                size: 15,
                color: Colors.black,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
