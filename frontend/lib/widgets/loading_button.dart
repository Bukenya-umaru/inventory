import 'package:flutter/material.dart';

/// An action button that shows progress while an asynchronous operation runs.
class LoadingElevatedButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final Widget? loadingChild;
  final ButtonStyle? style;

  const LoadingElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loadingChild,
    this.style,
  });

  @override
  State<LoadingElevatedButton> createState() => _LoadingElevatedButtonState();
}

class _LoadingElevatedButtonState extends State<LoadingElevatedButton> {
  bool _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _run,
      style: widget.style,
      child: _loading
          ? widget.loadingChild ??
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
          : widget.child,
    );
  }
}
