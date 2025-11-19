import os
import json
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings

def log_processing():
    # 1. Set up the Flink Environment
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(1) # Keep it simple for the assignment
    
    # Create Table Environment
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    t_env = StreamTableEnvironment.create(env, environment_settings=settings)

    # Get Kafka Connection Details (Passed via Environment Variables)
    kafka_brokers = os.environ.get('KAFKA_BROKERS', 'localhost:9092')
    source_topic = 'ticket-bookings'
    sink_topic = 'analytics-results'

    print(f"🚀 Starting Flink Job. Listening to {source_topic}...")

    # 2. Define the Source Table (Reading from Kafka)
    # We use SQL syntax because it's much easier to write Window aggregations
    t_env.execute_sql(f"""
        CREATE TABLE bookings (
            event_id STRING,
            ticket_count INT,
            proc_time AS PROCTIME()
        ) WITH (
            'connector' = 'kafka',
            'topic' = '{source_topic}',
            'properties.bootstrap.servers' = '{kafka_brokers}',
            'properties.group.id' = 'flink-analytics-group',
            'format' = 'json',
            'scan.startup.mode' = 'latest-offset'
        )
    """)

    # 3. Define the Sink Table (Writing Results back to Kafka)
    t_env.execute_sql(f"""
        CREATE TABLE results (
            event_id STRING,
            window_end TIMESTAMP(3),
            total_tickets BIGINT
        ) WITH (
            'connector' = 'kafka',
            'topic' = '{sink_topic}',
            'properties.bootstrap.servers' = '{kafka_brokers}',
            'format' = 'json'
        )
    """)

    # 4. The Logic: Tumbling Window Aggregation (1 Minute)
    # "Count tickets per event every 1 minute"
    t_env.execute_sql("""
        INSERT INTO results
        SELECT 
            event_id,
            TUMBLE_END(proc_time, INTERVAL '1' MINUTE) as window_end,
            SUM(ticket_count) as total_tickets
        FROM bookings
        GROUP BY 
            event_id,
            TUMBLE(proc_time, INTERVAL '1' MINUTE)
    """)

if __name__ == '__main__':
    log_processing()