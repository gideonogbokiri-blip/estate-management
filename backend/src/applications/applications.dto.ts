import { Type } from 'class-transformer';
import {
  IsEmail,
  IsInt,
  IsNumber,
  IsOptional,
  IsIn,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';

export class UploadApplicationDocumentDto {
  @IsIn(['management_authorization', 'business_registration', 'ownership_proof', 'address_proof', 'other'])
  category!: string;
}

export class UpdateApplicationDraftDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  proposedName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  estateType?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  address?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  state?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  lga?: string | null;

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

  @IsOptional()
  @IsString()
  @MaxLength(100)
  applicantRelationship?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  applicantContactName?: string | null;

  @ValidateIf((_object, value) => value !== undefined && value !== null && value !== '')
  @IsEmail()
  @MaxLength(254)
  applicantContactEmail?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  applicantContactPhone?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  managementEntityName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  registrationNumber?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  homeCount?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  phaseCount?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  structureSummary?: string | null;
}
