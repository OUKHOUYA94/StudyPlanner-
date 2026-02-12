import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import 'assessments_providers.dart';

/// Page for creating or editing an assessment (teacher only).
/// Pass [assessment] for edit mode; leave null for create mode.
class AssessmentFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? assessment;

  const AssessmentFormPage({super.key, this.assessment});

  @override
  ConsumerState<AssessmentFormPage> createState() => _AssessmentFormPageState();
}

class _AssessmentFormPageState extends ConsumerState<AssessmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  String? _selectedClassId;
  String? _selectedSubjectId;
  String _selectedType = 'exam';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  List<String> _classIds = [];
  /// Maps subjectId → subjectName for the dropdown.
  Map<String, String> _subjectMap = {};
  bool _loadingSubjects = false;
  bool _submitting = false;

  bool get _isEditing => widget.assessment != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final a = widget.assessment!;
      _titleController.text = a['title'] as String;
      _selectedClassId = a['classId'] as String;
      _selectedSubjectId = a['subjectId'] as String;
      _selectedType = a['type'] as String;
      final dt = a['dateTime'] as DateTime;
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects(String classId) async {
    setState(() => _loadingSubjects = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      var query = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('subjects')
          .orderBy('name');

      // Teacher: only their own subjects
      if (uid != null) {
        query = query.where('teacherUid', isEqualTo: uid);
      }

      final snap = await query.get();

      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        map[doc.id] = (data['name'] as String?) ?? doc.id;
      }

      setState(() {
        _subjectMap = map;
        if (!_subjectMap.containsKey(_selectedSubjectId)) {
          _selectedSubjectId =
              _subjectMap.isNotEmpty ? _subjectMap.keys.first : null;
        }
        _loadingSubjects = false;
      });
    } catch (e) {
      setState(() => _loadingSubjects = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null || _selectedSubjectId == null) return;

    setState(() => _submitting = true);

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      if (_isEditing) {
        await callUpdateAssessment(
          classId: _selectedClassId!,
          assessmentId: widget.assessment!['assessmentId'] as String,
          title: _titleController.text.trim(),
          type: _selectedType,
          subjectId: _selectedSubjectId,
          dateTime: dateTime,
        );
      } else {
        await callCreateAssessment(
          classId: _selectedClassId!,
          subjectId: _selectedSubjectId!,
          title: _titleController.text.trim(),
          type: _selectedType,
          dateTime: dateTime,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Examen mis à jour avec succès.'
                : 'Examen créé avec succès.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        // Extract Firebase function error message
        if (message.contains(']')) {
          message = message.substring(message.lastIndexOf(']') + 1).trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    if (_classIds.isEmpty && appUser != null) {
      _classIds = appUser.teacherClassIds ?? [];
      if (_selectedClassId == null && _classIds.isNotEmpty) {
        _selectedClassId = _classIds.first;
        _loadSubjects(_selectedClassId!);
      } else if (_selectedClassId != null && _subjectMap.isEmpty) {
        _loadSubjects(_selectedClassId!);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier l\'examen' : 'Nouvel examen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Class selector
              DropdownButtonFormField<String>(
                key: ValueKey('class_$_selectedClassId'),
                initialValue: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Classe',
                  border: OutlineInputBorder(),
                ),
                items: _classIds
                    .map((id) =>
                        DropdownMenuItem(value: id, child: Text(id)))
                    .toList(),
                onChanged: _isEditing
                    ? null
                    : (value) {
                        setState(() {
                          _selectedClassId = value;
                          _selectedSubjectId = null;
                          _subjectMap = {};
                        });
                        if (value != null) _loadSubjects(value);
                      },
                validator: (v) =>
                    v == null ? 'Veuillez sélectionner une classe.' : null,
              ),
              const SizedBox(height: 16),

              // Subject selector
              _loadingSubjects
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : DropdownButtonFormField<String>(
                      key: ValueKey('subject_${_selectedClassId}_$_selectedSubjectId'),
                      initialValue: _selectedSubjectId,
                      decoration: const InputDecoration(
                        labelText: 'Matière',
                        border: OutlineInputBorder(),
                      ),
                      items: _subjectMap.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedSubjectId = value);
                      },
                      validator: (v) =>
                          v == null ? 'Veuillez sélectionner une matière.' : null,
                    ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de l\'examen',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir un titre.'
                    : null,
              ),
              const SizedBox(height: 16),

              // Type
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'exam', child: Text('Examen')),
                  DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                  DropdownMenuItem(value: 'homework', child: Text('Devoir')),
                  DropdownMenuItem(value: 'project', child: Text('Projet')),
                  DropdownMenuItem(value: 'oral', child: Text('Oral')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time picker
              InkWell(
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Heure',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditing ? 'Mettre à jour' : 'Créer l\'examen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
