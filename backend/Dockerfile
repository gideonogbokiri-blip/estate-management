FROM node:24-alpine

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma
COPY prisma.config.ts ./
RUN npm ci

COPY . .
RUN npx prisma generate && npm run build

ENV NODE_ENV=production
ENV PORT=4100

# Private uploads live outside the image so they survive container replacement.
RUN mkdir -p /app/.private-documents && chown -R node:node /app
USER node

EXPOSE 4100

CMD ["sh", "-c", "npx prisma migrate deploy && node dist/src/main.js"]
