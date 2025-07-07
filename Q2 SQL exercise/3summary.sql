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
),

-- carve out opening blaance
OpeningBalance AS (
    SELECT
        Amount_EUR
    FROM JoinedWithFX
    WHERE Category = 'Opening Balance'
    LIMIT 1
),

-- calculate total inflow and outflow(excecpt opening balance)
CashFlows AS (
    SELECT
        SUM(CASE WHEN Amount_EUR > 0 AND Category != 'Opening Balance' THEN Amount_EUR ELSE 0 END) AS Total_Inflows,
        SUM(CASE WHEN Amount_EUR < 0 THEN Amount_EUR ELSE 0 END) AS Total_Outflows
    FROM JoinedWithFX
)

-- make summary table
SELECT
    ob.Amount_EUR AS Opening_Balance,
    cf.Total_Inflows,
    cf.Total_Outflows,
    (ob.Amount_EUR + cf.Total_Inflows + cf.Total_Outflows) AS Closing_Balance
FROM OpeningBalance ob
CROSS JOIN CashFlows cf;

-- conclusion
-- inflow(2.8M) was less than outflow(4.7M) hence 1.9M decrease in closing balance(2.8M) compare to opening balance(4.7M)
-- There are several possibilities for this decrease
-- 1. outflow from payroll, supplier payments and intercompany increased; 
--    look up main drivers for payroll and supplier payments, sudden increase compare to previous periods
--    look up main drivers for intercompany, it can be positive amount but not in this period
-- 2. inflow from receivable;
--    look up main drivers for receivables, it may be decreased compare to previous periods
-- cf)I ran several more qurries comparing categories against weekday, week number and currencies but couldn't find adequate explanation
