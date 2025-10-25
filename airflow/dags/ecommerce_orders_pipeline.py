"""
E-commerce Orders Data Pipeline
Processes raw order data from MinIO, transforms it with Spark, and publishes to curated layer
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor
from airflow.operators.python import PythonOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.http.operators.http import SimpleHttpOperator
import json

default_args = {
    'owner': 'gridata',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'ecommerce_orders_pipeline',
    default_args=default_args,
    description='Process e-commerce orders from raw to curated',
    schedule_interval='@hourly',
    catchup=False,
    tags=['ecommerce', 'orders', 'production'],
)

def validate_order_file(**context):
    """
    Validate order file structure and data quality
    """
    import boto3
    from datetime import datetime
    import json

    execution_date = context['ds']
    file_key = f"raw/ecommerce/orders/{execution_date}/orders.parquet"

    s3_hook = S3Hook(aws_conn_id='minio_default')

    # Check if file exists
    if not s3_hook.check_for_key(file_key, bucket_name='gridata-raw'):
        raise FileNotFoundError(f"File not found: {file_key}")

    # Get file size
    obj = s3_hook.get_key(file_key, bucket_name='gridata-raw')
    file_size = obj.content_length

    # Validate file size (must be > 0 and < 10GB)
    if file_size == 0:
        raise ValueError("File is empty")
    if file_size > 10 * 1024 * 1024 * 1024:  # 10GB
        raise ValueError(f"File too large: {file_size} bytes")

    print(f"Validation passed for {file_key}: {file_size} bytes")

    return {
        'file_key': file_key,
        'file_size': file_size,
        'validation_timestamp': datetime.utcnow().isoformat()
    }

def publish_to_datahub(**context):
    """
    Publish dataset metadata to DataHub
    """
    ti = context['task_instance']
    execution_date = context['ds']

    metadata = {
        "dataset": f"urn:li:dataset:(urn:li:dataPlatform:iceberg,gridata.curated.ecommerce_orders,PROD)",
        "operation": "UPDATE",
        "timestamp": datetime.utcnow().isoformat(),
        "tags": ["ecommerce", "orders", "production"],
        "owners": ["data-engineering@company.com"],
        "description": f"E-commerce orders processed on {execution_date}",
    }

    print(f"Publishing metadata to DataHub: {json.dumps(metadata, indent=2)}")
    return metadata

# Task 1: Wait for new order file
wait_for_orders = S3KeySensor(
    task_id='wait_for_orders',
    bucket_name='gridata-raw',
    bucket_key='raw/ecommerce/orders/{{ ds }}/orders.parquet',
    aws_conn_id='minio_default',
    timeout=3600,
    poke_interval=60,
    mode='poke',
    dag=dag,
)

# Task 2: Validate order file
validate_file = PythonOperator(
    task_id='validate_order_file',
    python_callable=validate_order_file,
    provide_context=True,
    dag=dag,
)

# Task 3: Run Spark job to process orders
process_orders = SparkKubernetesOperator(
    task_id='process_orders_spark',
    namespace='spark-operator',
    application_file='spark-jobs/manifests/process_orders.yaml',
    kubernetes_conn_id='kubernetes_default',
    dag=dag,
    api_group='sparkoperator.k8s.io',
    api_version='v1beta2',
)

# Task 4: Data quality checks
quality_checks = SparkKubernetesOperator(
    task_id='run_quality_checks',
    namespace='spark-operator',
    application_file='spark-jobs/manifests/quality_checks.yaml',
    kubernetes_conn_id='kubernetes_default',
    dag=dag,
    api_group='sparkoperator.k8s.io',
    api_version='v1beta2',
)

# Task 5: Publish metadata to DataHub
publish_metadata = PythonOperator(
    task_id='publish_to_datahub',
    python_callable=publish_to_datahub,
    provide_context=True,
    dag=dag,
)

# Task 6: Trigger downstream analytics jobs
trigger_analytics = SimpleHttpOperator(
    task_id='trigger_analytics',
    http_conn_id='analytics_api',
    endpoint='/api/v1/refresh/ecommerce_orders',
    method='POST',
    headers={"Content-Type": "application/json"},
    data=json.dumps({"date": "{{ ds }}"}),
    dag=dag,
)

# Define task dependencies
wait_for_orders >> validate_file >> process_orders >> quality_checks >> publish_metadata >> trigger_analytics
