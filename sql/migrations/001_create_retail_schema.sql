BEGIN;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version       VARCHAR(100) PRIMARY KEY,
    applied_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS customers (
    customer_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    phone         VARCHAR(30),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT customers_email_not_blank
        CHECK (LENGTH(TRIM(email)) > 0)
);

CREATE TABLE IF NOT EXISTS products (
    product_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku           VARCHAR(64) NOT NULL UNIQUE,
    product_name  VARCHAR(255) NOT NULL,
    category      VARCHAR(100),
    unit_price    NUMERIC(12, 2) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT products_price_nonnegative CHECK (unit_price >= 0),
    CONSTRAINT products_sku_not_blank
        CHECK (LENGTH(TRIM(sku)) > 0),
    CONSTRAINT products_name_not_blank
        CHECK (LENGTH(TRIM(product_name)) > 0)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number   VARCHAR(64) NOT NULL UNIQUE,
    customer_id    BIGINT NOT NULL REFERENCES customers(customer_id),
    order_date     TIMESTAMPTZ NOT NULL,
    order_status   VARCHAR(20) NOT NULL DEFAULT 'placed',
    currency       CHAR(3) NOT NULL DEFAULT 'USD',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT orders_status_valid
        CHECK (order_status IN (
            'placed', 'processing', 'shipped',
            'delivered', 'cancelled', 'returned'
        )),
    CONSTRAINT orders_currency_format
        CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT orders_number_not_blank
        CHECK (LENGTH(TRIM(order_number)) > 0)
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id          BIGINT NOT NULL
        REFERENCES orders(order_id) ON DELETE CASCADE,
    line_number       INTEGER NOT NULL,
    product_id        BIGINT NOT NULL REFERENCES products(product_id),
    quantity          INTEGER NOT NULL,
    unit_price        NUMERIC(12, 2) NOT NULL,
    discount_amount   NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT order_items_pk PRIMARY KEY (order_id, line_number),
    CONSTRAINT order_items_line_positive CHECK (line_number > 0),
    CONSTRAINT order_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT order_items_price_nonnegative CHECK (unit_price >= 0),
    CONSTRAINT order_items_discount_nonnegative
        CHECK (discount_amount >= 0),
    CONSTRAINT order_items_discount_within_line_total
        CHECK (discount_amount <= quantity * unit_price)
);

-- PostgreSQL does not automatically index the referencing side of foreign keys.
CREATE INDEX IF NOT EXISTS idx_orders_customer_date
    ON orders (customer_id, order_date DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_date
    ON orders (order_status, order_date DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_product
    ON order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_products_category_active
    ON products (category, is_active);

INSERT INTO schema_migrations (version)
VALUES ('001_create_retail_schema')
ON CONFLICT (version) DO NOTHING;

COMMIT;
