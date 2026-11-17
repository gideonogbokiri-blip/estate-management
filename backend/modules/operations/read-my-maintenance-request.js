const { safeMyMaintenanceRequest } = require('./list-my-maintenance-requests');

class MyMaintenanceRequestReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MyMaintenanceRequestReadError';
    this.code = code;
  }
}

function createMyMaintenanceRequestReadUseCase({
  transaction,
  resolveResidentMaintenanceAccess,
  findMyMaintenanceRequest,
} = {}) {
  const ports = { transaction, resolveResidentMaintenanceAccess, findMyMaintenanceRequest };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyMaintenanceRequestReadError('MISSING_ADAPTER', `Resident maintenance detail adapters are required: ${missing.join(', ')}.`);

  return async function readMyMaintenanceRequest({ actorUserId, estateId, requestId } = {}) {
    if (!actorUserId || !estateId || !(typeof requestId === 'string' || typeof requestId === 'number') || !String(requestId).trim()) {
      throw new MyMaintenanceRequestReadError('INVALID_INPUT', 'Authenticated resident, estate and request reference are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveResidentMaintenanceAccess(tx, { actorUserId, estateId });
      if (!access || String(access.userId) !== String(actorUserId) || String(access.estateId) !== String(estateId)
        || access.active !== true || access.mayViewMaintenance !== true) {
        throw new MyMaintenanceRequestReadError('RESIDENT_ACCESS_DENIED', 'The resident cannot view maintenance requests in this estate.');
      }
      // The adapter scopes by actor/property/estate before returning request or updates.
      const row = await findMyMaintenanceRequest(tx, { access, actorUserId, estateId, requestId });
      if (!row || String(row.request?.id) !== String(requestId)) {
        throw new MyMaintenanceRequestReadError('REQUEST_NOT_FOUND', 'The maintenance request was not found.');
      }
      let item;
      try { item = safeMyMaintenanceRequest(row, actorUserId, estateId); }
      catch (error) {
        if (error?.name === 'MyMaintenanceRequestListError') {
          throw new MyMaintenanceRequestReadError(error.code, error.message);
        }
        throw error;
      }
      return Object.freeze({ item });
    });
  };
}

module.exports = { MyMaintenanceRequestReadError, createMyMaintenanceRequestReadUseCase };
