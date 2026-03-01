import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../contacts/services/contact_service.dart';
import '../services/chat_service.dart';
import '../screens/call_screen.dart';

class DialerDialog extends ConsumerStatefulWidget {
  const DialerDialog({super.key});

  @override
  ConsumerState<DialerDialog> createState() => _DialerDialogState();
}

class _DialerDialogState extends ConsumerState<DialerDialog> {
  final _phoneController = TextEditingController(text: '+91');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Position cursor at the end of +91
    _phoneController.selection = TextSelection.fromPosition(
      TextPosition(offset: _phoneController.text.length),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startCall(bool isVideo) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = await ref
          .read(contactServiceProvider)
          .findUserByPhone(phone);

      if (user != null) {
        final userId = user['contactUserId'] ?? user['_id'];

        // Create/Get chat to get a valid chatId
        final chatRes = await ref.read(chatServiceProvider).createChat(userId);
        final chatData = chatRes['data'];
        final chat = chatData['chat'];
        final chatId = chat?['_id'];

        if (chatId == null) throw Exception('Failed to initialize chat');

        if (!mounted) return;
        Navigator.pop(context); // Close dialer

        Navigator.push(
          context,
          AnimatedPageRoute(
            builder: (_) => CallPage(
              chatId: chatId,
              userId: userId,
              callerName: user['name'] ?? user['serverName'] ?? phone,
              callerAvatar: user['avatar'] ?? '',
              isVideoCall: isVideo,
              isIncoming: false,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found on Infexor Chat'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Dial Number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter phone with country code',
                prefixIcon: const Icon(
                  Icons.phone_iphone,
                  color: AppColors.accentBlue,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _startCall(false),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _startCall(false),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.call),
                    label: const Text('Voice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _startCall(true),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.videocam),
                    label: const Text('Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
