class MeshGroup {
  final String groupId;
  final String name;
  final String address;
  final List<String> nodeIds;
  /// 16-byte Label UUID (virtual group) when [isVirtual] is true.
  final List<int>? labelUuid;

  bool get isVirtual => labelUuid != null && labelUuid!.length == 16;

  MeshGroup({
    required this.groupId,
    required this.name,
    required this.address,
    required this.nodeIds,
    this.labelUuid,
  });

  factory MeshGroup.fromMap(Map<String, dynamic> map) {
    return MeshGroup(
      groupId: map['groupId'],
      name: map['name'],
      address: map['address'],
      nodeIds: List<String>.from(map['nodeIds']),
      labelUuid: (map['labelUuid'] as List<dynamic>?)?.cast<int>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'address': address,
      'nodeIds': nodeIds,
      'labelUuid': labelUuid,
    };
  }
}