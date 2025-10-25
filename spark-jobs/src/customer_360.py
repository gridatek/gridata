"""
Spark job to build Customer 360 view
Combines customer demographics, order history, and behavioral data
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, sum as _sum, count, avg, max as _max, min as _min,
    datediff, current_date, months_between, first, last,
    struct, collect_list, when, lit, coalesce
)
from pyspark.sql.window import Window
from datetime import datetime

def create_spark_session():
    """Initialize Spark session with Iceberg support"""
    return SparkSession.builder \
        .appName("Customer360") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.gridata", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.gridata.type", "hadoop") \
        .config("spark.sql.catalog.gridata.warehouse", "s3a://gridata-curated/warehouse") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio.minio.svc.cluster.local:9000") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .getOrCreate()

def load_customer_data(spark):
    """Load customer demographic data"""
    return spark.table("gridata.ecommerce.customers")

def load_order_data(spark):
    """Load order history from Iceberg"""
    return spark.table("gridata.ecommerce.orders")

def load_clickstream_data(spark):
    """Load aggregated clickstream data"""
    return spark.table("gridata.ecommerce.clickstream_daily")

def calculate_order_metrics(orders_df):
    """Calculate customer order metrics"""

    customer_orders = orders_df.groupBy("customer_id").agg(
        count("order_id").alias("total_orders"),
        _sum("order_total").alias("total_revenue"),
        avg("order_total").alias("avg_order_value"),
        _max("order_timestamp").alias("last_order_date"),
        _min("order_timestamp").alias("first_order_date"),
        collect_list("order_id").alias("order_ids")
    )

    # Calculate recency, frequency, monetary (RFM)
    customer_orders = customer_orders.withColumn(
        "recency_days",
        datediff(current_date(), col("last_order_date"))
    )

    customer_orders = customer_orders.withColumn(
        "customer_tenure_months",
        months_between(current_date(), col("first_order_date"))
    )

    customer_orders = customer_orders.withColumn(
        "purchase_frequency",
        col("total_orders") / (col("customer_tenure_months") + 1)
    )

    return customer_orders

def calculate_customer_ltv(customer_orders):
    """Calculate Customer Lifetime Value (CLV)"""

    # Simple CLV formula: avg_order_value * purchase_frequency * avg_customer_lifespan
    # Assuming 24 months average lifespan
    avg_lifespan_months = 24

    customer_ltv = customer_orders.withColumn(
        "predicted_ltv",
        col("avg_order_value") * col("purchase_frequency") * lit(avg_lifespan_months)
    )

    # Categorize customers by value
    customer_ltv = customer_ltv.withColumn(
        "customer_segment",
        when(col("predicted_ltv") >= 5000, "VIP")
        .when(col("predicted_ltv") >= 1000, "High Value")
        .when(col("predicted_ltv") >= 200, "Medium Value")
        .otherwise("Low Value")
    )

    # Categorize by activity
    customer_ltv = customer_ltv.withColumn(
        "activity_status",
        when(col("recency_days") <= 30, "Active")
        .when(col("recency_days") <= 90, "At Risk")
        .when(col("recency_days") <= 180, "Dormant")
        .otherwise("Churned")
    )

    return customer_ltv

def enrich_with_clickstream(customer_df, clickstream_df):
    """Add clickstream behavioral metrics"""

    # Aggregate clickstream by customer
    clickstream_metrics = clickstream_df.groupBy("customer_id").agg(
        _sum("page_views").alias("total_page_views"),
        _sum("product_views").alias("total_product_views"),
        _sum("add_to_cart").alias("total_add_to_cart"),
        _sum("time_on_site").alias("total_time_on_site"),
        avg("session_duration").alias("avg_session_duration")
    )

    # Calculate conversion metrics
    clickstream_metrics = clickstream_metrics.withColumn(
        "browse_to_cart_rate",
        col("total_add_to_cart") / col("total_product_views")
    )

    # Join with customer data
    enriched = customer_df.join(
        clickstream_metrics,
        on="customer_id",
        how="left"
    )

    # Fill nulls for customers with no clickstream data
    for column in clickstream_metrics.columns:
        if column != "customer_id":
            enriched = enriched.withColumn(
                column,
                coalesce(col(column), lit(0))
            )

    return enriched

def build_customer_360(customers_df, customer_orders, clickstream_df):
    """Build comprehensive customer 360 view"""

    # Calculate LTV
    customer_ltv = calculate_customer_ltv(customer_orders)

    # Join customer demographics with order metrics
    customer_360 = customers_df.join(
        customer_ltv,
        on="customer_id",
        how="left"
    )

    # Enrich with clickstream data
    customer_360 = enrich_with_clickstream(customer_360, clickstream_df)

    # Add calculated fields
    customer_360 = customer_360.withColumn(
        "is_premium_customer",
        when(col("customer_segment").isin(["VIP", "High Value"]), True)
        .otherwise(False)
    )

    customer_360 = customer_360.withColumn(
        "churn_risk_score",
        when(col("activity_status") == "Churned", 1.0)
        .when(col("activity_status") == "Dormant", 0.7)
        .when(col("activity_status") == "At Risk", 0.4)
        .otherwise(0.1)
    )

    customer_360 = customer_360.withColumn(
        "processed_at",
        lit(datetime.utcnow().isoformat())
    )

    return customer_360

def write_customer_360(df, table_name="customer_360"):
    """Write customer 360 to Iceberg"""

    print(f"Writing Customer 360 table: {table_name}")

    df.writeTo(f"gridata.analytics.{table_name}") \
        .using("iceberg") \
        .tableProperty("write.format.default", "parquet") \
        .createOrReplace()

    # Print summary statistics
    print("\n=== Customer 360 Summary ===")
    print(f"Total customers: {df.count()}")

    print("\nCustomer Segments:")
    df.groupBy("customer_segment").count().orderBy(col("count").desc()).show()

    print("\nActivity Status:")
    df.groupBy("activity_status").count().orderBy(col("count").desc()).show()

    print("\nAverage Metrics:")
    df.select(
        avg("predicted_ltv").alias("avg_ltv"),
        avg("total_orders").alias("avg_orders"),
        avg("avg_order_value").alias("avg_aov")
    ).show()

def main():
    """Main processing logic"""

    print("Starting Customer 360 build process")

    spark = create_spark_session()

    try:
        # Load data
        customers = load_customer_data(spark)
        orders = load_order_data(spark)
        clickstream = load_clickstream_data(spark)

        # Calculate order metrics
        customer_orders = calculate_order_metrics(orders)

        # Build customer 360
        customer_360 = build_customer_360(customers, customer_orders, clickstream)

        # Write to Iceberg
        write_customer_360(customer_360)

        print("Customer 360 build completed successfully")

    except Exception as e:
        print(f"Error building Customer 360: {str(e)}")
        raise
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
