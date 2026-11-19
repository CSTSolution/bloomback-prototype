// Rules D2 + core rule 6: health numbers only decide whether to show the extra
// note "Ask a doctor before increasing activity". They never change a level, a
// target or a plan; no disease is named and nothing is shown in red.
import '../data/models.dart';

enum MarkerFlag { bloodPressure, glucose, hba1c, bmi }

const kBpSystolic = 140; // mmHg
const kBpDiastolic = 90; // mmHg
const kGlucoseMmol = 7.0; // fasting, mmol/L
const kGlucoseMgDl = 126.0; // fasting, mg/dL
const kHba1c = 6.5; // %
const kBmi = 30.0; // kg/m2 (an Asian cut-off of 27.5 exists; not used, see README)

const kD2Source =
    'BloomBack rules D2 (decided). Reference levels for the extra note only: blood pressure '
    '140/90 mmHg or above (WHO 2021 guideline, executive summary Al-Makki et al. 2022); fasting '
    'blood sugar 7.0 mmol/L (126 mg/dL) or above, HbA1c 6.5 % or above (CDC testing reference '
    'levels; WHO uses the same); BMI 30 or above (WHO Expert Consultation, Lancet 2004). Above a '
    'level BloomBack only shows "Ask a doctor before increasing activity". Your plan does not '
    'change. A medical adviser confirms this use before the pilot.';

/// BMI from height (cm) and weight (kg), or null.
double? bmiOf(int? heightCm, int? weightKg) {
  if (heightCm == null || weightKg == null || heightCm <= 0) return null;
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// Which reference levels are reached. Empty = no extra note.
Set<MarkerFlag> doctorNoteFlags({int? heightCm, int? weightKg, Biomarkers? markers}) {
  final out = <MarkerFlag>{};
  final b = markers;
  if (b != null) {
    if ((b.systolic ?? 0) >= kBpSystolic || (b.diastolic ?? 0) >= kBpDiastolic) {
      out.add(MarkerFlag.bloodPressure);
    }
    final g = b.glucose;
    if (g != null && g >= (b.glucoseMgDl ? kGlucoseMgDl : kGlucoseMmol)) out.add(MarkerFlag.glucose);
    if ((b.hba1c ?? 0) >= kHba1c) out.add(MarkerFlag.hba1c);
  }
  final bmi = bmiOf(heightCm, weightKg);
  if (bmi != null && bmi >= kBmi) out.add(MarkerFlag.bmi);
  return out;
}

/// The optional numbers are offered after the first week (B1 "ask gradually").
const kMarkersOfferAfterDays = 7;
