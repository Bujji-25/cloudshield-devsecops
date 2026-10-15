# Stage 1: Build the Spring Boot application
FROM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /app

COPY pom.xml .
COPY src ./src

RUN mvn clean package -DskipTests

# Stage 2: Run the application
FROM eclipse-temurin:11-jre

WORKDIR /app

COPY --from=build /app/target/database_service_project-0.0.7.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
