import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import '../notifications/notification_providers.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _uploadingPhoto = false;
  String? _className;
  List<String>? _teacherClassNames;

  @override
  void initState() {
    super.initState();
    _loadClassNames();
  }

  Future<void> _loadClassNames() async {
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser == null) return;

    if (appUser.isStudent && appUser.classId != null) {
      final name = await fetchClassName(appUser.classId!);
      if (mounted) setState(() => _className = name);
    } else if (appUser.isTeacher && appUser.teacherClassIds != null) {
      final names = await fetchTeacherClassNames(appUser.teacherClassIds!);
      if (mounted) setState(() => _teacherClassNames = names);
    }
  }

  Future<void> _pickPhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final url = await pickAndUploadProfilePhoto();
      if (url != null) {
        ref.invalidate(appUserProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo mise à jour')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showEmailChangeDialog(String currentEmail) {
    final emailController = TextEditingController(text: currentEmail);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier l\'email'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Nouvel email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email requis';
                    }
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Mot de passe requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Un email de vérification sera envoyé à la nouvelle adresse.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => loading = true);
                      try {
                        await updateEmail(
                          newEmail: emailController.text,
                          currentPassword: passwordController.text,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Email de vérification envoyé. Vérifiez votre boîte de réception.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        String message = 'Erreur lors de la modification';
                        if (e.toString().contains('wrong-password')) {
                          message = 'Mot de passe incorrect';
                        } else if (e.toString().contains('email-already-in-use')) {
                          message = 'Cet email est déjà utilisé';
                        } else if (e.toString().contains('invalid-email')) {
                          message = 'Email invalide';
                        }
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Remove FCM token before signing out
              await ref.read(notificationServiceProvider).removeToken();
              await ref.read(authServiceProvider).signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: appUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (appUser) {
          if (appUser == null) {
            return const Center(child: Text('Utilisateur non trouvé'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile photo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: AppColors.primary.withAlpha(30),
                        backgroundImage: appUser.photoURL != null
                            ? (appUser.photoURL!.startsWith('data:')
                                    ? MemoryImage(base64Decode(
                                        appUser.photoURL!.split(',')[1]))
                                    : NetworkImage(appUser.photoURL!))
                                as ImageProvider
                            : null,
                        child: appUser.photoURL == null
                            ? Text(
                                appUser.fullName.isNotEmpty
                                    ? appUser.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingPhoto ? null : _pickPhoto,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: _uploadingPhoto
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // User info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppCardStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Full name (immutable)
                      _InfoRow(
                        icon: Icons.person_outlined,
                        label: 'Nom complet',
                        value: appUser.fullName,
                      ),
                      const Divider(height: 24),

                      // Personal number (immutable)
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Numéro personnel',
                        value: appUser.personalNumber,
                      ),
                      const Divider(height: 24),

                      // Role
                      _InfoRow(
                        icon: Icons.school_outlined,
                        label: 'Rôle',
                        value: appUser.isStudent ? 'Étudiant' : 'Enseignant',
                      ),
                      const Divider(height: 24),

                      // Class(es)
                      if (appUser.isStudent) ...[
                        _InfoRow(
                          icon: Icons.class_outlined,
                          label: 'Classe',
                          value: _className ?? appUser.classId ?? '—',
                        ),
                        const Divider(height: 24),
                      ] else if (appUser.isTeacher) ...[
                        _InfoRow(
                          icon: Icons.class_outlined,
                          label: 'Classes',
                          value: _teacherClassNames?.join(', ') ??
                              appUser.teacherClassIds?.join(', ') ??
                              '—',
                        ),
                        const Divider(height: 24),
                      ],

                      // Email (editable)
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: appUser.email,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEmailChangeDialog(appUser.email),
                            icon: const Icon(Icons.edit_outlined),
                            color: AppColors.primary,
                            tooltip: 'Modifier l\'email',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Déconnexion'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
