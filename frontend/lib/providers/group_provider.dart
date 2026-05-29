import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../services/api_service.dart';

class GroupProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Group> _groups = [];
  List<GroupInvitation> _pendingInvites = [];
  bool _isLoading = false;
  String? _error;

  List<Group> get groups => _groups;
  List<GroupInvitation> get pendingInvites => _pendingInvites;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMyGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _groups = await _api.getMyGroups();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingInvites() async {
    try {
      _pendingInvites = await _api.getPendingGroupInvites();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading pending invites: $e');
    }
  }

  Future<Group?> createGroup({required String name, String? description}) async {
    try {
      final group = await _api.createGroup(name: name, description: description);
      _groups.insert(0, group);
      notifyListeners();
      return group;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> inviteUser(String groupId, String username) async {
    try {
      await _api.inviteToGroup(groupId, username);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptInvite(String inviteId) async {
    try {
      final group = await _api.acceptGroupInvite(inviteId);
      _pendingInvites.removeWhere((i) => i.id == inviteId);
      if (!_groups.any((g) => g.id == group.id)) {
        _groups.insert(0, group);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> declineInvite(String inviteId) async {
    try {
      await _api.declineGroupInvite(inviteId);
      _pendingInvites.removeWhere((i) => i.id == inviteId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      await _api.deleteGroup(groupId);
      _groups.removeWhere((g) => g.id == groupId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveOrRemoveMember(String groupId, String userId) async {
    try {
      await _api.leaveOrRemoveFromGroup(groupId, userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Refreshes a single group in-place after a detail-level operation.
  Future<void> refreshGroup(String groupId) async {
    try {
      final updated = await _api.getGroupById(groupId);
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index >= 0) {
        _groups[index] = updated;
      } else {
        _groups.insert(0, updated);
      }
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
