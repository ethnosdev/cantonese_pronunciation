import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Lays out children in a 2-column grid where every tile shares the tallest height.
class UniformTwoColumnGrid extends MultiChildRenderObjectWidget {
  const UniformTwoColumnGrid({
    super.key,
    required this.spacing,
    required this.runSpacing,
    required this.minTileHeight,
    required super.children,
  });

  final double spacing;
  final double runSpacing;
  final double minTileHeight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderUniformTwoColumnGrid(spacing, runSpacing, minTileHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderObject renderObject,
  ) {
    (renderObject as _RenderUniformTwoColumnGrid)
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..minTileHeight = minTileHeight;
  }
}

class _UniformGridParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderUniformTwoColumnGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _UniformGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _UniformGridParentData> {
  _RenderUniformTwoColumnGrid(
    this._spacing,
    this._runSpacing,
    this._minTileHeight,
  );

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  double _minTileHeight;
  double get minTileHeight => _minTileHeight;
  set minTileHeight(double value) {
    if (_minTileHeight == value) return;
    _minTileHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _UniformGridParentData) {
      child.parentData = _UniformGridParentData();
    }
  }

  double _tileWidthFor(double maxWidth) =>
      math.max(0.0, (maxWidth - _spacing) / 2.0);

  double _uniformHeightFor(double tileWidth) {
    var maxH = _minTileHeight;
    var child = firstChild;
    while (child != null) {
      final h = child.getMaxIntrinsicHeight(tileWidth);
      if (h > maxH) maxH = h;
      child = childAfter(child);
    }
    return maxH;
  }

  double _totalHeightForWidth(double width) {
    if (childCount == 0) return 0.0;
    final rows = (childCount + 1) ~/ 2;
    final tileHeight = _uniformHeightFor(_tileWidthFor(width));
    return rows * tileHeight + (rows - 1) * _runSpacing;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _totalHeightForWidth(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _totalHeightForWidth(width);

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.constrain(Size(constraints.maxWidth, 0.0));
      return;
    }
    final width = constraints.maxWidth;
    final tileWidth = _tileWidthFor(width);
    final tileHeight = _uniformHeightFor(tileWidth);
    final childConstraints = BoxConstraints.tightFor(
      width: tileWidth,
      height: tileHeight,
    );

    var index = 0;
    var child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final pd = child.parentData! as _UniformGridParentData;
      final col = index % 2;
      final row = index ~/ 2;
      pd.offset = Offset(
        col * (tileWidth + _spacing),
        row * (tileHeight + _runSpacing),
      );
      index++;
      child = childAfter(child);
    }

    final rows = (childCount + 1) ~/ 2;
    final totalHeight = rows * tileHeight + (rows - 1) * _runSpacing;
    size = constraints.constrain(Size(width, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
