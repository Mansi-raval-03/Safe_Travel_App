import 'package:flutter/material.dart';
import '../../models/user.dart';

class BasicInfoSection extends StatelessWidget {
  final User? user;
  final bool isEditing;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final Map<String, String> errors;
  final Function(String) onClearError;

  const BasicInfoSection({
    Key? key,
    required this.user,
    required this.isEditing,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.errors,
    required this.onClearError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            if (isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      'Full Name',
                      nameController,
                      'name',
                      onClearError,
                      errors,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildEditableField(
                      'Phone Number',
                      phoneController,
                      'phone',
                      onClearError,
                      errors,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildEditableField(
                'Email Address',
                emailController,
                'email',
                onClearError,
                errors,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.person, 'Full Name', user?.name ?? 'Not specified'),
                        SizedBox(height: 16),
                        _buildInfoRow(Icons.email, 'Email', user?.email ?? 'Not specified'),
                      ],
                    ),
                  ),
                  SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.phone, 'Phone', user?.phone ?? 'Not specified'),
                        SizedBox(height: 16),
                        _buildInfoRow(Icons.location_on, 'Location', '123 Main Street, Downtown'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    String fieldKey,
    Function(String) onClearError,
    Map<String, String> errors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: (_) => onClearError(fieldKey),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errors.containsKey(fieldKey) ? Colors.red : Colors.grey.shade300,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        if (errors.containsKey(fieldKey))
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              errors[fieldKey]!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}