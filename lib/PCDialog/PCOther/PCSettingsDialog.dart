import 'package:flutter/material.dart';

import '../../PCTool/PCAudioUtils.dart';
import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_text.dart';
import 'PCOtherDialogWidgets.dart';

enum _PCSettingsInfo { privacy, contact, terms }

/// 首页「Setting」设置弹窗：音效、背景音乐分别切换并立即保存到本地。
/// Privacy Policy、Terms of Use和Contact Us复用传入入口；未配置时面板内提示。
/// 右上角关闭，底部用户条例链接独立于联系入口。
class PCSettingsDialog extends StatefulWidget {
  const PCSettingsDialog({
    super.key,
    this.onBackgroundMusicChanged,
    this.onSoundEffectsChanged,
    this.onPrivacyPolicy,
    this.onContactUs,
    this.onTermsOfUse,
  });

  final Future<void> Function(bool enabled)? onBackgroundMusicChanged;
  final Future<void> Function(bool enabled)? onSoundEffectsChanged;
  final Future<void> Function()? onPrivacyPolicy, onContactUs, onTermsOfUse;

  @override
  State<PCSettingsDialog> createState() => _PCSettingsDialogState();
}

class _PCSettingsDialogState extends State<PCSettingsDialog> {
  final _local = PCLocalProvider.instance;
  bool _musicSaving = false, _effectsSaving = false, _openingInfo = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _local.addListener(_localChanged);
  }

  void _localChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle({required bool backgroundMusic}) async {
    if (backgroundMusic ? _musicSaving : _effectsSaving) return;
    final enabled = !(backgroundMusic
        ? _local.pc_bg_music
        : _local.pc_sound_music);
    setState(() {
      _message = null;
      if (backgroundMusic) {
        _musicSaving = true;
      } else {
        _effectsSaving = true;
      }
    });
    try {
      final change = backgroundMusic
          ? widget.onBackgroundMusicChanged ??
                PCAudioUtils().setBackgroundMusicEnabled
          : widget.onSoundEffectsChanged ??
                PCAudioUtils().setSoundEffectsEnabled;
      await change(enabled);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not save. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          if (backgroundMusic) {
            _musicSaving = false;
          } else {
            _effectsSaving = false;
          }
        });
      }
    }
  }

  Future<void> _openInfo(_PCSettingsInfo entry) async {
    if (_openingInfo) return;
    final (open, unavailable) = switch (entry) {
      _PCSettingsInfo.privacy => (
        widget.onPrivacyPolicy,
        'Privacy Policy is not available yet.',
      ),
      _PCSettingsInfo.contact => (
        widget.onContactUs,
        'Contact details are not available yet.',
      ),
      _PCSettingsInfo.terms => (
        widget.onTermsOfUse,
        'Terms of Use is not available yet.',
      ),
    };
    if (open == null) {
      setState(() => _message = unavailable);
      return;
    }
    setState(() {
      _openingInfo = true;
      _message = null;
    });
    try {
      await open();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to open. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _openingInfo = false);
    }
  }

  @override
  void dispose() {
    _local.removeListener(_localChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PCResponsiveDialog(
    designHeight: 389,
    child: SizedBox(
      key: const ValueKey('pcSettingsCanvas'),
      width: 360,
      height: 389,
      child: Stack(
        children: [
          const Positioned.fill(child: PCImg(name: 'pc_settings_panel')),
          Positioned(
            left: 131,
            top: 16,
            width: 101,
            height: 36,
            child: Semantics(
              header: true,
              label: 'Setting',
              child: const PCGradientStrokeText(
                text: 'Setting',
                gradientColors: [Colors.white, Color(0xFFFFF5B1)],
                strokeColor: Color(0xFF781184),
                strokeWidth: 2,
                fontSize: 28,
                width: 101,
                height: 36,
              ),
            ),
          ),
          Positioned(
            left: 60,
            top: 100,
            width: 112,
            height: 92,
            child: _toggleButton(
              backgroundMusic: false,
              enabled: _local.pc_sound_music,
              saving: _effectsSaving,
            ),
          ),
          Positioned(
            left: 188,
            top: 100,
            width: 112,
            height: 92,
            child: _toggleButton(
              backgroundMusic: true,
              enabled: _local.pc_bg_music,
              saving: _musicSaving,
            ),
          ),
          Positioned(
            left: 60,
            top: 212,
            width: 240,
            height: 56,
            child: _infoRow(privacy: true),
          ),
          Positioned(
            left: 60,
            top: 281,
            width: 240,
            height: 56,
            child: _infoRow(privacy: false),
          ),
          Positioned(
            left: 60,
            top: 339,
            width: 240,
            height: 44,
            child: Material(
              type: MaterialType.transparency,
              child: PCUnderlineTextButton(
                key: const ValueKey('pcSettingsTerms'),
                text: 'Terms of Use',
                fontSize: 12,
                textColor: const Color(0xFFFFF5B1),
                // 保留44高命中区，文案上移避开面板底部金边。
                padding: const EdgeInsets.only(bottom: 20),
                onPressed: _openingInfo
                    ? null
                    : () => _openInfo(_PCSettingsInfo.terms),
              ),
            ),
          ),
          if (_message != null)
            Positioned(
              left: 52,
              top: 58,
              width: 256,
              height: 32,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: PCText(
                  key: const ValueKey('pcSettingsMessage'),
                  text: _message!,
                  size: 11,
                  color: const Color(0xFFFFF5B1),
                  weight: FontWeight.w500,
                  align: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
          Positioned(
            left: 310,
            top: 0,
            width: 44,
            height: 44,
            child: Semantics(
              label: 'Close settings',
              button: true,
              child: ParticleButton(
                key: const ValueKey('pcSettingsClose'),
                onTap: () => Navigator.of(context).pop(),
                child: const Align(
                  alignment: Alignment(0, -.6),
                  child: PCImg(
                    name: 'pc_settings_close',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _toggleButton({
    required bool backgroundMusic,
    required bool enabled,
    required bool saving,
  }) {
    final name = backgroundMusic ? 'music' : 'volume';
    return Semantics(
      label: backgroundMusic ? 'Background music' : 'Sound effects',
      button: true,
      toggled: enabled,
      enabled: !saving,
      child: ParticleButton(
        key: ValueKey(
          backgroundMusic ? 'pcSettingsMusic' : 'pcSettingsEffects',
        ),
        enabled: !saving,
        onTap: () => _toggle(backgroundMusic: backgroundMusic),
        child: PCImg(
          name: 'pc_settings_${name}_${enabled ? 'on' : 'off'}',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _infoRow({required bool privacy}) => Semantics(
    label: privacy ? 'Privacy Policy' : 'Contact Us',
    button: true,
    child: ParticleButton(
      key: ValueKey(privacy ? 'pcSettingsPrivacy' : 'pcSettingsContact'),
      enabled: !_openingInfo,
      onTap: () => _openInfo(
        privacy ? _PCSettingsInfo.privacy : _PCSettingsInfo.contact,
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: PCImg(name: 'pc_settings_row_bg')),
          Positioned(
            left: 16,
            top: 16,
            width: 24,
            height: 24,
            child: PCImg(
              name: privacy
                  ? 'pc_settings_privacy_icon'
                  : 'pc_settings_contact_icon',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 44,
            right: 40,
            top: 18,
            height: 20,
            child: PCText(
              text: privacy ? 'Privacy Policy' : 'Contact Us',
              size: 14,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
          const Positioned(
            right: 16,
            top: 20,
            width: 16,
            height: 16,
            child: PCImg(name: 'pc_settings_arrow', fit: BoxFit.contain),
          ),
        ],
      ),
    ),
  );
}
