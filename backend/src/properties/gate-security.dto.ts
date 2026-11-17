import { Type } from 'class-transformer';
import { IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';

export class EstateGateContextDto { @IsUUID('4') estateId!: string; }
export class CreateEstateGateDto { @IsString() @MinLength(2) @MaxLength(40) code!: string; @IsString() @MinLength(2) @MaxLength(120) name!: string; }
export class AssignGateStaffDto { @IsUUID('4') userId!: string; }
export class GateCheckInDto { @IsString() @MinLength(1) @MaxLength(256) credential!: string; }
export class ManualAdmissionDto {
  @IsString() @MinLength(1) @MaxLength(100) visitorDisplayName!: string;
  @IsString() @MinLength(1) @MaxLength(80) propertyReference!: string;
  @IsString() @MinLength(10) @MaxLength(500) reason!: string;
}
export class AccessEventsQueryDto {
  @IsOptional() @IsUUID('4') gateId?: string;
  @IsOptional() @IsIn(['entry', 'exit', 'denied', 'manual_admission']) eventKind?: string;
  @IsOptional() @IsDateString({ strict: true }) from?: string;
  @IsOptional() @IsDateString({ strict: true }) to?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 25;
}
export class CreateSecurityContactDto {
  @IsString() @MinLength(2) @MaxLength(80) label!: string;
  @IsString() @MinLength(2) @MaxLength(120) displayName!: string;
  @IsString() @MinLength(5) @MaxLength(50) phoneDisplay!: string;
}
