export class MedicationVerificationService {
  verify(
    _name: string,
    _dosage?: string,
  ): {
    verified: boolean;
    confidence: number;
    details?: string;
  } {
    return {
      verified: false,
      confidence: 0,
      details: undefined,
    };
  }
}
