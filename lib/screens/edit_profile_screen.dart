import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  const EditProfileScreen({super.key, required this.initialProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _vehicleBrandController;
  late TextEditingController _vehicleModelController;
  late TextEditingController _licensePlateController;
  
  String _selectedVehicleType = 'Car';
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  File? _selectedImage;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _vehicleTypes = [
    'Car', 'Bike', 'Truck', 'Van', 'Auto Rickshaw', 'Bus', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile['name']);
    _phoneController = TextEditingController(text: widget.initialProfile['phone']);
    _vehicleBrandController = TextEditingController(text: widget.initialProfile['vehicleBrand']);
    _vehicleModelController = TextEditingController(text: widget.initialProfile['vehicleModel']);
    _licensePlateController = TextEditingController(text: widget.initialProfile['licensePlate']);
    
    _selectedVehicleType = widget.initialProfile['vehicleType'] ?? 'Car';
    if (_selectedVehicleType.isEmpty) _selectedVehicleType = 'Car';
    
    _profileImageUrl = widget.initialProfile['profileImageUrl'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _authService.saveUserProfile(
          uid: user.uid,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: user.email ?? widget.initialProfile['email'] ?? '',
          vehicleType: _selectedVehicleType,
          vehicleBrand: _vehicleBrandController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim(),
          licensePlate: _licensePlateController.text.trim(),
        );

        // Upload Profile Photo if changed
        if (_selectedImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${user.uid}.jpg');
          await storageRef.putFile(_selectedImage!);
          final downloadUrl = await storageRef.getDownloadURL();
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'profileImageUrl': downloadUrl}, SetOptions(merge: true));
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                                ? NetworkImage(_profileImageUrl!) as ImageProvider
                                : null,
                        child: _selectedImage == null && 
                               (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 50, color: Colors.blue)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              const Text("Personal Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildTextField(_nameController, "Full Name", Icons.person_outline),
              const SizedBox(height: 15),
              _buildTextField(_phoneController, "Phone Number", Icons.phone_outlined, keyboardType: TextInputType.phone),
              
              const SizedBox(height: 30),
              const Text("Vehicle Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedVehicleType,
                decoration: _inputDecoration("Vehicle Type", Icons.category_outlined),
                items: _vehicleTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => _selectedVehicleType = val!),
              ),
              const SizedBox(height: 15),
              _buildTextField(_vehicleBrandController, "Vehicle Brand", Icons.branding_watermark_outlined),
              const SizedBox(height: 15),
              _buildTextField(_vehicleModelController, "Vehicle Model", Icons.info_outline),
              const SizedBox(height: 15),
              _buildTextField(_licensePlateController, "License Plate", Icons.confirmation_number_outlined),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SAVE CHANGES",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label, icon),
      validator: (val) => (label.contains('optional') || !label.contains('Name')) ? null : (val!.isEmpty ? 'Required field' : null),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

