-- ============================================================================
-- DATABASE TRIGGERS - AUDIT AND AUTOMATION
-- Features: Row-level triggers, audit logging, data integrity
-- ============================================================================

-- TRIGGER 1: Audit Order Changes
CREATE OR REPLACE TRIGGER orders_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
    ELSIF DELETING THEN
        v_action := 'DELETE';
    END IF;
    
    INSERT INTO orders_audit (
        order_id, action, user_name, change_date, 
        old_amount, new_amount, old_status, new_status
    ) VALUES (
        NVL(:NEW.order_id, :OLD.order_id),
        v_action,
        USER,
        SYSDATE,
        :OLD.amount,
        :NEW.amount,
        :OLD.status,
        :NEW.status
    );
END orders_audit_trigger;
/

-- TRIGGER 2: Update Customer Last Order Date
CREATE OR REPLACE TRIGGER update_customer_last_order
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    UPDATE customers
    SET last_order_date = :NEW.order_date,
        order_count = order_count + 1
    WHERE customer_id = :NEW.customer_id;
END update_customer_last_order;
/

-- TRIGGER 3: Validate Order Status Transitions
CREATE OR REPLACE TRIGGER order_status_validation
BEFORE UPDATE ON orders
FOR EACH ROW
DECLARE
    v_valid_transition BOOLEAN := FALSE;
BEGIN
    -- Define valid status transitions
    IF (:OLD.status = 'PENDING' AND :NEW.status IN ('CONFIRMED', 'CANCELLED')) THEN
        v_valid_transition := TRUE;
    ELSIF (:OLD.status = 'CONFIRMED' AND :NEW.status IN ('SHIPPED', 'CANCELLED')) THEN
        v_valid_transition := TRUE;
    ELSIF (:OLD.status = 'SHIPPED' AND :NEW.status IN ('DELIVERED', 'RETURNED')) THEN
        v_valid_transition := TRUE;
    END IF;
    
    IF NOT v_valid_transition THEN
        RAISE_APPLICATION_ERROR(-20001, 'Invalid order status transition from ' || :OLD.status || ' to ' || :NEW.status);
    END IF;
END order_status_validation;
/

-- TRIGGER 4: Inventory Update on Order Items
CREATE OR REPLACE TRIGGER update_inventory_on_order
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock_quantity = stock_quantity - :NEW.quantity,
        last_modified_date = SYSDATE
    WHERE product_id = :NEW.product_id;
    
    -- Check for low stock
    IF :NEW.quantity > (SELECT stock_quantity FROM products WHERE product_id = :NEW.product_id) THEN
        INSERT INTO low_stock_alerts (product_id, current_stock, alert_date)
        VALUES (:NEW.product_id, 
                (SELECT stock_quantity FROM products WHERE product_id = :NEW.product_id),
                SYSDATE);
    END IF;
END update_inventory_on_order;
/
