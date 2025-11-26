// Load Testing Script using k6
// This satisfies Assignment Requirement (h): Load testing to validate HPA scaling

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '1m', target: 10 },   // Ramp up to 10 users over 1 minute
    { duration: '3m', target: 50 },   // Ramp up to 50 users over 3 minutes
    { duration: '5m', target: 100 },  // Ramp up to 100 users over 5 minutes (this should trigger HPA)
    { duration: '3m', target: 150 },  // Peak load: 150 users (max stress test)
    { duration: '2m', target: 50 },   // Ramp down to 50 users
    { duration: '1m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.1'],    // Less than 10% of requests should fail
    errors: ['rate<0.1'],              // Error rate should be less than 10%
  },
};

// Replace with your actual LoadBalancer URL
const BASE_URL = __ENV.FRONTEND_URL || 'http://ab281cfd51be84e1aa3f813cfc6d4a85-918774444.us-east-1.elb.amazonaws.com';

export default function () {
  // Test 1: Homepage
  let res = http.get(BASE_URL);
  check(res, {
    'homepage status is 200': (r) => r.status === 200,
  }) || errorRate.add(1);
  sleep(1);

  // Test 2: Register User
  const registerPayload = JSON.stringify({
    name: `TestUser_${__VU}_${Date.now()}`,
    email: `testuser${__VU}_${Date.now()}@example.com`,
  });
  
  res = http.post(`${BASE_URL}/api/users/register`, registerPayload, {
    headers: { 'Content-Type': 'application/json' },
  });
  
  check(res, {
    'user registration status is 200': (r) => r.status === 200,
    'user registration returns user_id': (r) => r.json('user_id') !== undefined,
  }) || errorRate.add(1);
  
  const userId = res.json('user_id');
  sleep(1);

  // Test 3: Get Events
  res = http.get(`${BASE_URL}/api/events`);
  check(res, {
    'get events status is 200': (r) => r.status === 200,
    'events list is not empty': (r) => r.json().length > 0,
  }) || errorRate.add(1);
  
  const events = res.json();
  sleep(1);

  // Test 4: Book Ticket (if we have events)
  if (events && events.length > 0 && userId) {
    const eventId = events[0].event_id;
    const bookingPayload = JSON.stringify({
      user_id: userId,
      event_id: eventId,
      ticket_count: Math.floor(Math.random() * 3) + 1, // Random 1-3 tickets
    });
    
    res = http.post(`${BASE_URL}/api/bookings/book`, bookingPayload, {
      headers: { 'Content-Type': 'application/json' },
    });
    
    check(res, {
      'booking status is 200': (r) => r.status === 200,
      'booking returns booking_id': (r) => r.json('booking_id') !== undefined,
    }) || errorRate.add(1);
  }
  
  sleep(2);

  // Test 5: Get User Bookings
  if (userId) {
    res = http.get(`${BASE_URL}/api/users/${userId}/bookings`);
    check(res, {
      'get bookings status is 200': (r) => r.status === 200,
    }) || errorRate.add(1);
  }
  
  sleep(1);

  // Test 6: Service Health Check
  res = http.get(`${BASE_URL}/api/health`);
  check(res, {
    'health check status is 200': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  sleep(2);
}

export function handleSummary(data) {
  return {
    'load-test-summary.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options) {
  return `
  ✅ Load Test Summary
  ═══════════════════════════════════════════════════
  
  📊 Request Metrics:
  - Total Requests: ${data.metrics.http_reqs.values.count}
  - Request Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)} req/s
  - Failed Requests: ${data.metrics.http_req_failed.values.rate.toFixed(2)}%
  
  ⏱️  Response Time:
  - Avg: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms
  - Min: ${data.metrics.http_req_duration.values.min.toFixed(2)}ms
  - Max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms
  - p(95): ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms
  - p(99): ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms
  
  👥 Virtual Users:
  - Peak VUs: ${data.metrics.vus_max.values.max}
  
  ❌ Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%
  
  ═══════════════════════════════════════════════════
  `;
}

