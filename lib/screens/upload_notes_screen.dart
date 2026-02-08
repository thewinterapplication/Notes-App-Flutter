import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/course.dart';
import '../services/api_service.dart';

/// Screen for uploading PDF notes
class UploadNotesScreen extends StatefulWidget {
  const UploadNotesScreen({super.key});

  @override
  State<UploadNotesScreen> createState() => _UploadNotesScreenState();
}

class _UploadNotesScreenState extends State<UploadNotesScreen> {
  File? _selectedFile;
  String? _selectedCourse;
  String? _selectedSubject;
  final TextEditingController _customFileNameController = TextEditingController();
  final TextEditingController _newSubjectController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingSubjects = false;
  List<String> _subjects = [];

  @override
  void dispose() {
    _customFileNameController.dispose();
    _newSubjectController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  Future<void> _loadSubjects(String course) async {
    setState(() {
      _isLoadingSubjects = true;
      _subjects = [];
      _selectedSubject = null;
    });

    final result = await ApiService.getSubjectsByCourse(course);

    setState(() {
      _isLoadingSubjects = false;
      if (result['success'] == true) {
        _subjects = List<String>.from(result['subjects'] ?? []);
      }
    });
  }

  void _showAddSubjectDialog() {
    _newSubjectController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Subject'),
        content: TextField(
          controller: _newSubjectController,
          decoration: InputDecoration(
            hintText: 'Enter subject name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newSubject = _newSubjectController.text.trim();
              if (newSubject.isNotEmpty) {
                setState(() {
                  if (!_subjects.contains(newSubject)) {
                    _subjects.add(newSubject);
                  }
                  _selectedSubject = newSubject;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D3E50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      _showSnackBar('Please select a PDF file', isError: true);
      return;
    }
    if (_selectedCourse == null) {
      _showSnackBar('Please select a course', isError: true);
      return;
    }
    if (_selectedSubject == null) {
      _showSnackBar('Please select or add a subject', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.uploadFile(
      file: _selectedFile!,
      course: _selectedCourse!,
      subject: _selectedSubject!,
      customFileName: _customFileNameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSnackBar('File uploaded successfully!');
      // Reset form
      setState(() {
        _selectedFile = null;
        _customFileNameController.clear();
      });
    } else {
      _showSnackBar(result['message'] ?? 'Upload failed', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D3E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Upload Notes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Picker Section
            _buildSectionCard(
              title: 'Select PDF File',
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedFile != null ? Icons.picture_as_pdf : Icons.cloud_upload_outlined,
                            size: 48,
                            color: _selectedFile != null ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFile != null
                                ? _selectedFile!.path.split(Platform.pathSeparator).last
                                : 'Tap to select PDF file',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedFile != null ? Colors.black87 : Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Change File'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Custom File Name
            _buildSectionCard(
              title: 'Custom File Name (Optional)',
              child: TextField(
                controller: _customFileNameController,
                decoration: InputDecoration(
                  hintText: 'Enter custom name (without .pdf)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Course Selection
            _buildSectionCard(
              title: 'Select Course',
              child: DropdownButtonFormField<String>(
                value: _selectedCourse,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                hint: const Text('Choose a course'),
                isExpanded: true,
                items: Course.allCourses.map((course) {
                  return DropdownMenuItem(
                    value: course.abbreviation,
                    child: Text(course.abbreviation),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCourse = value;
                  });
                  if (value != null) {
                    _loadSubjects(value);
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Subject Selection
            _buildSectionCard(
              title: 'Select Subject',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _isLoadingSubjects
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedSubject,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                hint: Text(
                                  _selectedCourse == null
                                      ? 'Select a course first'
                                      : _subjects.isEmpty
                                          ? 'No subjects - add one'
                                          : 'Choose a subject',
                                ),
                                items: _subjects.map((subject) {
                                  return DropdownMenuItem(
                                    value: subject,
                                    child: Text(subject),
                                  );
                                }).toList(),
                                onChanged: _selectedCourse == null
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedSubject = value;
                                        });
                                      },
                              ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _selectedCourse == null ? null : _showAddSubjectDialog,
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFF2D3E50),
                        iconSize: 32,
                        tooltip: 'Add new subject',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Upload Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3E50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Upload Notes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3E50),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
