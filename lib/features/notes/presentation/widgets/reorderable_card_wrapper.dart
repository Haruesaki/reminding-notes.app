import 'package:flutter/material.dart';
import '../../../explorer/domain/entities/entities.dart';

class ReorderableCardWrapper<T extends NodeEntry> extends StatefulWidget {
  final T item;
  final Widget child;
  final VoidCallback onLongPressRelease;
  final void Function(T source, T target) onReorder;
  final bool Function(T source, T target)? canReorderWith;

  const ReorderableCardWrapper({
    super.key,
    required this.item,
    required this.child,
    required this.onLongPressRelease,
    required this.onReorder,
    this.canReorderWith,
  });

  @override
  State<ReorderableCardWrapper<T>> createState() => _ReorderableCardWrapperState<T>();
}

class _ReorderableCardWrapperState<T extends NodeEntry>
    extends State<ReorderableCardWrapper<T>> {
  Offset? _startGlobalPosition;
  bool _dragMoved = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<T>(
      onWillAcceptWithDetails: (details) {
        if (details.data.id == widget.item.id) return false;
        if (widget.canReorderWith != null) {
          return widget.canReorderWith!(details.data, widget.item);
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        widget.onReorder(details.data, widget.item);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedScale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          scale: isHovered ? 1.03 : 1.0,
          child: LongPressDraggable<T>(
            data: widget.item,
            delay: const Duration(milliseconds: 250),
            hapticFeedbackOnStart: true,
            onDragStarted: () {
              _dragMoved = false;
            },
            onDragUpdate: (details) {
              if (_startGlobalPosition != null) {
                final dist =
                    (details.globalPosition - _startGlobalPosition!).distance;
                if (dist > 12) {
                  _dragMoved = true;
                }
              }
            },
            onDragEnd: (details) {
              if (!_dragMoved) {
                widget.onLongPressRelease();
              }
              _dragMoved = false;
              _startGlobalPosition = null;
            },
            onDraggableCanceled: (velocity, offset) {
              if (!_dragMoved) {
                widget.onLongPressRelease();
              }
              _dragMoved = false;
              _startGlobalPosition = null;
            },
            feedback: Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.44,
                child: Opacity(
                  opacity: 0.95,
                  child: Transform.scale(
                    scale: 1.03,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: widget.child,
            ),
            child: Listener(
              onPointerDown: (event) {
                _startGlobalPosition = event.position;
                _dragMoved = false;
              },
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
