FROM dart:stable AS build

# Install dependencies
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy source code
COPY . .

# Install dart_frog CLI and build
RUN dart pub global activate dart_frog_cli
ENV PATH="$PATH:/root/.pub-cache/bin"
RUN dart_frog build

# Production stage
FROM dart:stable
WORKDIR /app

# Copy built application
COPY --from=build /app/build .

# Set environment variables
ENV PORT=8080
EXPOSE 8080

# Start the server
CMD ["dart", "bin/server.dart"]
