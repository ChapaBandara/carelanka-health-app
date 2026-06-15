import 'dart:convert';

import 'package:carelanka_app/services/medication_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// A single drug–drug interaction record returned by the RxNav API.
class RxNavInteraction {
  final String drug1Name;
  final String drug2Name;
  final String description;

  const RxNavInteraction({
    required this.drug1Name,
    required this.drug2Name,
    required this.description,
  });
}

/// The combined result of a full conflict + allergy check.
class ConflictResult {
  /// Non-null when one or more drug conflicts were detected.
  final String? conflictMessage;

  /// Non-null when the medication triggers a known allergy.
  final String? allergyMessage;

  const ConflictResult({this.conflictMessage, this.allergyMessage});

  bool get hasWarning => conflictMessage != null || allergyMessage != null;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class DrugInteractionService {
  const DrugInteractionService();

  static const String _baseUrl = 'https://rxnav.nlm.nih.gov/REST';

  /// In-memory RxCUI cache — persists for the app session.
  /// Key: lowercase medication name. Value: rxcui string.
  static final Map<String, String> _rxcuiCache = {};

  // -------------------------------------------------------------------------
  // Step 1 — Resolve medication name → RxCUI
  // -------------------------------------------------------------------------

  /// Returns the RxNorm CUI for [medicationName], or `null` on any failure.
  ///
  /// Results are cached in [_rxcuiCache] so subsequent calls for the same
  /// name are instant and free.
  Future<String?> getRxCui(String medicationName) async {
    final key = medicationName.trim().toLowerCase();
    if (key.isEmpty) return null;

    // Return cached result immediately.
    if (_rxcuiCache.containsKey(key)) return _rxcuiCache[key];

    try {
      final url = Uri.parse(
        '$_baseUrl/rxcui.json?name=${Uri.encodeComponent(medicationName.trim())}',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ids = data['idGroup']?['rxnormId'] as List?;
        if (ids != null && ids.isNotEmpty) {
          final rxcui = ids[0] as String;
          _rxcuiCache[key] = rxcui;
          return rxcui;
        }
      }
    } catch (_) {
      // Network error, timeout, or parse failure — fall back to local JSON.
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Step 2 — Fetch interactions for an RxCUI
  // -------------------------------------------------------------------------

  /// Returns all [RxNavInteraction]s for [rxcui], or an empty list on failure.
  Future<List<RxNavInteraction>> getRxNavInteractions(String rxcui) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/interaction/interaction.json?rxcui=$rxcui',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final groups = data['interactionTypeGroup'] as List?;
        if (groups == null) return [];

        final interactions = <RxNavInteraction>[];

        for (final group in groups) {
          final types = (group as Map)['interactionType'] as List? ?? [];
          for (final type in types) {
            final pairs = (type as Map)['interactionPair'] as List? ?? [];
            for (final pair in pairs) {
              final concepts =
                  (pair as Map)['interactionConcept'] as List? ?? [];
              if (concepts.length >= 2) {
                final drug1 = (concepts[0] as Map)['minConceptItem']
                        ?['name'] as String? ??
                    '';
                final drug2 = (concepts[1] as Map)['minConceptItem']
                        ?['name'] as String? ??
                    '';
                final description = pair['description'] as String? ?? '';
                if (drug1.isNotEmpty && drug2.isNotEmpty) {
                  interactions.add(RxNavInteraction(
                    drug1Name: drug1,
                    drug2Name: drug2,
                    description: description,
                  ));
                }
              }
            }
          }
        }
        return interactions;
      }
    } catch (_) {
      // Silently fall back.
    }
    return [];
  }

  // -------------------------------------------------------------------------
  // Public API — combined check
  // -------------------------------------------------------------------------

  /// Performs a complete conflict + allergy check for [newMedicationName].
  ///
  /// Strategy:
  ///   1. Try RxNav API (primary, 5-second timeout).
  ///   2. Always also run local drug_conflicts.json check.
  ///   3. Merge results, deduplicate by conflicting drug name.
  ///   4. Run allergy_map.json check.
  ///   5. API results appear first; local results fill any gaps.
  ///
  /// The method NEVER throws — all errors are caught internally so the UI
  /// continues to work even when the network is unavailable.
  Future<ConflictResult> checkAll(
    String newMedicationName,
    String userId,
  ) async {
    final medName = newMedicationName.trim().toLowerCase();
    if (medName.isEmpty) return const ConflictResult();

    // Fetch the user's current active medication names once.
    final existingMeds =
        await MedicationService().watchMedications(userId).first;
    final existingNames = existingMeds
        .map((m) => (m['name'] as String? ?? '').trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    final conflictMessages = <String>[];
    // Track which conflicting drug names we've already reported to avoid
    // showing the same conflict from both the API and local JSON.
    final reportedDrugs = <String>{};

    // -----------------------------------------------------------------------
    // Step 1 — RxNav API (primary)
    // -----------------------------------------------------------------------
    final rxcui = await getRxCui(newMedicationName.trim());
    if (rxcui != null) {
      final rxNavInteractions = await getRxNavInteractions(rxcui);

      for (final interaction in rxNavInteractions) {
        final d1 = interaction.drug1Name.toLowerCase();
        final d2 = interaction.drug2Name.toLowerCase();

        // Determine which side of the pair matches the new medication.
        final newMatchesD1 =
            medName.contains(d1) || d1.contains(medName);
        final newMatchesD2 =
            medName.contains(d2) || d2.contains(medName);

        String? conflictingApiDrug;

        if (newMatchesD1) {
          // Look for d2 among existing meds.
          for (final existing in existingNames) {
            if (existing.contains(d2) || d2.contains(existing)) {
              conflictingApiDrug = interaction.drug2Name;
              break;
            }
          }
        } else if (newMatchesD2) {
          // Look for d1 among existing meds.
          for (final existing in existingNames) {
            if (existing.contains(d1) || d1.contains(existing)) {
              conflictingApiDrug = interaction.drug1Name;
              break;
            }
          }
        }

        if (conflictingApiDrug != null) {
          final normalised = conflictingApiDrug.toLowerCase();
          if (!reportedDrugs.contains(normalised)) {
            reportedDrugs.add(normalised);
            final capitalized =
                '${conflictingApiDrug[0].toUpperCase()}${conflictingApiDrug.substring(1)}';
            final desc = interaction.description.isNotEmpty
                ? interaction.description
                : 'Please consult your doctor.';
            conflictMessages.add('Conflicts with: $capitalized. $desc');
          }
        }
      }
    }

    // -----------------------------------------------------------------------
    // Step 2 — Local JSON fallback / supplement
    // -----------------------------------------------------------------------
    try {
      final conflictRaw =
          await rootBundle.loadString('assets/data/drug_conflicts.json');
      final conflicts =
          (jsonDecode(conflictRaw) as Map)['conflicts'] as List;

      for (final item in conflicts) {
        final map = Map<String, dynamic>.from(item as Map);
        final d1 = (map['drug1'] as String).toLowerCase();
        final d2 = (map['drug2'] as String).toLowerCase();

        final hitsNew = medName.contains(d1) || medName.contains(d2);
        final hitsExisting =
            existingNames.any((n) => n.contains(d1) || n.contains(d2));

        if (hitsNew && hitsExisting) {
          final other = medName.contains(d1) ? d2 : d1;
          if (!reportedDrugs.contains(other)) {
            reportedDrugs.add(other);
            conflictMessages.add(
              'Conflicts with: ${other[0].toUpperCase()}${other.substring(1)}.'
              ' Please consult your doctor.',
            );
          }
        }
      }
    } catch (_) {
      // Asset not found or parse error — ignore.
    }

    // -----------------------------------------------------------------------
    // Step 3 — Allergy check (always local JSON)
    // -----------------------------------------------------------------------
    String? allergyMessage;
    try {
      final allergyRaw =
          await rootBundle.loadString('assets/data/allergy_map.json');
      final allergyTriggers =
          (jsonDecode(allergyRaw) as Map)['allergy_triggers'] as List;

      for (final item in allergyTriggers) {
        final map = Map<String, dynamic>.from(item as Map);
        final triggers = (map['triggers'] as List)
            .map((e) => e.toString().toLowerCase())
            .toList();
        if (triggers.any((t) => medName.contains(t))) {
          allergyMessage = 'You are allergic to: ${map['allergy']}';
          break;
        }
      }
    } catch (_) {
      // Asset error — ignore.
    }

    return ConflictResult(
      conflictMessage:
          conflictMessages.isNotEmpty ? conflictMessages.join('\n') : null,
      allergyMessage: allergyMessage,
    );
  }
}
