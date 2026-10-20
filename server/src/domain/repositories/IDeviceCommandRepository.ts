import type {
  DeviceCommand,
  DeviceCommandStatus,
  DeviceCommandType,
} from '@domain/entities/DeviceCommand';

export type CreateDeviceCommandData = {
  deviceId: string;
  drawerId?: string | null;
  type: DeviceCommandType;
  status?: DeviceCommandStatus;
  reason?: string | null;
};

export type UpdateCommandResultData = {
  status: 'EXECUTED' | 'FAILED';
  error?: string | null;
};

export interface IDeviceCommandRepository {
  create(data: CreateDeviceCommandData): Promise<DeviceCommand>;
  findById(commandId: string): Promise<DeviceCommand | null>;
  findPendingByDeviceId(deviceId: string): Promise<DeviceCommand[]>;
  markManyAsSentInTransaction(commandIds: string[]): Promise<void>;
  updateResult(
    commandId: string,
    result: UpdateCommandResultData,
  ): Promise<DeviceCommand | null>;
}
