-- Deterministic, repeatable seed: 120 bookings across 4 orgs, 5 cities, and 4 statuses.
INSERT INTO hotel_bookings
    (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
    ('10000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
    ('20000000-0000-4000-8000-' || lpad(((g - 1) % 4 + 1)::text, 12, '0'))::uuid,
    'hotel-' || ((g - 1) % 18 + 1),
    (ARRAY['delhi', 'mumbai', 'chennai', 'bengaluru', 'hyderabad'])[((g - 1) % 5) + 1],
    CURRENT_DATE + ((g % 60) - 20),
    CURRENT_DATE + ((g % 60) - 17),
    (2500 + (g * 137 % 18000))::numeric(12,2),
    (ARRAY['confirmed', 'cancelled', 'pending', 'completed'])[((g - 1) % 4) + 1],
    NOW() - ((g % 55) || ' days')::interval
FROM generate_series(1, 120) AS g
ON CONFLICT (id) DO NOTHING;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    b.id,
    event.event_type,
    jsonb_build_object('source', 'assessment-seed', 'booking_status', b.status),
    b.created_at + interval '5 minutes'
FROM hotel_bookings b
JOIN LATERAL (
    SELECT unnest(ARRAY['booking_created', 'payment_checked']) AS event_type
) event ON true
WHERE substring(b.id::text from 29 for 12)::bigint % 3 = 0
ON CONFLICT DO NOTHING;
