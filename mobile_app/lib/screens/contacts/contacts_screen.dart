import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/contact_model.dart';
import '../../services/api_service.dart';
import '../../widgets/contact_card.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactModel> _contacts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ApiService.getContacts();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _contacts = res.data!;
      } else {
        _error = res.message;
      }
    });
  }

  void _showAddContactModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRel = 'Family';
    final relOptions = ['Family', 'Spouse', 'Parent', 'Friend', 'Doctor', 'Neighbor', 'Colleague'];
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
                  const Text(
                    'Add Emergency Contact',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              const Text('Contact Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. Papa, Sister, Pooja',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 14),

              // Phone
              const Text('Phone Number (for SMS)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '+91 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 14),

              // Relationship
              const Text('Relationship', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedRel,
                dropdownColor: AppTheme.surfaceCardElevated,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.people_outline_rounded, color: AppTheme.textMuted),
                ),
                items: relOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedRel = val);
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter name and phone number')),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);
                          final addRes = await ApiService.addContact(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            relationship: selectedRel,
                          );

                          if (!mounted) return;
                          Navigator.pop(ctx);

                          if (addRes.success) {
                            _loadContacts();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Emergency contact added!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(addRes.message)),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteContact(ContactModel contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contact?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove ${contact.name} from emergency contacts?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.deleteContact(contact.id);
              if (res.success) {
                _loadContacts();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.brightCrimson, size: 28),
            tooltip: 'Add Emergency Contact',
            onPressed: _showAddContactModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              onRefresh: _loadContacts,
              color: AppTheme.primaryRed,
              child: _contacts.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.borderStroke),
                                ),
                                child: const Icon(Icons.group_add_rounded, size: 44, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'No Emergency Contacts Added',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'Add your closest family, friends, or doctor so they receive SMS with live GPS when SOS is triggered.',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _showAddContactModal,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add First Contact'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return ContactCard(
                          contact: contact,
                          onDelete: () => _deleteContact(contact),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        onPressed: _showAddContactModal,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
