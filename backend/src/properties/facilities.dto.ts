import { Type } from 'class-transformer';
import { IsDateString, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min } from 'class-validator';

export class CreateEstateFacilityDto {
  @IsString() @MaxLength(60) code!: string;
  @IsString() @MaxLength(120) name!: string;
  @IsString() @MaxLength(60) category!: string;
  @IsString() @MaxLength(700) description!: string;
  @IsString() @MaxLength(160) location!: string;
  @Type(() => Number) @IsInt() @Min(1) @Max(500) capacity!: number;
  @Type(() => Number) @IsInt() @Min(15) @Max(720) durationMinutes!: number;
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/) openingTime!: string;
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/) closingTime!: string;
  @Type(() => Number) @IsInt() @Min(0) @Max(168) bookingLeadHours = 2;
}

export class CreateFacilityBookingDto {
  @IsUUID('4') propertyId!: string;
  @IsDateString({ strict: true }) startsAt!: string;
  @IsDateString({ strict: true }) endsAt!: string;
  @Type(() => Number) @IsInt() @Min(1) @Max(500) attendeeCount!: number;
  @IsOptional() @IsString() @MaxLength(500) purpose?: string;
  @Type(() => Number) @IsInt() @Min(1) acceptedPolicyVersion!: number;
}

export class ReviewFacilityBookingDto {
  @IsString() @Matches(/^(confirm|decline)$/) command!: 'confirm' | 'decline';
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
}
