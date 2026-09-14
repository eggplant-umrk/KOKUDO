import 'package:flutter/widgets.dart';

/// 非Web環境向けのスタブ。LoginScreen側でkIsWebによりWeb版でのみ呼び出す
/// 想定のため、実際に呼ばれることはない。
Widget buildGoogleSignInButton() {
  throw UnsupportedError('buildGoogleSignInButton is only available on web.');
}