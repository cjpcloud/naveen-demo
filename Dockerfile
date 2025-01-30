# First stage: Build JRE and package the app
FROM eclipse-temurin:17-jdk-alpine AS jre-builder

WORKDIR /opt/app

# Install required tools
RUN apk update && apk add --no-cache tar binutils wget

# Install Maven manually
ENV MAVEN_VERSION 3.5.4
RUN wget http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz && \
    tar -zxvf apache-maven-$MAVEN_VERSION-bin.tar.gz && \
    rm apache-maven-$MAVEN_VERSION-bin.tar.gz && \
    mv apache-maven-$MAVEN_VERSION /usr/lib/mvn
ENV PATH="/usr/lib/mvn/bin:${PATH}"

# Copy source code and package the application
COPY . /opt/app

# Build the application (skip tests for faster builds)
#RUN mvn clean package -DskipTests

# Extract dependencies for jlink
RUN jdeps --ignore-missing-deps -q --recursive --multi-release 17 --print-module-deps \
    --class-path 'BOOT-INF/lib/*' target/igloo-auth-engine-service-0.0.1-SNAPSHOT.jar > modules.txt

RUN echo "java.base" > modules.txt

# Build minimal JRE using jlink
RUN $JAVA_HOME/bin/jlink \
    --verbose \
    --add-modules $(cat modules.txt) \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=2 \
    --output /optimized-jdk-17

# Second stage: Use custom JRE and run the app using scratch image
FROM scratch

# Copy the minimal JRE from the build stage
COPY --from=jre-builder /optimized-jdk-17 /opt/jdk

# Set JAVA_HOME and PATH
ENV JAVA_HOME=/opt/jdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Use the nobody user in scratch (no shell or utilities)
USER nobody

# Copy the built JAR file from the build stage to the /app directory
COPY --from=jre-builder /opt/app/target/igloo-auth-engine-service-0.0.1-SNAPSHOT.jar /app/igloo-auth-engine-service-0.0.1-SNAPSHOT.jar

WORKDIR /app

EXPOSE 8080

# Set entrypoint
ENTRYPOINT [ "java", "-jar", "/app/igloo-auth-engine-service-0.0.1-SNAPSHOT.jar" ]

