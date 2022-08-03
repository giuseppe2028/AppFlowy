import 'dart:collection';
import 'package:flowy_editor/document/path.dart';
import 'package:flowy_editor/document/text_delta.dart';
import 'package:flowy_editor/operation/operation.dart';
import 'package:flutter/material.dart';
import './attributes.dart';

class Node extends ChangeNotifier with LinkedListEntry<Node> {
  Node? parent;
  final String type;
  final LinkedList<Node> children;
  final Attributes attributes;

  GlobalKey? key;
  // TODO: abstract a selectable node??
  final layerLink = LayerLink();

  String? get subtype {
    // TODO: make 'subtype' as a const value.
    if (attributes.containsKey('subtype')) {
      assert(attributes['subtype'] is String?,
          'subtype must be a [String] or [null]');
      return attributes['subtype'] as String?;
    }
    return null;
  }

  Path get path => _path();

  Node({
    required this.type,
    required this.children,
    required this.attributes,
    this.parent,
  }) {
    for (final child in children) {
      child.parent = this;
    }
  }

  factory Node.fromJson(Map<String, Object> json) {
    assert(json['type'] is String);

    // TODO: check the type that not exist on plugins.
    final jType = json['type'] as String;
    final jChildren = json['children'] as List?;
    final jAttributes = json['attributes'] != null
        ? Attributes.from(json['attributes'] as Map)
        : Attributes.from({});

    final LinkedList<Node> children = LinkedList();
    if (jChildren != null) {
      children.addAll(
        jChildren.map(
          (jChild) => Node.fromJson(
            Map<String, Object>.from(jChild),
          ),
        ),
      );
    }

    Node node;

    if (jType == "text") {
      final jDelta = json['delta'] as List<dynamic>?;
      final delta = jDelta == null ? Delta() : Delta.fromJson(jDelta);
      node = TextNode(
          type: jType,
          children: children,
          attributes: jAttributes,
          delta: delta);
    } else {
      node = Node(
        type: jType,
        children: children,
        attributes: jAttributes,
      );
    }

    for (final child in children) {
      child.parent = node;
    }

    return node;
  }

  void updateAttributes(Attributes attributes) {
    bool shouldNotifyParent =
        this.attributes['subtype'] != attributes['subtype'];

    for (final attribute in attributes.entries) {
      if (attribute.value == null) {
        this.attributes.remove(attribute.key);
      } else {
        this.attributes[attribute.key] = attribute.value;
      }
    }
    // Notify the new attributes
    // if attributes contains 'subtype', should notify parent to rebuild node
    // else, just notify current node.
    shouldNotifyParent ? parent?.notifyListeners() : notifyListeners();
  }

  Node? childAtIndex(int index) {
    if (children.length <= index) {
      return null;
    }

    return children.elementAt(index);
  }

  Node? childAtPath(Path path) {
    if (path.isEmpty) {
      return this;
    }

    return childAtIndex(path.first)?.childAtPath(path.sublist(1));
  }

  @override
  void insertAfter(Node entry) {
    entry.parent = parent;
    super.insertAfter(entry);

    // Notify the new node.
    parent?.notifyListeners();
  }

  @override
  void insertBefore(Node entry) {
    entry.parent = parent;
    super.insertBefore(entry);

    // Notify the new node.
    parent?.notifyListeners();
  }

  @override
  void unlink() {
    super.unlink();

    parent?.notifyListeners();
    parent = null;
  }

  Map<String, Object> toJson() {
    var map = <String, Object>{
      'type': type,
    };
    if (children.isNotEmpty) {
      map['children'] = children.map((node) => node.toJson());
    }
    if (attributes.isNotEmpty) {
      map['attributes'] = attributes;
    }
    return map;
  }

  Path _path([Path previous = const []]) {
    if (parent == null) {
      return previous;
    }
    var index = 0;
    for (var child in parent!.children) {
      if (child == this) {
        break;
      }
      index += 1;
    }
    return parent!._path([index, ...previous]);
  }
}

class TextNode extends Node {
  Delta _delta;

  TextNode({
    required super.type,
    required super.children,
    required super.attributes,
    required Delta delta,
  }) : _delta = delta;

  TextNode.empty()
      : _delta = Delta([TextInsert(' ')]),
        super(
          type: 'text',
          children: LinkedList(),
          attributes: {},
        );

  Delta get delta {
    return _delta;
  }

  set delta(Delta v) {
    _delta = v;
    notifyListeners();
  }

  @override
  Map<String, Object> toJson() {
    final map = super.toJson();
    map['delta'] = _delta.toJson();
    return map;
  }

  TextNode copyWith({
    String? type,
    LinkedList<Node>? children,
    Attributes? attributes,
    Delta? delta,
  }) =>
      TextNode(
        type: type ?? this.type,
        children: children ?? this.children,
        attributes: attributes ?? this.attributes,
        delta: delta ?? this.delta,
      );

  // TODO: It's unneccesry to compute everytime.
  String toRawString() =>
      _delta.operations.whereType<TextInsert>().map((op) => op.content).join();
}