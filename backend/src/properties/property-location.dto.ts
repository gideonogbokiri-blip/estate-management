import { Type } from 'class-transformer';
import { IsIn, IsNumber, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

export class CapturePropertyLocationDto {
  @Type(() => Number) @IsNumber({ allowNaN: false, allowInfinity: false }) @Min(-90) @Max(90)
  latitude!: number;

  @Type(() => Number) @IsNumber({ allowNaN: false, allowInfinity: false }) @Min(-180) @Max(180)
  longitude!: number;

  @IsOptional() @Type(() => Number) @IsNumber({ allowNaN: false, allowInfinity: false }) @Min(0) @Max(100000)
  accuracyMeters?: number;

  @IsIn(['GPS_DEVICE', 'MAP_PIN', 'MANUAL']) captureMethod!: 'GPS_DEVICE' | 'MAP_PIN' | 'MANUAL';

  @IsOptional() @IsString() @MaxLength(500) reason?: string;
}

export class VerifyPropertyLocationDto {
  @IsIn(['verify', 'reject']) decision!: 'verify' | 'reject';
  @IsOptional() @IsString() @MinLength(3) @MaxLength(500) reason?: string;
}
