import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceGroup {
  final String name;
  final List<String> deviceIds;

  DeviceGroup({required this.name, required this.deviceIds});

  Map<String, dynamic> toJson() => {
        'name': name,
        'deviceIds': deviceIds,
      };

  factory DeviceGroup.fromJson(Map<String, dynamic> json) {
    return DeviceGroup(
      name: json['name'] as String,
      deviceIds: List<String>.from(json['deviceIds'] as List),
    );
  }
}

class GroupService {
  GroupService._();
  static final GroupService instance = GroupService._();

  static const String _storageKey = 'saved_device_groups';

  Future<List<DeviceGroup>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => DeviceGroup.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveGroup(DeviceGroup group) async {
    final groups = await getGroups();
    
    // Remove if group with same name already exists to allow overriding
    groups.removeWhere((g) => g.name == group.name);
    groups.add(group);

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(groups.map((g) => g.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<void> deleteGroup(String name) async {
    final groups = await getGroups();
    groups.removeWhere((g) => g.name == name);

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(groups.map((g) => g.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }
}
