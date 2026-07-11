import 'package:flutter/material.dart';

import '../../../core/domain/models/tls_config.dart';

/// Controlled editor for a profile's TLS layer, focused on the DPI-evasion
/// "TLS tricks": mixed-case SNI, fragmentation (size + delay), padding (size),
/// plus the core SNI / Reality fields. Emits a new [TlsConfig] via [onChanged].
class TlsTricksForm extends StatelessWidget {
  final TlsConfig value;
  final ValueChanged<TlsConfig> onChanged;

  const TlsTricksForm({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Enable TLS'),
          value: value.enabled,
          onChanged: (v) => onChanged(value.copyWith(enabled: v)),
        ),
        if (value.enabled) ...[
          TextFormField(
            initialValue: value.sni,
            decoration: const InputDecoration(
              labelText: 'SNI / server name',
              hintText: 'reuse server address if empty',
            ),
            onChanged: (v) => onChanged(value.copyWith(sni: v)),
          ),
          TextFormField(
            initialValue: value.utlsFingerprint,
            decoration: const InputDecoration(
              labelText: 'uTLS fingerprint',
              hintText: 'chrome, firefox, safari, randomized…',
            ),
            onChanged: (v) => onChanged(value.copyWith(utlsFingerprint: v)),
          ),
          SwitchListTile(
            title: const Text('Allow insecure (skip cert verify)'),
            subtitle: const Text('Never enable in production'),
            value: value.allowInsecure,
            onChanged: (v) => onChanged(value.copyWith(allowInsecure: v)),
          ),
          const Divider(),

          // ---- Reality ------------------------------------------------------
          SwitchListTile(
            title: const Text('Reality'),
            value: value.reality.enabled,
            onChanged: (v) => onChanged(
              value.copyWith(reality: value.reality.copyWith(enabled: v)),
            ),
          ),
          if (value.reality.enabled) ...[
            TextFormField(
              initialValue: value.reality.publicKey,
              decoration: const InputDecoration(labelText: 'Reality public key'),
              onChanged: (v) => onChanged(
                value.copyWith(reality: value.reality.copyWith(publicKey: v)),
              ),
            ),
            TextFormField(
              initialValue: value.reality.shortId,
              decoration: const InputDecoration(labelText: 'Reality short id'),
              onChanged: (v) => onChanged(
                value.copyWith(reality: value.reality.copyWith(shortId: v)),
              ),
            ),
          ],
          const Divider(),

          // ---- TLS tricks ---------------------------------------------------
          Text('TLS Tricks', style: Theme.of(context).textTheme.titleSmall),
          SwitchListTile(
            title: const Text('Mixed-case SNI'),
            subtitle: const Text('Randomise SNI letter case to evade blocklists'),
            value: value.mixedCaseSni,
            onChanged: (v) => onChanged(value.copyWith(mixedCaseSni: v)),
          ),

          SwitchListTile(
            title: const Text('Fragmentation'),
            subtitle: const Text('Split the ClientHello across TCP segments'),
            value: value.fragment.enabled,
            onChanged: (v) => onChanged(
              value.copyWith(fragment: value.fragment.copyWith(enabled: v)),
            ),
          ),
          if (value.fragment.enabled)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: value.fragment.size,
                    decoration: const InputDecoration(
                      labelText: 'Fragment size',
                      hintText: '10-100',
                    ),
                    onChanged: (v) => onChanged(
                      value.copyWith(
                          fragment: value.fragment.copyWith(size: v)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: value.fragment.delay,
                    decoration: const InputDecoration(
                      labelText: 'Fragment delay (ms)',
                      hintText: '10-20',
                    ),
                    onChanged: (v) => onChanged(
                      value.copyWith(
                          fragment: value.fragment.copyWith(delay: v)),
                    ),
                  ),
                ),
              ],
            ),

          SwitchListTile(
            title: const Text('Padding'),
            subtitle: const Text('Pad the ClientHello to a randomised length'),
            value: value.padding.enabled,
            onChanged: (v) => onChanged(
              value.copyWith(padding: value.padding.copyWith(enabled: v)),
            ),
          ),
          if (value.padding.enabled)
            TextFormField(
              initialValue: value.padding.size,
              decoration: const InputDecoration(
                labelText: 'Padding size',
                hintText: '100-200',
              ),
              onChanged: (v) => onChanged(
                value.copyWith(padding: value.padding.copyWith(size: v)),
              ),
            ),
        ],
      ],
    );
  }
}
