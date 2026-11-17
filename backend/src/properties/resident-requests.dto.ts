import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

const RELATIONSHIPS = ['owner', 'tenant', 'household_member', 'authorized_occupant'] as const;

export class CreateResidentJoinRequestDto {
  @IsUUID('4') estateId!: string;
  @IsOptional() @IsUUID('4') propertyId?: string | null;
  @IsOptional() @IsIn(RELATIONSHIPS) relationship?: (typeof RELATIONSHIPS)[number] | null;
  @IsOptional() @IsString() @MaxLength(1000) note?: string | null;
}

export class DecideResidentJoinRequestDto {
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
}

export class ResidentJoinRequestQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  pageSize = 25;

  @IsOptional() @IsIn(['pending', 'approved', 'rejected'])
  status?: 'pending' | 'approved' | 'rejected';
}
