export interface DrawerSensorState {
  id: string;
  drawerId: string;
  temperature: number | null;
  humidity: number | null;
  fireDetected: boolean;
  updatedAt: Date;
  createdAt: Date;
}
