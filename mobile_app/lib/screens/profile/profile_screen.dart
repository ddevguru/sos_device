import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    // Cached first
    _user = StorageService.getUser();

    // Fresh from API
    final res = await ApiService.getProfile();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _user = res.data;
        }
      });
    }
  }

  void _showEditProfileModal() {
    if (_user == null) return;

    final nameCtrl = TextEditingController(text: _user!.name);
    final phoneCtrl = TextEditingController(text: _user!.phone);
    final notesCtrl = TextEditingController(text: _user!.medicalNotes);
    String blood = _user!.bloodGroup.isNotEmpty ? _user!.bloodGroup : 'B+';
    final bloodOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Profile & Medical Info',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted)),
              ),
              const SizedBox(height: 14),

              const Text('Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted)),
              ),
              const SizedBox(height: 14),

              const Text('Blood Group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: bloodOptions.contains(blood) ? blood : 'B+',
                dropdownColor: AppTheme.surfaceCardElevated,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.bloodtype_outlined, color: AppTheme.brightCrimson),
                ),
                items: bloodOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => blood = val);
                },
              ),
              const SizedBox(height: 14),

              const Text('Medical Notes / Allergies', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. Diabetic, Asthma, Penicillin allergy',
                  prefixIcon: Icon(Icons.medical_services_outlined, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          final res = await ApiService.updateProfile(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            bloodGroup: blood,
                            medicalNotes: notesCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          if (res.success && res.data != null) {
                            setState(() => _user = res.data);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile updated successfully!')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomSosMessageModal() {
    final controller = TextEditingController(text: StorageService.getCustomSosMessage());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Predefined SOS Message',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This message is sent via SMS to all emergency contacts when SOS is triggered:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Enter emergency alert text...',
                  helperText: 'Available placeholders: {location}, {name}, {phone}',
                  helperStyle: TextStyle(fontSize: 11, color: AppTheme.accentCyan),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      controller.text = AppConstants.defaultSosMessageTemplate;
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textMuted),
                    label: const Text('Reset Default', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;

                            setModalState(() => isSaving = true);
                            await StorageService.saveCustomSosMessage(text);
                            await ApiService.updateProfile(customSosMessage: text);

                            if (!mounted) return;
                            Navigator.pop(ctx);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Custom SOS Message saved!')),
                            );
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Message'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerUrlDialog() {
    final controller = TextEditingController(text: StorageService.getBaseUrl());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Backend API URL', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set IP address of your PC running the Express backend:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'http://192.168.1.100:5000/api'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              await StorageService.saveBaseUrl(controller.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend URL saved!')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out from this device?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.clearAll();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairedDevice = StorageService.getPairedDevice();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileModal,
          ),
        ],
      ),
      body: _isLoading && _user == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // User Avatar & Name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppTheme.primaryRed.withOpacity(0.18),
                          child: Text(
                            (_user?.name.isNotEmpty ?? false) ? _user!.name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.brightCrimson,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _user?.name ?? 'User',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? '',
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Medical & Emergency Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderStroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medical_services_rounded, color: AppTheme.brightCrimson, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Medical & Vital Info',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.brightCrimson.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _user?.bloodGroup.isNotEmpty ?? false ? _user!.bloodGroup : 'Not set',
                                style: const TextStyle(
                                  color: AppTheme.brightCrimson,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: AppTheme.borderStroke, height: 24),
                        const Text('Registered Phone Number', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        Text(_user?.phone ?? 'Not provided', style: const TextStyle(fontSize: 15, color: Colors.white)),
                        const SizedBox(height: 14),
                        const Text('Medical Notes & Allergies', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          (_user?.medicalNotes.isNotEmpty ?? false) ? _user!.medicalNotes : 'None added',
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paired Hardware Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderStroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.bluetooth_connected_rounded, color: AppTheme.accentCyan),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Paired IoT Device', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              const SizedBox(height: 2),
                              Text(
                                pairedDevice?.deviceName ?? 'No Device Paired',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              if (pairedDevice != null)
                                Text(
                                  'ID: ${pairedDevice.deviceIdentifier}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Predefined SOS Message Tile
                  ListTile(
                    tileColor: AppTheme.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.borderStroke),
                    ),
                    leading: const Icon(Icons.sms_rounded, color: AppTheme.brightCrimson),
                    title: const Text('Custom Predefined SOS Message', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    subtitle: Text(
                      StorageService.getCustomSosMessage(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.edit_outlined, color: AppTheme.textMuted),
                    onTap: _showCustomSosMessageModal,
                  ),
                  const SizedBox(height: 14),

                  // Settings / Config Server
                  ListTile(
                    tileColor: AppTheme.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.borderStroke),
                    ),
                    leading: const Icon(Icons.dns_rounded, color: AppTheme.accentAmber),
                    title: const Text('Backend Server URL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    subtitle: Text(StorageService.getBaseUrl(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                    onTap: _showServerUrlDialog,
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryRed,
                        side: const BorderSide(color: AppTheme.primaryRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
