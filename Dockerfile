# Multistage Dockerfile in nodejs

# CUSS Applet Builder
FROM maven:3.6.3-jdk-11 AS cuss-builder

WORKDIR /build
ENV JAVA_HOME="/opt/jdk1.7.0_21"
ENV PATH="${JAVA_HOME}/bin:${PATH}"
ENV SOURCE="cuss-applet"
RUN wget \
  --no-verbose https://blobanme.blob.core.windows.net/uae-project-files/jdk-7u21-linux-x64.tar.gz \
  --directory-prefix /tmp
RUN tar -xzf /tmp/jdk-7u21-linux-x64.tar.gz \
  --directory /opt
COPY $SOURCE/pom.xml ./pom.xml
RUN mvn -Dhttps.protocols=TLSv1.2 dependency:go-offline --batch-mode
COPY $SOURCE/. ./
RUN mvn -Dhttps.protocols=TLSv1.2 package


# UI Application Builder
FROM node:13-alpine AS ui-builder

RUN apk add --no-cache git
WORKDIR /build
ENV SOURCE="ui-application"
COPY $SOURCE/package*.json ./
RUN npm ci
COPY $SOURCE/. ./
EXPOSE 80
RUN npm run build


# Host Image
FROM nginx:stable-alpine
RUN mkdir /etc/nginx/default-locations
RUN sed -i -e '/log_format/{i \ \    log_format main escape=none $request_body;' -e 'N;N;d;}' /etc/nginx/nginx.conf
ADD logging.conf /etc/nginx/default-locations/logging.conf
RUN sed -i -e '/^}/iinclude \/etc\/nginx\/default-locations\/\*.conf;' -e '/^}/ierror_page  405     =200 $uri;' -e '/^}/iaccess_log off;' /etc/nginx/conf.d/default.conf
COPY --from=ui-builder /build/public /usr/share/nginx/html/
COPY --from=cuss-builder /build/target/classes/. /usr/share/nginx/html/applet/	
