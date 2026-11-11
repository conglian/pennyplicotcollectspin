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
/// 新账号可选四渠道；已有资料仅显示原渠道并回填，原脱敏账号不改可确认。
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
  late TextEditingController _account;
  bool _invalid = false;
  bool _submitted = false;
  static const _error = 'Please enter the correct withdrawal account number';

  @override
  void initState() {
    super.initState();
    _method = widget.hasSavedAccount
        ? switch (widget.initialPaymentIndex) {
            1 => PCWithdrawMethod.pix,
            2 => PCWithdrawMethod.cashApp,
            3 => PCWithdrawMethod.pagBank,
            _ => PCWithdrawMethod.paypal,
          }
        : PCWithdrawMethod.paypal;
    _account = TextEditingController(
      text: widget.hasSavedAccount ? widget.initialAccount : '',
    );
  }

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    final value = _account.text.trim();
    final unchanged =
        widget.hasSavedAccount &&
        value.isNotEmpty &&
        value == widget.initialAccount.trim();
    final validFormat = switch (_method) {
      PCWithdrawMethod.paypal => PCWithdrawValidation.email(value),
      PCWithdrawMethod.cashApp => PCWithdrawValidation.cashPhone(value),
      PCWithdrawMethod.pix || PCWithdrawMethod.pagBank =>
        PCWithdrawValidation.email(value) ||
            PCWithdrawValidation.cashPhone(value),
    };
    if (!unchanged && (value.length < 10 || !validFormat)) {
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
    final methods = widget.hasSavedAccount
        ? [_method]
        : PCWithdrawMethod.values;
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
                        child: _accountCard(methods),
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

  Widget _accountCard(List<PCWithdrawMethod> methods) => Container(
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
        if (methods.length == 1)
          SizedBox(
            height: 102,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 160,
                height: 44,
                child: _methodItem(methods.first),
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(child: _methodItem(methods[0])),
                const SizedBox(width: 8),
                Expanded(child: _methodItem(methods[1])),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(child: _methodItem(methods[2])),
                const SizedBox(width: 8),
                Expanded(child: _methodItem(methods[3])),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _label(
          _method == PCWithdrawMethod.paypal
              ? 'Email:'
              : _method == PCWithdrawMethod.cashApp
              ? 'Phone Number:'
              : 'Email/Phone Number:',
        ),
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
    final names = ['PayPal', 'Cash App', 'PiX', 'PagBank'];
    final assets = [
      'pc_withdraw_paypal_2x',
      'pc_withdraw_cashapp_2x',
      'pc_withdraw_pix_2x',
      'pc_withdraw_pagbank_2x',
    ];
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
              name: assets[method.index],
              width: 25,
              height: 25,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: PCText(
                text: names[method.index],
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
