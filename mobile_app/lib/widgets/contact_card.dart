import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../models/contact_model.dart';

class ContactCard extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onDelete;

  const ContactCard({
    Key? key,
    required this.contact,
    required this.onDelete,
  }) : super(key: key);

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderStroke),
      ),
      child: Row(
        children: [
          // Contact Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryRed.withOpacity(0.15),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.brightCrimson,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Contact Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCardElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        contact.relationship,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Quick Call Button
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: AppTheme.accentGreen),
            tooltip: 'Call Contact',
            onPressed: () => _callPhone(contact.phone),
          ),

          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted),
            tooltip: 'Delete Contact',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
