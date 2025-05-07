FROM openjdk:11-jre-slim

# Install Git and Git LFS
RUN apt-get update && \
    apt-get install -y git git-lfs && \
    git lfs install

# Clone the repository and fetch LFS files
RUN git clone https://github.com/your-username/your-repo.git /repo && \
    cd /repo && \
    git lfs pull

# Copy the jenkins.war file
COPY /repo/jenkins.war /usr/share/jenkins/jenkins.war

EXPOSE 8080
CMD ["java", "-jar", "/usr/share/jenkins/jenkins.war"]
