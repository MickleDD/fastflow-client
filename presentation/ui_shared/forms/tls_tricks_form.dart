import 'package:flutter/material.dart';

import 'package:fastflow_vpn/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(l10n.tlsEnable),
          value: value.enabled,
          onChanged: (v) => onChanged(value.copyWith(enabled: v)),
        ),
        if (value.enabled) ...[
          TextFormField(
            initialValue: value.sni,
            decoration: InputDecoration(
              labelText: l10n.tlsSni,
              hintText: l10n.tlsSniHint,
            ),
            onChanged: (v) => onChanged(value.copyWith(sni: v)),
          ),
          TextFormField(
            initialValue: value.utlsFingerprint,
            decoration: InputDecoration(
              labelText: l10n.tlsFingerprint,
              hintText: l10n.tlsFingerprintHint,
            ),
            onChanged: (v) => onChanged(value.copyWith(utlsFingerprint: v)),
          ),
          SwitchListTile(
            title: Text(l10n.tlsSkipCertVerify),
            value: value.allowInsecure,
            onChanged: (v) => onChanged(value.copyWith(allowInsecure: v)),
          ),
          const Divider(),

          // ---- Reality ------------------------------------------------------
          SwitchListTile(
            title: Text(l10n.tlsReality),
            value: value.reality.enabled,
            onChanged: (v) => onChanged(
              value.copyWith(reality: value.reality.copyWith(enabled: v)),
            ),
          ),
          if (value.reality.enabled) ...[
            TextFormField(
              initialValue: value.reality.publicKey,
              decoration: InputDecoration(labelText: l10n.tlsRealityPublicKey),
              onChanged: (v) => onChanged(
                value.copyWith(reality: value.reality.copyWith(publicKey: v)),
              ),
            ),
            TextFormField(
              initialValue: value.reality.shortId,
              decoration: InputDecoration(labelText: l10n.tlsRealityShortId),
              onChanged: (v) => onChanged(
                value.copyWith(reality: value.reality.copyWith(shortId: v)),
              ),
            ),
          ],
          const Divider(),

          // ---- TLS tricks ---------------------------------------------------
          Text(l10n.tlsTricks, style: Theme.of(context).textTheme.titleSmall),
          SwitchListTile(
            title: Text(l10n.tlsMixedCaseSni),
            subtitle: Text(l10n.tlsMixedCaseSniSubtitle),
            value: value.mixedCaseSni,
            onChanged: (v) => onChanged(value.copyWith(mixedCaseSni: v)),
          ),

          SwitchListTile(
            title: Text(l10n.tlsFragmentation),
            subtitle: Text(l10n.tlsFragmentationSubtitle),
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
                    decoration: InputDecoration(
                      labelText: l10n.tlsFragmentSize,
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
                    decoration: InputDecoration(
                      labelText: l10n.tlsFragmentDelay,
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
            title: Text(l10n.tlsPadding),
            subtitle: Text(l10n.tlsPaddingSubtitle),
            value: value.padding.enabled,
            onChanged: (v) => onChanged(
              value.copyWith(padding: value.padding.copyWith(enabled: v)),
            ),
          ),
          if (value.padding.enabled)
            TextFormField(
              initialValue: value.padding.size,
              decoration: InputDecoration(
                labelText: l10n.tlsPaddingSize,
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
