CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS hotel_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    hotel_id VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    checkin_date DATE NOT NULL,
    checkout_date DATE NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT hotel_bookings_checkout_after_checkin
        CHECK (checkout_date > checkin_date)
);

CREATE TABLE IF NOT EXISTS booking_events (
    id BIGSERIAL PRIMARY KEY,
    booking_id UUID NOT NULL REFERENCES hotel_bookings(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Supports the assessment query's city equality filter and created_at range filter,
-- with org_id/status available for grouping from the index where beneficial.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_org_status
    ON hotel_bookings (city, created_at, org_id, status)
    INCLUDE (amount);

CREATE INDEX IF NOT EXISTS idx_booking_events_booking_created
    ON booking_events (booking_id, created_at DESC);
