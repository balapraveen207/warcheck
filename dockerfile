FROM openjdk:11-jre-slim
COPY jenkins.war /usr/share/jenkins/jenkins.war
EXPOSE 8080
CMD ["java", "-jar", "/usr/share/jenkins/jenkins.war"]
