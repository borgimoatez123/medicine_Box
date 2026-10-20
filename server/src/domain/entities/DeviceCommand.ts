export type DeviceCommandType = 'OPEN_DRAWER' | 'CLOSE_DRAWER';

export type DeviceCommandStatus =
  | 'PENDING'
  | 'SENT'
  | 'EXECUTED'
  | 'FAILED'
  | 'EXPIRED';

export interface DeviceCommand {
  id: string;
  deviceId: string;
  drawerId: string | null;
  type: DeviceCommandType;
  status: DeviceCommandStatus;
  reason: string | null;
  createdAt: Date;
  sentAt: Date | null;
  executedAt: Date | null;
  error: string | null;
}
