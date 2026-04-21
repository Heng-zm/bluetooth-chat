import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/encryption_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _passphraseController = TextEditingController();
  bool _obscure = true;
  String? _currentHashPreview;

  @override
  void initState() {
    super.initState();
    _currentHashPreview =
        EncryptionService.hashPreview('BT_CHAT_SECURE_KEY_2024');
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        title: const Text('SECURITY SETTINGS'),
        backgroundColor: AppTheme.bgDeep,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderGlow),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildPassphraseSection(),
            const SizedBox(height: 24),
            _buildKeyInfo(),
            const SizedBox(height: 24),
            _buildSecurityTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentCyan.withOpacity(0.1),
            AppTheme.accentPurple.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: AppTheme.accentCyan, size: 22),
              const SizedBox(width: 10),
              const Text(
                'ENCRYPTION STATUS',
                style: TextStyle(
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStatusRow('Algorithm', 'AES-256-CBC'),
          _buildStatusRow('Key Derivation', 'SHA-256'),
          _buildStatusRow('IV Generation', 'MD5 of passphrase'),
          _buildStatusRow(
            'Key Hash',
            _currentHashPreview ?? '--------',
            mono: true,
            color: AppTheme.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value,
      {bool mono = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppTheme.textPrimary,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassphraseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHARED PASSPHRASE',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Both devices must use the same passphrase to decrypt messages.',
          style: TextStyle(
            color: AppTheme.textDim,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passphraseController,
          obscureText: _obscure,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Enter passphrase...',
            prefixIcon:
                const Icon(Icons.key, color: AppTheme.textDim, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              setState(() {
                _currentHashPreview = EncryptionService.hashPreview(value);
              });
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _generatePassphrase,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('GENERATE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.accentCyan),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _applyPassphrase,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('APPLY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: AppTheme.bgDeep,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyInfo() {
    final preview = _passphraseController.text.isEmpty
        ? null
        : EncryptionService.hashPreview(_passphraseController.text);

    if (preview == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.bgCard,
        border: Border.all(color: AppTheme.borderGlow),
      ),
      child: Row(
        children: [
          const Icon(Icons.fingerprint, color: AppTheme.accentPurple, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KEY FINGERPRINT',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                preview,
                style: const TextStyle(
                  color: AppTheme.accentPurple,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: preview));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fingerprint copied')),
              );
            },
            icon: const Icon(Icons.copy, color: AppTheme.textDim, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTips() {
    final tips = [
      (
        '🔐',
        'Share the same passphrase with the other user through a secure channel.'
      ),
      ('🔄', 'Change passphrase regularly for better security.'),
      ('📋', 'Compare key fingerprints to verify you both use the same key.'),
      ('⚠️', 'Messages encrypted with different passphrases cannot be read.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SECURITY TIPS',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.$1, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip.$2,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _generatePassphrase() {
    final generated = EncryptionService.generatePassphrase();
    _passphraseController.text = generated;
    setState(() {
      _currentHashPreview = EncryptionService.hashPreview(generated);
      _obscure = false;
    });
  }

  void _applyPassphrase() {
    final passphrase = _passphraseController.text.trim();
    if (passphrase.isEmpty) return;

    context.read<BluetoothService>().updatePassphrase(passphrase);
    setState(() {
      _currentHashPreview = EncryptionService.hashPreview(passphrase);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Passphrase updated successfully'),
        backgroundColor: AppTheme.accentGreen.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
