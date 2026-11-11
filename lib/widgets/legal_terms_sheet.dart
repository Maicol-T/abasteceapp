import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../constants/legal_texts.dart';
import '../theme/app_theme.dart';

/// Abre los Términos y Condiciones o la Política de Tratamiento de Datos.
Future<void> showLegalSheet(
  BuildContext context, {
  bool initialPolicy = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) =>
        _LegalSheet(initialPolicy: initialPolicy),
  );
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.initialPolicy});

  final bool initialPolicy;

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height * 0.92;
    return DefaultTabController(
      length: 2,
      initialIndex: initialPolicy ? 1 : 0,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Marco legal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.18),
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.gavel_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ley 1581 de 2012 · Decreto 1377 de 2013 · versión '
                      '${LegalDocs.policyVersion}',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              tabs: <Widget>[
                Tab(text: 'Términos y condiciones'),
                Tab(text: 'Política de datos'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _LegalSections(
                    sections: LegalDocs.terms,
                    footer: _footer(context, isTerms: true),
                  ),
                  _LegalSections(
                    sections: LegalDocs.dataPolicy,
                    footer: _footer(context, isTerms: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, {required bool isTerms}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(height: 24),
          Text(
            isTerms
                ? LegalDocs.consentIntro
                : 'Canal de atención: ${AppInfo.dataProtectionEmail} · '
                    '${AppConstants.supportPhone}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSections extends StatelessWidget {
  const _LegalSections({required this.sections, required this.footer});

  final List<LegalSection> sections;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      children: <Widget>[
        ...sections.map(
          (LegalSection section) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section.body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
        footer,
      ],
    );
  }
}
