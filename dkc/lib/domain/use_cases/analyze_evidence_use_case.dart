import '../../data/services/jev_service.dart';

class AnalyzeEvidenceUseCase {
  final JevService _jevService;

  AnalyzeEvidenceUseCase(this._jevService);

  Future<EvidenceAnalysisResult> call(String evidenceContext) async {
    try {
      final harassmentType = await _jevService.classifyHarassment(
        evidenceContext,
      );
      final severity = await _jevService.scoreSeverity(evidenceContext);
      final needsLegal = await _jevService.requiresImmediateLegalSupport(
        evidenceContext,
      );

      return EvidenceAnalysisResult(
        harassmentType: harassmentType ?? 'unclassified',
        severityScore: severity,
        requiresImmediateLegalSupport: needsLegal,
      );
    } catch (e) {
      // Return a safe fallback if Jev analysis fails
      return EvidenceAnalysisResult(
        harassmentType: 'error_analyzing',
        severityScore: 1,
        requiresImmediateLegalSupport: false,
      );
    }
  }
}

class EvidenceAnalysisResult {
  final String harassmentType;
  final int severityScore;
  final bool requiresImmediateLegalSupport;

  EvidenceAnalysisResult({
    required this.harassmentType,
    required this.severityScore,
    required this.requiresImmediateLegalSupport,
  });
}
