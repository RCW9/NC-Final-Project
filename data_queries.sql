'This query provides the number of units sold by staff and month,
 percentage of total sales by employee, each month
 and month on month employee sales growth.'

WITH employee_sales AS (
  SELECT
    dim_staff.first_name || ' ' || dim_staff.last_name AS employee,
    to_char(fact_sales_order.created_date, 'YYYY-MM') AS date,
    SUM(fact_sales_order.units_sold) AS employee_monthly_units_sold
  FROM
    project_team_4.fact_sales_order
    JOIN dim_staff ON fact_sales_order.sales_staff_id = dim_staff.staff_id
  GROUP BY
    employee,
    date
),
previous_months_sales AS (
  SELECT
    employee,
    date,
    employee_monthly_units_sold,
    CAST(
      LAG(employee_monthly_units_sold) OVER (
        PARTITION BY employee
        ORDER BY
          date
      ) AS numeric
    ) AS previous_months_units_sold
  FROM
    employee_sales
)
SELECT
  employee,
  date,
  employee_monthly_units_sold,
  ROUND(
    employee_monthly_units_sold / SUM(employee_monthly_units_sold) OVER (PARTITION BY date) * 100,
    2
  ) AS percentage_of_total_monthly_sales,
  CASE WHEN previous_months_units_sold IS NULL THEN 0 ELSE ROUND(
    CAST(
      (
        employee_monthly_units_sold - previous_months_units_sold
      ) / previous_months_units_sold * 100 AS numeric
    ),
    2
  ) END AS employee_sales_monthly_percentage_change
FROM
  previous_months_sales
ORDER BY
  date,
  employee_monthly_units_sold DESC;


'This query provides the amount of unpaid sales by currency and company
and the average days overdue of unpaid late invoices.'

SELECT
  dim_counterparty.counterparty_legal_name,
  dim_currency.currency_code,
  SUM(
    CASE WHEN fact_payment.paid = False
    AND fact_payment.payment_type_id = 1 THEN fact_payment.payment_amount ELSE 0 END
  ) AS total_amount_unpaid_sales,
  ROUND(
    AVG(
      CASE WHEN fact_payment.paid = False
      AND fact_payment.payment_type_id = 1
      AND DATE_PART('day', now() - fact_payment.payment_date) > 0 THEN (
        CAST(
          DATE_PART('day', now() - fact_payment.payment_date) AS NUMERIC
        )
      ) END
    )
  ) AS average_days_overdue
FROM
  project_team_4.fact_payment
  JOIN dim_counterparty ON fact_payment.counterparty_id = dim_counterparty.counterparty_id
  JOIN dim_currency ON fact_payment.currency_id = dim_currency.currency_id
GROUP BY
  dim_counterparty.counterparty_legal_name,
  dim_currency.currency_code
ORDER BY
  dim_counterparty.counterparty_legal_name,
  dim_currency.currency_code ASC;



'This query provide the top 3 designs by number of orders placed
 in each country.'

SELECT
  country AS delivery_country,
  design_name,
  number_orders_placed
FROM
  (
    SELECT
      dim_location.country,
      dim_design.design_name,
      COUNT(*) AS number_orders_placed,
      RANK() OVER (
        PARTITION BY dim_location.country
        ORDER BY
          COUNT(*) DESC
      ) AS ranked_designs
    FROM
      project_team_4.fact_sales_order
      JOIN dim_location ON fact_sales_order.agreed_delivery_location_id = dim_location.location_id
      JOIN dim_design ON fact_sales_order.design_id = dim_design.design_id
    GROUP BY
      dim_location.country,
      dim_design.design_name
  ) AS ranked_designs
WHERE
  ranked_designs <= 3
ORDER BY
  delivery_country,
  number_orders_placed DESC;