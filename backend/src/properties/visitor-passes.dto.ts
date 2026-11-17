import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreateVisitorPassDto {
  @IsUUID('4') estateId!: string;
  @IsUUID('4') propertyId!: string;
  @IsString() @MaxLength(100) visitorDisplayName!: string;
  @IsString() validFrom!: string;
  @IsString() validUntil!: string;
  @IsOptional() @IsString() @MaxLength(80) vehicleSummary?: string;
}

export class MyVisitorPassesQueryDto {
  @IsUUID('4') estateId!: string;
}

export class RevokeVisitorPassDto {
  @IsString() @MaxLength(300) reason!: string;
}
