import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

const MAINTENANCE_CATEGORIES = ['plumbing', 'electrical', 'security', 'cleaning', 'other'] as const;
const MAINTENANCE_PRIORITIES = ['normal', 'high', 'urgent'] as const;
const MAINTENANCE_COMMANDS = ['review', 'assign', 'start', 'await_parts', 'resume', 'resolve', 'close', 'reject', 'reopen'] as const;

export class CreateMaintenanceRequestDto {
  @IsUUID('4') estateId!: string;
  @IsUUID('4') propertyId!: string;
  @IsIn(MAINTENANCE_CATEGORIES) category!: (typeof MAINTENANCE_CATEGORIES)[number];
  @IsIn(MAINTENANCE_PRIORITIES) priority!: (typeof MAINTENANCE_PRIORITIES)[number];
  @IsString() @MaxLength(700) description!: string;
}

export class MyMaintenanceQueryDto {
  @IsUUID('4') estateId!: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 25;
}

export class LandlordMaintenanceQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 25;
}

export class MaintenanceQueueQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 25;
  @IsOptional() @IsString() @MaxLength(100) status?: string;
  @IsOptional() @IsString() @MaxLength(20) priority?: string;
  @IsOptional() @IsString() @MaxLength(100) search?: string;
}

export class ReviewMaintenanceRequestDto {
  @IsOptional() @IsIn(MAINTENANCE_COMMANDS) command?: (typeof MAINTENANCE_COMMANDS)[number];
  @IsOptional() @IsUUID('4') assigneeUserId?: string;
  @IsOptional() @IsString() @MaxLength(300) reason?: string;
  @IsOptional() @IsString() @MaxLength(700) resolutionSummary?: string;
  @IsOptional() @IsString() @MaxLength(700) residentUpdate?: string;
  @IsOptional() @IsString() @MaxLength(700) internalNote?: string;
}
