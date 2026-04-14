enum AppRole {
  dispatcher,
  accountant,
  paperwork,
  admin;

  String get value => name;

  String get label => switch (this) {
        AppRole.dispatcher => 'Dispatcher',
        AppRole.accountant => 'Accountant',
        AppRole.paperwork => 'Paperwork',
        AppRole.admin => 'Admin',
      };

  static AppRole fromValue(String? raw) {
    return AppRole.values.firstWhere(
      (role) => role.value == raw,
      orElse: () => AppRole.dispatcher,
    );
  }
}
