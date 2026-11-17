import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class PlatformTeamRoleDto {
  @IsUUID('4') userId!: string;
  @IsIn(['platform_super_admin', 'platform_application_reviewer']) roleKey!: string;
}

export class PlatformEstateQueryDto {
  @IsOptional() @MaxLength(120) search?: string;
  @IsOptional() @IsIn(['ACTIVE', 'SUSPENDED', 'DEACTIVATED']) status?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 25;
}
