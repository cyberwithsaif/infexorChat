import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/api_client.dart';
import 'package:dio/dio.dart';

class VerificationRequestScreen extends ConsumerStatefulWidget {
  const VerificationRequestScreen({super.key});

  @override
  ConsumerState<VerificationRequestScreen> createState() =>
      _VerificationRequestScreenState();
}

class _VerificationRequestScreenState
    extends ConsumerState<VerificationRequestScreen> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason (at least 5 characters)'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.verificationRequest,
        data: {'reason': reason},
      );

      if (!mounted) return;

      // Refresh user profile to get updated verification status
      final profileRes = await ref
          .read(apiClientProvider)
          .get(ApiEndpoints.profile);
      final freshUser = profileRes.data?['data']?['user'];
      if (freshUser != null) {
        ref
            .read(authProvider.notifier)
            .updateUserLocally(Map<String, dynamic>.from(freshUser));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.data?['message'] ?? 'Request submitted!'),
          backgroundColor: Colors.green,
        ),
      );

      _reasonController.clear();
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Failed to submit request';
      if (e is DioException && e.response?.data != null) {
        errorMsg = e.response?.data['message']?.toString() ?? errorMsg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isVerified = user?['isVerified'] == true;
    final verificationRequest =
        user?['verificationRequest'] as Map<String, dynamic>? ?? {};
    final requestStatus = verificationRequest['status']?.toString() ?? 'none';
    final adminNote = verificationRequest['adminNote']?.toString() ?? '';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFFAF8F5);
    final cardColor = isDark ? const Color(0xFF202C33) : Colors.white;
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    final subtitleColor =
        theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.grey[400]! : Colors.grey);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primaryPurple),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Verification',
          style: TextStyle(
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark
                ? Colors.grey.withValues(alpha: 0.1)
                : const Color(0xFFF0F2F5),
            height: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isVerified
                        ? const Color(0xFF1DA1F2).withValues(alpha: 0.1)
                        : requestStatus == 'pending'
                        ? Colors.orange.withValues(alpha: 0.1)
                        : requestStatus == 'rejected'
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.primaryPurple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVerified
                        ? Icons.verified
                        : requestStatus == 'pending'
                        ? Icons.hourglass_empty
                        : requestStatus == 'rejected'
                        ? Icons.cancel_outlined
                        : Icons.verified_outlined,
                    size: 40,
                    color: isVerified
                        ? const Color(0xFF1DA1F2)
                        : requestStatus == 'pending'
                        ? Colors.orange
                        : requestStatus == 'rejected'
                        ? Colors.red
                        : AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 16),
                // Status text
                Text(
                  isVerified
                      ? 'You are Verified!'
                      : requestStatus == 'pending'
                      ? 'Verification Pending'
                      : requestStatus == 'rejected'
                      ? 'Request Rejected'
                      : 'Get Verified',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVerified
                      ? 'Your account has been verified. The blue tick badge is now visible on your profile.'
                      : requestStatus == 'pending'
                      ? 'Your verification request is under review. We\'ll update you once it\'s processed.'
                      : requestStatus == 'rejected'
                      ? 'Your verification request was not approved.'
                      : 'Request a blue tick badge to let others know your account is authentic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(height: 16),
                  const VerifiedBadge(size: 32),
                ],
                if (requestStatus == 'rejected' && adminNote.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Note:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adminNote,
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Request Form (show when not verified and not pending)
          if (!isVerified && requestStatus != 'pending') ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestStatus == 'rejected'
                        ? 'Submit a New Request'
                        : 'Request Verification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tell us why you should be verified.',
                    style: TextStyle(fontSize: 13, color: subtitleColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    maxLength: 500,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'e.g., I am a public figure, brand, or notable person...',
                      hintStyle: TextStyle(color: subtitleColor, fontSize: 13),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1A252D)
                          : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryPurple,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DA1F2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Request',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Info section
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Verification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                _infoItem(
                  Icons.verified,
                  'What is the blue tick?',
                  'A verified badge confirms your account is the authentic presence of the person or brand it represents.',
                  textColor,
                  subtitleColor,
                ),
                const SizedBox(height: 12),
                _infoItem(
                  Icons.fact_check_outlined,
                  'Requirements',
                  'You need a complete profile with a name and photo to request verification.',
                  textColor,
                  subtitleColor,
                ),
                const SizedBox(height: 12),
                _infoItem(
                  Icons.schedule,
                  'Review Process',
                  'Requests are reviewed by our team. You\'ll be notified of the outcome.',
                  textColor,
                  subtitleColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoItem(
    IconData icon,
    String title,
    String description,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1DA1F2)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
