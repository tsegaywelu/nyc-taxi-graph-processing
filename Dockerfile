# Base image: ubuntu:22.04
FROM ubuntu:22.04

# ARGs
# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG TARGETPLATFORM=linux/amd64,linux/arm64
ARG DEBIAN_FRONTEND=noninteractive

# neo4j 2025.08.0 installation (match GDS v2.21.0) and some cleanup
RUN apt-get update && \
    apt-get install -y wget gnupg software-properties-common && \
    wget -O - https://debian.neo4j.com/neotechnology.gpg.key | apt-key add - && \
    echo 'deb https://debian.neo4j.com stable latest' > /etc/apt/sources.list.d/neo4j.list && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y nano unzip neo4j=1:2025.08.0 python3-pip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


RUN ln -s /usr/lib/jvm/java-21-openjdk-$(dpkg --print-architecture) \
    /opt/java-home
ENV JAVA_HOME=/opt/java-home


WORKDIR /cse511

RUN wget -O yellow_tripdata_2022-03.parquet https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2022-03.parquet &&\
    python3 -m pip install --upgrade pip && \
    pip3 install pyarrow pandas neo4j && \
    wget -O /var/lib/neo4j/plugins/neo4j-graph-data-science-2.21.0.jar https://github.com/neo4j/graph-data-science/releases/download/2.21.0/neo4j-graph-data-science-2.21.0.jar

ADD data_loader.py /cse511/

RUN printf '%s\n' \
    "server.default_listen_address=0.0.0.0" \
    "server.bolt.listen_address=:7687" \
    "server.http.listen_address=:7474" \
    "dbms.security.procedures.allowlist=apoc.*,gds.*" \
    "dbms.security.procedures.unrestricted=apoc.*,gds.*" \
    >> /etc/neo4j/neo4j.conf && \
    neo4j-admin dbms set-initial-password graphprocessing



# Run the data loader script
RUN chmod +x /cse511/data_loader.py && \
    neo4j start && \
    python3 data_loader.py && \
    neo4j stop

# Expose neo4j ports
EXPOSE 7474 7687

# Start neo4j service and show the logs on container run
CMD ["/bin/bash", "-c", "neo4j start && tail -f /dev/null"]
