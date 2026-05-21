import 'package:flutter/material.dart';
import '../models/text_item.dart';

class DraggableText extends StatefulWidget {
  final TextItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const DraggableText({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<DraggableText> createState() => _DraggableTextState();
}

class _DraggableTextState extends State<DraggableText> {
  bool _isEditing = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.item.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.item.position.dx,
      top: widget.item.position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleUpdate: (details) {
          widget.onTap();
          setState(() {
            if (details.pointerCount == 1) {
              // Dragging
              widget.item.position += details.focalPointDelta;
            } else if (details.pointerCount > 1) {
              // Scaling and Rotation
              widget.item.scale *= details.scale;
              widget.item.rotation += details.rotation;
            }
          });
          widget.onUpdate();
        },
        onDoubleTap: () {
          setState(() {
            _isEditing = true;
          });
        },
        onLongPress: widget.onDelete,
        child: Container(
          decoration: BoxDecoration(
            border: widget.isSelected
                ? Border.all(
                    color: Colors.blue.withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
          ),
          child: Transform.rotate(
            angle: widget.item.rotation,
            child: Transform.scale(
              scale: widget.item.scale,
              child: _isEditing
                  ? IntrinsicWidth(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: widget.item.fontStyle.copyWith(
                          color: widget.item.color,
                          fontSize: 24,
                        ),
                        onSubmitted: (val) {
                          setState(() {
                            widget.item.text = val;
                            _isEditing = false;
                          });
                          widget.onUpdate();
                        },
                      ),
                    )
                  : Text(
                      widget.item.text,
                      style: widget.item.fontStyle.copyWith(
                        color: widget.item.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
