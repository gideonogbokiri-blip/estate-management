import { IsDateString, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateSecurityIncidentDto {
  @IsIn(['safety', 'theft', 'suspicious_activity', 'property_damage', 'access_control', 'other']) category!: string;
  @IsIn(['normal', 'high', 'urgent']) priority!: string;
  @IsString() @MaxLength(1000) description!: string;
  @IsOptional() @IsString() @MaxLength(120) locationDescription?: string;
  @IsDateString({ strict: true }) observedAt!: string;
}

export class ReviewSecurityIncidentDto {
  @IsIn(['acknowledge', 'investigate', 'resolve', 'close']) command!: string;
  @IsOptional() @IsString() @MaxLength(1000) note?: string;
}
