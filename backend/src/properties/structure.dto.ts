import { Type } from 'class-transformer';
import { IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

const TYPES = ['zone', 'street', 'building', 'floor'] as const;

export class StructureQueryDto {
  @IsOptional() @Type(() => Boolean) @IsBoolean()
  includeArchived = false;
}

export class StructureNodeDraftDto {
  @IsIn(TYPES) type!: (typeof TYPES)[number];
  @IsString() @MaxLength(120) name!: string;
  @IsOptional() @IsString() @MaxLength(60) code?: string | null;
  @IsOptional() @IsArray() @IsUUID('4', { each: true }) parentIds?: string[];
  @IsOptional() @IsString() @MaxLength(80) buildingType?: string | null;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(300) floorCount?: number | null;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) sortOrder?: number;
}

export class UpdateStructureNodeDto {
  @IsOptional() @IsString() @MaxLength(120) name?: string;
  @IsOptional() @IsString() @MaxLength(60) code?: string | null;
  @IsOptional() @IsArray() @IsUUID('4', { each: true }) parentIds?: string[];
  @IsOptional() @IsString() @MaxLength(80) buildingType?: string | null;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(300) floorCount?: number | null;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) sortOrder?: number;
}
