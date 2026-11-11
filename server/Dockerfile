FROM node:22-alpine
WORKDIR /app

# Prisma engines need openssl present at runtime and migrate time
RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci

COPY . .
RUN npx prisma generate && npm run build

EXPOSE 3000
CMD ["node", "dist/main.js"]
