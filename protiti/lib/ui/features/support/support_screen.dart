import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  final bool isDecoy;

  const SupportScreen({super.key, this.isDecoy = false});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDecoy) {
      return _buildDecoySupportView();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: const [
            Icon(Icons.support_agent, color: AppTheme.brandSecondary, size: 24),
            SizedBox(width: 8),
            Text(
              'Legal Aid & Support Bridge',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Confidential legal defense, pro-bono advocates, and psycho-social shelters across Bangladesh.',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        _buildSupportCard(
          name: 'BLAST (Bangladesh Legal Aid & Services Trust)',
          specialty: 'Pro-Bono Legal Aid & Cyber Litigations',
          phone: '+88028391970',
          location: 'Dhaka (National Coverage)',
          color: AppTheme.brandSecondary,
        ),
        const SizedBox(height: 12),
        _buildSupportCard(
          name: 'Ain o Salish Kendra (ASK)',
          specialty: 'Human Rights, Legal Counseling & Shelter',
          phone: '01726222222',
          location: 'Dhaka',
          color: AppTheme.accentSoft,
        ),
        const SizedBox(height: 12),
        _buildSupportCard(
          name: 'One-Stop Crisis Centre (OCC - DMCH)',
          specialty: 'Immediate Medical, Legal, & Forensic Support',
          phone: '+880255165088',
          location: 'Dhaka Medical College Hospital',
          color: AppTheme.panicRed,
        ),
        const SizedBox(height: 12),
        _buildSupportCard(
          name: 'Bangladesh Mahila Parishad',
          specialty: 'Women Legal Protection & Crisis Intervention',
          phone: '+88029587422',
          location: 'Sufia Kamal Bhaban, Dhaka',
          color: AppTheme.brandSecondary,
        ),
      ],
    );
  }

  Widget _buildSupportCard({
    required String name,
    required String specialty,
    required String phone,
    required String location,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: AppTheme.brandSecondary),
                  onPressed: () => _makePhoneCall(phone),
                  tooltip: 'Call $name',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              specialty,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.brandSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoySupportView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: const [
            Icon(Icons.school_outlined, color: AppTheme.brandSecondary, size: 24),
            SizedBox(width: 8),
            Text(
              'Student Services & Campus Directory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'University administrative contacts, student counseling, and academic advisement centers.',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        _buildSupportCard(
          name: 'Academic Affairs & Registrar',
          specialty: 'Transcript & Course Enrollments',
          phone: '+88029661900',
          location: 'Administrative Building',
          color: AppTheme.accentSoft,
        ),
        const SizedBox(height: 12),
        _buildSupportCard(
          name: 'Student Career Counseling Centre',
          specialty: 'Internship Placement & Skill Development',
          phone: '+88029661920',
          location: 'TSC 2nd Floor, Dhaka',
          color: AppTheme.brandSecondary,
        ),
      ],
    );
  }
}
