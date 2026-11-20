import { Controller, Get, Param, ParseUUIDPipe, Query, Req, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { ReportsService } from './reports.service.js';

function csvCell(value: unknown) {
  const text = value === null || value === undefined ? '' : String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function toCsv(headers: string[], rows: unknown[][]) {
  return [headers, ...rows].map((row) => row.map(csvCell).join(',')).join('\n');
}

@Controller('estate/estates/:estateId')
@UseGuards(AccessTokenGuard)
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get('reports/summary')
  summary(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.reports.managerSummary(request.actor.userId, estateId);
  }

  @Get('statements/wallet')
  async walletStatement(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Query('from') from: string | undefined, @Query('to') to: string | undefined,
    @Query('walletId') walletId: string | undefined, @Query('format') format: string | undefined,
    @Res() response: Response) {
    const result = await this.reports.walletStatement(request.actor.userId, estateId, { from, to, walletId });
    if (format === 'csv') {
      response.setHeader('Content-Type', 'text/csv; charset=utf-8');
      response.setHeader('Content-Disposition', 'attachment; filename="wallet-statement.csv"');
      response.send(toCsv(
        ['Date', 'Currency', 'Type', 'Amount', 'Signed amount', 'Balance', 'Reference', 'Description', 'Source'],
        result.items.map((item) => [item.date, item.currency, item.type, item.amount, item.signedAmount, item.balance, item.reference, item.description, item.sourceType]),
      ));
      return;
    }
    response.json(result);
  }

  @Get('statements/ledger')
  async ledgerStatement(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Query('from') from: string | undefined, @Query('to') to: string | undefined,
    @Query('format') format: string | undefined, @Res() response: Response) {
    const result = await this.reports.ledgerStatement(request.actor.userId, estateId, { from, to });
    if (format === 'csv') {
      response.setHeader('Content-Type', 'text/csv; charset=utf-8');
      response.setHeader('Content-Disposition', 'attachment; filename="ledger-statement.csv"');
      const rows: unknown[][] = [];
      for (const journal of result.items) {
        for (const entry of journal.entries) {
          rows.push([journal.occurredAt, journal.reference, journal.sourceType, journal.description, entry.accountCode, entry.direction, entry.amount, entry.currency]);
        }
      }
      response.send(toCsv(
        ['Occurred at', 'Reference', 'Source type', 'Description', 'Account', 'Direction', 'Amount', 'Currency'],
        rows,
      ));
      return;
    }
    response.json(result);
  }

  @Get('audit')
  async audit(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Query('from') from: string | undefined, @Query('to') to: string | undefined,
    @Query('action') action: string | undefined, @Query('actorUserId') actorUserId: string | undefined,
    @Query('outcome') outcome: string | undefined, @Query('format') format: string | undefined,
    @Res() response: Response) {
    const result = await this.reports.audit(request.actor.userId, estateId, { from, to, action, actorUserId, outcome });
    if (format === 'csv') {
      response.setHeader('Content-Type', 'text/csv; charset=utf-8');
      response.setHeader('Content-Disposition', 'attachment; filename="audit-log.csv"');
      response.send(toCsv(
        ['Occurred at', 'Actor', 'Action', 'Target type', 'Target id', 'Outcome', 'Reason'],
        result.items.map((item) => [item.occurredAt, item.actorName, item.action, item.targetType, item.targetId, item.outcome, item.reason]),
      ));
      return;
    }
    response.json(result);
  }
}
