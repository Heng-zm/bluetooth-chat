import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../models/message_model.dart';
import '../theme/app_theme.dart';
import '../widgets/glow_container.dart';
import 'home_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showEncrypted = false;

  @override
  void initState() {
    super.initState();
    // Scroll to bottom on new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothService>().addListener(_onMessagesChanged);
    });
  }

  void _onMessagesChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothService>(
      builder: (context, service, _) {
        if (!service.isConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          });
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: AppTheme.bgDeep,
          appBar: _buildAppBar(context, service),
          body: Column(
            children: [
              _buildEncryptionBadge(service),
              Expanded(child: _buildMessageList(service)),
              _buildInputBar(service),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, BluetoothService service) {
    return AppBar(
      backgroundColor: AppTheme.bgDeep,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios,
            color: AppTheme.accentCyan, size: 18),
        onPressed: () async {
          await service.disconnect();
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.connectedDeviceName ?? 'Unknown Device',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'CONNECTED · ENCRYPTED',
                style: TextStyle(
                  color: AppTheme.accentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showEncrypted ? Icons.lock_open : Icons.lock,
            color: _showEncrypted ? AppTheme.warning : AppTheme.textSecondary,
            size: 20,
          ),
          onPressed: () => setState(() => _showEncrypted = !_showEncrypted),
          tooltip: _showEncrypted ? 'Hide cipher' : 'Show raw cipher',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
          color: AppTheme.bgCard,
          onSelected: (value) async {
            if (value == 'disconnect') {
              await service.disconnect();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'disconnect',
              child: Row(
                children: [
                  Icon(Icons.bluetooth_disabled,
                      color: AppTheme.danger, size: 18),
                  SizedBox(width: 10),
                  Text('Disconnect', style: TextStyle(color: AppTheme.danger)),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.borderGlow),
      ),
    );
  }

  Widget _buildEncryptionBadge(BluetoothService service) {
    final hashPreview = service.encryptionService.runtimeType.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.bgSurface,
      child: Row(
        children: [
          const Icon(Icons.shield, color: AppTheme.accentGreen, size: 14),
          const SizedBox(width: 8),
          const Text(
            'End-to-end encrypted with AES-256-CBC',
            style: TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showEncrypted = !_showEncrypted),
            child: Text(
              _showEncrypted ? 'HIDE CIPHER' : 'VIEW CIPHER',
              style: const TextStyle(
                color: AppTheme.accentCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BluetoothService service) {
    if (service.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgCard,
                border: Border.all(color: AppTheme.borderGlow),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: AppTheme.accentCyan,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'SECURE CHANNEL OPEN',
              style: TextStyle(
                color: AppTheme.accentCyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Messages are encrypted before sending',
              style: TextStyle(
                color: AppTheme.textDim,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: service.messages.length,
      itemBuilder: (context, index) {
        final message = service.messages[index];
        final prevMessage = index > 0 ? service.messages[index - 1] : null;
        final showTime = prevMessage == null ||
            message.timestamp.difference(prevMessage.timestamp).inMinutes > 2;

        return Column(
          children: [
            if (showTime) _buildTimeDivider(message.timestamp),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }

  Widget _buildTimeDivider(DateTime time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppTheme.borderGlow, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatTime(time),
              style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppTheme.borderGlow, height: 1)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMine) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgCard,
                border: Border.all(color: AppTheme.borderGlow),
              ),
              child: const Icon(
                Icons.bluetooth,
                size: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(message.text),
              child: Column(
                crossAxisAlignment: message.isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight:
                            message.isMine ? const Radius.circular(4) : null,
                        bottomLeft:
                            !message.isMine ? const Radius.circular(4) : null,
                      ),
                      gradient: message.isMine
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF0A3D62),
                                Color(0xFF0C2E4D),
                              ],
                            )
                          : null,
                      color: message.isMine ? null : AppTheme.theirBubble,
                      border: Border.all(
                        color: message.isMine
                            ? AppTheme.accentCyan.withOpacity(0.25)
                            : AppTheme.borderGlow,
                      ),
                      boxShadow: message.isMine
                          ? [
                              BoxShadow(
                                color: AppTheme.accentCyan.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.isDecryptionError)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber,
                                  color: AppTheme.warning, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                message.text,
                                style: const TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            message.text,
                            style: TextStyle(
                              color: message.isMine
                                  ? AppTheme.textPrimary
                                  : AppTheme.textPrimary.withOpacity(0.9),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        if (_showEncrypted) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.warning.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              message.encryptedText.length > 40
                                  ? '${message.encryptedText.substring(0, 40)}...'
                                  : message.encryptedText,
                              style: const TextStyle(
                                color: AppTheme.warning,
                                fontSize: 9,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 9, color: AppTheme.textDim),
                      const SizedBox(width: 3),
                      Text(
                        message.timeString,
                        style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message.isMine) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentCyan.withOpacity(0.15),
                border: Border.all(
                  color: AppTheme.accentCyan.withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.person,
                size: 14,
                color: AppTheme.accentCyan,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(BluetoothService service) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(top: BorderSide(color: AppTheme.borderGlow)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentCyan.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Type encrypted message...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textDim,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppTheme.textDim,
                    size: 16,
                  ),
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.borderGlow),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.borderGlow),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppTheme.accentCyan,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(service),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 10),
            GlowContainer(
              child: GestureDetector(
                onTap: () => _sendMessage(service),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accentCyan,
                        AppTheme.accentTeal,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: AppTheme.bgDeep,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(BluetoothService service) {
    if (_controller.text.trim().isEmpty) return;
    service.sendMessage(_controller.text);
    _controller.clear();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
