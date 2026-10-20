export class OcrService {
  analyzeImage(_imageBufferOrUrl?: Buffer | string): {
    text: string;
    medicationName?: string;
    dosage?: string;
    form?:
      | 'TABLET'
      | 'CAPSULE'
      | 'LIQUID'
      | 'INJECTION'
      | 'CREAM'
      | 'POWDER'
      | 'OTHER';
  } {
    return {
      text: '',
      medicationName: undefined,
      dosage: undefined,
      form: undefined,
    };
  }
}
