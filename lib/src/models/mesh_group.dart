class MeshGroup {
  final String groupId;
  final String name;
  final String address;
  final List<String> nodeIds;

  MeshGroup({
    required this.groupId,
    required this.name,
    required this.address,
    required this.nodeIds,
  });

  factory MeshGroup.fromMap(Map<String, dynamic> map) {
    return MeshGroup(
      groupId: map['groupId'],
      name: map['name'],
      address: map['address'],
      nodeIds: List<String>.from(map['nodeIds']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'address': address,
      'nodeIds': nodeIds,
    };
  }
}