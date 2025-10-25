"""
Spark job to process raw e-commerce orders and write to Iceberg curated layer
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, when, sum as _sum, count, avg, max as _max,
    to_timestamp, date_format, year, month, dayofmonth,
    struct, array, explode, hash
)
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType,
    IntegerType, TimestampType, ArrayType
)
from datetime import datetime

def create_spark_session():
    """Initialize Spark session with Iceberg support"""
    return SparkSession.builder \
        .appName("ProcessOrders") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.gridata", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.gridata.type", "hadoop") \
        .config("spark.sql.catalog.gridata.warehouse", "s3a://gridata-curated/warehouse") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio.minio.svc.cluster.local:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "${MINIO_ACCESS_KEY}") \
        .config("spark.hadoop.fs.s3a.secret.key", "${MINIO_SECRET_KEY}") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .getOrCreate()

def read_raw_orders(spark, input_path):
    """Read raw orders from MinIO"""
    print(f"Reading raw orders from: {input_path}")

    return spark.read \
        .format("parquet") \
        .load(input_path)

def transform_orders(df):
    """
    Apply business logic transformations:
    - Parse and validate order data
    - Calculate order totals
    - Enrich with derived fields
    - Handle data quality issues
    """

    # Convert timestamps
    df = df.withColumn(
        "order_timestamp",
        to_timestamp(col("order_date"))
    )

    # Add date partitions
    df = df.withColumn("year", year(col("order_timestamp"))) \
           .withColumn("month", month(col("order_timestamp"))) \
           .withColumn("day", dayofmonth(col("order_timestamp")))

    # Calculate order totals
    df = df.withColumn(
        "order_total",
        col("subtotal") + col("tax") + col("shipping_cost") - col("discount")
    )

    # Validate order amounts
    df = df.withColumn(
        "is_valid_amount",
        when(
            (col("order_total") > 0) & (col("order_total") < 100000),
            True
        ).otherwise(False)
    )

    # Categorize orders by value
    df = df.withColumn(
        "order_category",
        when(col("order_total") < 50, "small")
        .when(col("order_total") < 200, "medium")
        .when(col("order_total") < 1000, "large")
        .otherwise("very_large")
    )

    # Handle missing customer data
    df = df.withColumn(
        "customer_id_clean",
        when(col("customer_id").isNull(), "unknown")
        .otherwise(col("customer_id"))
    )

    # Add processing metadata
    df = df.withColumn(
        "processed_at",
        to_timestamp(lit(datetime.utcnow().isoformat()))
    )

    df = df.withColumn(
        "data_quality_score",
        when(col("is_valid_amount") & col("customer_id_clean") != "unknown", 1.0)
        .when(col("is_valid_amount"), 0.8)
        .otherwise(0.3)
    )

    return df

def write_to_iceberg(df, table_name):
    """Write transformed data to Iceberg table"""

    print(f"Writing to Iceberg table: {table_name}")

    # Write to Iceberg with partitioning
    df.writeTo(f"gridata.ecommerce.{table_name}") \
        .using("iceberg") \
        .partitionedBy("year", "month") \
        .tableProperty("write.format.default", "parquet") \
        .tableProperty("write.metadata.compression-codec", "gzip") \
        .createOrReplace()

    # Collect statistics
    record_count = df.count()
    print(f"Successfully wrote {record_count} records to {table_name}")

    return record_count

def write_rejected_records(df, output_path):
    """Write records that failed validation to rejected folder"""

    rejected = df.filter(col("data_quality_score") < 0.5)

    if rejected.count() > 0:
        print(f"Writing {rejected.count()} rejected records to {output_path}")

        rejected.write \
            .mode("append") \
            .parquet(output_path)

def main(input_path, execution_date):
    """Main processing logic"""

    print(f"Starting order processing job for {execution_date}")

    # Create Spark session
    spark = create_spark_session()

    try:
        # Read raw data
        raw_df = read_raw_orders(spark, input_path)

        print(f"Read {raw_df.count()} raw orders")

        # Transform data
        transformed_df = transform_orders(raw_df)

        # Write valid records to Iceberg
        valid_df = transformed_df.filter(col("data_quality_score") >= 0.5)
        record_count = write_to_iceberg(valid_df, "orders")

        # Write rejected records
        rejected_path = f"s3a://gridata-raw/rejected/orders/{execution_date}/"
        write_rejected_records(transformed_df, rejected_path)

        # Print summary statistics
        print("\n=== Processing Summary ===")
        print(f"Total records processed: {transformed_df.count()}")
        print(f"Valid records: {record_count}")
        print(f"Rejected records: {transformed_df.filter(col('data_quality_score') < 0.5).count()}")

        transformed_df.groupBy("order_category").count().show()

        print("Order processing completed successfully")

    except Exception as e:
        print(f"Error processing orders: {str(e)}")
        raise
    finally:
        spark.stop()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: process_orders.py <input_path> <execution_date>")
        sys.exit(1)

    input_path = sys.argv[1]
    execution_date = sys.argv[2]

    main(input_path, execution_date)
