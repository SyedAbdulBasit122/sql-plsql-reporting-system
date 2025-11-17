-- ============================================================================
-- PL/SQL PROCEDURES - BUSINESS LOGIC & REPORTING
-- Features: Transaction handling, error management, dynamic SQL
-- ============================================================================

-- PROCEDURE 1: Generate Monthly Sales Report
CREATE OR REPLACE PROCEDURE generate_monthly_sales_report (
    p_month IN DATE,
    p_report_id OUT NUMBER
) AS
    v_start_date DATE;
    v_end_date DATE;
    v_total_revenue NUMBER;
    v_order_count NUMBER;
    v_record_count NUMBER := 0;
BEGIN
    -- Set date range
    v_start_date := TRUNC(p_month, 'MM');
    v_end_date := ADD_MONTHS(v_start_date, 1) - 1;
    
    -- Create report record
    INSERT INTO reports (report_type, report_month, created_date)
    VALUES ('MONTHLY_SALES', v_start_date, SYSDATE)
    RETURNING report_id INTO p_report_id;
    
    -- Aggregate sales data
    SELECT COUNT(*), SUM(amount)
    INTO v_order_count, v_total_revenue
    FROM orders
    WHERE order_date BETWEEN v_start_date AND v_end_date;
    
    -- Insert aggregated results
    INSERT INTO report_details (report_id, metric_name, metric_value)
    VALUES (p_report_id, 'Total Revenue', v_total_revenue);
    
    INSERT INTO report_details (report_id, metric_name, metric_value)
    VALUES (p_report_id, 'Order Count', v_order_count);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Report ' || p_report_id || ' generated successfully');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END generate_monthly_sales_report;
/

-- PROCEDURE 2: Update Customer Lifetime Value Cache
CREATE OR REPLACE PROCEDURE update_customer_ltv_cache AS
    v_batch_size NUMBER := 1000;
    v_processed NUMBER := 0;
BEGIN
    -- Truncate cache table
    EXECUTE IMMEDIATE 'TRUNCATE TABLE customer_ltv_cache';
    
    -- Insert aggregated CLV data
    INSERT INTO customer_ltv_cache (
        customer_id, customer_name, order_count, 
        total_revenue, avg_order_value, last_order_date
    )
    SELECT 
        c.customer_id,
        c.customer_name,
        COUNT(o.order_id),
        SUM(oi.quantity * oi.unit_price),
        AVG(oi.quantity * oi.unit_price),
        MAX(o.order_date)
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_name;
    
    v_processed := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Updated ' || v_processed || ' customer records');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Cache update failed: ' || SQLERRM);
END update_customer_ltv_cache;
/

-- PROCEDURE 3: Archive Historical Data
CREATE OR REPLACE PROCEDURE archive_old_orders (
    p_archive_date IN DATE
) AS
    v_rows_archived NUMBER := 0;
BEGIN
    -- Archive orders older than specified date
    INSERT INTO orders_archive
    SELECT * FROM orders
    WHERE order_date < p_archive_date;
    
    v_rows_archived := SQL%ROWCOUNT;
    
    -- Delete archived orders
    DELETE FROM orders
    WHERE order_date < p_archive_date;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Archived ' || v_rows_archived || ' orders');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END archive_old_orders;
/

-- PROCEDURE 4: Calculate Product Rankings
CREATE OR REPLACE PROCEDURE calculate_product_rankings AS
BEGIN
    MERGE INTO product_rankings pr
    USING (
        SELECT 
            p.product_id,
            ROW_NUMBER() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) as rank,
            SUM(oi.quantity) as total_qty,
            SUM(oi.quantity * oi.unit_price) as total_revenue
        FROM products p
        LEFT JOIN order_items oi ON p.product_id = oi.product_id
        WHERE oi.order_id IN (SELECT order_id FROM orders WHERE order_date >= TRUNC(SYSDATE, 'MM'))
        GROUP BY p.product_id
    ) src
    ON (pr.product_id = src.product_id)
    WHEN MATCHED THEN
        UPDATE SET pr.rank = src.rank, pr.total_qty = src.total_qty, pr.total_revenue = src.total_revenue
    WHEN NOT MATCHED THEN
        INSERT (product_id, rank, total_qty, total_revenue, last_updated)
        VALUES (src.product_id, src.rank, src.total_qty, src.total_revenue, SYSDATE);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Product rankings updated');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END calculate_product_rankings;
/
