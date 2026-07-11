import 'package:localsend_app/util/native/channel/android_channel.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// A folder the user explicitly granted (via Android's SAF folder picker) to be
/// browsable from a PC over Direct Mode.
///
/// This is the alternative to "All files access": instead of exposing the whole
/// of shared storage, the user grants exactly one folder tree and only the files
/// inside it are listable/downloadable.
final grantedFolderProvider =
    NotifierProvider<GrantedFolderNotifier, PickDirectoryResult?>((ref) {
      return GrantedFolderNotifier();
    });

class GrantedFolderNotifier extends Notifier<PickDirectoryResult?> {
  @override
  PickDirectoryResult? init() => null;

  /// Opens Android's folder picker. The returned result carries the tree URI and
  /// a flat list of every file inside it (name, size, content URI).
  Future<void> grant() async {
    final result = await pickDirectoryAndroid();
    if (result != null) {
      state = result;
    }
  }

  void revoke() {
    state = null;
  }
}
