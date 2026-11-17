import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNumber,
  IsArray,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const PROPERTY_STATUSES = [
  'active',
  'under_development',
  'reserved',
  'under_maintenance',
  'inactive',
] as const;

export class PropertyQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 25;

  @IsOptional()
  @IsIn(PROPERTY_STATUSES)
  status?: (typeof PROPERTY_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}

export class PropertyDraftDto {
  @IsString()
  @MaxLength(80)
  code!: string;

  @IsString()
  @MaxLength(80)
  propertyType!: string;

  @IsOptional()
  @IsIn(PROPERTY_STATUSES)
  status?: (typeof PROPERTY_STATUSES)[number];

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  structureNodeIds?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(80)
  unitNumber?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  address?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(700)
  description?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  latitude?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  longitude?: number | null;
}

export class UpdatePropertyDto {
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  structureNodeIds?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(80)
  code?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  propertyType?: string;

  @IsOptional()
  @IsIn(PROPERTY_STATUSES)
  status?: (typeof PROPERTY_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(80)
  unitNumber?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  address?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(700)
  description?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  latitude?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  longitude?: number | null;
}
