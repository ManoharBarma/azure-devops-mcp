# Build MCP app and install into runtime image, then install code-server
FROM node:20-bullseye AS build
WORKDIR /app

# Install dependencies for build
COPY package*.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

# Copy sources and build
COPY tsconfig.json ./
COPY src ./src
COPY docs ./docs
RUN npm run build

FROM node:20-bullseye AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PERSONAL_ACCESS_TOKEN=""

# Install runtime deps and install this package globally so `mcp-server-azuredevops` is available
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund && npm cache clean --force
COPY --from=build /app/dist ./dist
RUN npm install -g .

# Install code-server (official install script)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create a non-root user for code-server
RUN useradd -m coder && mkdir -p /home/coder/project && chown -R coder:coder /home/coder

USER coder
WORKDIR /home/coder/project

EXPOSE 8080

ENTRYPOINT ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "password"]
