-- ============================================================================
-- DATABASE INDEXES - PERFORMANCE OPTIMIZATION
-- Critical indexes for query performance and reporting efficiency
-- ============================================================================

-- INDEXES ON ORDERS TABLE
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_region_id ON orders(region_id);
CREATE INDEX idx_orders_region_date ON orders(region_id, order_date);
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);

-- INDEXES ON ORDER_ITEMS TABLE
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_composite ON order_items(product_id, order_id);

-- INDEXES ON PRODUCTS TABLE
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_status ON products(product_status);
CREATE INDEX idx_products_category_status ON products(category_id, product_status);

-- INDEXES ON CUSTOMERS TABLE
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_phone ON customers(phone_number);
CREATE INDEX idx_customers_last_order ON customers(last_order_date);

-- UNIQUE INDEXES
CREATE UNIQUE INDEX idx_customers_email_unique ON customers(email);
CREATE UNIQUE INDEX idx_products_sku_unique ON products(sku);

-- COMPOSITE INDEXES FOR REPORTING
CREATE INDEX idx_report_query_1 ON orders(customer_id, order_date, status, amount);
CREATE INDEX idx_report_query_2 ON order_items(product_id, quantity, unit_price);
CREATE INDEX idx_report_query_3 ON orders(order_date, region_id, customer_id);

-- ANALYZE INDEXES
ANALYZE INDEX idx_orders_customer_id COMPUTE STATISTICS;
ANALYZE INDEX idx_orders_order_date COMPUTE STATISTICS;
ANALYZE INDEX idx_order_items_product_id COMPUTE STATISTICS;

-- VIEW INDEX USAGE STATISTICS
-- SELECT index_name, leaf_blocks, distinct_keys, used FROM v$object_usage;
