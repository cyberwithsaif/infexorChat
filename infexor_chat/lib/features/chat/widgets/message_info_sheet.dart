import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

/// Shows message delivery info (sent, delivered, read) like WhatsApp
void showMessageInfoSheet({
  required BuildContext context,
  required Map<String, dynamic> message,
}) {
  final createdAt = message['createdAt'] ?? message['timestamp'];
  final status = message['status']?.toString() ?? 'sent';
  final fmt = DateFormat('dd MMM yyyy, hh:mm a');

  DateTime? sentTime;
  try {
    sentTime = createdAt is String ? DateTime.parse(createdAt).toLocal() : null;
  } catch (_) {}

  // Derive timestamps from status
  DateTime? deliveredTime;
  DateTime? readTime;

  if (status == 'delivered' || status == 'read') {
    // If message has explicit delivery/read timestamps, use them
    final deliveredAt = message['deliveredAt'];
    final readAt = message['readAt'];

    if (deliveredAt != null) {
      try {
        deliveredTime = DateTime.parse(deliveredAt.toString()).toLocal();
      } catch (_) {}
    }
    if (readAt != null) {
      try {
        readTime = DateTime.parse(readAt.toString()).toLocal();
      } catch (_) {}
    }

    // Fallback: if no explicit timestamps, use sentTime + offset
    deliveredTime ??= sentTime;
    if (status == 'read') {
      readTime ??= deliveredTime;
    }
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              Text(
                'Message Info',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16.h),

              // Message preview
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message['content']?.toString() ?? '[ Media ]',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 20.h),

              // Sent
              _InfoRow(
                icon: Icons.check,
                iconColor: AppColors.textMuted,
                label: 'Sent',
                time: sentTime != null ? fmt.format(sentTime) : '—',
              ),
              SizedBox(height: 12.h),

              // Delivered
              _InfoRow(
                icon: Icons.done_all,
                iconColor: deliveredTime != null
                    ? AppColors.textMuted
                    : AppColors.textMuted.withValues(alpha: 0.3),
                label: 'Delivered',
                time: deliveredTime != null ? fmt.format(deliveredTime) : '—',
              ),
              SizedBox(height: 12.h),

              // Read
              _InfoRow(
                icon: Icons.done_all,
                iconColor: readTime != null
                    ? Colors.blue
                    : AppColors.textMuted.withValues(alpha: 0.3),
                label: 'Read',
                time: readTime != null ? fmt.format(readTime) : '—',
              ),

              SizedBox(height: 16.h),
            ],
          ),
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String time;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20.sp),
        SizedBox(width: 12.w),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          time,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
      ],
    );
  }
}
