import os
import json
import time
import logging
import threading
from flask import Flask, request, jsonify
from kafka import KafkaProducer
from prometheus_flask_exporter import PrometheusMetrics

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

app = Flask(__name__)

# Initialize Prometheus Metrics
metrics = PrometheusMetrics(app)
# Add default metrics
metrics.info('booking_service_info', 'Booking Service Information', version='1.0.0')

# Get Kafka Broker URL from Environment Variable (Set by Kubernetes later)
# Defaulting to localhost for local testing, but K8s will overwrite this.
KAFKA_BROKERS = os.environ.get('KAFKA_BROKERS', 'localhost:9092')
TOPIC_NAME = 'ticket-bookings'

# Initialize Kafka Producer
# We add a retry loop because Kafka might take a few seconds to wake up
producer = None
def get_kafka_producer():
    global producer
    if producer is None:
        try:
            producer = KafkaProducer(
                bootstrap_servers=KAFKA_BROKERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            print(f"Connected to Kafka at {KAFKA_BROKERS}")
        except Exception as e:
            print(f"Error connecting to Kafka: {e}")
    return producer

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/book', methods=['POST'])
def book_ticket():
    data = request.json
    
    # Basic Validation
    if not data or 'user_id' not in data or 'event_id' not in data:
        return jsonify({"error": "Invalid request. Missing user_id or event_id"}), 400

    # Create the booking event message
    booking_event = {
        "event_id": data['event_id'],
        "user_id": data['user_id'],
        "ticket_count": data.get('ticket_count', 1),
        "timestamp": time.time()
    }
    logging.info("Booking request received: %s", booking_event)

    # Send to Kafka
    kp = get_kafka_producer()
    if kp:
        kp.send(TOPIC_NAME, booking_event)
        return jsonify({"message": "Booking request received!", "status": "queued"}), 202
    else:
        return jsonify({"error": "Booking system currently unavailable (Kafka Error)"}), 500


def _heartbeat_loop():
    """Continuously emit a lightweight heartbeat log so Loki always has data."""
    interval = int(os.environ.get("HEARTBEAT_SECONDS", "60"))
    while True:
        logging.info("[heartbeat] booking-service alive | kafka=%s", KAFKA_BROKERS)
        time.sleep(interval)


threading.Thread(target=_heartbeat_loop, daemon=True).start()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)