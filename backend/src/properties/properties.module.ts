import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { PrivateDocumentsModule } from '../private-documents/private-documents.module.js';
import { EstatesController } from './estates.controller.js';
import { PropertiesController } from './properties.controller.js';
import { PropertiesService } from './properties.service.js';
import { StructureController } from './structure.controller.js';
import { ResidentRequestsController } from './resident-requests.controller.js';
import { LandlordEstatesController, LandlordPortfolioController, OwnershipController } from './ownership.controller.js';
import { OwnershipService } from './ownership.service.js';
import { TenanciesController } from './tenancies.controller.js';
import { TenanciesService } from './tenancies.service.js';
import { TenantAccessController } from './tenant-access.controller.js';
import { TenantAccessService } from './tenant-access.service.js';
import { EstateDashboardController } from './estate-dashboard.controller.js';
import { EstateDashboardService } from './estate-dashboard.service.js';
import { MaintenanceController } from './maintenance.controller.js';
import { LandlordMaintenanceController } from './landlord-maintenance.controller.js';
import { MaintenanceService } from './maintenance.service.js';
import { VisitorPassesController } from './visitor-passes.controller.js';
import { VisitorPassesService } from './visitor-passes.service.js';
import { GateSecurityController } from './gate-security.controller.js';
import { GateSecurityService } from './gate-security.service.js';
import { EstateChargesController, ResidentInvoicesController } from './charges.controller.js';
import { EstateChargesService } from './charges.service.js';
import { EstateFacilitiesController } from './facilities.controller.js';
import { EstateFacilitiesService } from './facilities.service.js';
import { EstateAnnouncementsController, ResidentAnnouncementsController } from './announcements.controller.js';
import { EstateAnnouncementsService } from './announcements.service.js';
import { SecurityIncidentsController } from './incidents.controller.js';
import { SecurityIncidentsService } from './incidents.service.js';
import { EstateExpensesController } from './expenses.controller.js';
import { EstateExpensesService } from './expenses.service.js';
import { EstateBudgetsController } from './budgets.controller.js';
import { EstateBudgetsService } from './budgets.service.js';
import { StaffInvitationsController } from './staff-invitations.controller.js';
import { StaffInvitationsService } from './staff-invitations.service.js';
import { EstateSettingsController } from './estate-settings.controller.js';
import { EstateSettingsService } from './estate-settings.service.js';
import { EstateNotificationsController } from './notifications.controller.js';
import { EstateNotificationsService } from './notifications.service.js';
import { EstateWalletsController, PaystackWebhookController } from './wallets.controller.js';
import { EstateWalletService } from './wallets.service.js';
import { LedgerService } from './ledger.service.js';
import { EstateTreasuryController } from './treasury.controller.js';
import { EstateTreasuryService } from './treasury.service.js';
import { EstatePayoutController } from './payouts.controller.js';
import { EstatePayoutService } from './payouts.service.js';
import { RentController } from './rent.controller.js';
import { RentService } from './rent.service.js';

@Module({
  imports: [AuthModule, PrivateDocumentsModule],
  controllers: [EstatesController, PropertiesController, StructureController, ResidentRequestsController, OwnershipController, LandlordPortfolioController, LandlordEstatesController, TenanciesController, TenantAccessController, EstateDashboardController, MaintenanceController, LandlordMaintenanceController, VisitorPassesController, GateSecurityController, EstateChargesController, ResidentInvoicesController, EstateFacilitiesController, EstateAnnouncementsController, ResidentAnnouncementsController, SecurityIncidentsController, EstateExpensesController, EstateBudgetsController, EstateNotificationsController, StaffInvitationsController, EstateSettingsController, EstateWalletsController, PaystackWebhookController, EstateTreasuryController, EstatePayoutController, RentController],
  providers: [PropertiesService, OwnershipService, TenanciesService, TenantAccessService, EstateDashboardService, MaintenanceService, VisitorPassesService, GateSecurityService, EstateChargesService, EstateFacilitiesService, EstateAnnouncementsService, SecurityIncidentsService, EstateExpensesService, EstateBudgetsService, EstateNotificationsService, StaffInvitationsService, EstateSettingsService, EstateWalletService, LedgerService, EstateTreasuryService, EstatePayoutService, RentService],
})
export class PropertiesModule {}
