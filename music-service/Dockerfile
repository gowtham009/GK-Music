FROM maven:3.9.7-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY . .
RUN mvn -pl music-service -am package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/music-service/target/*.jar /app/app.jar
EXPOSE 8083
ENTRYPOINT ["java","-jar","/app/app.jar"]

