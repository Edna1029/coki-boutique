import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_management_service.dart';
import '../../../domain/entities/enums.dart';
import '../../widgets/role_badge.dart';

/// Owner-only screen to add staff, change their role, or remove their access.
class UserManagementScreen extends StatefulWidget {
  final UserModel currentUser;

  const UserManagementScreen({super.key, required this.currentUser});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _service = UserManagementService();
  List<UserModel> _users = [];
  bool _loading = true;
  String? _loadError;

  bool get _am => Localizations.localeOf(context).languageCode == 'am';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final users = await _service.listUsers();
      if (mounted) setState(() => _users = users);
    } on UserAdminException catch (e) {
      if (mounted) setState(() => _loadError = _message(e.reason));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleLabel(UserRole role) {
    return RoleStyle.label(role, isAmharic: _am);
  }

  Color _roleColor(UserRole role) => RoleStyle.color(role);

  String _message(UserAdminFailure reason) {
    switch (reason) {
      case UserAdminFailure.emailInUse:
        return _am
            ? 'ይህ ኢሜይል አስቀድሞ መለያ አለው። በFirebase Authentication ውስጥ ያረጋግጡ።'
            : 'This email already has an account. Check Firebase Authentication.';
      case UserAdminFailure.invalidEmail:
        return _am ? 'የኢሜይል አድራሻው ትክክል አይደለም።' : 'That email address is not valid.';
      case UserAdminFailure.weakPassword:
        return _am ? 'የይለፍ ቃሉ ቢያንስ 6 ፊደላት መሆን አለበት።' : 'The password must be at least 6 characters.';
      case UserAdminFailure.network:
        return _am ? 'ኢንተርኔት ያስፈልጋል።' : 'An internet connection is needed for this.';
      case UserAdminFailure.permissionDenied:
        return _am
            ? 'ፈቃድ የለም። ባለቤት ብቻ ተጠቃሚዎችን ማስተዳደር ይችላል።'
            : 'Permission denied. Only the owner can manage users.';
      case UserAdminFailure.unknown:
        return _am ? 'አልተሳካም። እንደገና ይሞክሩ።' : 'Something went wrong. Please try again.';
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.primaryGreen),
    );
  }

  // --------------------------------------------------------------------------
  // Add user

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    UserRole role = UserRole.employee;
    bool obscure = true;
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        Future<void> save() async {
          final name = nameCtrl.text.trim();
          final email = emailCtrl.text.trim();
          final password = passwordCtrl.text;
          if (name.isEmpty || email.isEmpty || password.isEmpty) {
            setD(() => error = _am
                ? 'ስም፣ ኢሜይል እና ጊዜያዊ የይለፍ ቃል ያስፈልጋሉ።'
                : 'Name, email and a temporary password are required.');
            return;
          }
          if (password.length < 6) {
            setD(() => error = _message(UserAdminFailure.weakPassword));
            return;
          }
          setD(() {
            saving = true;
            error = null;
          });
          try {
            final user = await _service.createUser(
              fullName: name,
              email: email,
              phoneNumber: phoneCtrl.text,
              role: role,
              temporaryPassword: password,
            );
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            _snack(_am
                ? '${user.fullName} ታክሏል። ጊዜያዊ የይለፍ ቃሉን በአካል ይንገሯቸው።'
                : '${user.fullName} added. Give them the temporary password in person.');
            _load();
          } on UserAdminException catch (e) {
            setD(() {
              saving = false;
              error = _message(e.reason);
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusDialog)),
          title: Text(_am ? 'አዲስ ሰራተኛ ጨምር' : 'Add Staff Member',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: _am ? 'ሙሉ ስም' : 'Full Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: _am ? 'ኢሜይል' : 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: _am ? 'ስልክ ቁጥር (አማራጭ)' : 'Phone (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: _am ? 'ጊዜያዊ የይለፍ ቃል' : 'Temporary Password',
                      helperText: _am ? 'ቢያንስ 6 ፊደላት። በኋላ መቀየር ይችላሉ።' : 'At least 6 characters. They can change it later.',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setD(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: _am ? 'ሚና' : 'Role'),
                    items: [UserRole.employee, UserRole.admin]
                        .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                        .toList(),
                    onChanged: (r) {
                      if (r != null) setD(() => role = r);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: Text(_am ? 'ተመለስ' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_am ? 'ጨምር' : 'Add'),
            ),
          ],
        );
      }),
    );
  }

  // --------------------------------------------------------------------------
  // Change role / remove access

  Future<void> _changeRole(UserModel user, UserRole role) async {
    try {
      await _service.changeRole(user.userId, role);
      _snack(_am ? 'የ${user.fullName} ሚና ወደ ${_roleLabel(role)} ተቀይሯል።' : '${user.fullName} is now ${_roleLabel(role)}.');
      _load();
    } on UserAdminException catch (e) {
      _snack(_message(e.reason), error: true);
    }
  }

  Future<void> _confirmRemove(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_am ? 'መዳረሻ ይወገድ?' : 'Remove access?'),
        content: Text(_am
            ? '${user.fullName} ከእንግዲህ መግባት አይችሉም። ያለፉ ሽያጮች እና መዝገቦች አይጠፉም።'
            : '${user.fullName} will no longer be able to sign in. Their past sales and records are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_am ? 'ተመለስ' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_am ? 'አስወግድ' : 'Remove', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.removeAccess(user.userId);
      _snack(_am ? 'የ${user.fullName} መዳረሻ ተወግዷል።' : '${user.fullName} can no longer sign in.');
      _load();
    } on UserAdminException catch (e) {
      _snack(_message(e.reason), error: true);
    }
  }

  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_am ? 'ተጠቃሚዎች' : 'Users', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text(_am ? 'ሰራተኛ ጨምር' : 'Add Staff', style: const TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: Text(_am ? 'እንደገና ሞክር' : 'Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildUserTile(_users[i], isDark),
                  ),
                ),
    );
  }

  Widget _buildUserTile(UserModel user, bool isDark) {
    final isMe = user.userId == widget.currentUser.userId;
    // Owners can't be edited here (prevents locking the store out).
    final editable = !isMe && user.role != UserRole.owner;
    final color = _roleColor(user.role);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          isMe ? '${user.fullName} (${_am ? 'እርስዎ' : 'you'})' : user.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          user.phoneNumber.isNotEmpty ? '${user.email}\n${user.phoneNumber}' : user.email,
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: user.phoneNumber.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoleBadge(role: user.role),
            if (editable)
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'admin') _changeRole(user, UserRole.admin);
                  if (action == 'employee') _changeRole(user, UserRole.employee);
                  if (action == 'remove') _confirmRemove(user);
                },
                itemBuilder: (_) => [
                  if (user.role != UserRole.admin)
                    PopupMenuItem(value: 'admin', child: Text(_am ? 'አስተዳዳሪ አድርግ' : 'Make Admin')),
                  if (user.role != UserRole.employee)
                    PopupMenuItem(value: 'employee', child: Text(_am ? 'ሰራተኛ አድርግ' : 'Make Employee')),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(_am ? 'መዳረሻ አስወግድ' : 'Remove access',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ],
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
