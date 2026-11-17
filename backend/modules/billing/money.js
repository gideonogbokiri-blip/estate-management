class MoneyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MoneyError';
    this.code = code;
  }
}

function validateScale(scale) {
  if (!Number.isInteger(scale) || scale < 0 || scale > 6) {
    throw new MoneyError('INVALID_CURRENCY_SCALE', 'Use the configured currency precision from the payment service.');
  }
}

function normalizeDecimal(amount, scale) {
  validateScale(scale);
  if (typeof amount !== 'string' || !/^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(amount)) {
    throw new MoneyError('INVALID_AMOUNT', 'Money must be provided as a non-negative decimal string.');
  }
  const [whole, fraction = ''] = amount.split('.');
  if (fraction.length > scale) {
    throw new MoneyError('INVALID_PRECISION', 'Amount exceeds the configured currency precision.');
  }
  return scale === 0 ? whole : `${whole}.${fraction.padEnd(scale, '0')}`;
}

function toMinorUnits(amount, scale) {
  return BigInt(normalizeDecimal(amount, scale).replace('.', ''));
}

function fromMinorUnits(minorUnits, scale) {
  validateScale(scale);
  const amount = BigInt(minorUnits);
  const negative = amount < 0n;
  const digits = (negative ? -amount : amount).toString();
  if (scale === 0) return `${negative ? '-' : ''}${digits}`;
  const padded = digits.padStart(scale + 1, '0');
  const whole = padded.slice(0, -scale);
  const fraction = padded.slice(-scale);
  return `${negative ? '-' : ''}${whole}.${fraction}`;
}

module.exports = { MoneyError, fromMinorUnits, normalizeDecimal, toMinorUnits, validateScale };
