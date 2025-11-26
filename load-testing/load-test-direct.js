// Alternative k6 Load Test - Direct Service Testing
// This script tests services directly via port-forwarding if frontend LoadBalancer is not working

import http from 'k6/http';
import { check, sleep } from 'k6';

// ⚠️ UPDATE THESE WITH YOUR SERVICE IPs
// Get these by running: kubectl get svc -n default
const BOOKING_SERVICE_URL = 'http://booking-service.default.svc.cluster.local:5000';
const USER_SERVICE_URL = 'http://user-service.default.svc.cluster.local:3000';
const EVENT_CATALOG_URL = 'http://event-catalog.default.svc.cluster.local:5000';

// Simplified load test - focuses on booking service (CPU intensive)
export const options = {
  stages: [
    { duration: '1m', target: 20 },   // Warm up
    { duration: '3m', target: 50 },   // Trigger HPA
    { duration: '2m', target: 100 },  // Peak load
    { duration: '2m', target: 50 },   // Scale down
    { duration: '1m', target: 0 },    // Complete
  ],
};

export default function () {
  // Focus on booking service (this will trigger CPU-based HPA)
  let bookingPayload = JSON.stringify({
    event_id: Math.floor(Math.random() * 5) + 1,
    user_id: `load-test-user-${__VU}`,
    ticket_count: 1,
  });

  let bookingRes = http.post(`${BOOKING_SERVICE_URL}/book`, bookingPayload, {
    headers: { 'Content-Type': 'application/json' },
  });
  
  check(bookingRes, {
    'booking successful': (r) => r.status === 200,
  });

  sleep(1);
}

