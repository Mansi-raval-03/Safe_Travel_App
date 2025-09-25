import 'package:flutter/material.dart';

class EmergencyInfoSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController emergencyInfoController;
  final TextEditingController medicalConditionsController;
  final TextEditingController bloodTypeController;
  final TextEditingController allergiesController;

  const EmergencyInfoSection({
    Key? key,
    required this.isEditing,
    required this.emergencyInfoController,
    required this.medicalConditionsController,
    required this.bloodTypeController,
    required this.allergiesController,
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
              'Emergency Information',
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
                    child: _buildEditableField('Blood Type', bloodTypeController, 'e.g., A+, O-, B+'),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildEditableField('Emergency Contact Info', emergencyInfoController, 'Primary emergency contact'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildEditableTextArea('Medical Conditions', medicalConditionsController, 'List any medical conditions emergency responders should know about'),
              SizedBox(height: 16),
              _buildEditableTextArea('Allergies', allergiesController, 'List any allergies or medications to avoid'),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildEmptyInfo('Blood Type'),
                  ),
                  SizedBox(width: 24),
                  Expanded(
                    child: _buildEmptyInfo('Emergency Contact'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildEmptyInfo('Medical Conditions'),
              SizedBox(height: 16),
              _buildEmptyInfo('Allergies'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  border: Border.all(color: Colors.yellow.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.yellow.shade600, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complete your emergency information to help first responders assist you better.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.yellow.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, String hint) {
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
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableTextArea(String label, TextEditingController controller, String hint) {
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
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyInfo(String label) {
    return Column(
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
          'Not specified',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}