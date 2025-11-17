-- ============================================================================
-- LEGACY QUERIES - BEFORE OPTIMIZATION
-- Issues: Missing indexes, N+1 queries, subquery materialization problems
-- Performance Impact: Queries timeout on large datasets
-- ============================================================================

-- LEGACY QUERY 1: Sales Report by Region (INEFFICIENT)
-- Problem: Nested subqueries, no index hints, cartesian join risk
SELECT 
    r.region_id,
    r.region_name,
    (SELECT COUNT(*) FROM orders o WHERE o.region_id = r.region_id) as order_count,
    (SELECT SUM(o.amount) FROM orders o WHERE o.region_id = r.region_id) as total_revenue,
    (SELECT AVG(o.amount) FROM orders o WHERE o.region_id = r.region_id) as avg_order_value
FROM regions r
WHERE EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.region_id = r.region_id 
    AND o.order_date >= TRUNC(SYSDATE, 'YYYY')
);

-- LEGACY QUERY 2: Customer Lifetime Value (SLOW JOIN)
-- Problem: Missing indexes on foreign keys, no query hints
SELECT 
    c.customer_id,
    c.customer_name,
    o.order_id,
    o.order_date,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price) as line_total
FROM customers c
FULL OUTER JOIN orders o ON c.customer_id = o.customer_id
FULL OUTER JOIN order_items oi ON o.order_id = oi.order_id
WHERE c.customer_id IS NOT NULL;

-- LEGACY QUERY 3: Product Performance (N+1 PROBLEM)
-- Problem: Multiple subqueries without aggregation
SELECT 
    p.product_id,
    p.product_name,
    (SELECT COUNT(*) FROM order_items oi WHERE oi.product_id = p.product_id) as times_sold,
    (SELECT SUM(oi.quantity) FROM order_items oi WHERE oi.product_id = p.product_id) as total_quantity,
    (SELECT MAX(o.order_date) FROM order_items oi JOIN orders o ON oi.order_id = o.order_id WHERE oi.product_id = p.product_id) as last_sold
FROM products p;

-- LEGACY QUERY 4: Category Comparison (NO PARTITION PRUNING)
-- Problem: Full table scans, no window functions for ranking
SELECT * FROM (
    SELECT 
        c.category_id,
        c.category_name,
        p.product_id,
        p.product_name,
        SUM(oi.quantity * oi.unit_price) as revenue
    FROM categories c
    JOIN products p ON c.category_id = p.category_id
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY c.category_id, c.category_name, p.product_id, p.product_name
)
WHERE revenue > (SELECT AVG(revenue) FROM (
    SELECT SUM(oi.quantity * oi.unit_price) as revenue
    FROM order_items oi
    GROUP BY oi.product_id
))
ORDER BY revenue DESC;

-- LEGACY QUERY 5: Monthly Sales Trend (MISSING WINDOW FUNCTION)
-- Problem: Complex self-joins instead of window functions
SELECT 
    TRUNC(o1.order_date, 'MM') as month,
    SUM(o1.amount) as monthly_revenue
FROM orders o1
WHERE o1.order_date >= ADD_MONTHS(SYSDATE, -12)
GROUP BY TRUNC(o1.order_date, 'MM')
HAVING SUM(o1.amount) > (
    SELECT AVG(monthly_revenue)
    FROM (
        SELECT SUM(o2.amount) as monthly_revenue
        FROM orders o2
        WHERE o2.order_date >= ADD_MONTHS(SYSDATE, -24)
        GROUP BY TRUNC(o2.order_date, 'MM')
    )
)
ORDER BY month DESC;
