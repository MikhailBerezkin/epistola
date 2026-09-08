import 'package:flutter/foundation.dart';

abstract final class EpistolaPlatformCapabilities {
  /// Первая облегчённая Web-версия Epistola.
  static bool get isWebLite => kIsWeb;

  /// Push для Web подключим отдельным этапом.
  static bool get supportsPushNotifications => !kIsWeb;

  /// Полноценный Messenger пока оставляем только Android.
  static bool get supportsChats => !kIsWeb;

  /// Контакты пока не считаем частью обязательного Web Lite scope.
  static bool get supportsContacts => !kIsWeb;

  /// SpacesBar работает в Web по тем же ролям, что и в Android.
  static bool get supportsSpacesBarManagement => true;

  /// "Список" работает в Web по существующим ролям.
  static bool get supportsSubstitutionManagement => true;

  /// Пользователь может менять свою доступность и в Web.
  static bool get supportsSubstitutionAvailabilityChanges => true;
}
