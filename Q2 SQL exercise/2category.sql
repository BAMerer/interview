WITH CleanedData AS (
    SELECT
        Transaction_ID,
        DATE(Transaction_date) AS Transaction_date,
        Category,
        Subcategory,
        Amount,
        Currency,
        Transaction_Type,
        ROW_NUMBER() OVER (PARTITION BY Transaction_ID ORDER BY Transaction_date DESC) AS rn
    FROM cashflow_forecast
),
NoDuplicates AS (
    SELECT *
    FROM CleanedData
    WHERE rn = 1
),
JoinedWithFX AS (
    SELECT
        nd.Transaction_ID,
        nd.Transaction_date,
        nd.Category,
        nd.Subcategory,
        nd.Amount,
        nd.Currency,
        nd.Transaction_Type,
        fx.CZK,
        fx.GBP,
        fx.USD,
        CASE 
            WHEN nd.Currency = 'EUR' THEN nd.Amount
            WHEN nd.Currency = 'USD' THEN nd.Amount / fx.USD
            WHEN nd.Currency = 'GBP' THEN nd.Amount / fx.GBP
            WHEN nd.Currency = 'CZK' THEN nd.Amount / fx.CZK
            ELSE NULL
        END AS Amount_EUR
    FROM NoDuplicates nd
    LEFT JOIN FX fx
        ON nd.Transaction_date = DATE(fx.Date)
)

-- sum up the Amount_EUR per Categories
SELECT 
    Category,
    SUM(Amount_EUR) AS Total_Amount
FROM JoinedWithFX
WHERE Category IN ('Receivables', 'Supplier Payments', 'Intercompany', 'Payroll')
GROUP BY Category;


