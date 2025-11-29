/* ASSIGNMENT 2 */
/* SECTION 2 */

-- COALESCE
/* 1. Our favourite manager wants a detailed long list of products, but is afraid of tables! 
We tell them, no problem! We can produce a list with all of the appropriate details. 

Using the following syntax you create our super cool and not at all needy manager a list:

SELECT 
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product


But wait! The product table has some bad data (a few NULL values). 
Find the NULLs and then using COALESCE, replace the NULL with a blank for the first column with
nulls, and 'unit' for the second column with nulls. 

**HINT**: keep the syntax the same, but edited the correct components with the string. 
The `||` values concatenate the columns into strings. 
Edit the appropriate columns -- you're making two edits -- and the NULL rows will be fixed. 
All the other rows will remain the same. */

SELECT 
    COALESCE(product_name, '') 
    || ', ' || COALESCE(product_size, '') 
    || ' (' || COALESCE(product_qty_type, 'unit') || ')'
FROM product;


--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s  
visits to the farmer’s market (labeling each market date with a different number). 
Each customer’s first visit is labeled 1, second visit is labeled 2, etc. 

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer 
(without purchase details) and number those visits. 
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */

SELECT
  cp.*,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY market_date, transaction_time) AS visit_number
FROM customer_purchases cp
ORDER BY customer_id, market_date, transaction_time;

--1B) Number unique market_date visits per customer (1,2,3... for unique dates)

SELECT
  customer_id,
  market_date,
  DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY market_date) AS visit_number
FROM (
  SELECT DISTINCT customer_id, market_date
  FROM customer_purchases
) t
ORDER BY customer_id, market_date;

/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1, 
then write another query that uses this one as a subquery (or temp table) and filters the results to 
only the customer’s most recent visit. */

WITH visits_rev AS (
  SELECT
    cp.*,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY market_date DESC, transaction_time DESC) AS rev_visit_number
  FROM customer_purchases cp
)
-- Get only each customer's most recent visit
SELECT *
FROM visits_rev
WHERE rev_visit_number = 1
ORDER BY customer_id;


/* 3. Using a COUNT() window function, include a value along with each row of the 
customer_purchases table that indicates how many different times that customer has purchased that product_id. */

-- 3a) Count of transactions per customer & product
SELECT
  cp.*,
  COUNT(*) OVER (PARTITION BY customer_id, product_id) AS times_purchased_transactions
FROM customer_purchases cp
ORDER BY customer_id, product_id, market_date, transaction_time;

-- 3b) Count of distinct market_date purchases per customer & product
-- (some SQL engines disallow COUNT(DISTINCT) as a window; this uses a derived table approach)
SELECT
  cp.*,
  pd.purchase_dates_count
FROM customer_purchases cp
JOIN (
  SELECT customer_id, product_id, COUNT(*) AS purchase_dates_count
  FROM (
    SELECT DISTINCT customer_id, product_id, market_date
    FROM customer_purchases
  ) x
  GROUP BY customer_id, product_id
) pd
  ON cp.customer_id = pd.customer_id
 AND cp.product_id = pd.product_id
ORDER BY cp.customer_id, cp.product_id, cp.market_date;

-- String manipulations
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic". 
These are separated from the product name with a hyphen. 
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL. 
Remove any trailing or leading whitespaces. Don't just use a case statement for each product! 

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

SELECT
  product_id,
  product_name,
  CASE
    WHEN INSTR(product_name, '-') > 0
    THEN TRIM(SUBSTR(product_name, INSTR(product_name, '-') + 1))
    ELSE NULL
  END AS description
FROM product
ORDER BY product_id;

/* 2. Filter the query to show any product_size value that contain a number with REGEXP. */

SELECT *
FROM product
WHERE product_size REGEXP '[0-9]'
ORDER BY product_id;

-- UNION
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following: 
1) Create a CTE/Temp Table to find sales values grouped dates; 
2) Create another CTE/Temp table with a rank windowed function on the previous query to create 
"best day" and "worst day"; 
3) Query the second temp table twice, once for the best day, once for the worst day, 
with a UNION binding them. */

WITH daily_sales AS (
  SELECT
    market_date,
    SUM(COALESCE(quantity, 0) * COALESCE(cost_to_customer_per_qty, 0)) AS total_sales
  FROM customer_purchases
  GROUP BY market_date
),
ranked AS (
  SELECT
    market_date,
    total_sales,
    RANK() OVER (ORDER BY total_sales DESC) AS rank_desc,
    RANK() OVER (ORDER BY total_sales ASC)  AS rank_asc
  FROM daily_sales
)
-- Best day(s)
SELECT 'best' AS kind, market_date, total_sales
FROM ranked
WHERE rank_desc = 1

UNION

-- Worst day(s)
SELECT 'worst' AS kind, market_date, total_sales
FROM ranked
WHERE rank_asc = 1

ORDER BY kind DESC, market_date;


/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */

WITH cust_count AS (
  SELECT COUNT(*) AS customer_count FROM customer
),
vendor_products AS (
  -- take distinct vendor/product combos from vendor_inventory, along with price
  SELECT vendor_id, product_id, AVG(COALESCE(original_price, 0)) AS original_price
  FROM vendor_inventory
  GROUP BY vendor_id, product_id
)
SELECT
  v.vendor_name,
  p.product_name,
  5 * c.customer_count * COALESCE(vp.original_price, 0) AS projected_revenue
FROM vendor_products vp
JOIN vendor v ON v.vendor_id = vp.vendor_id
JOIN product p ON p.product_id = vp.product_id
CROSS JOIN cust_count c
ORDER BY v.vendor_name, p.product_name;

-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */

CREATE TABLE product_units AS
SELECT
  product_id,
  product_name,
  product_size,
  product_category_id,
  product_qty_type,
  CURRENT_TIMESTAMP AS snapshot_timestamp
FROM product
WHERE product_qty_type = 'unit';

/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */

INSERT INTO product_units (product_id, product_name, product_size, product_category_id, product_qty_type, snapshot_timestamp)
VALUES (9999, 'Apple Pie', '1 pie', 1, 'unit', CURRENT_TIMESTAMP);

-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/

DELETE FROM product_units
WHERE product_id = 9999
  AND snapshot_timestamp < (
    SELECT MAX(snapshot_timestamp) FROM (SELECT * FROM product_units) AS t WHERE t.product_id = 9999
  );


-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT;

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */

ALTER TABLE product_units
ADD current_quantity INT;

UPDATE product_units pu
LEFT JOIN (
  -- latest quantity per product (most recent market_date). If several vendors exist, this picks the vendor row(s) on the max date;
  -- if you want vendor-specific logic, adjust accordingly.
  SELECT vi.product_id, COALESCE(vi.quantity, 0) AS last_quantity
  FROM vendor_inventory vi
  JOIN (
    SELECT product_id, MAX(market_date) AS max_date
    FROM vendor_inventory
    GROUP BY product_id
  ) latest ON vi.product_id = latest.product_id AND vi.market_date = latest.max_date
) vlast ON pu.product_id = vlast.product_id
SET pu.current_quantity = COALESCE(vlast.last_quantity, 0);


