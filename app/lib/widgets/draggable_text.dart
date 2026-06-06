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

  Widget _buildTextWidget() {
    final String displayText = widget.item.useCaps
        ? widget.item.text.toUpperCase()
        : widget.item.text;

    final TextStyle baseStyle = widget.item.fontStyle.copyWith(
      fontSize: widget.item.fontSize,
      fontWeight: FontWeight.bold,
    );

    if (widget.item.isMemeStyle) {
      return Stack(
        children: [
          Text(
            displayText,
            textAlign: TextAlign.center,
            style: baseStyle.copyWith(
              color: null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = widget.item.outlineWidth
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round
                ..color = widget.item.outlineColor,
            ),
          ),
          Text(
            displayText,
            textAlign: TextAlign.center,
            style: baseStyle.copyWith(
              color: widget.item.color,
              shadows: widget.item.hasShadow
                  ? [
                      Shadow(
                        offset: const Offset(2.0, 2.0),
                        blurRadius: 3.0,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      );
    } else {
      return Text(
        displayText,
        textAlign: TextAlign.center,
        style: baseStyle.copyWith(color: widget.item.color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.item.position.dx,
      top: widget.item.position.dy,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: widget.onTap,
              onScaleUpdate: (details) {
                widget.onTap();
                setState(() {
                  if (details.pointerCount == 1) {
                    widget.item.position += details.focalPointDelta;
                  } else if (details.pointerCount > 1) {
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
                                fontSize: widget.item.fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              onSubmitted: (val) {
                                setState(() {
                                  widget.item.text = val;
                                  _isEditing = false;
                                });
                                widget.onUpdate();
                              },
                            ),
                          )
                        : _buildTextWidget(),
                  ),
                ),
              ),
            ),
            if (widget.isSelected)
              Positioned(
                top: -10,
                right: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDelete,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
