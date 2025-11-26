# -*- coding: utf-8 -*-
import os
import sys
import argparse
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings

def log_processing(kafka_brokers):
    # 1. Set up the Flink Environment
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(1) # Keep it simple for the assignment
    
    # Create Table Environment
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    t_env = StreamTableEnvironment.create(env, environment_settings=settings)

    # Kafka topics
    source_topic = 'ticket-bookings'
    sink_topic = 'analytics-results'

    print("=== Starting Flink Analytics Job ===")
    print("Kafka Brokers: {}".format(kafka_brokers))
    print("Source Topic: {}".format(source_topic))
    print("Sink Topic: {}".format(sink_topic))
    print("=====================================")

    # 2. Define the Source Table (Reading from Kafka)
    # We use SQL syntax because it's much easier to write Window aggregations
    t_env.execute_sql("""
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
    """.format(source_topic=source_topic, kafka_brokers=kafka_brokers))

    # 3. Define the Sink Table (Writing Results back to Kafka)
    t_env.execute_sql("""
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
    """.format(sink_topic=sink_topic, kafka_brokers=kafka_brokers))

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
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Flink Analytics Job for Ticket Bookings')
    parser.add_argument('--kafka-brokers', 
                        type=str, 
                        default=os.environ.get('KAFKA_BROKERS', 'localhost:9092'),
                        help='Comma-separated list of Kafka broker addresses')
    
    args = parser.parse_args()
    
    print("Starting with Kafka brokers: {}".format(args.kafka_brokers))
    log_processing(args.kafka_brokers)