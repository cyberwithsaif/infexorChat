import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  String _lastSeen = 'everyone';
  String _profilePhoto = 'everyone';
  String _about = 'everyone';
  bool _readReceipts = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final privacy = user?['privacySettings'] as Map<String, dynamic>? ?? {};

    setState(() {
      _lastSeen = privacy['lastSeen']?.toString() ?? 'everyone';
      _profilePhoto = privacy['profilePhoto']?.toString() ?? 'everyone';
      _about = privacy['about']?.toString() ?? 'everyone';
      _readReceipts = privacy['readReceipts'] ?? true;
      _isLoading = false;
    });
  }

  Future<void> _updatePrivacy(Map<String, dynamic> updates) async {
    // Save previous values for rollback on failure
    final prevLastSeen = _lastSeen;
    final prevProfilePhoto = _profilePhoto;
    final prevAbout = _about;
    final prevReadReceipts = _readReceipts;

    try {
      final api = ref.read(apiClientProvider);
      await api.put(
        ApiEndpoints.privacySettings,
        data: updates,
      );

      // Update local auth state so the change persists
      final authNotifier = ref.read(authProvider.notifier);
      final currentUser = ref.read(authProvider).user;
      if (currentUser != null) {
        final updatedUser = Map<String, dynamic>.from(currentUser);
        final privacy = Map<String, dynamic>.from(
          updatedUser['privacySettings'] as Map? ?? {},
        );
        privacy.addAll(updates);
        updatedUser['privacySettings'] = privacy;
        authNotifier.updateUserLocally(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Privacy updated')));
      }
    } catch (e) {
      // Revert UI state on failure
      if (mounted) {
        setState(() {
          _lastSeen = prevLastSeen;
          _profilePhoto = prevProfilePhoto;
          _about = prevAbout;
          _readReceipts = prevReadReceipts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showOptionPicker(
    String title,
    String currentValue,
    Function(String) onChanged,
  ) async {
    final theme = Theme.of(context);
    final sheetBg = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final options = [
      {'value': 'everyone', 'label': 'Everyone'},
      {'value': 'contacts', 'label': 'My Contacts'},
      {'value': 'nobody', 'label': 'Nobody'},
    ];

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...options.map(
            (opt) => RadioListTile<String>(
              title: Text(
                opt['label']!,
                style: TextStyle(color: textColor),
              ),
              value: opt['value']!,
              groupValue: currentValue,
              activeColor: AppColors.accentBlue,
              onChanged: (val) => Navigator.pop(ctx, val),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          title: Text(
            'Privacy',
            style: TextStyle(color: textColor),
          ),
          iconTheme: IconThemeData(color: textColor),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accentBlue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Privacy',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'WHO CAN SEE MY PERSONAL INFO',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),

          _PrivacyTile(
            title: 'Last Seen',
            value: _capitalize(_lastSeen),
            onTap: () => _showOptionPicker('Last Seen', _lastSeen, (val) {
              setState(() => _lastSeen = val);
              _updatePrivacy({'lastSeen': val});
            }),
          ),
          _PrivacyTile(
            title: 'Profile Photo',
            value: _capitalize(_profilePhoto),
            onTap: () =>
                _showOptionPicker('Profile Photo', _profilePhoto, (val) {
                  setState(() => _profilePhoto = val);
                  _updatePrivacy({'profilePhoto': val});
                }),
          ),
          _PrivacyTile(
            title: 'About',
            value: _capitalize(_about),
            onTap: () => _showOptionPicker('About', _about, (val) {
              setState(() => _about = val);
              _updatePrivacy({'about': val});
            }),
          ),

          const Divider(height: 1),

          SwitchListTile(
            title: Text(
              'Read Receipts',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'If turned off, you won\'t send or receive read receipts',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _readReceipts,
            activeThumbColor: AppColors.accentBlue,
            onChanged: (val) {
              setState(() => _readReceipts = val);
              _updatePrivacy({'readReceipts': val});
            },
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s == 'everyone') return 'Everyone';
    if (s == 'contacts') return 'My Contacts';
    if (s == 'nobody') return 'Nobody';
    return s;
  }
}

class _PrivacyTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _PrivacyTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.accentBlue, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: subtitleColor, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
