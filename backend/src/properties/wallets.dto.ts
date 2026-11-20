import { IsIn, IsUUID, Matches, MaxLength } from 'class-validator';

export class ProvisionWalletDto {
  @IsUUID('4') estateId!: string;
}

export class PayWalletRentDto {
  @IsUUID('4') estateId!: string;
  @IsUUID('4') invoiceId!: string;
  @Matches(/^[0-9]+(\.[0-9]{1,2})?$/) amount!: string;
}

export class CreateFundingIntentDto {
  @IsUUID('4') estateId!: string;
  @Matches(/^[0-9]+(\.[0-9]{1,2})?$/) amount!: string;
}
