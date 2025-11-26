import os
from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

# Initialize Prometheus Metrics
metrics = PrometheusMetrics(app)
# Add default metrics
metrics.info('event_catalog_info', 'Event Catalog Service Information', version='1.0.0')

# --- DATABASE CONFIGURATION ---
# We check if we are in AWS by looking for the DB_HOST environment variable.
db_host = os.environ.get('DB_HOST')
db_user = os.environ.get('DB_USER', 'dbadmin')
db_password = os.environ.get('DB_PASSWORD') # We will set this in K8s secrets later
db_name = os.environ.get('DB_NAME', 'ticketdb')

if db_host:
    # Production: Connect to AWS RDS (PostgreSQL)
    app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{db_user}:{db_password}@{db_host}:5432/{db_name}"
    print(f"🔌 Connecting to AWS RDS at {db_host}...")
else:
    # Local Development: Use a local file (SQLite)
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///local_events.db'
    print("⚠️  No DB_HOST found. Using local SQLite database for testing.")

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# --- DATA MODEL ---
class Event(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    date = db.Column(db.String(50), nullable=False)
    venue = db.Column(db.String(100), nullable=False)
    tickets_available = db.Column(db.Integer, default=100)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "date": self.date,
            "venue": self.venue,
            "tickets_available": self.tickets_available
        }

# --- INITIALIZATION ---
# This creates the tables and adds dummy data if the table is empty
with app.app_context():
    try:
        db.create_all()
        if not Event.query.first():
            print("🌱 Seeding database with initial events...")
            db.session.add(Event(name="Coldplay World Tour", date="2025-11-20", venue="Wembley Stadium", tickets_available=5000))
            db.session.add(Event(name="Taylor Swift Eras Tour", date="2025-12-15", venue="MCG", tickets_available=2000))
            db.session.add(Event(name="Ed Sheeran Mathematics", date="2026-01-10", venue="Madison Square Garden", tickets_available=3000))
            db.session.commit()
    except Exception as e:
        print(f"Database connection error (Expected during build phase): {e}")

# --- ROUTES ---
@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/events', methods=['GET'])
def get_events():
    events = Event.query.all()
    return jsonify([e.to_dict() for e in events])

@app.route('/events/<int:event_id>', methods=['GET'])
def get_event_by_id(event_id):
    event = Event.query.get(event_id)
    if event:
        return jsonify(event.to_dict())
    return jsonify({"error": "Event not found"}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)