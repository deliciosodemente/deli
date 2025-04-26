#s Use official Node.js image as the build stage
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm install

# Copy the rest of the source code
COPY . .

# Build the React app
RUN npm run build

# Use a lightweight server to serve the build folder
FROM node:18-alpine

# Install serve globally
RUN npm install -g serve

# Set working directory
WORKDIR /app

# Copy build output from the build stage
COPY --from=build /app/build ./build

# Expose port 8080
EXPOSE 8080

# Set environment variable PORT to 8080
ENV PORT=8080

# Start the server to serve the build folder on port 8080
CMD ["serve", "-s", "build", "-l", "tcp://0.0.0.0:8080"]
