import 'package:flutter/material.dart';

class TooltipIconButton extends StatelessWidget {
  const TooltipIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(onPressed: onPressed, color: color, icon: icon),
    );
  }
}
