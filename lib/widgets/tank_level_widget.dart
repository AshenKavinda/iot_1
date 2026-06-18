import 'package:flutter/material.dart';

class TankLevelWidget extends StatelessWidget {
  final int sensorA;
  final int sensorB;

  const TankLevelWidget({
    super.key,
    required this.sensorA,
    required this.sensorB,
  });

  String get _level {
    if (sensorA == 0 && sensorB == 0) return 'full';
    if (sensorA == 0 && sensorB == 1) return 'half';
    return 'empty';
  }

  double get _fillFraction {
    switch (_level) {
      case 'full':
        return 1.0;
      case 'half':
        return 0.5;
      default:
        return 0.06;
    }
  }

  Color get _fillColor {
    switch (_level) {
      case 'full':
        return Colors.green;
      case 'half':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String get _label {
    switch (_level) {
      case 'full':
        return 'Full';
      case 'half':
        return 'Half';
      default:
        return 'Empty';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SensorDot(label: 'B', active: sensorB == 0),
                const SizedBox(height: 56),
                _SensorDot(label: 'A', active: sensorA == 0),
                const SizedBox(height: 28),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              width: 72,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 2.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(color: Colors.black26),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeInOut,
                            height: constraints.maxHeight * _fillFraction,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  _fillColor.withValues(alpha: 0.9),
                                  _fillColor.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _label,
            key: ValueKey(_label),
            style: TextStyle(
              color: _fillColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _SensorDot extends StatelessWidget {
  final String label;
  final bool active;

  const _SensorDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(width: 3),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.green : Colors.red.shade400,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    (active ? Colors.green : Colors.red).withValues(alpha: 0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
