import 'package:flutter/material.dart';

import '../../../core/domain/enums/flow_type.dart';
import '../../../core/domain/models/proxy_profile.dart';

/// Compact chip summarising a profile's protocol, transport and flow.
class ProtocolBadge extends StatelessWidget {
  final ProxyProfile profile;

  const ProtocolBadge({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _label();
    final color =
        profile.isHysteria2 ? scheme.tertiaryContainer : scheme.primaryContainer;
    final onColor = profile.isHysteria2
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _label() {
    final parts = <String>[profile.protocol.value.toUpperCase()];
    if (!profile.isHysteria2) {
      parts.add(profile.transport.type.label);
      if (profile.flow == FlowType.xtlsRprxVision) parts.add('Vision');
      if (profile.tls.reality.enabled) parts.add('Reality');
    }
    return parts.join(' · ');
  }
}
