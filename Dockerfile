# syntax=docker/dockerfile:1.7

# Build stage: compile the TypeScript sources into the dist/ output.
FROM node:20-alpine AS build
WORKDIR /app

# Install all dependencies first so Docker layer caching remains effective.
# Ignore lifecycle scripts during install so the package's prepare/build hooks do not run before sources are copied.
COPY package*.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

# Copy the TypeScript configuration and application sources for compilation.
COPY tsconfig.json ./
COPY src ./src
COPY docs ./docs

# Generate the production build output expected by the package entrypoint.
RUN npm run build

# Runtime stage: keep only the compiled app and production dependencies.
FROM node:20-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
# Runtime secrets should be injected via environment variables at container start time.
ENV PERSONAL_ACCESS_TOKEN=""

# Install only production dependencies to reduce attack surface and image size.
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund && npm cache clean --force

# Copy the compiled application into the runtime image.
COPY --from=build --chown=node:node /app/dist ./dist

# Run as a non-root user to avoid privilege escalation in the container.
RUN chown -R node:node /app
USER node

# The MCP server uses stdio for JSON-RPC, so start the compiled Node process directly.
ENTRYPOINT ["node", "/app/dist/index.js"]
