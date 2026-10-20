import type { DeviceCommand } from '@domain/entities/DeviceCommand';
import type { IDeviceCommandRepository } from '@domain/repositories/IDeviceCommandRepository';
import { BadRequestError, ForbiddenError, NotFoundError } from '@shared/errors';

export type AcknowledgeDeviceCommandResultDTO = {
  commandId: string;
  status: 'EXECUTED' | 'FAILED';
};

const ALLOWED_FINAL_STATUSES = new Set(['EXECUTED', 'FAILED'] as const);
type AllowedFinalStatus = typeof ALLOWED_FINAL_STATUSES extends Set<infer S> ? S : never;

export class AcknowledgeDeviceCommandResult {
  constructor(private readonly commandRepo: IDeviceCommandRepository) {}

  async execute(
    commandId: string,
    deviceId: string,
    status: string,
    error?: string | null,
  ): Promise<AcknowledgeDeviceCommandResultDTO> {
    const cleanCommandId = commandId.trim();
    const cleanDeviceId = deviceId.trim();

    const command: DeviceCommand | null = await this.commandRepo.findById(cleanCommandId);
    if (!command) {
      throw new NotFoundError('Command not found');
    }

    if (command.deviceId !== cleanDeviceId) {
      throw new ForbiddenError(
        'This command belongs to a different device; acknowledgement denied.',
      );
    }

    if (!ALLOWED_FINAL_STATUSES.has(status as AllowedFinalStatus)) {
      throw new BadRequestError(
        `Invalid status. Must be one of: EXECUTED, FAILED. Received: ${status}`,
      );
    }

    const sanitizedError =
      status === 'FAILED' && typeof error === 'string' && error.trim().length > 0
        ? error.trim()
        : null;

    const updated = await this.commandRepo.updateResult(cleanCommandId, {
      status: status as 'EXECUTED' | 'FAILED',
      error: sanitizedError,
    });
    if (!updated) {
      throw new NotFoundError('Command not found');
    }

    return {
      commandId: updated.id,
      status: updated.status as 'EXECUTED' | 'FAILED',
    };
  }
}
