# Dockerfile for Spark jobs
FROM apache/spark:3.5.0-python3

USER root

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
COPY requirements.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Copy Spark job code
COPY src/ /opt/spark-jobs/src/
COPY manifests/ /opt/spark-jobs/manifests/

# Set working directory
WORKDIR /opt/spark-jobs

# Configure Spark
ENV SPARK_HOME=/opt/spark
ENV PYTHONPATH=/opt/spark-jobs:$PYTHONPATH
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

# Download Iceberg and AWS dependencies
RUN wget -P $SPARK_HOME/jars \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.4.2/iceberg-spark-runtime-3.5_2.12-1.4.2.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar

USER 185

CMD ["/opt/spark/bin/spark-submit"]
