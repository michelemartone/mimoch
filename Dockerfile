# Start with a configurable base image
ARG IMG="debian:unstable"
FROM "${IMG}"

# Declare the arguments
ARG PKG="environment-modules bash"

# Update the package lists
RUN apt-get update

# Install required packages
RUN env DEBIAN_FRONTEND=noninteractive apt-get install --yes \
    ${PKG}

# Copy the current directory to the container and continue inside it
COPY "." "/mnt"
WORKDIR "/mnt"

# Build and test
RUN . /etc/profile.d/modules.sh ; ./mimoch.sh -T
