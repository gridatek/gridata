"""
E-commerce Customer 360 Pipeline
Builds comprehensive customer profiles by joining orders, product views, and customer data
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

default_args = {
    'owner': 'gridata',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'ecommerce_customer_360',
    default_args=default_args,
    description='Build customer 360 view from multiple data sources',
    schedule_interval='0 2 * * *',  # Daily at 2 AM
    catchup=False,
    tags=['ecommerce', 'customer', 'analytics'],
)

# Task 1: Join customer demographics with order history
join_customer_orders = SparkKubernetesOperator(
    task_id='join_customer_orders',
    namespace='spark-operator',
    application_file='spark-jobs/manifests/customer_order_join.yaml',
    kubernetes_conn_id='kubernetes_default',
    dag=dag,
    api_group='sparkoperator.k8s.io',
    api_version='v1beta2',
)

# Task 2: Aggregate product views and clickstream data
aggregate_clickstream = SparkKubernetesOperator(
    task_id='aggregate_clickstream',
    namespace='spark-operator',
    application_file='spark-jobs/manifests/clickstream_aggregation.yaml',
    kubernetes_conn_id='kubernetes_default',
    dag=dag,
    api_group='sparkoperator.k8s.io',
    api_version='v1beta2',
)

# Task 3: Calculate customer lifetime value (CLV)
calculate_clv = SparkKubernetesOperator(
    task_id='calculate_customer_ltv',
    namespace='spark-operator',
    application_file='spark-jobs/manifests/calculate_clv.yaml',
    kubernetes_conn_id='kubernetes_default',
    dag=dag,
    api_group='sparkoperator.k8s.io',
    api_version='v1beta2',
)

# Task 4: Build final customer 360 table
build_customer_360 = SparkKubernetesOperator(
    task_id='build_customer_360',
    namespace='spark-operator',
    application_file='spark-jobs/manifests/customer_360_final.yaml',
    kubernetes_conn_id='kubernetes_default',
    dag=dag,
    api_group='sparkoperator.k8s.io',
    api_version='v1beta2',
)

# Task 5: Data quality validation
validate_customer_360 = PythonOperator(
    task_id='validate_customer_360',
    python_callable=lambda: print("Running customer 360 data quality checks"),
    dag=dag,
)

# Define dependencies
[join_customer_orders, aggregate_clickstream] >> calculate_clv >> build_customer_360 >> validate_customer_360
