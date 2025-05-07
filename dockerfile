# Stage 1: Build
FROM openjdk:11-jre-slim AS build

WORKDIR /app
COPY . .
RUN apt-get update && \
    apt-get install -y git-lfs && \
    git lfs install && \
    git lfs pull && \
    rm -rf /var/lib/apt/lists/*

# Stage 2: Runtime
FROM openjdk:11-jre-slim

WORKDIR /usr/share/jenkins
COPY --from=build /app/jenkins.war .

EXPOSE 8080
CMD ["java", "-jar", "jenkins.war"]
