import { IsBoolean, IsEmail, IsIn, IsOptional, IsString, IsUUID, Matches, MaxLength, MinLength } from 'class-validator';

const RELATIONSHIPS = ['SPOUSE', 'CHILD', 'PARENT', 'DEPENDENT', 'OTHER', 'AUTHORIZED_OCCUPANT'] as const;
const MEMBER_TYPES = ['ADULT', 'CHILD', 'RESTRICTED'] as const;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

export class AddHouseholdMemberDto {
  @IsUUID('4') propertyId!: string;
  @IsOptional() @IsUUID('4') primaryUserId?: string;
  @IsString() @MinLength(2) @MaxLength(160) fullName!: string;
  @IsIn(RELATIONSHIPS) relationship!: (typeof RELATIONSHIPS)[number];
  @IsIn(MEMBER_TYPES) memberType!: (typeof MEMBER_TYPES)[number];
  @IsOptional() @IsString() @Matches(DATE) dateOfBirth?: string | null;
  @IsOptional() @IsString() @MaxLength(30) phone?: string | null;
  @IsOptional() @IsEmail() @MaxLength(254) email?: string | null;
  @IsOptional() @IsUUID('4') linkedUserId?: string | null;
  @IsOptional() @IsBoolean() financialAccess?: boolean;
  @IsString() @Matches(DATE) effectiveFrom!: string;
  @IsOptional() @IsString() @Matches(DATE) effectiveTo?: string | null;
}

export class DecideHouseholdMemberDto {
  @IsIn(['approve', 'reject']) decision!: 'approve' | 'reject';
  @IsOptional() @IsString() @MaxLength(500) note?: string;
}

export class EndHouseholdMemberDto {
  @IsString() @MinLength(3) @MaxLength(500) reason!: string;
  @IsOptional() @IsString() @Matches(DATE) effectiveTo?: string;
}
