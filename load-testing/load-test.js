// k6 Load Test Script for Ticket Booking System
// This script simulates real user traffic to demonstrate HPA scaling

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// ⚠️ UPDATE THIS WITH YOUR FRONTEND EXTERNAL-IP
const BASE_URL = 'http://a7cd6e28f340f4e4c9bb21bd7e1e0a51-1164090834.us-east-1.elb.amazonaws.com';

// Load test configuration
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users over 2 minutes
    { duration: '5m', target: 100 },  // Stay at 100 users for 5 minutes (trigger scaling)
    { duration: '2m', target: 200 },  // Spike to 200 users for 2 minutes
    { duration: '3m', target: 100 },  // Back down to 100 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests should be below 2s
    http_req_failed: ['rate<0.1'],     // Less than 10% of requests should fail
  },
};

// Simulate user behavior
export default function () {
  // 1. Get list of events (event-catalog service)
  let eventsRes = http.get(`${BASE_URL}/api/events`);
  check(eventsRes, {
    'events status is 200': (r) => r.status === 200,
    'events response time < 2s': (r) => r.timings.duration < 2000,
  }) || errorRate.add(1);
  
  sleep(1);

  // 2. Get user info (user-service)
  let userRes = http.get(`${BASE_URL}/api/users/test-user-${__VU}`);
  check(userRes, {
    'user status is 200': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  sleep(1);

  // 3. Book a ticket (booking-service - this will trigger CPU load)
  let bookingPayload = JSON.stringify({
    event_id: Math.floor(Math.random() * 5) + 1,
    user_id: `test-user-${__VU}`,
    ticket_count: 1,
  });

  let bookingRes = http.post(`${BASE_URL}/api/book`, bookingPayload, {
    headers: { 'Content-Type': 'application/json' },
  });
  
  check(bookingRes, {
    'booking status is 200': (r) => r.status === 200,
    'booking response time < 3s': (r) => r.timings.duration < 3000,
  }) || errorRate.add(1);

  sleep(2);
}

// Display summary at the end
export function handleSummary(data) {
  console.log('========================================');
  console.log('  Load Test Summary');
  console.log('========================================');
  console.log(`Total Requests: ${data.metrics.http_reqs.values.count}`);
  console.log(`Failed Requests: ${data.metrics.http_req_failed.values.rate * 100}%`);
  console.log(`Avg Response Time: ${data.metrics.http_req_duration.values.avg}ms`);
  console.log(`P95 Response Time: ${data.metrics.http_req_duration.values['p(95)']}ms`);
  console.log('========================================');
  
  return {
    'load-test-summary.json': JSON.stringify(data, null, 2),
  };
}

