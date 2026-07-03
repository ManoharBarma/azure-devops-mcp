# syntax=docker/dockerfile:1.7

# Build stage: compile the TypeScript sources into the dist/ output.
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

COPY tsconfig.json ./
COPY src ./src
COPY docs ./docs

RUN npm run build

# Runtime stage: keep only the compiled app and production dependencies.
FROM node:20-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PERSONAL_ACCESS_TOKEN=""
ENV PORT=3000

COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund && npm cache clean --force

COPY --from=build --chown=node:node /app/dist ./dist

# Create a symlink to globally register the bin command if needed natively
RUN ln -s /app/dist/index.js /usr/local/bin/mcp-server-azuredevops && chmod +x /app/dist/index.js

RUN chown -R node:node /app
USER node

# Expose the network listener wrapper port
EXPOSE 3000

# RUN VIA SSE: This spawns the app as an HTTP listener so other computers can reach it
ENTRYPOINT ["node", "/app/dist/index.js", "--transport", "sse"]