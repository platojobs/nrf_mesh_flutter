/// Mesh group metadata (fixed SIG group address or virtual label group).
class MeshGroup {
  /// Stable identifier assigned by native/plugin layers.
  final String groupId;

  /// Display name chosen during provisioning UI flows.
  final String name;

  /// Hex string representation of the group's publish/subscribe address.
  final String address;

  /// Provisioned node UUID strings participating in this group when tracked.
  final List<String> nodeIds;

  /// 16-byte Label UUID (virtual group) when [isVirtual] is true.
  final List<int>? labelUuid;

  /// Whether [labelUuid] defines a virtual SIG address via Label UUID.
  bool get isVirtual => labelUuid != null && labelUuid!.length == 16;

  /// Constructs group snapshot returned by [PlatoJobsNrfMeshManager.getGroups].
  MeshGroup({
    required this.groupId,
    required this.name,
    required this.address,
    required this.nodeIds,
    this.labelUuid,
  });

  /// Parses JSON-style persisted structures.
  factory MeshGroup.fromMap(Map<String, dynamic> map) {
    return MeshGroup(
      groupId: map['groupId'],
      name: map['name'],
      address: map['address'],
      nodeIds: List<String>.from(map['nodeIds']),
      labelUuid: (map['labelUuid'] as List<dynamic>?)?.cast<int>(),
    );
  }

  /// Converts this snapshot into JSON-style maps.
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
