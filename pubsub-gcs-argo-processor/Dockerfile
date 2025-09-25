# Use a slim Node.js image for the build stage
FROM node:22-slim AS builder

WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install all dependencies, including dev dependencies
RUN npm ci

# Copy the rest of the application source code
COPY . .

# Compile TypeScript to JavaScript
RUN npm run compile

# Use a slim Node.js image for the production stage
FROM node:22-slim

WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev

# Copy the compiled code from the builder stage
COPY --from=builder /usr/src/app/build ./build

# The command to run the application
CMD ["node", "build/src/index.js"]
