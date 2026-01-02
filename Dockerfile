FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub global activate dart_frog_cli
RUN dart pub global run dart_frog_cli:dart_frog build

FROM dart:stable
WORKDIR /app
COPY --from=build /app/build ./build
COPY --from=build /app/.dart_tool ./.dart_tool

# Cloud Run requires listening on 0.0.0.0
ENV PORT=8080
EXPOSE 8080

CMD ["dart", "build/bin/server.dart"]
